function pupil = fpm_build_pupil(config)
[dfx, dfy] = fpm_get_reconstruction_frequency_step(config);
fx = ((0:config.sensorSize(2) - 1) - floor(config.sensorSize(2) / 2)) * dfx;
fy = ((0:config.sensorSize(1) - 1) - floor(config.sensorSize(1) / 2)) * dfy;
[fxGrid, fyGrid] = meshgrid(fx, fy);
cutoff = config.objectiveNA / config.wavelength;
pupil = double((fxGrid .^ 2 + fyGrid .^ 2) <= cutoff ^ 2);
end
