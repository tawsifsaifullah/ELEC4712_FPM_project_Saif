function pupil = fpm_build_pupil(config)
objectPlanePixelSize = config.sensorPixelSize / (config.magnification * config.upsampleFactor);
dfx = 1 / (config.reconstructionSize(2) * objectPlanePixelSize);
dfy = 1 / (config.reconstructionSize(1) * objectPlanePixelSize);
fx = ((-config.sensorSize(2) / 2):(config.sensorSize(2) / 2 - 1)) * dfx;
fy = ((-config.sensorSize(1) / 2):(config.sensorSize(1) / 2 - 1)) * dfy;
[fxGrid, fyGrid] = meshgrid(fx, fy);
cutoff = config.objectiveNA / config.wavelength;
pupil = double((fxGrid .^ 2 + fyGrid .^ 2) <= cutoff ^ 2);
end
