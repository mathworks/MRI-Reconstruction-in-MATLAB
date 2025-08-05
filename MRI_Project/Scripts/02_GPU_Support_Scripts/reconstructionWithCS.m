function rss_CSimage = reconstructionWithCS(data, factor)
% Initialize necessary parameters
num_coils = 4;
num_frames = 18;
num_iters = 50;
threshold = 0.01;

% Check if GPU is available
if gpuDeviceCount > 0
    useGPU = true;
else
    useGPU = false;
end

% FFT2 and IFFT2 shift function
    function y = fft2s(x)
        y = fftshift(fft2(ifftshift(x)));
    end

    function y = ifft2s(x)
        y = fftshift(ifft2(ifftshift(x)));
    end


kspaceShifted = ifftshift(ifftshift(data, 1), 2);
kspace_data = complex(kspaceShifted.r, kspaceShifted.i);

if useGPU
    kspace_data = gpuArray(kspace_data);
end

[m, n, coils, sliceIndex] = size(kspace_data);

% Generate coil sensitivity maps using RSS approach
imageSpace = ifft2s(kspace_data);
rssImage = sqrt(sum(abs(imageSpace).^2, 3));
coilSensitivityMaps = zeros(m, n, coils, sliceIndex, 'like', kspace_data);

for s = 1:sliceIndex
    for c = 1:coils
        coilSensitivityMaps(:, :, c, s) = abs(imageSpace(:, :, c, s)) ./ (rssImage(:, :, s) + eps);
    end
end

% Generate variable density Poisson disc sampling mask
accelerationFactor = factor; % Desired acceleration factor
density = 1 / accelerationFactor; % Calculate density from acceleration

% Choose mask options as per your need
mask_vardens = generateVariableDensityCartesianMask(m, n, density);
% mask_vardens = generate1DVariableDensityMask(n, density);

% Initialize reconstructed image storage
im_cs = zeros(size(kspace_data), 'like', kspace_data);

% Loop over each coil and frame
for frame = 1:num_frames
    for coil = 1:num_coils
        % Extract the k-space data for the current coil and frame
        undersampled_data = kspace_data(:,:,coil,frame) .* mask_vardens;
        % Initial image estimate
        im_cs(:,:,coil,frame) = ifft2s(undersampled_data);
        % Apply coil sensitivity map
        im_cs(:,:,coil,frame) = im_cs(:,:,coil,frame) .* coilSensitivityMaps(:,:,coil,frame);

        % POCS iterations
        for iter = 1:num_iters
            [C, S] = wavedec2(im_cs(:,:,coil,frame), 2, 'db1');
            if useGPU
            C = gather(C);
            end
            C =single(C);
       
            C_thresh = wthresh(C, 's', threshold);
            im_cs(:,:,coil,frame) = waverec2(C_thresh, S, 'db1');
            kspace_estimate = fft2s(im_cs(:,:,coil,frame));
            kspace_estimate(mask_vardens) = undersampled_data(mask_vardens);
            im_cs(:,:,coil,frame) = ifft2s(kspace_estimate);
        end
    end
end

% Combine coil images using root-sum-of-squares (RSS)
rss_CSimage = sqrt(sum(abs(im_cs).^2, 3));
rss_CSimage = squeeze(rss_CSimage);

if useGPU
    rss_CSimage = gather(rss_CSimage);
end
end



function samplingMask = generate1DVariableDensityMask(N, density)
% Generate a 1D variable density undersampling mask
% N: Length of the k-space data in the phase encoding direction
% density: Parameter controlling the density profile

% Create a polynomial density profile
x = linspace(-1, 1, N);
densityProfile = (1 - abs(x)).^density;

% Generate mask based on density profile
randomValues = rand(1, N);
samplingMask = randomValues < densityProfile;
end

function samplingMask = generateVariableDensityCartesianMask(m, n, density)
% Generate a 2D variable density Cartesian undersampling mask
% m: Number of rows in the k-space data
% n: Number of columns in the k-space data
% density: Parameter controlling the density profile

% Create a polynomial density profile
[X, Y] = meshgrid(linspace(-1, 1, n), linspace(-1, 1, m));
densityProfile = (1 - abs(X)).^density .* (1 - abs(Y)).^density;

% Generate mask based on density profile
randomValues = rand(m, n);
samplingMask = randomValues < densityProfile;
end
