
% Introduction This script sets up the required folder structure for
% storing results from three examples: Inverse Fast Fourier Transform
% (IFFT), Compressed Sensing (CS), and Deep Learning (DL). It downloads
% K-space data from a specified URL, unzips the file, and saves only the T1
% modality .h5 files to the appropriate directory.



% Required folder structure for storing results from three examples
dataDir = fullfile(pwd, "data", "rawData");
inputData = fullfile(pwd, "data", "inputData");
ifftOutDir = fullfile(pwd, "result", "ifftResult");
csOutDir = fullfile(pwd, "result", "CSResult");
dlOutDir = fullfile(pwd, "result", "DLResult");

% Create directories if they do not exist
if ~exist(dataDir, 'dir')
    mkdir(dataDir);
end

if ~exist(inputData, 'dir')
    mkdir(inputData);
end

if ~exist(ifftOutDir, 'dir')
    mkdir(ifftOutDir);
end

if ~exist(csOutDir, 'dir')
    mkdir(csOutDir);
end

if ~exist(dlOutDir, 'dir')
    mkdir(dlOutDir);
end

% Download the K-space data from support files
kspaceDataFileURL = 'https://ssd.mathworks.com/supportfiles/medical/M4Raw_sample.zip';
zipFilePath = fullfile(dataDir, 'M4Raw_sample.zip');
websave(zipFilePath, kspaceDataFileURL);

% Unzip the downloaded file into the data directory
unzip(zipFilePath, dataDir);

% Only T1 modality is used - you can change this as per your own requirement
% Define the pattern for T1 .h5 files
filePattern = fullfile(dataDir, '**', '*T1*.h5');

% Get a list of all T1 .h5 files
T1Files = dir(filePattern);

% Copy T1 .h5 files to the input data directory
for k = 1:length(T1Files)
    sourceFile = fullfile(T1Files(k).folder, T1Files(k).name);
    destinationFile = fullfile(inputData, T1Files(k).name);
    copyfile(sourceFile, destinationFile);
end