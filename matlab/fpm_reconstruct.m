function reconstruction = fpm_reconstruct(intensityStack, config, ledPositions)
if nargin < 3 || isempty(ledPositions)
    ledPositions = fpm_generate_led_positions(config);
end

pupil = build_pupil(config);
beta = config.beta;
upsampleFactor = config.upsampleFactor;

referenceIndex = find([ledPositions.isBrightfieldReference], 1, 'first');
if isempty(referenceIndex)
    referenceIndex = 1;
end

referenceAmplitude = sqrt(max(intensityStack(:, :, referenceIndex), 0));
objectEstimate = kron(referenceAmplitude, ones(upsampleFactor));
objectEstimate = objectEstimate(1:config.reconstructionSize(1), 1:config.reconstructionSize(2));
objectEstimate = objectEstimate .* exp(1i * zeros(config.reconstructionSize));
objectSpectrum = fftshift(fft2(objectEstimate));

fftCenterRow = floor(config.reconstructionSize(1) / 2) + 1;
fftCenterCol = floor(config.reconstructionSize(2) / 2) + 1;
halfHeight = floor(config.sensorSize(1) / 2);
halfWidth = floor(config.sensorSize(2) / 2);
errorHistory = zeros(config.iterations, 1);

for iteration = 1:config.iterations
    cumulativeError = 0;

    for index = 1:numel(ledPositions)
        rowRange = (fftCenterRow - halfHeight + ledPositions(index).shiftY):(fftCenterRow + halfHeight - 1 + ledPositions(index).shiftY);
        colRange = (fftCenterCol - halfWidth + ledPositions(index).shiftX):(fftCenterCol + halfWidth - 1 + ledPositions(index).shiftX);

        spectrumPatch = objectSpectrum(rowRange, colRange);
        detectorField = ifft2(ifftshift(spectrumPatch .* pupil));
        measuredAmplitude = sqrt(max(intensityStack(:, :, index), 0));
        updatedField = measuredAmplitude .* exp(1i * angle(detectorField));
        updatedSpectrum = fftshift(fft2(updatedField));

        correction = updatedSpectrum - spectrumPatch .* pupil;
        pupilMask = pupil > 0;
        spectrumPatch(pupilMask) = spectrumPatch(pupilMask) + ...
            beta * correction(pupilMask) .* conj(pupil(pupilMask)) ./ max(abs(pupil(pupilMask)) .^ 2, eps);
        objectSpectrum(rowRange, colRange) = spectrumPatch;

        amplitudeResidual = abs(abs(detectorField) - measuredAmplitude);
        cumulativeError = cumulativeError + mean(amplitudeResidual(:));
    end

    errorHistory(iteration) = cumulativeError / numel(ledPositions);
end

estimatedObject = ifft2(ifftshift(objectSpectrum));
reconstruction.object = estimatedObject;
reconstruction.amplitude = abs(estimatedObject);
reconstruction.phase = angle(estimatedObject);
reconstruction.spectrum = objectSpectrum;
reconstruction.errorHistory = errorHistory;
reconstruction.ledPositions = ledPositions;
end

function pupil = build_pupil(config)
samplePlanePixelSize = config.sensorPixelSize / config.magnification;
fx = ((-config.sensorSize(2) / 2):(config.sensorSize(2) / 2 - 1)) / (config.sensorSize(2) * samplePlanePixelSize);
fy = ((-config.sensorSize(1) / 2):(config.sensorSize(1) / 2 - 1)) / (config.sensorSize(1) * samplePlanePixelSize);
[fxGrid, fyGrid] = meshgrid(fx, fy);
cutoff = config.objectiveNA / config.wavelength;
pupil = double((fxGrid .^ 2 + fyGrid .^ 2) <= cutoff ^ 2);
end
