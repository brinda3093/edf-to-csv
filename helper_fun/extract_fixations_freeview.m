function extract_fixations_freeview(edf, eventKey, timeForView, Results, imgRect, subjectName, outCSV)
% extract_fixations_freeview  Export fixations from FreeView paradigm to CSV.
%
% Parses EDF messages matching eventKey to find the onset of each free-view
% period. The trial number embedded in each message (e.g. "FreeviewStart 3")
% is used to look up image name and trial type from the Results table.
%
% Inputs:
%   edf          - Struct from Edf2Mat.
%   eventKey     - EDF message prefix marking free-view onset ('FreeviewStart').
%   timeForView  - Length of the free-viewing window in ms (cfg.FreeViewTime*1000).
%   Results      - Results table saved by the paradigm.
%   imgRect      - [xmin ymin xmax ymax] display rect of image in screen pixels.
%                  Pass a cell array of per-trial rects if images differ in size.
%   subjectName  - String written to the Subject column (cfg.sub).
%   outCSV       - Output CSV filepath.
%
% Output CSV columns:
%   Subject, Trial, Scene, FixationNumber, x, y, Duration, TrialType

emptyTable = table('Size', [0 8], ...
    'VariableTypes', {'cell','double','cell','double','double','double','double','cell'}, ...
    'VariableNames', {'Subject','Trial','Scene','FixationNumber','x','y','Duration','TrialType'});

% Validate imgRect
usePerTrialRects = iscell(imgRect);
if ~usePerTrialRects
    if numel(imgRect) ~= 4
        error('imgRect must be a 4-element vector [xmin ymin xmax ymax] or a cell array of such vectors.');
    end
    img_xmin = imgRect(1); img_ymin = imgRect(2);
    img_xmax = imgRect(3); img_ymax = imgRect(4);
    if (img_xmax - img_xmin) <= 0 || (img_ymax - img_ymin) <= 0
        error('imgRect has non-positive width or height.');
    end
end

% 1) Parse EDF messages to find free-view END times and their trial numbers.
% NOTE: 'FreeviewStart' is sent AFTER the free-view loop completes (i.e. it
% marks the END of the 5-second window, not the start). The actual free-view
% window is therefore [msgTime - timeForView, msgTime].
freeViewOnsets = [];
trialNums      = [];
for iMsg = 1:length(edf.Events.Messages.info)
    msg = edf.Events.Messages.info{iMsg};
    if contains(msg, eventKey)
        tokens = regexp(msg, '\d+', 'match');
        if ~isempty(tokens)
            trialNums(end+1) = str2double(tokens{end}); %#ok<AGROW>
        else
            trialNums(end+1) = numel(freeViewOnsets) + 1; %#ok<AGROW>
        end
        freeViewOnsets(end+1) = edf.Events.Messages.time(iMsg); %#ok<AGROW>
    end
end

nTrials = numel(freeViewOnsets);
if nTrials == 0
    fprintf('No "%s" messages found in EDF — writing empty CSV.\n', eventKey);
    writetable(emptyTable, outCSV);
    return;
end

% 2) Build fixation rows
SubjectList = {}; TrialList = []; SceneList = {}; FixNumList = [];
xList = []; yList = []; DurList = []; TypeList = {};
globalFixCounter = 0;

for iTrial = 1:nTrials
    t1       = freeViewOnsets(iTrial);      % message is sent after the loop ends
    t0       = t1 - timeForView;           % so subtract to get the true onset
    trialNum = trialNums(iTrial);

    % Per-trial rect (if provided as cell array)
    if usePerTrialRects
        if iTrial <= numel(imgRect)
            r = imgRect{iTrial};
        else
            r = imgRect{end};
        end
        img_xmin = r(1); img_ymin = r(2); img_xmax = r(3); img_ymax = r(4);
    end
    img_w = img_xmax - img_xmin;
    img_h = img_ymax - img_ymin;

    % Image name from Results
    sceneName = sprintf('trial_%d', trialNum);
    if trialNum <= height(Results) && ismember('ImgName', Results.Properties.VariableNames)
        raw = Results.ImgName(trialNum);
        if iscell(raw),   raw = raw{1};  end
        if isstring(raw), raw = char(raw); end
        if ischar(raw) && ~all(raw == ' ') && ~isempty(raw)
            [~, sceneName, ~] = fileparts(raw);
        end
    end

    % Trial type from Results (set in fix_with_img stage: 'Stimulation' or 'Blank')
    trialType = 'Unknown';
    if trialNum <= height(Results) && ismember('TrialType', Results.Properties.VariableNames)
        tt = Results.TrialType(trialNum);
        if iscell(tt),    tt = tt{1};   end
        if isstring(tt),  tt = char(tt); end
        if ischar(tt) && ~isempty(tt) && ~all(tt == ' ')
            trialType = tt;
        end
    end

    % Fixations within the free-view window
    fixIdx = find(edf.Events.Efix.start >= t0 & edf.Events.Efix.start <= t1);
    fixNumThisTrial = 0;

    for k = 1:numel(fixIdx)
        fi   = fixIdx(k);
        fx   = round(edf.Events.Efix.posX(fi));
        fy   = round(edf.Events.Efix.posY(fi));
        fdur = edf.Events.Efix.duration(fi);

        if fx >= img_xmin && fx < img_xmax && fy >= img_ymin && fy < img_ymax
            lx = fx - img_xmin;  if lx == img_w, lx = img_w - 1; end
            ly = fy - img_ymin;  if ly == img_h, ly = img_h - 1; end

            fixNumThisTrial  = fixNumThisTrial + 1;
            globalFixCounter = globalFixCounter + 1;

            SubjectList{globalFixCounter, 1} = subjectName;
            TrialList(globalFixCounter, 1)   = trialNum;
            SceneList{globalFixCounter, 1}   = sceneName;
            FixNumList(globalFixCounter, 1)  = fixNumThisTrial;
            xList(globalFixCounter, 1)       = lx;
            yList(globalFixCounter, 1)       = ly;
            DurList(globalFixCounter, 1)     = fdur;
            TypeList{globalFixCounter, 1}    = trialType;
        end
    end
end

% 3) Write CSV
if globalFixCounter > 0
    T = table(SubjectList, TrialList, SceneList, FixNumList, xList, yList, DurList, TypeList, ...
        'VariableNames', {'Subject','Trial','Scene','FixationNumber','x','y','Duration','TrialType'});
else
    T = emptyTable;
end
writetable(T, outCSV);
fprintf('Wrote %d fixations across %d free-view trials to %s\n', globalFixCounter, nTrials, outCSV);
end
