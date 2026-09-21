function pupil = fpm_build_pupil(config)
[dfx, dfy] = fpm_get_reconstruction_frequency_step(config);
fx = ((-config.sensorSize(2) / 2):(config.sensorSize(2) / 2 - 1)) * dfx;
fy = ((-config.sensorSize(1) / 2):(config.sensorSize(1) / 2 - 1)) * dfy;
[fxGrid, fyGrid] = meshgrid(fx, fy);
cutoff = config.objectiveNA / config.wavelength;
pupil = double((fxGrid .^ 2 + fyGrid .^ 2) <= cutoff ^ 2);
end
