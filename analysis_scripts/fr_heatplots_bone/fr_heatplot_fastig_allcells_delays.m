%% ================================================================
% Single-file population heatmaps:
% Catch/control and stimulation delay conditions
%
% Segment names expected in Data.segments:
%
%   active_like_stim_neg_nan
%   active_like_stim_pos_nan
%
%   active_like_stim_neg_0
%   active_like_stim_pos_0
%
%   active_like_stim_neg_100
%   active_like_stim_pos_100
%
%   active_like_stim_neg_200
%   active_like_stim_pos_200
%
% Logic:
%   - Catch/control "_nan" trials are aligned to first abs(headYawVel) >= 85 deg/s.
%   - Delay 0 trials are aligned to stimulation onset.
%   - Delay 100 trials are aligned to stimulation onset - 100 ms.
%   - Delay 200 trials are aligned to stimulation onset - 200 ms.
%
%   Therefore time 0 is the estimated 0-delay reference for all conditions.
%
%   - Preferred direction is determined from catch/control "_nan" trials.
%   - Normalization is computed from catch/control "_nan" trials.
%   - Neuron order is determined from catch/control "_nan" trials.
%   - Same preferred direction, normalization, and order are applied to all conditions.
%% ================================================================

colordef white
clear
clc

%% ---------------- Parameters ----------------

stim_var2 = 'headYawVel';

FsSpike = 30000;      % spike timestamp sampling rate
FsBeh   = 1000;       % behavioral sampling rate

preTime  = 300;       % ms before alignment point
postTime = 600;       % ms after alignment point

win = -preTime:postTime;

sigma = 30;           % Gaussian smoothing kernel width, ms

x = -4*sigma:4*sigma;
g = exp(-(x.^2)/(2*sigma^2));
g = g / sum(g);

velocityThreshold = 85;   % deg/s threshold for catch/control alignment

%% ---------------- Custom pink/purple colormap ----------------

nColors = 256;

% Anchor colors:
% value 0   = dark purple
% value 0.4 = bright pink
% value 1   = very light pink / white

anchorColors = [
    25   0   70;    % deep purple
    40   70  180;   % royal blue
    80   200 255;   % cyan-blue
    250  250 255    % near white
] / 255;

anchorVals = [0 0.35 0.75 1];

customPinkMap = interp1(anchorVals, anchorColors, linspace(0,1,nColors));

%% ---------------- Conditions based directly on segment names ----------------

% These are the suffixes used in Data.segments:
% active_like_stim_neg_SUFFIX
% active_like_stim_pos_SUFFIX

condLabels = {'nan','0','100','200'};

% Numeric delay in ms for shifting stimulation-aligned trials.
% This is only used after the segment has already been identified by name.
condDelays = [NaN, 0, 100, 200];

catchLabel = 'nan';

sides = {'neg','pos'};

nCond = length(condLabels);

catchIdx = find(strcmp(condLabels, catchLabel));

fprintf('Catch/control condition is "%s", condition index %d\n', ...
    condLabels{catchIdx}, catchIdx)

%% ---------------- Load one file ----------------

Path = '\\cullenstor\data\Current Project Databases - NHP\2025 Cerebellum prosthesis\Bert\BL_RW_003_Session_1\Calibrated\IntanFile_3';
paradigm = 'BL_closed_loop_STIM_003_006_Cal_stim_stitched_individual';

load(fullfile(Path,[paradigm '.mat']))

%% ---------------- Find stimulation onsets ----------------

stimOnsets = findStimOnsets(Data.Neural(:,1), FsSpike, FsBeh);

fprintf('Detected %d stimulation trains\n', length(stimOnsets))

%% Optional sanity-check plot: detected stimulation onsets

figure('Color','w')
plot(Data.(stim_var2),'k')
hold on

for i = 1:length(stimOnsets)
    xline(stimOnsets(i),'r')
end

xlabel('Time, behavioral samples')
ylabel(stim_var2)
title('Detected stimulation train onsets')
box off

%% ---------------- Find neurons ----------------

fields = fieldnames(Data);
unitFields = fields(startsWith(fields,'unit_'));

unitNumbers = cellfun(@(x) sscanf(x,'unit_%d'), unitFields);

fprintf('Found %d neurons\n', length(unitFields))

nUnits = length(unitFields);
nTime  = length(win);

%% ================================================================
% Storage
%% ================================================================

% Raw mean FR:
% time x neuron x side x condition
%
% side:
%   1 = neg
%   2 = pos
%
% condition:
%   1 = nan/catch
%   2 = 0
%   3 = 100
%   4 = 200

FRmean_all = nan(nTime, nUnits, 2, nCond);

% Mean velocity:
% time x side x condition
VelMean_all = nan(nTime, 2, nCond);

% Number of valid trials:
% neuron x side x condition
nTrials_all = zeros(nUnits, 2, nCond);

% Preferred side based on catch trials:
% 1 = neg, 2 = pos
preferredSide = nan(1,nUnits);

% Normalization peak from catch preferred-direction response
normPeak = nan(1,nUnits);

% Preferred-side normalized responses:
% time x neuron x condition
FRpref_norm = nan(nTime, nUnits, nCond);

%% ================================================================
% Process neurons
%% ================================================================

for n = 1:nUnits

    fprintf('Neuron %d/%d: %s\n', n, nUnits, unitFields{n})

    %% ---------------- Build smoothed firing rate ----------------

    spikeTimes = double(Data.(unitFields{n}));

    % Convert spike samples/timestamps from spike rate to behavioral rate
    spikeSamples = round(spikeTimes / FsSpike * FsBeh);

    spikeSamples(spikeSamples < 1) = [];
    spikeSamples(spikeSamples > length(Data.(stim_var2))) = [];

    spikeTrain = zeros(length(Data.(stim_var2)),1);

    % In case multiple spikes round to the same behavioral sample:
    for sp = 1:length(spikeSamples)
        spikeTrain(spikeSamples(sp)) = spikeTrain(spikeSamples(sp)) + 1;
    end

    FR = conv(spikeTrain * 1000, g, 'same');

    %% ---------------- Loop over named conditions and movement directions ----------------

    for c = 1:nCond

        condLabel = condLabels{c};

        for s = 1:2

            sideLabel = sides{s};

            % Segment field name is constructed directly from naming convention
            segField = ['active_like_stim_' sideLabel '_' condLabel];

            fprintf('  Condition %s, side %s, field %s\n', ...
                condLabel, sideLabel, segField)

            segs = Data.segments.(segField);

            FRtrials  = [];
            VelTrials = [];

            for k = 1:size(segs,1)

                seg_start = segs(k,1);
                seg_end   = segs(k,2);

                %% ---------------- Alignment based on segment name ----------------

                if strcmp(condLabel, 'nan')

                    % Catch/control trials:
                    % align to first velocity threshold crossing

                    vel_segment = Data.(stim_var2)(seg_start:seg_end);

                    cross_idx = find(abs(vel_segment) >= velocityThreshold, 1, 'first');

                    if isempty(cross_idx)
                        continue
                    end

                    alignPoint = seg_start + cross_idx - 1;

else

    % Stimulated trials:
    % find stimulation onset associated with this segment.
    %
    % Stimulation may occur after seg_end, especially for delayed stim,
    % so search from segment start to segment start + 400 ms.

    delayMs = condDelays(c);

    stimSearchStart = seg_start;
    stimSearchEnd   = seg_start + 400;   % ms/samples at FsBeh = 1000 Hz

    stim_idx = find(stimOnsets >= stimSearchStart & ...
                    stimOnsets <= stimSearchEnd);

    if isempty(stim_idx)
        continue
    end

    % Use the first stimulation train found after segment start.
    stimTime = stimOnsets(stim_idx(1));

    % Align all conditions to the estimated 0-delay reference.
    %
    % delay 0:   alignPoint = stimTime
    % delay 100: alignPoint = stimTime - 100
    % delay 200: alignPoint = stimTime - 200
    %
    % Therefore actual stimulation appears at +delay on the heatmap.

    alignPoint = stimTime - delayMs;

end

                alignPoint = round(alignPoint);

                %% ---------------- Extract peri-event window ----------------

                idx = alignPoint - preTime : alignPoint + postTime;

                if idx(1) < 1 || idx(end) > length(FR)
                    continue
                end

                FRtrials(:,end+1)  = FR(idx);
                VelTrials(:,end+1) = Data.(stim_var2)(idx);

            end

            %% ---------------- Average trials ----------------

            nTrials_all(n,s,c) = size(FRtrials,2);

            if ~isempty(FRtrials)
                FRmean_all(:,n,s,c) = mean(FRtrials, 2, 'omitnan');
            end

            % Velocity does not depend on neuron, so store it once.
            if n == 1 && ~isempty(VelTrials)
                VelMean_all(:,s,c) = mean(VelTrials, 2, 'omitnan');
            end

        end
    end

    %% ============================================================
    % Preferred direction from catch/control "_nan" trials
    %% ============================================================

    FR_neg_catch = FRmean_all(:,n,1,catchIdx);
    FR_pos_catch = FRmean_all(:,n,2,catchIdx);

    if all(isnan(FR_neg_catch)) && all(isnan(FR_pos_catch))
        warning('No valid catch/control data for neuron %s', unitFields{n})
        continue
    end

    baseline_neg = mean(FR_neg_catch(1:preTime), 'omitnan');
    baseline_pos = mean(FR_pos_catch(1:preTime), 'omitnan');

    modNeg = max(FR_neg_catch(preTime+1:end), [], 'omitnan') - baseline_neg;
    modPos = max(FR_pos_catch(preTime+1:end), [], 'omitnan') - baseline_pos;

    if modPos >= modNeg
        preferredSide(n) = 2;   % pos
    else
        preferredSide(n) = 1;   % neg
    end

    %% ============================================================
    % Normalization from catch/control preferred-direction response
    %% ============================================================

    prefCatch = FRmean_all(:,n,preferredSide(n),catchIdx);

    % Normalize by peak in 0 to 400 ms after catch threshold crossing.
    normWindow = preTime+1 : preTime+401;

    peak = max(prefCatch(normWindow), [], 'omitnan');

    if isempty(peak) || isnan(peak) || peak <= 0
        peak = 1;
    end

    normPeak(n) = peak;

    %% ============================================================
    % Apply same preferred side and catch-derived normalization
    % to every named condition
    %% ============================================================

    for c = 1:nCond

        FRpref_norm(:,n,c) = FRmean_all(:,n,preferredSide(n),c) / normPeak(n);

    end

end

%% ================================================================
% Remove neurons without usable catch/control response
%% ================================================================

fr_catch = FRpref_norm(:,:,catchIdx);

badNeurons = all(isnan(fr_catch),1);

FRpref_norm(:,badNeurons,:) = [];
FRmean_all(:,badNeurons,:,:) = [];
nTrials_all(badNeurons,:,:) = [];
unitNumbers(badNeurons) = [];
preferredSide(badNeurons) = [];
normPeak(badNeurons) = [];

fprintf('Kept %d neurons after removing neurons without catch/control data\n', ...
    size(FRpref_norm,2))

%% ================================================================
% Sort neurons based on catch/control latency
%% ================================================================

fr_catch = FRpref_norm(:,:,catchIdx);

% Sort by peak latency in first 250 ms after threshold crossing.
searchWindow = preTime+1 : preTime+251;

[~, peakLoc] = max(fr_catch(searchWindow,:), [], 1, 'omitnan');

[~, order] = sort(peakLoc);

% Apply same order to all conditions.
% FRsorted dimensions:
% neuron x time x condition
FRsorted = nan(size(FRpref_norm,2), nTime, nCond);

for c = 1:nCond

    tmp = FRpref_norm(:,order,c)';   % neuron x time

    % Flip so early-latency neurons are visually near the top.
    FRsorted(:,:,c) = flipud(tmp);

end

sortedUnitNumbers = unitNumbers(order);
sortedUnitNumbers = flipud(sortedUnitNumbers(:));

sortedPreferredSide = preferredSide(order);
sortedPreferredSide = flipud(sortedPreferredSide(:));

%% ================================================================
% Manually remove bad rows from heatmap
%% ================================================================

badRows = [1 3:6 11:13 16 20:22 27 29 31 39 42 43 45 46 53 55 57 61 63:70 73];

% Keep only valid row numbers in case some exceed number of neurons
badRows = badRows(badRows <= size(FRsorted,1));

fprintf('Removing %d manually selected heatmap rows\n', length(badRows))

% Remove from sorted heatmap matrix
FRsorted(badRows,:,:) = [];

% Remove corresponding sorted neuron metadata
sortedUnitNumbers(badRows) = [];
sortedPreferredSide(badRows) = [];

%% ================================================================
% Plot 4 heatmaps:
%   catch/control nan, delay 0, delay 100, delay 200
%% ================================================================

figure('Color','w')

for c = 1:nCond

    subplot(1,nCond,c)

    imagesc(win, 1:size(FRsorted,1), FRsorted(:,:,c))

    axis xy
    colormap(customPinkMap)
    colorbar

    % Time zero:
    % catch = threshold crossing
    % stim conditions = estimated 0-delay stimulation reference
    xline(0,'r--','LineWidth',1.5)

    % Mark actual stimulation time for stimulation conditions.
    % For delay 0 this is at 0 ms.
    % For delay 100 this is at 100 ms.
    % For delay 200 this is at 200 ms.
    if ~strcmp(condLabels{c}, 'nan')
        xline(condDelays(c),'b--','LineWidth',1.2)
    end

    xlabel('Time from 0-delay reference / catch threshold crossing (ms)')
    ylabel('Neuron')

    if strcmp(condLabels{c}, 'nan')
        title('Catch/control, nan')
    else
        title(['Stim delay ' condLabels{c} ' ms'])
    end

    caxis([0 1])
    box off

end

sgtitle('Preferred-direction heatmaps ordered by catch/control latency')

%% ================================================================
% Plot velocity traces for each condition
%% ================================================================

figure('Color','w')

for c = 1:nCond

    subplot(1,nCond,c)
    hold on

    plot(win, VelMean_all(:,1,c), 'b', 'LineWidth', 1.5)
    plot(win, VelMean_all(:,2,c), 'r', 'LineWidth', 1.5)

    xline(0,'k--','LineWidth',1.2)

    if ~strcmp(condLabels{c}, 'nan')
        xline(condDelays(c),'m--','LineWidth',1.2)
    end

    xlabel('Time from alignment point (ms)')
    ylabel(stim_var2)

    if strcmp(condLabels{c}, 'nan')
        title('Catch/control velocity')
    else
        title(['Delay ' condLabels{c} ' velocity'])
    end

    legend({'neg','pos'},'Location','best')
    box off

end

sgtitle('Mean velocity traces')

%% ================================================================
% Difference heatmaps relative to catch/control
%% ================================================================

figure('Color','w')

frCatchSorted = FRsorted(:,:,catchIdx);

stimCondIdx = find(~strcmp(condLabels,'nan'));

for i = 1:length(stimCondIdx)

    c = stimCondIdx(i);

    subplot(1,length(stimCondIdx),i)

    diffMat = FRsorted(:,:,c) - frCatchSorted;

    imagesc(win, 1:size(diffMat,1), diffMat)

    axis xy
    colormap(customPinkMap)
    colorbar

    xline(0,'r--','LineWidth',1.5)
    xline(condDelays(c),'b--','LineWidth',1.2)

    xlabel('Time from 0-delay reference (ms)')
    ylabel('Neuron')
    title(['Delay ' condLabels{c} ' - catch'])

    box off

end

sgtitle('Stimulation conditions minus catch/control')

%% ================================================================
% Trial count summary
%% ================================================================

fprintf('\nTrial counts by condition and side, averaged over neurons:\n')

for c = 1:nCond
    for s = 1:2

        meanTrials = mean(nTrials_all(:,s,c), 'omitnan');

        fprintf('  %s / %s: %.1f trials per neuron\n', ...
            condLabels{c}, sides{s}, meanTrials)

    end
end

%% ================================================================
% Save output
%% ================================================================

save('MultiDelay_stim_catch_heatmaps.mat', ...
    'FRpref_norm', ...
    'FRsorted', ...
    'FRmean_all', ...
    'VelMean_all', ...
    'nTrials_all', ...
    'condLabels', ...
    'condDelays', ...
    'catchIdx', ...
    'preferredSide', ...
    'sortedPreferredSide', ...
    'unitNumbers', ...
    'sortedUnitNumbers', ...
    'order', ...
    'normPeak', ...
    'stimOnsets', ...
    'win', ...
    'preTime', ...
    'postTime', ...
    'velocityThreshold')



%% ================================================================
% Trial-by-trial spike-count analysis
% Avoids smoothing/blanking bleed from firing-rate convolution
%% ================================================================

baselineWin = [-250 -150];   % relative to alignment point
postStimWin = [50 150];     % relative to actual stim onset

% For catch trials, because there is no actual stim,
% compare the same absolute windows relative to alignment point.
% You can choose the window matching delay 0, or compare stim to catch
% in each condition's actual post-stim time window.

stimSearchMaxFromSegStart = 400;  % ms

nUnits = length(unitFields);
nCond = length(condLabels);

% Cell array: spikeCounts{unit, side, condition}
% Each cell contains trials x 1 counts
spikeCounts_baseline = cell(nUnits,2,nCond);
spikeCounts_post     = cell(nUnits,2,nCond);

alignTimes_byTrial = cell(2,nCond);
stimTimes_byTrial  = cell(2,nCond);

for n = 1:nUnits

    fprintf('Spike count analysis neuron %d/%d\n', n, nUnits)

    spikeTimes_beh = double(Data.(unitFields{n})) / FsSpike * FsBeh;
    spikeTimes_beh = spikeTimes_beh(:);

    for c = 1:nCond

        condLabel = condLabels{c};

        for s = 1:2

            sideLabel = sides{s};
            segField = ['active_like_stim_' sideLabel '_' condLabel];

            segs = Data.segments.(segField);

            baseCounts = [];
            postCounts = [];

            thisAlignTimes = [];
            thisStimTimes = [];

            for k = 1:size(segs,1)

                seg_start = segs(k,1);
                seg_end   = segs(k,2);

                %% ---------------- Determine alignment point ----------------

                if strcmp(condLabel,'nan')

                    % Catch/control:
                    % align to velocity threshold crossing

                    vel_segment = Data.(stim_var2)(seg_start:seg_end);
                    cross_idx = find(abs(vel_segment) >= velocityThreshold, 1, 'first');

                    if isempty(cross_idx)
                        continue
                    end

                    alignPoint = seg_start + cross_idx - 1;
                    stimTime = NaN;

                    % For catch trials, define post window relative to alignment.
                    % This makes catch comparable to delay 0 post-stim timing.
                    postStart = alignPoint + postStimWin(1);
                    postEnd   = alignPoint + postStimWin(2);

                else

                    % Stim trials:
                    % find stimulation within ~400 ms after segment start

                    delayMs = condDelays(c);

                    stim_idx = find(stimOnsets >= seg_start & ...
                                    stimOnsets <= seg_start + stimSearchMaxFromSegStart);

                    if isempty(stim_idx)
                        continue
                    end

                    stimTime = stimOnsets(stim_idx(1));

                    % Common alignment point = estimated 0-delay reference
                    alignPoint = stimTime - delayMs;

                    % Post-stim response window relative to actual stim onset
                    postStart = stimTime + postStimWin(1);
                    postEnd   = stimTime + postStimWin(2);

                end

                %% ---------------- Baseline window ----------------

                baseStart = alignPoint + baselineWin(1);
                baseEnd   = alignPoint + baselineWin(2);

                % Skip invalid windows
                if baseStart < 1 || postEnd > length(Data.(stim_var2))
                    continue
                end

                %% ---------------- Count spikes ----------------

                baseCount = sum(spikeTimes_beh >= baseStart & spikeTimes_beh < baseEnd);
                postCount = sum(spikeTimes_beh >= postStart & spikeTimes_beh < postEnd);

                baseCounts(end+1,1) = baseCount;
                postCounts(end+1,1) = postCount;

                thisAlignTimes(end+1,1) = alignPoint;
                thisStimTimes(end+1,1) = stimTime;

            end

            spikeCounts_baseline{n,s,c} = baseCounts;
            spikeCounts_post{n,s,c}     = postCounts;

            if n == 1
                alignTimes_byTrial{s,c} = thisAlignTimes;
                stimTimes_byTrial{s,c}  = thisStimTimes;
            end

        end
    end
end
%% ================================================================
% Convert spike counts to rates and compute post-baseline modulation
%% ================================================================

baselineDur_s = diff(baselineWin) / 1000;
postDur_s     = diff(postStimWin) / 1000;

countRate_base_mean = nan(nUnits,2,nCond);
countRate_post_mean = nan(nUnits,2,nCond);
countRate_delta     = nan(nUnits,2,nCond);

for n = 1:nUnits
    for s = 1:2
        for c = 1:nCond

            baseCounts = spikeCounts_baseline{n,s,c};
            postCounts = spikeCounts_post{n,s,c};

            if isempty(baseCounts) || isempty(postCounts)
                continue
            end

            baseRate = baseCounts / baselineDur_s;
            postRate = postCounts / postDur_s;

            countRate_base_mean(n,s,c) = mean(baseRate,'omitnan');
            countRate_post_mean(n,s,c) = mean(postRate,'omitnan');

            countRate_delta(n,s,c) = mean(postRate - baseRate,'omitnan');

        end
    end
end
%% ================================================================
% Preferred-direction spike-count modulation
%% ================================================================

countDelta_pref = nan(nUnits,nCond);
countPost_pref  = nan(nUnits,nCond);
countBase_pref  = nan(nUnits,nCond);

for n = 1:nUnits
    s = preferredSide(n);

    if isnan(s)
        continue
    end

    for c = 1:nCond
        countDelta_pref(n,c) = countRate_delta(n,s,c);
        countPost_pref(n,c)  = countRate_post_mean(n,s,c);
        countBase_pref(n,c)  = countRate_base_mean(n,s,c);
    end
end
%% ================================================================
% Plot preferred-direction spike-count modulation
%% ================================================================

%% ================================================================
% Bar plot with dots and SEM for all 4 conditions
% Replaces: boxplot(countDelta_pref, condLabels)
%% ================================================================

figure('Color','w')
hold on

plotData = countDelta_pref;   % neurons x conditions

x = 1:size(plotData,2);

meanVals = mean(plotData,1,'omitnan');
semVals  = std(plotData,[],1,'omitnan') ./ sqrt(sum(~isnan(plotData),1));

% Colors:
% 1 = catch/nan
% 2 = delay 0
% 3 = delay 100
% 4 = delay 200
barColors = [
    0.35 0.35 0.35;   % catch/control gray
    0.80 0.10 0.10;   % delay 0 red
    0.10 0.40 0.90;   % delay 100 blue
    0.10 0.70 0.30    % delay 200 green
];

% Bars = condition means
b = bar(x, meanVals, ...
    'FaceColor','flat', ...
    'EdgeColor','none', ...
    'FaceAlpha',0.75);

for i = 1:length(x)
    b.CData(i,:) = barColors(i,:);
end

% SEM error bars
errorbar(x, meanVals, semVals, 'k', ...
    'LineStyle','none', ...
    'LineWidth',1.5, ...
    'CapSize',10)

% Individual neuron dots
jitterAmount = 0.12;

for i = 1:length(x)

    y = plotData(:,i);
    good = ~isnan(y);

    jitter = (rand(sum(good),1)-0.5) * 2 * jitterAmount;

    scatter(x(i) + jitter, y(good), ...
        32, ...
        'MarkerFaceColor',[0.1 0.1 0.1], ...
        'MarkerEdgeColor','none', ...
        'MarkerFaceAlpha',0.6)

end

% Reference line
yline(0,'k--','LineWidth',1)

% Axes formatting
xlim([0.4 length(x)+0.6])
xticks(x)
xticklabels(condLabels)

xlabel('Condition')
ylabel('Post - baseline firing rate, spikes/s')

title(sprintf('Spike-count modulation, %d-%d ms after actual/fake stim', ...
    postStimWin(1), postStimWin(2)))

box off

set(gca,'TickDir','out')
catchIdx = find(strcmp(condLabels,'nan'));
stimIdx = find(~strcmp(condLabels,'nan'));

fprintf('\nSpike-count stats: post-baseline modulation\n')

for i = 1:length(stimIdx)

    c = stimIdx(i);

    x = countDelta_pref(:,c);
    y = countDelta_pref(:,catchIdx);

    good = ~isnan(x) & ~isnan(y);

    if sum(good) > 3
        p = signrank(x(good), y(good));
        fprintf('Delay %s vs catch: p = %.4f, n = %d neurons\n', ...
            condLabels{c}, p, sum(good))
    end

end

%% ================================================================
% Matched spike-count comparison:
% Catch epoch matched separately to each stimulation delay
%
% Output:
%   matchedCatchRates(:,1) = catch window matching delay 0
%   matchedStimRates(:,1)  = stim delay 0
%
%   matchedCatchRates(:,2) = catch window matching delay 100
%   matchedStimRates(:,2)  = stim delay 100
%
%   matchedCatchRates(:,3) = catch window matching delay 200
%   matchedStimRates(:,3)  = stim delay 200
%% ================================================================

baselineWin = [-300 -200];   % optional; not used in this direct post-window plot
postStimWin = [50 150];     % ms after actual/fake stimulation

catchIdx = find(strcmp(condLabels,'nan'));
stimIdx = find(~strcmp(condLabels,'nan'));

nStimCond = length(stimIdx);

matchedCatchRates = nan(nUnits,nStimCond);
matchedStimRates  = nan(nUnits,nStimCond);
deltaStimMinusCatch = nan(nUnits,nStimCond);

for n = 1:nUnits

    s = preferredSide(n);

    if isnan(s)
        continue
    end

    spikeTimes_beh = double(Data.(unitFields{n})) / FsSpike * FsBeh;
    spikeTimes_beh = spikeTimes_beh(:);

    for i = 1:nStimCond

        c = stimIdx(i);
        condLabel = condLabels{c};
        delayMs = condDelays(c);

        %% ---------------- Stim trials ----------------

        stimSegField = ['active_like_stim_' sides{s} '_' condLabel];
        stimSegs = Data.segments.(stimSegField);

        stimRates = [];

        for k = 1:size(stimSegs,1)

            seg_start = stimSegs(k,1);
            seg_end   = stimSegs(k,2);

            % Search for actual stim train within ~400 ms after segment start
            stim_idx = find(stimOnsets >= seg_start & ...
                            stimOnsets <= seg_start + 400);

            if isempty(stim_idx)
                continue
            end

            stimTime = stimOnsets(stim_idx(1));

            % Count window relative to actual stimulation
            countStart = stimTime + postStimWin(1);
            countEnd   = stimTime + postStimWin(2);

            if countStart < 1 || countEnd > length(Data.(stim_var2))
                continue
            end

            count = sum(spikeTimes_beh >= countStart & spikeTimes_beh < countEnd);
            stimRates(end+1,1) = count / (diff(postStimWin)/1000);

        end

        %% ---------------- Catch trials matched to same movement epoch ----------------

        catchSegField = ['active_like_stim_' sides{s} '_nan'];
        catchSegs = Data.segments.(catchSegField);

        catchRates = [];

        for k = 1:size(catchSegs,1)

            seg_start = catchSegs(k,1);
            seg_end   = catchSegs(k,2);

            vel_segment = Data.(stim_var2)(seg_start:seg_end);

            cross_idx = find(abs(vel_segment) >= velocityThreshold, 1, 'first');

            if isempty(cross_idx)
                continue
            end

            thresholdCrossing = seg_start + cross_idx - 1;

            % Fake stimulation time in catch trial:
            % delay 0   -> thresholdCrossing + 0
            % delay 100 -> thresholdCrossing + 100
            % delay 200 -> thresholdCrossing + 200
            fakeStimTime = thresholdCrossing + delayMs;

            % Count window relative to fake stimulation time
            countStart = fakeStimTime + postStimWin(1);
            countEnd   = fakeStimTime + postStimWin(2);

            if countStart < 1 || countEnd > length(Data.(stim_var2))
                continue
            end

            count = sum(spikeTimes_beh >= countStart & spikeTimes_beh < countEnd);
            catchRates(end+1,1) = count / (diff(postStimWin)/1000);

        end

        %% ---------------- Store neuron means ----------------

        if ~isempty(stimRates)
            matchedStimRates(n,i) = mean(stimRates,'omitnan');
        end

        if ~isempty(catchRates)
            matchedCatchRates(n,i) = mean(catchRates,'omitnan');
        end

        if ~isempty(stimRates) && ~isempty(catchRates)
            deltaStimMinusCatch(n,i) = matchedStimRates(n,i) - matchedCatchRates(n,i);
        end

    end
end

%% ================================================================
% Six-bar matched catch vs stim plot
%% ================================================================

% Arrange data as:
% column 1 = catch matched to delay 0
% column 2 = stim delay 0
% column 3 = catch matched to delay 100
% column 4 = stim delay 100
% column 5 = catch matched to delay 200
% column 6 = stim delay 200

plotData6 = nan(nUnits, nStimCond*2);

for i = 1:nStimCond
    plotData6(:,2*i-1) = matchedCatchRates(:,i);
    plotData6(:,2*i)   = matchedStimRates(:,i);
end

plotLabels6 = {};
for i = 1:nStimCond
    plotLabels6{2*i-1} = ['Catch ' condLabels{stimIdx(i)}];
    plotLabels6{2*i}   = ['Stim ' condLabels{stimIdx(i)}];
end

x = 1:size(plotData6,2);

meanVals = mean(plotData6,1,'omitnan');
semVals  = std(plotData6,[],1,'omitnan') ./ sqrt(sum(~isnan(plotData6),1));

figure('Color','w')
hold on

% Colors alternate catch/stim for each delay
barColors = [
    0.55 0.55 0.55;   % catch 0
    0.80 0.10 0.10;   % stim 0

    0.55 0.55 0.55;   % catch 100
    0.10 0.40 0.90;   % stim 100

    0.55 0.55 0.55;   % catch 200
    0.10 0.70 0.30    % stim 200
];

b = bar(x, meanVals, ...
    'FaceColor','flat', ...
    'EdgeColor','none', ...
    'FaceAlpha',0.75);

for i = 1:length(x)
    b.CData(i,:) = barColors(i,:);
end

% SEM bars
errorbar(x, meanVals, semVals, 'k', ...
    'LineStyle','none', ...
    'LineWidth',1.5, ...
    'CapSize',10)

% Individual neuron dots
jitterAmount = 0.10;

for i = 1:length(x)

    y = plotData6(:,i);
    good = ~isnan(y);

    jitter = (rand(sum(good),1)-0.5) * 2 * jitterAmount;

    scatter(x(i) + jitter, y(good), ...
        30, ...
        'MarkerFaceColor',[0.1 0.1 0.1], ...
        'MarkerEdgeColor','none', ...
        'MarkerFaceAlpha',0.45)

end

% % Optional paired lines between catch and stim for each delay
% for i = 1:nStimCond
% 
%     catchCol = 2*i - 1;
%     stimCol  = 2*i;
% 
%     for n = 1:nUnits
% 
%         yPair = plotData6(n,[catchCol stimCol]);
% 
%         if all(~isnan(yPair))
%             plot([catchCol stimCol], yPair, '-', ...
%                 'Color',[0.75 0.75 0.75], ...
%                 'LineWidth',0.5)
%         end
% 
%     end
% 
% end

% Re-plot bars/errorbars/dots on top after paired lines if desired
% If lines visually clutter the plot, comment out the paired-line loop above.

xlim([0.4 length(x)+0.6])
xticks(x)
xticklabels(plotLabels6)
xtickangle(35)

ylabel('Firing rate, spikes/s')
xlabel('Matched catch/stimulation condition')

title(sprintf('Matched post-stim spike counts, %d-%d ms after actual/fake stim', ...
    postStimWin(1), postStimWin(2)))

box off
set(gca,'TickDir','out')
%% ================================================================
% Bar plot with neuron dots and SEM
%% ================================================================

figure('Color','w')
hold on

x = 1:size(deltaStimMinusCatch,2);

meanVals = mean(deltaStimMinusCatch,1,'omitnan');
semVals  = std(deltaStimMinusCatch,[],1,'omitnan') ./ ...
           sqrt(sum(~isnan(deltaStimMinusCatch),1));

barColors = [
    0.8 0.1 0.1;    % delay 0
    0.1 0.4 0.9;    % delay 100
    0.1 0.7 0.3     % delay 200
];

b = bar(x, meanVals, 'FaceColor','flat', 'EdgeColor','none');

for i = 1:length(x)
    b.CData(i,:) = barColors(i,:);
end

errorbar(x, meanVals, semVals, 'k', ...
    'LineStyle','none', ...
    'LineWidth',1.5, ...
    'CapSize',10)

% Overlay individual neuron dots with jitter
jitterAmount = 0.12;

for i = 1:length(x)

    y = deltaStimMinusCatch(:,i);
    good = ~isnan(y);

    jitter = (rand(sum(good),1)-0.5) * 2 * jitterAmount;

    scatter(x(i) + jitter, y(good), ...
        35, ...
        'MarkerFaceColor',[0.2 0.2 0.2], ...
        'MarkerEdgeColor','none', ...
        'MarkerFaceAlpha',0.5)

end

yline(0,'k--','LineWidth',1)

xlim([0.4 length(x)+0.6])
xticks(x)
xticklabels(condLabels(stimIdx))

xlabel('Stimulation delay, ms')
ylabel('Stim - matched catch firing rate, spikes/s')
title(sprintf('Spike-count effect, %d-%d ms after actual/fake stim', ...
    postStimWin(1), postStimWin(2)))

box off
set(gca,'TickDir','out')

fprintf('\nMatched spike-count stim-catch effects:\n')

for i = 1:length(stimIdx)

    x = deltaStimMinusCatch(:,i);
    good = ~isnan(x);

    if sum(good) > 3
        p = signrank(x(good));
        fprintf('Delay %s: median effect %.2f sp/s, p = %.4f, n = %d\n', ...
            condLabels{stimIdx(i)}, median(x(good),'omitnan'), p, sum(good))
    end

end