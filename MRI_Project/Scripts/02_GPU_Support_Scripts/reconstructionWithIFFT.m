function reconImage = reconstructionWithIFFT(data)
    % Check if GPU is available
    if gpuDeviceCount > 0
        useGPU = true;
    else
        useGPU = false;
    end

    % Ensure data is numeric
    if isstruct(data)
        data = complex(data.r, data.i); % Convert struct to complex numeric array
    end

    if useGPU
        data = gpuArray(data);
    end

    % Shift k-space data
    kspaceShifted = ifftshift(ifftshift(data, 1), 2);

    % Perform inverse FFT
    imageC = ifft2(double(kspaceShifted));

    % Shift the image back
    imageC = fftshift(fftshift(imageC, 1), 2);

    % Compute the root-sum-of-squares (RSS) image
    reconImage = sqrt(sum(abs(imageC).^2, 3));
    reconImage = squeeze(reconImage);

    if useGPU
        reconImage = gather(reconImage);
    end
end