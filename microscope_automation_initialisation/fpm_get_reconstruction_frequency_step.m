function [dfx, dfy] = fpm_get_reconstruction_frequency_step(config)
objectPlanePixelSize = config.sensorPixelSize / (config.magnification * config.upsampleFactor);
dfx = 1 / (config.reconstructionSize(2) * objectPlanePixelSize);
dfy = 1 / (config.reconstructionSize(1) * objectPlanePixelSize);
end
