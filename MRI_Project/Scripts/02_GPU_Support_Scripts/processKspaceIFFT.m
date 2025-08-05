
function imageData=processKspaceIFFT(kspaceData)
 
  % Start timing the reconstruction process
        tic;
        
        % Process the k-space data to image data on GPU
        imageData = gpuIFFT(kspaceData);
        
        % End timing
        reconstructionTime = toc;
        
        % Display or log the reconstruction time

end



function reconImage = gpuIFFT(kspaceData)
    % Use GPU Coder directive to generate CUDA code
    coder.gpu.kernelfun();
    kspaceData = complex(kspaceData.r, kspaceData.i);
    kspaceShifted = ifftshift(ifftshift(kspaceData, 1), 2);
    imageC = ifft2(kspaceShifted);
    imageC = fftshift(fftshift(imageC, 1), 2);
    reconImage = sqrt(sum(abs(imageC).^2, 3));
    reconImage = squeeze(reconImage);
    %save('Cuda_reconstructed_image.mat', 'reconImage');
    save(fullfile(pwd,'Cuda_reconstructed_IFFT_image.mat'), 'reconImage');
end