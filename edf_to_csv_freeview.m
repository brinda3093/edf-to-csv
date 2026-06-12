%% edf_to_csv_freeview.m
% Convert EDF + MAT data from the FreeView fixation paradigm to CSV.
% Paradigm files: fixationReward_final_withImage.m / fixationWrapper_freeview.m
%
% MAT files expected (saved by the paradigm's exp_end case):
%   {sessionName}.mat          -> Results table
%   {sessionName}cfg.mat       -> cfg struct
%   {sessionName}imgBlocks.mat -> allBlocks cell array (DstRect per image)

scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir), scriptDir = pwd; end

% --- Session to process ---
sessionName = 'fvstim2';   % edfFile name used during recording (no extension)
dataDir     = 'D:\Ripple_data\090925\matlab';
outDir      = fullfile('D:\Ripple_data\090925\matlab', 'secondary_data');

if ~exist(outDir, 'dir'), mkdir(outDir); end

edfConverterPath = fullfile(scriptDir, 'edf-converter-master');
helperPath       = fullfile(scriptDir, 'helper_fun');

if ~isfolder(edfConverterPath), error('Edf2Mat converter path not found: %s', edfConverterPath); end
if ~isfolder(helperPath),       error('helper_fun path not found: %s', helperPath); end
addpath(edfConverterPath);
addpath(helperPath);

% --- Load EDF ---
origDir = pwd;
cd(dataDir);
if ~isfile([sessionName '.edf']), error('EDF file not found in %s', dataDir); end
edf = Edf2Mat([sessionName '.edf']);
cd(origDir);

% --- Load MAT files saved by paradigm ---
load(fullfile(dataDir, [sessionName '.mat']),          'Results');
load(fullfile(dataDir, [sessionName 'cfg.mat']),       'cfg');
load(fullfile(dataDir, [sessionName 'imgBlocks.mat']), 'allBlocks');

% --- Derive imgRect from allBlocks ---
% All images from the same folder share the same display rect when they have
% the same resolution. If your images have mixed resolutions, pass the rect
% for each trial explicitly (see extract_fixations_freeview for that option).
allDstRects = [allBlocks{1}.DstRect; allBlocks{2}.DstRect];
imgRect = allDstRects{1};   % [xmin ymin xmax ymax]

% --- Extract fixations and write CSV ---
eventKey    = 'FreeviewStart';
timeForView = cfg.FreeViewTime * 1000;   % seconds -> ms
subjectName = cfg.sub;
outCSV      = fullfile(outDir, [sessionName '_fixations.csv']);

fprintf('Starting fixation export...\n');
extract_fixations_freeview(edf, eventKey, timeForView, Results, imgRect, subjectName, outCSV);
fprintf('Export complete: %s\n', outCSV);

% --- Optional: plot summary (reuses existing helper) ---
outPNG    = fullfile(outDir, [sessionName '_fixations_summary.png']);
coordMax  = [imgRect(3) - imgRect(1), imgRect(4) - imgRect(2)];
plot_fixations(outCSV, outPNG, coordMax);
