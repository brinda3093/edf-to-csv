function extract_fixations(edf, eventKey, timeForView, imageShown, imgRect, outCSV)
% extract_fixations  Export Eyelink-detected fixations within an imgRect to CSV.
% Fixations are filtered to be within the provided imgRect (screen coordinates),
% and their coordinates are saved as local to that imgRect's top-left.
%
% Inputs:
%   edf          - Structure from Edf2Mat.
%   eventKey     - String key for trial start messages (e.g., 'FreeView').
%   timeForView  - Duration of free viewing (ms).
%   imageShown   - Cell array of image filenames corresponding to filtered freeViewTimes.
%   imgRect      - 4-element vector [xmin, ymin, xmax, ymax] defining the
%                  image's display area in screen coordinates.
%   outCSV       - Output CSV filepath.

if isempty(imgRect) || numel(imgRect) ~= 4
    error('extract_fixations: Input imgRect must be a 4-element vector [xmin, ymin, xmax, ymax].');
end

img_screen_xmin = imgRect(1);
img_screen_ymin = imgRect(2);
img_screen_xmax = imgRect(3);
img_screen_ymax = imgRect(4);

img_display_width  = img_screen_xmax - img_screen_xmin;
img_display_height = img_screen_ymax - img_screen_ymin;

if img_display_width <= 0 || img_display_height <= 0
    error('extract_fixations: imgRect has invalid width or height (xmin >= xmax or ymin >= ymax).');
end

% 1) Identify Free-viewing events
freeViewTimes = [];
for iMsg = 1:length(edf.Events.Messages.info)
    if contains(edf.Events.Messages.info{iMsg}, eventKey)
        freeViewTimes(end+1) = edf.Events.Messages.time(iMsg); %#ok<AGROW>
    end
end

nTrials = length(freeViewTimes);
if nTrials == 0
    fprintf('No valid trials found. CSV will be empty.\n');
    writetable(table('Size',[0 7],'VariableTypes',{'double','cell','double','double','double','double','cell'},...
        'VariableNames', {'Subject', 'Scene', 'FixationNumber', 'x', 'y', 'Duration', 'Task'}), outCSV);
    fprintf('Wrote empty table to %s\n', outCSV);
    return;
end

% 2) Build a table of all fixations using Eyelink's detected fixations
SubjectList = []; SceneList = {}; FixNumList = [];
xList = []; yList = []; DurList = []; TaskList = {};
globalFixCounter = 0;

for iTrial = 1:nTrials
    startTime_local = freeViewTimes(iTrial);
    endTime_local   = startTime_local + timeForView;

    rawSceneName = imageShown{iTrial};
    [~, sceneNameNoExt, ~] = fileparts(rawSceneName);
    fixNumThisTrial = 0;

    fixIndicesInWindow = find(edf.Events.Efix.start >= startTime_local & ...
        edf.Events.Efix.start <= endTime_local);

    for k_idx = 1:length(fixIndicesInWindow)
        fix_event_idx = fixIndicesInWindow(k_idx);
        curX_screen = round(edf.Events.Efix.posX(fix_event_idx));
        curY_screen = round(edf.Events.Efix.posY(fix_event_idx));
        curDuration = edf.Events.Efix.duration(fix_event_idx);

        % Check if fixation (screen coords) is within the provided imgRect.
        % imgRect [xmin, ymin, xmax, ymax] comes from PsychToolbox destinationRect,
        % where xmax and ymax are exclusive upper bounds.
        if curX_screen >= img_screen_xmin && curX_screen < img_screen_xmax && ...
                curY_screen >= img_screen_ymin && curY_screen < img_screen_ymax

            float_curX_imgLocal = curX_screen - img_screen_xmin;
            float_curY_imgLocal = curY_screen - img_screen_ymin;

            rounded_x = round(float_curX_imgLocal);
            if rounded_x == img_display_width
                final_x_to_store = img_display_width - 1;
            else
                final_x_to_store = rounded_x;
            end

            rounded_y = round(float_curY_imgLocal);
            if rounded_y == img_display_height
                final_y_to_store = img_display_height - 1;
            else
                final_y_to_store = rounded_y;
            end

            fixNumThisTrial = fixNumThisTrial + 1;
            globalFixCounter = globalFixCounter + 1;
            SubjectList(globalFixCounter, 1) = 1;
            SceneList{globalFixCounter, 1} = sceneNameNoExt;
            FixNumList(globalFixCounter, 1) = fixNumThisTrial;
            xList(globalFixCounter, 1) = final_x_to_store;
            yList(globalFixCounter, 1) = final_y_to_store;
            DurList(globalFixCounter, 1) = curDuration;
            TaskList{globalFixCounter, 1} = 'freeviewing';
        end
    end
end

if globalFixCounter > 0
    T = table(SubjectList, SceneList, FixNumList, xList, yList, DurList, TaskList, ...
        'VariableNames', {'Subject', 'Scene', 'FixationNumber', 'x', 'y', 'Duration', 'Task'});
else
    T = table('Size',[0 7],'VariableTypes',{'double','cell','double','double','double','double','cell'},...
        'VariableNames', {'Subject', 'Scene', 'FixationNumber', 'x', 'y', 'Duration', 'Task'});
end
writetable(T, outCSV);
fprintf('Wrote %d fixations to %s\n', height(T), outCSV);
end
