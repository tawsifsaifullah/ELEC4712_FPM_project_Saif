clear;
close all;
clc;

rootDir = fileparts(mfilename('fullpath'));
addpath(rootDir);

config = fpm_default_config();
dataset = fpm_simulate_dataset(config);
reconstruction = fpm_reconstruct(dataset.intensityStack, config, dataset.ledPositions);

referenceIndex = find([dataset.ledPositions.isBrightfieldReference], 1, 'first');
if isempty(referenceIndex)
    referenceIndex = 1;
end

figure('Name', 'Fourier Ptychographic Microscopy Simulation');
subplot(2, 3, 1);
imagesc(abs(dataset.objectField));
axis image off;
title('Ground truth amplitude');
colormap gray;

subplot(2, 3, 2);
imagesc(angle(dataset.objectField));
axis image off;
title('Ground truth phase');

subplot(2, 3, 3);
imagesc(dataset.intensityStack(:, :, referenceIndex));
axis image off;
title('Reference low-res capture');

subplot(2, 3, 4);
imagesc(reconstruction.amplitude);
axis image off;
title('Reconstructed amplitude');

subplot(2, 3, 5);
imagesc(reconstruction.phase);
axis image off;
title('Reconstructed phase');

subplot(2, 3, 6);
plot(reconstruction.errorHistory, '-o', 'LineWidth', 1.2);
xlabel('Iteration');
ylabel('Mean amplitude error');
title('Reconstruction convergence');
grid on;

disp('Simulation complete.');
disp(['LED captures used: ', num2str(numel(dataset.ledPositions))]);
