%% ================================================================
% Single-file stimulation-aligned population heatmap
%% ================================================================

colordef white
clear
clc

%% ---------------- Parameters ----------------

FsSpike = 30000;      % spike timestamp sampling rate
FsBeh   = 1000;       % behavioral / output sampling rate

preTime  = 300;       % ms before stimulation
postTime = 600;       % ms after stimulation

win = -preTime:postTime;

sigma = 30;           % Gaussian smoothing kernel width, in ms

x = -4*sigma:4*sigma;
g = exp(-(x.^2)/(2*sigma^2));
g = g / sum(g);

%% ---------------- Load one file ----------------

Path = '\\cullenstor\data\Current Project Databases - NHP\2025 Cerebellum prosthesis\Bert\BL_RW_003_Session_1\Calibrated\IntanFile_3';
paradigm = 'BL_closed_loop_STIM_003_006_Cal_stim_stitched_individual';

load(fullfile(Path,[paradigm '.mat']))

%% ---------------- Find stimulation onsets ----------------

% This assumes you have findStimOnsets.m available on the MATLAB path.
% If not, add its folder with addpath().
%
% Example:
% addpath('\\cullenstor\data\Current Project Databases - NHP\2025 Cerebellum prosthesis\Bryan\RCP_fastigial_analysis\functions')

stimOnsets = findStimOnsets(Data.Neural(:,1), FsSpike, FsBeh);

fprintf('Detected %d stimulation trains\n', length(stimOnsets))

%% Optional: plot detected stimulation onsets on yaw velocity

figure('Color','w')
plot(Data.headYawVel,'k')
hold on
for i = 1:length(stimOnsets)
    xline(stimOnsets(i),'r')
end
xlabel('Time, behavioral samples')
ylabel('Yaw velocity')
title('Detected stimulation train onsets')
box off

%% ---------------- Find neurons ----------------

fields = fieldnames(Data);
unitFields = fields(startsWith(fields,'unit_'));

unitNumbers = cellfun(@(x) sscanf(x,'unit_%d'), unitFields);

fprintf('Found %d neurons\n', length(unitFields))

%% ---------------- Process neurons ----------------

fr_all = [];

for n = 1:length(unitFields)

    fprintf('Neuron %d/%d: %s\n', n, length(unitFields), unitFields{n})

    spikeTimes = double(Data.(unitFields{n}));

    % Convert spike timestamps from spike sampling rate to behavior sampling rate
    spikeSamples = round(spikeTimes / FsSpike * FsBeh);

    % Remove out-of-range spikes
    spikeSamples(spikeSamples < 1) = [];
    spikeSamples(spikeSamples > length(Data.headYawVel)) = [];

    % Create spike train at behavioral sampling rate
    spikeTrain = zeros(length(Data.headYawVel),1);
    spikeTrain(spikeSamples) = spikeTrain(spikeSamples) + 1;

    % Convert to firing rate in spikes/sec and smooth
    FR = conv(spikeTrain * 1000, g, 'same');

    %% Extract trials aligned to stimulation onset

    FRtrials = [];

    for k = 1:length(stimOnsets)

        onset = stimOnsets(k);

        idx = onset - preTime : onset + postTime;

        % Skip if window goes outside recording
        if idx(1) < 1 || idx(end) > length(FR)
            continue
        end

        FRtrials(:,end+1) = FR(idx);

    end

    %% Average across stimulation trials

    if isempty(FRtrials)
        warning('No valid trials for neuron %s', unitFields{n})
        fr_mean = nan(length(win),1);
    else
        fr_mean = mean(FRtrials, 2, 'omitnan');
    end

    %% Normalize neuron response

    % Option 1: normalize by peak response after stimulation
    normWindow = preTime+1 : preTime+401;   % 0 to 400 ms after stimulation

    peak = max(fr_mean(normWindow));

    if isempty(peak) || isnan(peak) || peak <= 0
        peak = 1;
    end

    fr_all(:,n) = fr_mean / peak;

end

%% ---------------- Remove bad neurons ----------------

badNeurons = all(isnan(fr_all),1);
fr_all(:,badNeurons) = [];
unitNumbers(badNeurons) = [];

fprintf('Kept %d neurons after removing empty neurons\n', size(fr_all,2))

%% ---------------- Sort neurons ----------------

% Sort by peak latency after stimulation
searchWindow = preTime+1 : preTime+251;   % 0 to 250 ms after stim

[~, peakLoc] = max(fr_all(searchWindow,:), [], 1);
[~, order] = sort(peakLoc);

fr_sorted = fr_all(:,order)';

% Flip so earliest/strongest responses appear near top if desired
fr_sorted = flipud(fr_sorted);

sortedUnitNumbers = unitNumbers(order);
sortedUnitNumbers = flipud(sortedUnitNumbers(:));

%% ---------------- Plot heatmap ----------------

figure('Color','w')

imagesc(win, 1:size(fr_sorted,1), fr_sorted)

axis xy
colormap(bone)
colorbar

xlabel('Time from stimulation onset (ms)')
ylabel('Neuron')
title('Stimulation-aligned population heatmap')

xline(0,'r--','LineWidth',1.5)

caxis([0 1])

box off

%% Optional: save output

save('SingleFile_stim_aligned_heatmap.mat', ...
    'fr_all', ...
    'fr_sorted', ...
    'unitNumbers', ...
    'sortedUnitNumbers', ...
    'stimOnsets', ...
    'win', ...
    'preTime', ...
    'postTime')