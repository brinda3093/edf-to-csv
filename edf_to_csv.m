%% edf_to_csv.m
% This script sets up directory variables, loads EDF data and
% experiment parameters, calls extract_fixations to export fixation
% data to a CSV file, and then plots a 1x3 summary figure.

% --- Define Directories ---
% Anchor paths to this script's location so it works regardless of MATLAB's pwd.
scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir), scriptDir = pwd; end

sessionName  = 'sample_data';
dataMainPath = fullfile(scriptDir, 'data');
dataMatPath  = fullfile(scriptDir, 'data');
outDir       = fullfile(scriptDir, 'data', 'secondary_data');

if ~exist(outDir, 'dir')
    mkdir(outDir);
end

dataName = [sessionName '.edf'];
matName  = [sessionName '.mat'];
edfFile  = fullfile(dataMainPath, dataName);
matFile  = fullfile(dataMatPath, matName);

edfConverterPath = fullfile(scriptDir, 'edf-converter-master');
helperPath       = fullfile(scriptDir, 'helper_fun');

% --- Load EDF Data and Experiment Parameters ---
if ~isfolder(edfConverterPath), error('Edf2Mat converter path not found: %s', edfConverterPath); end
if ~isfolder(helperPath), error('helper_fun path not found: %s', helperPath); end
addpath(edfConverterPath);
addpath(helperPath);

origDir = pwd;
if ~isfolder(dataMainPath), error('Data main path not found: %s', dataMainPath); end
cd(dataMainPath);
if ~isfile(dataName), error('EDF file not found: %s', fullfile(dataMainPath,dataName)); end
edf = Edf2Mat(dataName);
cd(origDir);
if ~isfile(fullfile(dataMatPath, matName)), error('MAT file not found: %s', fullfile(dataMatPath,matName)); end

load(matFile, 'params', 'Results');
timeForView = params.durations.t_freeview * 1000;

% --- Parameters for extract_fixations ---
eventKey = 'DotOff';
trialSuccess = logical(Results.TrialSuccess);
imageShown = Results.ImageShown(trialSuccess);
tmp_imgRect = Results.ImageRect(trialSuccess);
imgRect = tmp_imgRect{1};
outCSV = fullfile(outDir, 'fixations_data.csv');

% --- Export Fixations to CSV ---
fprintf('Starting fixation export...\n');
extract_fixations(edf, eventKey, timeForView, imageShown, imgRect, outCSV);
fprintf('Export complete: %s\n', outCSV);

% --- Plot 1x3 summary (x, y, duration) and save PNG next to CSV ---
outPNG = fullfile(outDir, 'fixations_summary.png');
% Screen-size max per axis (imgRect width and height).
coordMax = [imgRect(3) - imgRect(1), imgRect(4) - imgRect(2)];
plot_fixations(outCSV, outPNG, coordMax);
