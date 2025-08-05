function resultDL = reconstructionWithDL(data, factor)
    % Load the network
    net = load("2025-03-03-14-38.mat");
    
    % Undersample k-space data
    undersampled_kspace = undersampleKspace(data, factor);
    
    % Check if GPU is available
    if canUseGPU()
        undersampled_kspace = gpuArray(undersampled_kspace);
        undersampled_kspace = gather(undersampled_kspace);
        resultDL = predict(net.net, double(undersampled_kspace));
    else
        resultDL = predict(net.net, undersampled_kspace);
    end
end




% Function to generate VD-PDS mask
function samplingMask = generatePoissonDiscMask(m, n, density)
    % Create a radial density profile
    [X, Y] = meshgrid(linspace(-1, 1, n), linspace(-1, 1, m));
    radius = sqrt(X.^2 + Y.^2);
    densityProfile = exp(-radius.^2 / (2 * (density^2)));

    % Generate mask based on density profile
    randomValues = rand(m, n);
    samplingMask = randomValues < densityProfile;
end

% Function to undersample k-space data
function [undersampled_kspace, coilSensitivityMaps] = undersampleKspace(data, factor)
    % Check if GPU is available
    if gpuDeviceCount > 0
        useGPU = true;
    else
        useGPU = false;
    end

    % Load the dataset into a MATLAB variable
    kspaceShifted = ifftshift(ifftshift(data, 1), 2);
    kspace_data = complex(kspaceShifted.r, kspaceShifted.i);

    if useGPU
        kspace_data = gpuArray(kspace_data);
    end

    % Define the size of the spatial dimensions
    [nx, ny, nc, nt] = size(kspace_data);

    % Preallocate for speed
    undersampled_kspace = zeros(size(kspace_data), 'like', kspace_data);

    % Define the undersampling mask for 1D undersampling in the phase direction
    if factor
         % Desired acceleration factor
       density = 1 / factor; % Calculate density from acceleration
        mask = generate1DVariableDensityMask(ny, density);
        % mask = generatePoissonDiscMask(nx, ny, factor);
    else
        mask = true(1, ny); % No undersampling if factor is not provided
    end

    % Apply the mask to each 2D slice in the phase direction
    for slice3 = 1:nc
        for slice4 = 1:nt
            undersampled_kspace(:, :, slice3, slice4) = kspace_data(:, :, slice3, slice4) .* mask;
        end
    end

    % Perform inverse FFT and shift operations
    imageC = ifft2(double(undersampled_kspace));
    imageC = fftshift(fftshift(imageC, 1), 2);
    reconImage = sqrt(sum(abs(imageC).^2, 3));
    undersampled_kspace = squeeze(reconImage);

    % Calculate coil sensitivity maps
    coilSensitivityMaps = calculateCoilSensitivityMaps(kspace_data);
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

function coilSensitivityMaps = calculateCoilSensitivityMaps(kspace_data)
    % Check if GPU is available
    if gpuDeviceCount > 0
        useGPU = true;
    else
        useGPU = false;
    end

    [m, n, coils, sliceIndex] = size(kspace_data);

    % Generate coil sensitivity maps using RSS approach
    imageSpace = ifft2(kspace_data);
    rssImage = sqrt(sum(abs(imageSpace).^2, 3));
    coilSensitivityMaps = zeros(m, n, coils, sliceIndex, 'like', kspace_data);

    for s = 1:sliceIndex
        for c = 1:coils
            coilSensitivityMaps(:, :, c, s) = abs(imageSpace(:, :, c, s)) ./ (rssImage(:, :, s) + eps);
        end
    end

    if useGPU
        coilSensitivityMaps = gather(coilSensitivityMaps);
    end
end
