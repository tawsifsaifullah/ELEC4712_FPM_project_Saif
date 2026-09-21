function [rowRange, colRange] = fpm_get_spectrum_patch_ranges(config, ledPosition)
fftCenterRow = floor(config.reconstructionSize(1) / 2) + 1;
fftCenterCol = floor(config.reconstructionSize(2) / 2) + 1;
patchSize = size(fpm_build_pupil(config));

rowStart = fftCenterRow - floor((patchSize(1) - 1) / 2) + ledPosition.shiftY;
colStart = fftCenterCol - floor((patchSize(2) - 1) / 2) + ledPosition.shiftX;
rowRange = rowStart:(rowStart + patchSize(1) - 1);
colRange = colStart:(colStart + patchSize(2) - 1);
end
