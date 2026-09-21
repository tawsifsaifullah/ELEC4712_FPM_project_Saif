function dataset = fpm_simulate_dataset(config, objectField)
if nargin < 2 || isempty(objectField)
    objectField = fpm_generate_sample_object(config);
end

ledPositions = fpm_generate_led_positions(config);
pupil = fpm_build_pupil(config);
objectSpectrum = fftshift(fft2(objectField));

imageStack = zeros(config.sensorSize(1), config.sensorSize(2), numel(ledPositions));

for index = 1:numel(ledPositions)
    [rowRange, colRange] = fpm_get_spectrum_patch_ranges(config, ledPositions(index));
    bandLimitedSpectrum = objectSpectrum(rowRange, colRange) .* pupil;
    field = ifft2(ifftshift(bandLimitedSpectrum));
    imageStack(:, :, index) = config.intensityScale * abs(field) .^ 2;
end

dataset.config = config;
dataset.objectField = objectField;
dataset.ledPositions = ledPositions;
dataset.pupil = pupil;
dataset.intensityStack = imageStack;
end
