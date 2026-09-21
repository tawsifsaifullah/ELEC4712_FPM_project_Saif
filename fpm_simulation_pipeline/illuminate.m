function y = illuminate(object, x, y, object_x, object_y, illumination_distance, wave_number)
    %% illuminates 'object' with an LED at distance x,y
    % generate kx and ky
    wavevector_denominator = sqrt(x^2 + y^2 + illumination_distance^2);
    kx = wave_number*x/wavevector_denominator;
    ky = wave_number*y/wavevector_denominator;

    % generate the illumination matrix
    illumination_matrix = object_x*kx + object_y*ky;

    % Then we apply the plane wave to the object
    % given by exp(jk.r)*obj
    illuminated_object = 10*object.*exp(j*illumination_matrix);
    y = illuminated_object;
end

% returns the complex object after it has been illumniated 
% from position (x, y) relative to the object.
% this function is applied before maskk and imageit

%Original complex object (represented as aimplitude and phase - 2D complex matrix)
%        ↓
%   illuminate() % multiplies the object by the illumination matrix : 10*exp(j*illumination_matrix)
%        ↓
%Illuminated complex object
%        ↓
%     imageit() % after interacting with the sample, the same sample information is now encoded in a field with an additional spatial phase ramp.
%        ↓
% Fourier transform % the above will cause Fourier_space shift that fpm relies on
%        ↓
% Low-pass pupil (NA)
%        ↓
% Inverse Fourier transform
%        ↓
%Low-resolution optical image
%        ↓
% Downsample to 5.5 µm pixels
%        ↓
%Low-resolution camera image