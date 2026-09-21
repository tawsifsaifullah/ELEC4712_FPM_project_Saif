%% reconstruct_wirtinger_fpm.m
% Wirtinger-flow-style FPM reconstruction using the SAME measurements
% produced by generate_fpm.m.
%
% The objective is an intensity-domain least-squares loss:
%
%   L = sum_n || |u_n|^2 - I_n ||^2
%
% and the complex object spectrum is updated using a Wirtinger gradient.
%
% This is an educational implementation of the WFP idea; published
% variants use different cost functions, step-size rules and regularisers.

%% Check workspace
if ~exist('imaged_images','var')
    error('Run generate_fpm.m first.');
end

required={'initial_px','sampled_px','wavelength','NA','LED_spacing', ...
           'illumination_distance','illumination_layers'};
for q=1:numel(required)
    if ~exist(required{q},'var')
        error('Missing variable %s. Run generate_fpm.m first.',required{q});
    end
end

[Ny,Nx,Nimg]=size(imaged_images);
scale=round(sampled_px/initial_px);
Nhr_y=Ny*scale;
Nhr_x=Nx*scale;
Nled=2*illumination_layers-1;

if Nimg~=Nled^2
    error('Expected %d images, found %d.',Nled^2,Nimg);
end

%% Parameters
num_iterations=15;
step=0.15;             % gradient step
gradient_normalise=true;

%% Initial estimate
centre=ceil(Nimg/2);
amp0=sqrt(max(imaged_images(:,:,centre),0));
amp0=amp0/(max(amp0(:))+eps);
obj=complex(imresize(amp0,[Nhr_y,Nhr_x],'bilinear'),0);
F=fftshift(fft2(obj));

%% Objective pupil
dfx=2*pi/(Nx*sampled_px);
dfy=2*pi/(Ny*sampled_px);
fx=((0:Nx-1)-floor(Nx/2))*dfx;
fy=((0:Ny-1)-floor(Ny/2))*dfy;
[fxg,fyg]=meshgrid(fx,fy);
cutoff=2*pi*NA/wavelength;
pupil=double(fxg.^2+fyg.^2<=cutoff^2);

%% Illumination shifts
k=2*pi/wavelength;
dfx_hr=2*pi/(Nhr_x*initial_px);
dfy_hr=2*pi/(Nhr_y*initial_px);
kx_pix=zeros(Nled,Nled);
ky_pix=zeros(Nled,Nled);

for a=1:Nled
    for b=1:Nled
        xled=(a-illumination_layers)*LED_spacing;
        yled=(b-illumination_layers)*LED_spacing;
        d=sqrt(xled^2+yled^2+illumination_distance^2);
        kx=k*xled/d;
        ky=k*yled/d;
        kx_pix(a,b)=kx/dfx_hr;
        ky_pix(a,b)=ky/dfy_hr;
    end
end

half_x=floor(Nx/2);
half_y=floor(Ny/2);

%% Wirtinger-flow iterations
for it=1:num_iterations
    total_loss=0;
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

            % Forward model for this LED
            u=ifft2(ifftshift(patch.*pupil));
            predicted_I=abs(u).^2;
            measured_I=max(imaged_images(:,:,n),0);

            % Intensity residual
            residual=predicted_I-measured_I;
            total_loss=total_loss+mean(residual(:).^2);

            % Wirtinger gradient:
            % gradient in spatial field -> Fourier patch
            grad_u=residual.*u;
            grad_patch=fftshift(fft2(grad_u)).*conj(pupil);

            % Optional per-patch normalisation
            if gradient_normalise
                grad_patch=grad_patch/(max(abs(grad_patch(:)))+eps);
            end

            % Gradient descent in the object Fourier spectrum
            F(y1:y2,x1:x2)=patch-step*grad_patch;
        end
    end

    fprintf('Wirtinger iteration %d/%d, mean loss = %.6e\n', ...
            it,num_iterations,total_loss/Nimg);
end

%% Results
obj=ifft2(ifftshift(F));
reconstructed_amplitude=abs(obj);
reconstructed_phase=angle(obj);

figure('Name','Wirtinger-flow-style FPM reconstruction');
subplot(1,2,1); imagesc(reconstructed_amplitude); axis image off;
title('Amplitude');
subplot(1,2,2); imagesc(reconstructed_phase); axis image off;
title('Phase');
colormap gray;

save('fpm_wirtinger_reconstruction.mat','obj','F', ...
     'reconstructed_amplitude','reconstructed_phase');

fprintf('Wirtinger-flow-style reconstruction finished.\n');
