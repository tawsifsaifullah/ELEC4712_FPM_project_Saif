function dataset = fpm_simulate_dataset(config, objectField)
if nargin < 2 || isempty(objectField)
    objectField = fpm_generate_sample_object(config);
end

ledPositions = fpm_generate_led_positions(config);
pupil = build_pupil(config);
objectSpectrum = fftshift(fft2(objectField));

imageStack = zeros(config.sensorSize(1), config.sensorSize(2), numel(ledPositions));
fftCenterRow = floor(config.reconstructionSize(1) / 2) + 1;
fftCenterCol = floor(config.reconstructionSize(2) / 2) + 1;
halfHeight = floor(config.sensorSize(1) / 2);
halfWidth = floor(config.sensorSize(2) / 2);

for index = 1:numel(ledPositions)
    rowRange = (fftCenterRow - halfHeight + ledPositions(index).shiftY):(fftCenterRow + halfHeight - 1 + ledPositions(index).shiftY);
    colRange = (fftCenterCol - halfWidth + ledPositions(index).shiftX):(fftCenterCol + halfWidth - 1 + ledPositions(index).shiftX);

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

function pupil = build_pupil(config)
samplePlanePixelSize = config.sensorPixelSize / config.magnification;
fx = ((-config.sensorSize(2) / 2):(config.sensorSize(2) / 2 - 1)) / (config.sensorSize(2) * samplePlanePixelSize);
fy = ((-config.sensorSize(1) / 2):(config.sensorSize(1) / 2 - 1)) / (config.sensorSize(1) * samplePlanePixelSize);
[fxGrid, fyGrid] = meshgrid(fx, fy);
cutoff = config.objectiveNA / config.wavelength;
pupil = double((fxGrid .^ 2 + fyGrid .^ 2) <= cutoff ^ 2);
end
