function ledPositions = fpm_generate_led_positions(config)
rows = config.ledArraySize(1);
cols = config.ledArraySize(2);
rowCenter = (rows + 1) / 2;
colCenter = (cols + 1) / 2;

objectPixelSize = config.sensorPixelSize / (config.magnification * config.upsampleFactor);
dfx = 1 / (config.reconstructionSize(2) * objectPixelSize);
dfy = 1 / (config.reconstructionSize(1) * objectPixelSize);

halfHeight = floor(config.sensorSize(1) / 2);
halfWidth = floor(config.sensorSize(2) / 2);
fftCenterRow = floor(config.reconstructionSize(1) / 2) + 1;
fftCenterCol = floor(config.reconstructionSize(2) / 2) + 1;

index = 0;
positions = repmat(struct( ...
    'ledRow', 0, ...
    'ledCol', 0, ...
    'x', 0, ...
    'y', 0, ...
    'illuminationNaX', 0, ...
    'illuminationNaY', 0, ...
    'illuminationNa', 0, ...
    'shiftX', 0, ...
    'shiftY', 0, ...
    'radius', 0, ...
    'isBrightfieldReference', false), rows * cols, 1);

for row = 1:rows
    for col = 1:cols
        x = (col - colCenter) * config.ledPitch;
        y = (row - rowCenter) * config.ledPitch;

        thetaX = atan2(x, config.ledHeight);
        thetaY = atan2(y, config.ledHeight);
        illuminationNaX = sin(thetaX);
        illuminationNaY = sin(thetaY);
        illuminationNa = hypot(illuminationNaX, illuminationNaY);

        if illuminationNa > config.maxIlluminationNA
            continue;
        end

        shiftX = round((illuminationNaX / config.wavelength) / dfx);
        shiftY = round((illuminationNaY / config.wavelength) / dfy);

        rowRange = (fftCenterRow - halfHeight + shiftY):(fftCenterRow + halfHeight - 1 + shiftY);
        colRange = (fftCenterCol - halfWidth + shiftX):(fftCenterCol + halfWidth - 1 + shiftX);

        if min(rowRange) < 1 || min(colRange) < 1 || ...
                max(rowRange) > config.reconstructionSize(1) || ...
                max(colRange) > config.reconstructionSize(2)
            continue;
        end

        index = index + 1;
        positions(index).ledRow = row;
        positions(index).ledCol = col;
        positions(index).x = x;
        positions(index).y = y;
        positions(index).illuminationNaX = illuminationNaX;
        positions(index).illuminationNaY = illuminationNaY;
        positions(index).illuminationNa = illuminationNa;
        positions(index).shiftX = shiftX;
        positions(index).shiftY = shiftY;
        positions(index).radius = hypot(row - rowCenter, col - colCenter);
        positions(index).isBrightfieldReference = false;
    end
end

positions = positions(1:index);
if isempty(positions)
    error('No valid LED positions remain after applying illumination and spectrum bounds constraints.');
end
[positions.isBrightfieldReference] = deal(false);
[~, referenceIndex] = min([positions.illuminationNa] + eps * [positions.radius]);
positions(referenceIndex).isBrightfieldReference = true;
[~, order] = sortrows([[positions.radius].', [positions.illuminationNa].'], [1 2]);
ledPositions = positions(order);
end
