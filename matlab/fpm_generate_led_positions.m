function ledPositions = fpm_generate_led_positions(config)
rows = config.ledArraySize(1);
cols = config.ledArraySize(2);
rowCenter = (rows + 1) / 2;
colCenter = (cols + 1) / 2;

objectPlanePixelSize = config.sensorPixelSize / (config.magnification * config.upsampleFactor);
dfx = 1 / (config.reconstructionSize(2) * objectPlanePixelSize);
dfy = 1 / (config.reconstructionSize(1) * objectPlanePixelSize);
patchSize = config.sensorSize;
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

        rowStart = fftCenterRow - floor((patchSize(1) - 1) / 2) + shiftY;
        colStart = fftCenterCol - floor((patchSize(2) - 1) / 2) + shiftX;
        rowRange = rowStart:(rowStart + patchSize(1) - 1);
        colRange = colStart:(colStart + patchSize(2) - 1);

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
[~, order] = sortrows([[positions.radius].', [positions.illuminationNa].'], [1 2]);
ledPositions = positions(order);
[ledPositions.isBrightfieldReference] = deal(false);
[~, referenceOrder] = sortrows([[ledPositions.illuminationNa].', [ledPositions.radius].'], [1 2]);
referenceIndex = referenceOrder(1);
ledPositions(referenceIndex).isBrightfieldReference = true;
end
