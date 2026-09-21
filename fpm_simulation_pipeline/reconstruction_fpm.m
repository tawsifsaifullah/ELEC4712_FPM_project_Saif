%% reconstruct_fpm.m
% Baseline iterative Fourier Ptychographic Microscopy reconstruction.
%
% Run this AFTER generate_fpm.m has produced:
%     imaged_images
% and the variables from system_constants.m are still in the workspace.
%
% The script uses the 25 simulated low-resolution intensity images and
% iteratively builds a high-resolution complex object estimate.

%% Check that the simulated measurements exist
if ~exist('imaged_images','var')
    error('imaged_images was not found. Run generate_fpm.m first.');
end

if ~exist('initial_px','var') || ~exist('sampled_px','var') || ...
   ~exist('wavelength','var') || ~exist('NA','var') || ...
   ~exist('LED_spacing','var') || ~exist('illumination_distance','var') || ...
   ~exist('illumination_layers','var')
    error(['Required variables were not found. Run generate_fpm.m first ', ...
           'so system_constants.m has populated the workspace.']);
end

%% Reconstruction settings
num_iterations = 20;      % Number of complete LED passes
alpha = 0.8;              % Fourier-patch update strength

% Measurements:
% imaged_images(:,:,k) = intensity image from LED k
[Ny, Nx, num_images] = size(imaged_images);

% The original simulation downsamples from initial_px to sampled_px.
% Therefore the simulated high-resolution reconstruction grid is:
scale = round(sampled_px / initial_px);
Nhr_y = Ny * scale;
Nhr_x = Nx * scale;

fprintf('Measurements: %d x %d x %d\n', Ny, Nx, num_images);
fprintf('Reconstruction grid: %d x %d\n', Nhr_y, Nhr_x);

%% Initial high-resolution estimate
% Start from the central-LED measurement, because it has the least
% oblique illumination.
centre_led = ceil(num_images/2);

initial_amplitude = sqrt(max(imaged_images(:,:,centre_led), 0));
initial_amplitude = initial_amplitude ./ (max(initial_amplitude(:)) + eps);

object_estimate = imresize(initial_amplitude, [Nhr_y Nhr_x], 'bilinear');

% Start with zero phase.
object_estimate = complex(object_estimate, zeros(size(object_estimate)));

%% Fourier-domain representation
F = fftshift(fft2(object_estimate));

% Fourier sampling interval in angular spatial frequency [rad/um].
% This matches the physical pixel size used by the reference simulation.
dfx = 2*pi/(Nhr_x * initial_px);
dfy = 2*pi/(Nhr_y * initial_px);

%% Build LED positions
Nled = 2*illumination_layers - 1;

if num_images ~= Nled^2
    warning(['Expected %d images from the LED grid, but found %d. ', ...
             'Continuing using the available images.'], Nled^2, num_images);
end

%% The measured image defines the Fourier patch size
patch_h = Ny;
patch_w = Nx;

half_h = floor(patch_h/2);
half_w = floor(patch_w/2);

% A simple square support for the measured Fourier patch.
% The forward simulation has already applied the objective pupil before
% producing each measurement, so we do not need to apply another hard
% pupil mask here.
pupil_patch = ones(patch_h, patch_w);

%% Pre-compute the Fourier-space centre for every LED
wave_number = 2*pi/wavelength;

kx_pixels = zeros(Nled, Nled);
ky_pixels = zeros(Nled, Nled);

for a = 1:Nled
    for b = 1:Nled

        % Same LED coordinates used in generate_fpm.m
        x_led = (a - illumination_layers) * LED_spacing;
        y_led = (b - illumination_layers) * LED_spacing;

        distance = sqrt(x_led^2 + y_led^2 + illumination_distance^2);

        kx = wave_number * x_led / distance;
        ky = wave_number * y_led / distance;

        % Convert physical wavevector shift to high-resolution Fourier
        % grid pixels.
        kx_pixels(a,b) = kx / dfx;
        ky_pixels(a,b) = ky / dfy;
    end
end

%% Iterative reconstruction
fprintf('\nStarting FPM reconstruction...\n');

for iter = 1:num_iterations

    % Reset image counter for this complete LED scan
    image_index = 0;

    for a = 1:Nled
        for b = 1:Nled

            image_index = image_index + 1;

            if image_index > num_images
                break;
            end

            %% Fourier-patch centre for this illumination angle
            cx = round(Nhr_x/2 + 1 + kx_pixels(a,b));
            cy = round(Nhr_y/2 + 1 + ky_pixels(a,b));

            % Patch boundaries
            x1 = cx - half_w + 1;
            x2 = x1 + patch_w - 1;

            y1 = cy - half_h + 1;
            y2 = y1 + patch_h - 1;

            % Skip an LED if its patch would leave the reconstruction grid.
            if x1 < 1 || x2 > Nhr_x || y1 < 1 || y2 > Nhr_y
                warning('Skipping LED %d: Fourier patch is outside the grid.', image_index);
                continue;
            end

            %% Extract current Fourier patch
            current_patch = F(y1:y2, x1:x2);

            %% Predict the low-resolution complex field
            predicted_field = ifft2(ifftshift(current_patch));

            %% Measured amplitude
            measured_intensity = max(imaged_images(:,:,image_index), 0);
            measured_amplitude = sqrt(measured_intensity);

            %% Enforce the measured amplitude
            predicted_amplitude = abs(predicted_field);

            updated_field = predicted_field .* ...
                (measured_amplitude ./ (predicted_amplitude + eps));

            %% Return to Fourier domain
            updated_patch = fftshift(fft2(updated_field));

            %% Update the corresponding high-resolution Fourier region
            F(y1:y2, x1:x2) = F(y1:y2, x1:x2) + ...
                alpha .* pupil_patch .* (updated_patch - current_patch);

        end
    end

    %% Current object estimate
    object_estimate = ifft2(ifftshift(F));

    fprintf('Iteration %2d / %2d complete\n', iter, num_iterations);

end

%% Final amplitude and phase
reconstructed_amplitude = abs(object_estimate);
reconstructed_phase = angle(object_estimate);

%% Display the reconstruction
figure('Name','FPM Reconstruction');

subplot(1,2,1);
imagesc(reconstructed_amplitude);
axis image off;
colormap gray;
title('Reconstructed amplitude');

subplot(1,2,2);
imagesc(reconstructed_phase);
axis image off;
colormap gray;
title('Reconstructed phase');

%% Save results
save('fpm_reconstruction.mat', ...
     'object_estimate', ...
     'reconstructed_amplitude', ...
     'reconstructed_phase', ...
     'F', ...
     'num_iterations', ...
     'alpha');

fprintf('\nReconstruction finished.\n');
fprintf('Saved results to fpm_reconstruction.mat\n');
