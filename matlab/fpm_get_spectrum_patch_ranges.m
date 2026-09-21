function [rowRange, colRange] = fpm_get_spectrum_patch_ranges(config, ledPosition)
fftCenterRow = floor(config.reconstructionSize(1) / 2) + 1;
fftCenterCol = floor(config.reconstructionSize(2) / 2) + 1;
halfHeight = floor(config.sensorSize(1) / 2);
halfWidth = floor(config.sensorSize(2) / 2);

rowRange = (fftCenterRow - halfHeight + ledPosition.shiftY):(fftCenterRow + halfHeight - 1 + ledPosition.shiftY);
colRange = (fftCenterCol - halfWidth + ledPosition.shiftX):(fftCenterCol + halfWidth - 1 + ledPosition.shiftX);
end
