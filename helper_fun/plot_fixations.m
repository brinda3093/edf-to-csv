function plot_fixations(csvPath, outImagePath, coordMax)
% plot_fixations  Render a publication-ready 1x3 histogram figure of x, y,
% and Duration from the fixations CSV produced by extract_fixations.
%
% Inputs:
%   csvPath      - Path to the fixations CSV file.
%   outImagePath - (optional) Path to save the figure as PNG (300 dpi).
%                  If omitted/empty, the figure is shown on screen only.
%   coordMax     - (optional) 2-element vector [maxX maxY] giving the maximum
%                  possible x and y coordinate values (e.g. imgRect width-1
%                  and height-1). When provided, panels 1 and 2 have their
%                  x-axis extended to that max with an explicit tick at it.

if ~isfile(csvPath)
    error('plot_fixations: CSV not found: %s', csvPath);
end
T = readtable(csvPath);
if height(T) == 0
    warning('plot_fixations: CSV has no rows; nothing to plot.');
    return;
end

% Okabe-Ito colorblind-friendly palette: blue, vermillion, bluish-green
colors = [0.000 0.447 0.741;   % blue
          0.835 0.369 0.000;   % vermillion
          0.000 0.620 0.451];  % bluish-green

fig = figure('Color','w', ...
             'Units','inches', ...
             'Position',[1 1 11 3.4], ...
             'Visible','off');

% Bin widths: 50 px for x/y (same), 25 ms for Duration
% Fourth column is the panel's normalized [left width] for figure layout
% (third panel is narrower than the first two).
panels = { ...
    T.x,        'x coordinates (px)',     25, [0.06 0.31];  ...
    T.y,        'y coordinates (px)',     25, [0.44 0.31];  ...
    T.Duration, 'Fixation duration (ms)', 25, [0.82 0.16] };

panelBottom = 0.18;
panelHeight = 0.75;

for k = 1:3
    pos = [panels{k,4}(1), panelBottom, panels{k,4}(2), panelHeight];
    ax = axes('Position', pos); %#ok<LAXES>
    histogram(panels{k,1}, ...
        'BinWidth', panels{k,3}, ...
        'FaceColor', colors(k,:), ...
        'EdgeColor', 'w', ...
        'LineWidth', 0.5, ...
        'FaceAlpha', 0.9);
    xlabel(panels{k,2}, 'FontSize', 12);
    ylabel('Count', 'FontSize', 12);

    ax.FontName     = 'Helvetica';
    ax.FontSize     = 11;
    ax.FontWeight   = 'normal';
    ax.LineWidth    = 1.1;
    ax.TickDir      = 'out';
    ax.TickLength   = [0.015 0.015];
    ax.Box          = 'off';
    ax.XColor       = [0.15 0.15 0.15];
    ax.YColor       = [0.15 0.15 0.15];
    ax.XLimitMethod = 'tight';

    % For the first two panels, extend the x-axis to the max possible
    % coordinate value (if provided) and ensure that value is a tick.
    % Drop any auto-tick that would collide with the max label.
    if k <= 2 && nargin >= 3 && numel(coordMax) >= 2
        m = coordMax(k);
        ax.XLim  = [0 m];
        ticks    = ax.XTick;
        minGap   = 0.12 * m;          % ~12% of axis range
        ax.XTick = [ticks(ticks < m - minGap), m];
    end
end

if nargin >= 2 && ~isempty(outImagePath)
    exportgraphics(fig, outImagePath, 'Resolution', 300);
    fprintf('Saved figure to %s\n', outImagePath);
end

% Show the figure on screen after rendering / saving.
set(fig, 'Visible', 'on');
drawnow;
end
