function objectField = fpm_generate_sample_object(config)
rows = config.reconstructionSize(1);
cols = config.reconstructionSize(2);
[xGrid, yGrid] = meshgrid(linspace(-1, 1, cols), linspace(-1, 1, rows));

amplitude = 0.2 + 0.65 * exp(-3.2 * (xGrid .^ 2 + yGrid .^ 2));
amplitude = amplitude + 0.25 * (((xGrid + 0.35) .^ 2 + (yGrid - 0.15) .^ 2) < 0.08 ^ 2);
amplitude = amplitude - 0.15 * (((xGrid - 0.18) .^ 2 + (yGrid + 0.32) .^ 2) < 0.13 ^ 2);
amplitude = min(max(amplitude, 0.05), 1.0);

phase = 0.55 * pi * sin(3 * pi * xGrid) .* exp(-2.5 * yGrid .^ 2);
phase = phase + 0.35 * pi * xGrid .* (((xGrid .^ 2 + yGrid .^ 2) < 0.45 ^ 2));

objectField = amplitude .* exp(1i * phase);
end
