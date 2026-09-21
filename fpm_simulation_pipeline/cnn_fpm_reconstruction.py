"""
cnn_fpm_reconstruction.py

PyTorch CNN reconstruction prototype for the MATLAB FPM simulator.

What this script does:
1. Starts MATLAB through the MATLAB Engine API.
2. Runs the user's existing generate_fpm.m.
3. Retrieves the 25 simulated low-resolution intensity images and the
   known high-resolution amplitude object.
4. Trains a small CNN/U-Net-style model to map the 25 measurements to
   a high-resolution amplitude reconstruction.
5. Saves the trained PyTorch weights.
6. Runs inference on the same generated measurement stack.

IMPORTANT:
- This is a PROTOTYPE, not a finished thesis-quality training pipeline.
- Your current generate_fpm.m always uses the same Cameraman object and
  zero phase. Therefore this script can demonstrate the MATLAB -> PyTorch
  connection, but it is NOT enough to train a useful generalising CNN.
- For meaningful training, create many different objects/phase maps and
  generate a corresponding FPM stack for each one.
- This first version predicts AMPLITUDE only. Phase can be added as a
  second output channel once the MATLAB forward model contains non-zero
  ground-truth phase.

Requirements:
    MATLAB R2026a
    MATLAB Engine for Python
    Python
    PyTorch
    NumPy
    SciPy (only needed if you later choose MAT-file loading)

Typical use:
    python cnn_fpm_reconstruction.py

The MATLAB Engine must be installed in the Python environment. In a
MATLAB installation, the engine package is normally under:
    <matlabroot>/extern/engines/python

You can install it from a terminal using the Python executable/environment
you intend to use, following MathWorks' MATLAB Engine for Python
installation instructions.
"""

import os
import sys
import time
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import Dataset, DataLoader


# ---------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------

NUM_EPOCHS = 100
LEARNING_RATE = 1e-3
SAVE_FILE = "fpm_cnn_amplitude.pt"

# The original MATLAB simulation produces 64x64 measurements and a
# 1280x1280 high-resolution object with the current parameters.
# To keep this first CNN prototype computationally reasonable, the
# target is resized to 256x256.
TARGET_SIZE = 256

# Number of simulated FPM measurements.
NUM_MEASUREMENTS = 25

DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")


# ---------------------------------------------------------------------
# MATLAB -> Python
# ---------------------------------------------------------------------

def run_matlab_fpm():
    """
    Run the user's existing generate_fpm.m through MATLAB Engine.

    Returns
    -------
    measurements : np.ndarray
        Shape (25, H, W).
    ground_truth_amplitude : np.ndarray
        High-resolution amplitude image.
    """

    try:
        import matlab.engine
    except ImportError as exc:
        raise RuntimeError(
            "\nMATLAB Engine for Python is not installed in this Python "
            "environment.\n\n"
            "Install the MATLAB Engine for Python for your MATLAB "
            "installation, then rerun this script.\n"
        ) from exc

    project_dir = Path(__file__).resolve().parent

    print("Starting MATLAB...")
    eng = matlab.engine.start_matlab()

    try:
        eng.cd(str(project_dir), nargout=0)

        print("Running MATLAB generate_fpm.m ...")
        eng.generate_fpm(nargout=0)

        # Retrieve the MATLAB variables created by system_constants.m
        # and generate_fpm.m.
        images_mat = eng.workspace["imaged_images"]
        intensity_mat = eng.workspace["intensity_image"]

        # MATLAB arrays arrive as nested Python sequences. Convert them.
        measurements = np.asarray(images_mat, dtype=np.float32)

        # MATLAB's stack is H x W x N.
        if measurements.ndim != 3:
            raise RuntimeError(
                f"Expected a 3-D measurement stack, got shape "
                f"{measurements.shape}"
            )

        # Convert to PyTorch/CNN convention: N x H x W.
        measurements = np.transpose(measurements, (2, 0, 1))

        if measurements.shape[0] != NUM_MEASUREMENTS:
            print(
                f"Warning: expected {NUM_MEASUREMENTS} measurements but "
                f"MATLAB returned {measurements.shape[0]}."
            )

        ground_truth_amplitude = np.asarray(
            intensity_mat, dtype=np.float32
        )

    finally:
        eng.quit()

    print(f"MATLAB measurements: {measurements.shape}")
    print(f"MATLAB ground truth:  {ground_truth_amplitude.shape}")

    return measurements, ground_truth_amplitude


# ---------------------------------------------------------------------
# Preprocessing
# ---------------------------------------------------------------------

def normalize_stack(x):
    """Normalize the complete measurement stack to approximately [0, 1]."""
    x = np.maximum(x, 0.0)
    maximum = np.max(x)
    if maximum > 0:
        x = x / maximum
    return x


def resize_target(target, size):
    """Resize a 2-D NumPy target using PyTorch interpolation."""
    tensor = torch.from_numpy(target).float()[None, None, :, :]
    tensor = F.interpolate(
        tensor,
        size=(size, size),
        mode="bilinear",
        align_corners=False,
    )
    return tensor[0, 0].numpy()


# ---------------------------------------------------------------------
# Dataset
# ---------------------------------------------------------------------

class FPMDataset(Dataset):
    """
    Minimal dataset wrapper.

    NOTE:
    This prototype contains one generated FPM example. Repeating the same
    example is useful only for verifying that the CNN can learn the mapping.
    It is NOT a valid generalisation experiment.
    """

    def __init__(self, measurements, target):
        measurements = normalize_stack(measurements)
        target = np.maximum(target, 0.0)

        # Normalize ground-truth amplitude.
        maximum = np.max(target)
        if maximum > 0:
            target = target / maximum

        target = resize_target(target, TARGET_SIZE)

        self.x = torch.from_numpy(measurements).float()
        self.y = torch.from_numpy(target).float().unsqueeze(0)

    def __len__(self):
        # Repeat the same example to demonstrate training mechanics.
        # Replace this with many different FPM examples for real training.
        return 32

    def __getitem__(self, index):
        return self.x, self.y


# ---------------------------------------------------------------------
# CNN
# ---------------------------------------------------------------------

class ConvBlock(nn.Module):
    def __init__(self, in_channels, out_channels):
        super().__init__()

        self.block = nn.Sequential(
            nn.Conv2d(in_channels, out_channels, 3, padding=1),
            nn.ReLU(inplace=True),
            nn.Conv2d(out_channels, out_channels, 3, padding=1),
            nn.ReLU(inplace=True),
        )

    def forward(self, x):
        return self.block(x)


class FPMCNN(nn.Module):
    """
    Small encoder-decoder CNN.

    Input:
        25 x 64 x 64 (with the current MATLAB simulation)

    Output:
        1 x 256 x 256 amplitude image

    The network is intentionally small for the first prototype.
    """

    def __init__(self, input_channels=25):
        super().__init__()

        self.enc1 = ConvBlock(input_channels, 32)
        self.enc2 = ConvBlock(32, 64)
        self.enc3 = ConvBlock(64, 128)

        self.pool = nn.MaxPool2d(2)

        self.bottleneck = ConvBlock(128, 256)

        self.up3 = nn.ConvTranspose2d(256, 128, 2, stride=2)
        self.dec3 = ConvBlock(256, 128)

        self.up2 = nn.ConvTranspose2d(128, 64, 2, stride=2)
        self.dec2 = ConvBlock(128, 64)

        self.up1 = nn.ConvTranspose2d(64, 32, 2, stride=2)
        self.dec1 = ConvBlock(64, 32)

        # 64x64 -> 128x128 -> 256x256
        self.final_up = nn.Sequential(
            nn.ConvTranspose2d(32, 32, 2, stride=2),
            nn.ReLU(inplace=True),
            nn.Conv2d(32, 1, 3, padding=1),
            nn.Sigmoid(),
        )

    def forward(self, x):

        e1 = self.enc1(x)               # 64 x 64
        e2 = self.enc2(self.pool(e1))   # 32 x 32
        e3 = self.enc3(self.pool(e2))   # 16 x 16

        b = self.bottleneck(self.pool(e3))  # 8 x 8

        d3 = self.up3(b)                # 16 x 16
        d3 = torch.cat([d3, e3], dim=1)
        d3 = self.dec3(d3)

        d2 = self.up2(d3)               # 32 x 32
        d2 = torch.cat([d2, e2], dim=1)
        d2 = self.dec2(d2)

        d1 = self.up1(d2)               # 64 x 64
        d1 = torch.cat([d1, e1], dim=1)
        d1 = self.dec1(d1)

        out = self.final_up(d1)          # 256 x 256

        return out


# ---------------------------------------------------------------------
# Training
# ---------------------------------------------------------------------

def train_model(model, dataset):
    loader = DataLoader(
        dataset,
        batch_size=4,
        shuffle=True,
    )

    optimizer = torch.optim.Adam(
        model.parameters(),
        lr=LEARNING_RATE,
    )

    # L1 is a useful simple reconstruction loss.
    criterion = nn.L1Loss()

    model.train()

    for epoch in range(NUM_EPOCHS):

        running_loss = 0.0

        for x, y in loader:

            x = x.to(DEVICE)
            y = y.to(DEVICE)

            optimizer.zero_grad()

            prediction = model(x)

            loss = criterion(prediction, y)

            loss.backward()
            optimizer.step()

            running_loss += loss.item()

        mean_loss = running_loss / len(loader)

        if epoch == 0 or (epoch + 1) % 10 == 0:
            print(
                f"Epoch {epoch + 1:3d}/{NUM_EPOCHS} "
                f"loss = {mean_loss:.6f}"
            )

    return model


# ---------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------

def main():

    print("=" * 70)
    print("FPM MATLAB -> PyTorch CNN reconstruction prototype")
    print("=" * 70)
    print(f"Device: {DEVICE}")
    print()

    # 1. Generate measurements using YOUR MATLAB files.
    measurements, ground_truth = run_matlab_fpm()

    # 2. Build dataset.
    dataset = FPMDataset(
        measurements,
        ground_truth,
    )

    # 3. Build CNN.
    model = FPMCNN(
        input_channels=measurements.shape[0]
    ).to(DEVICE)

    print("\nCNN created.")
    print(
        f"Input:  {measurements.shape[0]} x "
        f"{measurements.shape[1]} x {measurements.shape[2]}"
    )
    print(
        f"Output: 1 x {TARGET_SIZE} x {TARGET_SIZE}"
    )

    # 4. Train.
    print("\nTraining...")
    model = train_model(model, dataset)

    # 5. Save model weights.
    torch.save(
        {
            "model_state_dict": model.state_dict(),
            "input_channels": measurements.shape[0],
            "target_size": TARGET_SIZE,
        },
        SAVE_FILE,
    )

    print(f"\nSaved trained model to: {SAVE_FILE}")

    # 6. Inference.
    model.eval()

    x = dataset.x.unsqueeze(0).to(DEVICE)

    with torch.no_grad():
        prediction = model(x)

    prediction = prediction[0, 0].cpu().numpy()

    print(
        "CNN inference complete. "
        f"Output shape = {prediction.shape}"
    )

    # 7. Save the CNN reconstruction as a NumPy file.
    np.save(
        "cnn_reconstructed_amplitude.npy",
        prediction,
    )

    print("Saved: cnn_reconstructed_amplitude.npy")

    print("\nDone.")
    print(
        "\nIMPORTANT: this first run trains on repeated copies of ONE "
        "Cameraman FPM example. It proves the MATLAB -> PyTorch pipeline "
        "works, but it does not prove generalisation."
    )


if __name__ == "__main__":
    main()
