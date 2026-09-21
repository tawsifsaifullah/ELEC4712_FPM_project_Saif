%% reconstruct_epry_fpm.m
% EPRY-style FPM reconstruction using the SAME simulated measurements
% produced by generate_fpm.m.
%
% EPRY-FPM jointly updates:
%   1) the high-resolution complex object spectrum
%   2) the objective pupil function
%
% This is an educational EPRY-style implementation, not a byte-for-byte
% reproduction of any published code.

%% Load/check the existing simulation workspace
if ~exist('imaged_images','var')
    error('Run generate_fpm.m first.');
end

required = {'initial_px','sampled_px','wavelength','NA','LED_spacing', ...
            'illumination_distance','illumination_layers'};
for q = 1:numel(required)
    if ~exist(required{q},'var')
        error('Missing variable %s. Run generate_fpm.m first.', required{q});
    end
end

[Ny,Nx,Nimg] = size(imaged_images);
scale = round(sampled_px/initial_px);
Nhr_y = Ny*scale;
Nhr_x = Nx*scale;

Nled = 2*illumination_layers - 1;
if Nimg ~= Nled^2
    error('Expected %d images from the LED grid, but found %d.',Nled^2,Nimg);
end

%% Parameters
num_iterations = 15;
alpha_obj = 0.7;       % object update strength
beta_pupil = 0.05;     % pupil update strength
pupil_floor = 0.05;    % prevent pupil from collapsing to zero

%% Initial object and pupil
centre = ceil(Nimg/2);
amp0 = sqrt(max(imaged_images(:,:,centre),0));
amp0 = amp0/(max(amp0(:))+eps);
obj = complex(imresize(amp0,[Nhr_y,Nhr_x],'bilinear'),0);
F = fftshift(fft2(obj));

% Initial objective pupil on the LR Fourier grid.
% Radius follows the physical NA/lambda cutoff.
dfx = 2*pi/(Nx*sampled_px);
dfy = 2*pi/(Ny*sampled_px);
fx = ((0:Nx-1)-floor(Nx/2))*dfx;
fy = ((0:Ny-1)-floor(Ny/2))*dfy;
[fxg,fyg] = meshgrid(fx,fy);
cutoff = 2*pi*NA/wavelength;
pupil = double(fxg.^2 + fyg.^2 <= cutoff^2);

% Because imageit.m already applies a pupil during forward simulation,
% the initial pupil is only used as the reconstruction's model of it.

%% LED Fourier shifts
k = 2*pi/wavelength;
dfx_hr = 2*pi/(Nhr_x*initial_px);
dfy_hr = 2*pi/(Nhr_y*initial_px);

kx_pix = zeros(Nled,Nled);
ky_pix = zeros(Nled,Nled);

for a=1:Nled
    for b=1:Nled
        xled = (a-illumination_layers)*LED_spacing;
        yled = (b-illumination_layers)*LED_spacing;
        d = sqrt(xled^2+yled^2+illumination_distance^2);
        kx = k*xled/d;
        ky = k*yled/d;
        kx_pix(a,b) = kx/dfx_hr;
        ky_pix(a,b) = ky/dfy_hr;
    end
end

half_x=floor(Nx/2);
half_y=floor(Ny/2);

%% Reconstruction
for it=1:num_iterations
    n=0;
    for a=1:Nled
        for b=1:Nled
            n=n+1;

            cx=round(Nhr_x/2+1+kx_pix(a,b));
            cy=round(Nhr_y/2+1+ky_pix(a,b));

            x1=cx-half_x; x2=x1+Nx-1;
            y1=cy-half_y; y2=y1+Ny-1;

            if x1<1 || y1<1 || x2>Nhr_x || y2>Nhr_y
                continue
            end

            patch=F(y1:y2,x1:x2);

            % Predicted low-resolution complex field
            u=ifft2(ifftshift(patch.*pupil));

            % Measured amplitude constraint
            target_amp=sqrt(max(imaged_images(:,:,n),0));
            u_new=target_amp.*exp(1i*angle(u));

            % Fourier-domain error
            du=fftshift(fft2(u_new-u));

            % EPRY-style object update
            denom_p=max(abs(pupil(:)).^2)+eps;
            patch_new=patch + alpha_obj*(conj(pupil)./(denom_p)).*du;

            % EPRY-style pupil update
            denom_obj=max(abs(patch(:)).^2)+eps;
            pupil_new=pupil + beta_pupil*(conj(patch)./denom_obj).*du;

            % Keep pupil support circular and avoid negative/vanishing magnitude
            pupil = pupil_new.*double(fxg.^2+fyg.^2<=cutoff^2);
            magp=abs(pupil);
            pupil(magp<pupil_floor & pupil~=0) = ...
                pupil_floor*exp(1i*angle(pupil(magp<pupil_floor & pupil~=0)));

            F(y1:y2,x1:x2)=patch_new;
        end
    end
    fprintf('EPRY iteration %d/%d\n',it,num_iterations);
end

%% Results
obj=ifft2(ifftshift(F));
reconstructed_amplitude=abs(obj);
reconstructed_phase=angle(obj);

figure('Name','EPRY-style FPM reconstruction');
subplot(1,3,1); imagesc(reconstructed_amplitude); axis image off;
title('Amplitude');
subplot(1,3,2); imagesc(reconstructed_phase); axis image off;
title('Phase');
subplot(1,3,3); imagesc(angle(pupil)); axis image off;
title('Recovered pupil phase');
colormap gray;

save('fpm_epry_reconstruction.mat','obj','F','pupil', ...
     'reconstructed_amplitude','reconstructed_phase');

fprintf('EPRY-style reconstruction finished.\n');
