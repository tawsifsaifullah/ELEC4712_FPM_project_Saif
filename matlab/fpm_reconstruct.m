function reconstruction = fpm_reconstruct(intensityStack, config, ledPositions)
if nargin < 3 || isempty(ledPositions)
    ledPositions = fpm_generate_led_positions(config);
end

pupil = fpm_build_pupil(config);
upsampleFactor = config.upsampleFactor;

referenceIndex = find([ledPositions.isBrightfieldReference], 1, 'first');
if isempty(referenceIndex)
    referenceIndex = 1;
end

referenceAmplitude = sqrt(max(intensityStack(:, :, referenceIndex), 0));
objectEstimate = repelem(referenceAmplitude, upsampleFactor, upsampleFactor);
objectEstimate = objectEstimate(1:config.reconstructionSize(1), 1:config.reconstructionSize(2));
objectEstimate = objectEstimate .* exp(1i * zeros(config.reconstructionSize));
objectSpectrum = fftshift(fft2(objectEstimate));

errorHistory = zeros(config.iterations, 1);

for iteration = 1:config.iterations
    cumulativeError = 0;

    for index = 1:numel(ledPositions)
        [rowRange, colRange] = fpm_get_spectrum_patch_ranges(config, ledPositions(index));
        spectrumPatch = objectSpectrum(rowRange, colRange);
        detectorField = ifft2(ifftshift(spectrumPatch .* pupil));
        measuredAmplitude = sqrt(max(intensityStack(:, :, index), 0));
        updatedField = measuredAmplitude .* exp(1i * angle(detectorField));
        updatedSpectrum = fftshift(fft2(updatedField));

        spectrumPatch = updatedSpectrum .* pupil;
        objectSpectrum(rowRange, colRange) = spectrumPatch;

        updatedDetectorField = ifft2(ifftshift(objectSpectrum(rowRange, colRange) .* pupil));
        amplitudeResidual = abs(abs(updatedDetectorField) - measuredAmplitude);
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
