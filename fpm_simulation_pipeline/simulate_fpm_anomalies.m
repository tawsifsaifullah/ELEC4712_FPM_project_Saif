%% simulate_fpm_anomalies.m
% FPM physical-system imperfection / anomaly framework
%
% This script uses the SAME basic forward-model variables as the existing
% FPM simulation:
%
%   system_constants.m
%   illuminate.m
%   imageit.m
%   maskk.m
%
% It generates a second, more realistic FPM dataset by deliberately
% introducing imperfections that can occur in a physical microscope.
%
% The idea is:
%
%       IDEAL FPM                         REALISTIC FPM
%       ---------                        -------------
%       perfect LEDs                     LED position errors
%       equal LED power                  LED intensity variation
%       ideal plane wave                 spherical-wave / geometry effects
%       ideal objective                  pupil aberration / defocus
%       ideal camera                     noise + background + quantisation
%       perfect field                    vignetting / dead pixels
%
% This is NOT a reconstruction algorithm. It is a controlled testbed for
% studying how reconstruction algorithms behave when the microscope is
% imperfect.
%
% Run:
%
%   1) Make sure this file is in the same folder as the existing FPM files.
%   2) Run:
%
%          simulate_fpm_anomalies
%
%   3) Inspect:
%
%          ideal_images
%          anomalous_images
%
% The anomalous stack can then be passed to reconstruct_fpm.m, EPRY, etc.
%
% All distances are in microns, matching system_constants.m.

clearvars -except ans;
close all;
clc;

%% ========================================================================
% 1. LOAD YOUR EXISTING FPM SYSTEM
% =========================================================================

system_constants;

% Re-create the same zero-phase object used by generate_fpm.m.
% Change this later if you want a known non-zero phase object.
phase_image = zeros(size(phase_image));
object = intensity_image .* exp(1j * phase_image);

Nled = 2 * illumination_layers - 1;
num_images = Nled^2;

fprintf('FPM anomaly simulation\n');
fprintf('LED grid: %d x %d = %d images\n', Nled, Nled, num_images);


%% ========================================================================
% 2. ANOMALY / IMPERFECTION SETTINGS
% =========================================================================
%
% Set each "enabled" value to true/false.
%
% The default values are deliberately moderate so that the reconstruction
% problem is harder than the ideal case but still visually understandable.

cfg = struct();

% -------------------- LED geometry ---------------------------------------
cfg.led_position_error_enabled = true;

% Standard deviation of LED x/y positioning error [microns].
% Example: 100 um = 0.1 mm physical placement error.
cfg.led_position_error_std = 100;


% -------------------- LED intensity --------------------------------------
cfg.led_intensity_variation_enabled = true;

% Standard deviation of relative LED intensity variation.
% 0.10 means approximately 10% variation.
cfg.led_intensity_std = 0.10;


% -------------------- Illumination wavefront -----------------------------
cfg.spherical_wave_enabled = true;

% The original illuminate.m creates a plane-wave-like phase ramp using
% the local kx and ky. Here we additionally model the finite LED-to-sample
% spherical wavefront.
cfg.spherical_wave_strength = 1.0;


% -------------------- Objective aberrations ------------------------------
cfg.pupil_aberration_enabled = true;

% Dimensionless phase coefficients in radians.
% These are deliberately small/moderate starting values.
cfg.defocus_strength = 0.35;
cfg.astigmatism_strength = 0.20;
cfg.coma_strength = 0.10;


% -------------------- Defocus --------------------------------------------
cfg.defocus_enabled = true;

% Additional defocus in the pupil phase.
% This is kept separate so you can turn it on/off independently.
cfg.additional_defocus = 0.25;


% -------------------- Vignetting -----------------------------------------
cfg.vignetting_enabled = true;

% Gaussian vignetting strength. 0 = none.
% Larger values produce stronger falloff toward the image edges.
cfg.vignetting_strength = 0.20;


% -------------------- Background -----------------------------------------
cfg.background_enabled = true;

% Background level as a fraction of normalized image intensity.
cfg.background_level = 0.015;


% -------------------- Camera noise ---------------------------------------
cfg.read_noise_enabled = true;

% Additive Gaussian read noise relative to normalized signal range.
cfg.read_noise_std = 0.008;


cfg.shot_noise_enabled = true;

% Approximate photon/shot noise strength.
% Larger value = noisier image.
cfg.shot_noise_strength = 0.015;


% -------------------- Camera quantisation -------------------------------
cfg.quantisation_enabled = true;

% Simulate an n-bit camera.
cfg.camera_bits = 12;


% -------------------- Bad pixels -----------------------------------------
cfg.dead_pixels_enabled = true;

% Fraction of pixels replaced by zero.
cfg.dead_pixel_fraction = 0.001;


% -------------------- Reproducibility ------------------------------------
cfg.random_seed = 4712;
rng(cfg.random_seed);


%% ========================================================================
% 3. PRE-ALLOCATE
% =========================================================================

% First generate one ideal image to determine camera dimensions.
test_illuminated = illuminate( ...
    object, ...
    0, 0, ...
    object_x, object_y, ...
    illumination_distance, wave_number);

test_field = imageit( ...
    test_illuminated, ...
    initial_px, ...
    sampled_px, ...
    pupil_radius);

test_intensity = abs(test_field).^2;

[Ny, Nx] = size(test_intensity);

ideal_images = zeros(Ny, Nx, num_images);
anomalous_images = zeros(Ny, Nx, num_images);

% Store the actual simulated LED positions and intensities so that later
% reconstruction/calibration experiments can compare assumed vs actual
% system parameters.
actual_led_x = zeros(Nled, Nled);
actual_led_y = zeros(Nled, Nled);
actual_led_intensity = zeros(Nled, Nled);


%% ========================================================================
% 4. BUILD RANDOM LED IMPERFECTIONS
% =========================================================================

if cfg.led_position_error_enabled
    led_dx = cfg.led_position_error_std .* randn(Nled, Nled);
    led_dy = cfg.led_position_error_std .* randn(Nled, Nled);
else
    led_dx = zeros(Nled, Nled);
    led_dy = zeros(Nled, Nled);
end

if cfg.led_intensity_variation_enabled
    led_intensity_factor = 1 + ...
        cfg.led_intensity_std .* randn(Nled, Nled);

    % Prevent an LED from becoming negative.
    led_intensity_factor = max(led_intensity_factor, 0.05);
else
    led_intensity_factor = ones(Nled, Nled);
end


%% ========================================================================
% 5. GENERATE IDEAL AND ANOMALOUS FPM MEASUREMENTS
% =========================================================================

image_index = 0;

for a = 1:Nled
    for b = 1:Nled

        image_index = image_index + 1;

        % ---------------------------------------------------------------
        % Nominal LED position
        % ---------------------------------------------------------------
        nominal_x = (a - illumination_layers) * LED_spacing;
        nominal_y = (b - illumination_layers) * LED_spacing;

        % ---------------------------------------------------------------
        % Actual physical LED position
        % ---------------------------------------------------------------
        actual_x = nominal_x + led_dx(a,b);
        actual_y = nominal_y + led_dy(a,b);

        actual_led_x(a,b) = actual_x;
        actual_led_y(a,b) = actual_y;
        actual_led_intensity(a,b) = led_intensity_factor(a,b);


        % ===============================================================
        % IDEAL MEASUREMENT
        % ===============================================================

        ideal_field = illuminate( ...
            object, ...
            nominal_x, nominal_y, ...
            object_x, object_y, ...
            illumination_distance, wave_number);

        ideal_field = imageit( ...
            ideal_field, ...
            initial_px, ...
            sampled_px, ...
            pupil_radius);

        ideal_intensity = abs(ideal_field).^2;

        ideal_images(:,:,image_index) = ideal_intensity;


        % ===============================================================
        % ANOMALOUS MEASUREMENT
        % ===============================================================

        % Use actual LED position.
        if cfg.spherical_wave_enabled

            anomalous_field = spherical_illuminate( ...
                object, ...
                actual_x, actual_y, ...
                object_x, object_y, ...
                illumination_distance, ...
                wave_number, ...
                cfg.spherical_wave_strength);

        else

            anomalous_field = illuminate( ...
                object, ...
                actual_x, actual_y, ...
                object_x, object_y, ...
                illumination_distance, ...
                wave_number);

        end


        % ---------------------------------------------------------------
        % Objective + camera sampling, but with an aberrated pupil
        % ---------------------------------------------------------------
        anomalous_field = imageit_aberrated( ...
            anomalous_field, ...
            initial_px, ...
            sampled_px, ...
            pupil_radius, ...
            cfg);


        % ---------------------------------------------------------------
        % LED intensity fluctuation
        % ---------------------------------------------------------------
        anomalous_field = anomalous_field .* ...
            sqrt(led_intensity_factor(a,b));


        anomalous_intensity = abs(anomalous_field).^2;


        % ---------------------------------------------------------------
        % Camera vignetting
        % ---------------------------------------------------------------
        if cfg.vignetting_enabled

            anomalous_intensity = apply_vignetting( ...
                anomalous_intensity, ...
                cfg.vignetting_strength);

        end


        % ---------------------------------------------------------------
        % Add background
        % ---------------------------------------------------------------
        if cfg.background_enabled

            signal_scale = max(anomalous_intensity(:));

            anomalous_intensity = anomalous_intensity + ...
                cfg.background_level * signal_scale;

        end


        % ---------------------------------------------------------------
        % Normalize before camera noise/quantisation
        % ---------------------------------------------------------------
        max_value = max(anomalous_intensity(:));

        if max_value > 0
            anomalous_intensity = anomalous_intensity ./ max_value;
        end


        % ---------------------------------------------------------------
        % Approximate shot noise
        % ---------------------------------------------------------------
        if cfg.shot_noise_enabled

            anomalous_intensity = anomalous_intensity + ...
                cfg.shot_noise_strength .* ...
                sqrt(max(anomalous_intensity,0)) .* randn(size(anomalous_intensity));

        end


        % ---------------------------------------------------------------
        % Camera read noise
        % ---------------------------------------------------------------
        if cfg.read_noise_enabled

            anomalous_intensity = anomalous_intensity + ...
                cfg.read_noise_std .* randn(size(anomalous_intensity));

        end


        % Camera cannot measure negative intensity.
        anomalous_intensity = max(anomalous_intensity, 0);


        % ---------------------------------------------------------------
        % Camera quantisation
        % ---------------------------------------------------------------
        if cfg.quantisation_enabled

            max_dn = 2^cfg.camera_bits - 1;

            anomalous_intensity = round( ...
                anomalous_intensity .* max_dn) ./ max_dn;

        end


        % ---------------------------------------------------------------
        % Dead / defective pixels
        % ---------------------------------------------------------------
        if cfg.dead_pixels_enabled

            dead_mask = rand(size(anomalous_intensity)) < ...
                cfg.dead_pixel_fraction;

            anomalous_intensity(dead_mask) = 0;

        end


        anomalous_images(:,:,image_index) = anomalous_intensity;

    end
end


%% ========================================================================
% 6. DISPLAY A COMPARISON
% =========================================================================

centre_image = ceil(num_images/2);

figure('Name','Ideal vs realistic FPM measurement');

subplot(1,2,1);
imagesc(ideal_images(:,:,centre_image));
axis image off;
colormap gray;
title('Ideal FPM image');

subplot(1,2,2);
imagesc(anomalous_images(:,:,centre_image));
axis image off;
colormap gray;
title('Anomalous FPM image');


%% ========================================================================
% 7. DISPLAY ALL 25 ANOMALOUS MEASUREMENTS
% =========================================================================

figure('Name','25 anomalous FPM measurements');

for k = 1:num_images

    subplot(Nled,Nled,k);
    imagesc(anomalous_images(:,:,k));
    axis image off;
    title(sprintf('LED %d',k));

end

colormap gray;


%% ========================================================================
% 8. DISPLAY THE LED POSITION ERRORS
% =========================================================================

if cfg.led_position_error_enabled

    figure('Name','Simulated LED position errors');

    nominal_grid_x = zeros(Nled,Nled);
    nominal_grid_y = zeros(Nled,Nled);

    for a = 1:Nled
        for b = 1:Nled

            nominal_grid_x(a,b) = ...
                (a - illumination_layers) * LED_spacing;

            nominal_grid_y(a,b) = ...
                (b - illumination_layers) * LED_spacing;

        end
    end

    plot(nominal_grid_x(:), nominal_grid_y(:), ...
        'ko', 'MarkerSize', 7);
    hold on;

    plot(actual_led_x(:), actual_led_y(:), ...
        'rx', 'MarkerSize', 8, 'LineWidth', 1.5);

    for k = 1:num_images

        line( ...
            [nominal_grid_x(k) actual_led_x(k)], ...
            [nominal_grid_y(k) actual_led_y(k)]);

    end

    axis equal;
    grid on;
    xlabel('LED x position [um]');
    ylabel('LED y position [um]');
    legend('Nominal LED position','Actual LED position');

    title('Simulated LED misalignment');

end


%% ========================================================================
% 9. SAVE DATASET
% =========================================================================

save('fpm_anomalous_dataset.mat', ...
    'ideal_images', ...
    'anomalous_images', ...
    'actual_led_x', ...
    'actual_led_y', ...
    'actual_led_intensity', ...
    'cfg');

fprintf('\n============================================================\n');
fprintf('Anomaly simulation complete.\n');
fprintf('Ideal dataset:     ideal_images\n');
fprintf('Anomalous dataset: anomalous_images\n');
fprintf('Saved to:          fpm_anomalous_dataset.mat\n');
fprintf('============================================================\n');


%% ========================================================================
% LOCAL FUNCTION: SPHERICAL ILLUMINATION
% =========================================================================
function illuminated_object = spherical_illuminate( ...
    object, x_led, y_led, object_x, object_y, distance, k, strength)

    % Exact distance from LED to every sample point.
    r = sqrt( ...
        (object_x - x_led).^2 + ...
        (object_y - y_led).^2 + ...
        distance.^2);

    % Remove the constant phase at the sample centre so that only the
    % spatially varying wavefront remains.
    r0 = sqrt(x_led^2 + y_led^2 + distance^2);

    spherical_phase = strength .* k .* (r - r0);

    % 1/r amplitude falloff. Normalize relative to the centre.
    amplitude = r0 ./ r;

    illumination = amplitude .* exp(1j .* spherical_phase);

    illuminated_object = object .* illumination;

end


%% ========================================================================
% LOCAL FUNCTION: IMAGE FORMATION WITH ABERRATED PUPIL
% =========================================================================
function output_field = imageit_aberrated( ...
    illuminated_object, initial_px, sampled_px, pupil_radius, cfg)

    % Fourier transform of illuminated object.
    FT = fftshift(fft2(illuminated_object));

    [Ny, Nx] = size(FT);

    % Circular objective pupil.
    pupil = maskk( ...
        0, ...
        0, ...
        pupil_radius, ...
        Nx, ...
        Ny);

    pupil = double(pupil);


    % ---------------------------------------------------------------
    % Normalized pupil coordinates: -1 to +1
    % ---------------------------------------------------------------
    [X,Y] = meshgrid( ...
        linspace(-1,1,Nx), ...
        linspace(-1,1,Ny));

    R2 = X.^2 + Y.^2;

    % Only define aberration inside the objective pupil.
    rho = sqrt(max(R2,0));

    theta = atan2(Y,X);


    % ---------------------------------------------------------------
    % Simple Zernike-like aberration terms
    % ---------------------------------------------------------------

    phase_aberration = zeros(size(X));

    if cfg.pupil_aberration_enabled

        % Defocus-like term.
        phase_aberration = phase_aberration + ...
            cfg.defocus_strength .* (2*rho.^2 - 1);

        % Astigmatism.
        phase_aberration = phase_aberration + ...
            cfg.astigmatism_strength .* ...
            rho.^2 .* cos(2*theta);

        % Coma-like term.
        phase_aberration = phase_aberration + ...
            cfg.coma_strength .* ...
            (3*rho.^3 - 2*rho) .* cos(theta);

    end

    if cfg.defocus_enabled

        phase_aberration = phase_aberration + ...
            cfg.additional_defocus .* rho.^2;

    end


    % Phase-only pupil aberration.
    aberrated_pupil = pupil .* exp(1j .* phase_aberration);


    % Apply objective pupil.
    filtered_FT = FT .* aberrated_pupil;


    % Transform back to spatial domain.
    filtered_field = ifft2(ifftshift(filtered_FT));


    % Downsample to simulated camera.
    resize_factor = initial_px / sampled_px;

    output_field = imresize(filtered_field, resize_factor);

end


%% ========================================================================
% LOCAL FUNCTION: VIGNETTING
% =========================================================================
function output = apply_vignetting(input, strength)

    [Ny,Nx] = size(input);

    [X,Y] = meshgrid( ...
        linspace(-1,1,Nx), ...
        linspace(-1,1,Ny));

    radius_squared = X.^2 + Y.^2;

    % Smooth Gaussian-like falloff.
    vignette = exp(-strength .* radius_squared);

    output = input .* vignette;

end
