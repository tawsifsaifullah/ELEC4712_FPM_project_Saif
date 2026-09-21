function pupil = fpm_build_pupil(config)
samplePlanePixelSize = config.sensorPixelSize / config.magnification;
fx = ((-config.sensorSize(2) / 2):(config.sensorSize(2) / 2 - 1)) / (config.sensorSize(2) * samplePlanePixelSize);
fy = ((-config.sensorSize(1) / 2):(config.sensorSize(1) / 2 - 1)) / (config.sensorSize(1) * samplePlanePixelSize);
[fxGrid, fyGrid] = meshgrid(fx, fy);
cutoff = config.objectiveNA / config.wavelength;
pupil = double((fxGrid .^ 2 + fyGrid .^ 2) <= cutoff ^ 2);
end
