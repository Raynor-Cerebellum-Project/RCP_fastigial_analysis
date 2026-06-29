%% ============================================================
% FASTIGIAL POPULATION ANALYSIS
%
% Computes for each neuron:
%   1) Depth of modulation (peak FR - baseline FR)
%   2) Peak timing relative to movement onset
%   3) Peak timing relative to movement offset
%
% Preferred direction is defined from PASSIVE data only:
%   preferred = direction with larger mean modulation
%
% The same preferred/nonpreferred labels are then applied to
% ACTIVE data.
%
% Population histograms use ONE value per neuron (median across trials).
%
% Assumptions:
%   - Data.fr_XXX are firing rates sampled at fs
%   - Data.segments.ipsi and .contra are [start end] samples
%   - yaw_vel exists but is not required for this analysis
%% ============================================================
 %pooled data location: \\cullenstor\data\Current Project Databases - NHP\2025 Cerebellum prosthesis\Bryan\RCP_fastigial_analysis\Pooled_neural_data
 % where "results" are stored for each animal
clear
close all

%% LOAD DATA
%-----BERT-----------
% good_neurons = [107 38 42 18 43 111 47 24 10 40 76 55 31 28]; %active condition labeling
% 
% load(fullfile('\\cullenstor\data\Current Project Databases - NHP\2025 Cerebellum prosthesis\Bert\BL_RW_003_Session_1\Calibrated\IntanFile_1\Seperate cells', ...
%     'BL_closed_loop_STIM_003_003_Cal.mat')) %passive filepath Bert S3
% pas_Data = Data;
% 
% load(fullfile('\\cullenstor\data\Current Project Databases - NHP\2025 Cerebellum prosthesis\Bert\BL_RW_003_Session_1\Calibrated\IntanFile_1\Seperate cells', ...
%     'BL_closed_loop_STIM_003_004_Cal.mat')) %passive filepath Bert S3
% act_Data = Data;

%-----NIKE----------
good_neurons = [49 50 19 17 16 22 46 51]; %active condition labeling

load(fullfile('\\cullenstor\data\Current Project Databases - NHP\2025 Cerebellum prosthesis\Nike\20260410_NRR_RW030_fastig\Calibrated\IntanFile_6\Seperate cells', ...
    'NRR_RW030_006_Cal.mat')) %passive filepath Nike S030
pas_Data = Data;

% pas_Data.fr_7 = pas_Data.fr_1; %Conversion Nike S027 passive to active neurons
% pas_Data.fr_34 = pas_Data.fr_58;
% pas_Data.fr_39 = pas_Data.fr_11;
% pas_Data.fr_36 = pas_Data.fr_12;
% pas_Data.fr_11 = pas_Data.fr_23;
% pas_Data.fr_1 = pas_Data.fr_8;
% pas_Data.fr_20 = pas_Data.fr_17;

pas_Data.fr_49 = pas_Data.fr_36; %Conversion Nike S027 passive to active neurons
pas_Data.fr_50 = pas_Data.fr_42;
pas_Data.fr_19 = pas_Data.fr_37;
pas_Data.fr_17 = pas_Data.fr_44;
pas_Data.fr_16 = pas_Data.fr_47;
pas_Data.fr_22 = pas_Data.fr_46;
pas_Data.fr_46 = pas_Data.fr_31;
pas_Data.fr_51 = pas_Data.fr_22;

load(fullfile('\\cullenstor\data\Current Project Databases - NHP\2025 Cerebellum prosthesis\Nike\20260410_NRR_RW030_fastig\Calibrated\IntanFile_14\Seperate cells', ...
    'NRR_RW030_014_Cal.mat')) %passive filepath Nike S030
act_Data = Data;
%--------------------------

%% PARAMETERS

fs = 1000;                 % Hz

baseline_time = 0.5;      % s before movement onset
pre_samp = round(baseline_time * fs);

fc = 5;                    % low-pass cutoff (Hz)

[b,a] = butter(2, fc/(fs/2), 'low');

dirs = {'ipsi','contra'};

exclude_time = 0.05;       % s
exclude_samp = round(exclude_time * fs);


%% INITIALIZE RESULTS

nNeurons = numel(good_neurons);
    results.neurons = repmat( ...
        struct( ...
            'id', [], ...
            'pref_dir', '', ...
            'passive', struct(), ...
            'active', struct()), ...
        nNeurons, 1);

results.passive.pref_label = strings(nNeurons,1);

results.passive.pref_dom = nan(nNeurons,1);
results.passive.nonpref_dom = nan(nNeurons,1);

results.passive.pref_peak_onset = nan(nNeurons,1);
results.passive.nonpref_peak_onset = nan(nNeurons,1);

results.passive.pref_peak_offset = nan(nNeurons,1);
results.passive.nonpref_peak_offset = nan(nNeurons,1);

results.active.pref_dom = nan(nNeurons,1);
results.active.nonpref_dom = nan(nNeurons,1);

results.active.pref_peak_onset = nan(nNeurons,1);
results.active.nonpref_peak_onset = nan(nNeurons,1);

results.active.pref_peak_offset = nan(nNeurons,1);
results.active.nonpref_peak_offset = nan(nNeurons,1);


%% ============================================================
% MAIN LOOP
%% ============================================================

for n = 1:nNeurons

    neuron_id = good_neurons(n);

    fprintf('Analyzing neuron %d (%d/%d)\n', ...
        neuron_id, n, nNeurons)

    fr_name = sprintf('fr_%d', neuron_id);

    if ~isfield(pas_Data, fr_name) || ~isfield(act_Data, fr_name)

        warning('Missing %s', fr_name)
        continue

    end

    %% FILTER FIRING RATES

    fr_passive = pas_Data.(fr_name);
    fr_active = act_Data.(fr_name);

    fr_passive = fillmissing(fr_passive,'linear');
    fr_active = fillmissing(fr_active,'linear');

    fr_passive = filtfilt(b,a,fr_passive);
    fr_active = filtfilt(b,a,fr_active);

    %% ANALYZE IPSI + CONTRA FOR BOTH CONDITIONS

    neuron = struct();

    for d = 1:2

        direction = dirs{d};

        segments_passive = pas_Data.segments.(direction);
        segments_active = act_Data.segments.(direction);

       [dom_p, onset_p, offset_p] = analyze_segments( ...
        fr_passive, segments_passive, fs, pre_samp, exclude_samp);

        [dom_a, onset_a, offset_a] = analyze_segments( ...
        fr_active, segments_active, fs, pre_samp, exclude_samp);

        neuron.passive.(direction).dom = dom_p;
        neuron.passive.(direction).peak_onset = onset_p;
        neuron.passive.(direction).peak_offset = offset_p;

        neuron.active.(direction).dom = dom_a;
        neuron.active.(direction).peak_onset = onset_a;
        neuron.active.(direction).peak_offset = offset_a;

    end

    %% ========================================================
    % DEFINE PREFERRED DIRECTION FROM PASSIVE DATA ONLY
    %% ========================================================

    ipsi_dom = mean(neuron.passive.ipsi.dom,'omitnan');
    contra_dom = mean(neuron.passive.contra.dom,'omitnan');

    if ipsi_dom >= contra_dom

        pref_dir = 'ipsi';
        nonpref_dir = 'contra';

    else

        pref_dir = 'contra';
        nonpref_dir = 'ipsi';

    end

    results.passive.pref_label(n) = pref_dir;

    %% PASSIVE SUMMARIES

    results.passive.pref_dom(n) = ...
        mean(neuron.passive.(pref_dir).dom,'omitnan');

    results.passive.nonpref_dom(n) = ...
        mean(neuron.passive.(nonpref_dir).dom,'omitnan');

    results.passive.pref_peak_onset(n) = ...
        median(neuron.passive.(pref_dir).peak_onset,'omitnan');

    results.passive.nonpref_peak_onset(n) = ...
        median(neuron.passive.(nonpref_dir).peak_onset,'omitnan');

    results.passive.pref_peak_offset(n) = ...
        median(neuron.passive.(pref_dir).peak_offset,'omitnan');

    results.passive.nonpref_peak_offset(n) = ...
        median(neuron.passive.(nonpref_dir).peak_offset,'omitnan');

    %% ACTIVE SUMMARIES
    % Use SAME preferred direction assignment

    results.active.pref_dom(n) = ...
        mean(neuron.active.(pref_dir).dom,'omitnan');

    results.active.nonpref_dom(n) = ...
        mean(neuron.active.(nonpref_dir).dom,'omitnan');

    results.active.pref_peak_onset(n) = ...
        median(neuron.active.(pref_dir).peak_onset,'omitnan');

    results.active.nonpref_peak_onset(n) = ...
        median(neuron.active.(nonpref_dir).peak_onset,'omitnan');

    results.active.pref_peak_offset(n) = ...
        median(neuron.active.(pref_dir).peak_offset,'omitnan');

    results.active.nonpref_peak_offset(n) = ...
        median(neuron.active.(nonpref_dir).peak_offset,'omitnan');
 
        %% SAVE INDIVIDUAL NEURON DATA

    neuron.id = neuron_id;
    neuron.pref_dir = pref_dir;
    results.neurons(n) = neuron;

n_skipped = sum((segments_passive(:,2) - segments_passive(:,1)) <= 2*exclude_samp);

fprintf('%s: skipped %d passive trials\n', ...
    direction, n_skipped);
end

%% ============================================================
% HISTOGRAMS: PEAK TIMING RELATIVE TO ONSET
%% ============================================================

edges_onset = -200:50:1000;

figure('Color','w')

subplot(2,2,1)
histogram(1000*results.passive.pref_peak_onset, edges_onset)
xlabel('Peak time from onset (ms)')
ylabel('Neurons')
title('Passive Preferred')
ylim([0 8])
xlim([-200 800])

subplot(2,2,2)
histogram(1000*results.passive.nonpref_peak_onset, edges_onset)
xlabel('Peak time from onset (ms)')
ylabel('Neurons')
title('Passive Nonpreferred')
ylim([0 8])
xlim([-200 800])

subplot(2,2,3)
histogram(1000*results.active.pref_peak_onset, edges_onset)
xlabel('Peak time from onset (s)')
ylabel('Neurons')
title('Active Preferred')
ylim([0 8])
xlim([-200 800])

subplot(2,2,4)
histogram(1000*results.active.nonpref_peak_onset, edges_onset)
xlabel('Peak time from onset (ms)')
ylabel('Neurons')
title('Active Nonpreferred')
ylim([0 8])
xlim([-200 800])

sgtitle('Population Peak Timing Relative to Movement Onset')

%% ============================================================
% HISTOGRAMS: PEAK TIMING RELATIVE TO OFFSET
%% ============================================================

edges_offset = -1000:50:200;

figure('Color','w')

subplot(2,2,1)
histogram(1000*results.passive.pref_peak_offset, edges_offset)
xlabel('Peak time from offset (ms)')
ylabel('Neurons')
title('Passive Preferred')
ylim([0 8])
xlim([-800 200])

subplot(2,2,2)
histogram(1000*results.passive.nonpref_peak_offset, edges_offset)
xlabel('Peak time from offset (ms)')
ylabel('Neurons')
title('Passive Nonpreferred')
ylim([0 8])
xlim([-800 200])

subplot(2,2,3)
histogram(1000*results.active.pref_peak_offset, edges_offset)
xlabel('Peak time from offset (ms)')
ylabel('Neurons')
title('Active Preferred')
ylim([0 8])
xlim([-800 200])

subplot(2,2,4)
histogram(1000*results.active.nonpref_peak_offset, edges_offset)
xlabel('Peak time from offset (ms)')
ylabel('Neurons')
title('Active Nonpreferred')
ylim([0 8])
xlim([-800 200])

sgtitle('Population Peak Timing Relative to Movement Offset')

%% ============================================================
% DEPTH OF MODULATION: MEAN ± SEM
%% ============================================================

groups = {
    results.passive.pref_dom
    results.passive.nonpref_dom
    results.active.pref_dom
    results.active.nonpref_dom};

labels = {'Pass Pref','Pass NonPref', ...
          'Act Pref','Act NonPref'};

means = nan(1,numel(groups));
sems = nan(1,numel(groups));
ns = nan(1,numel(groups));

for i = 1:numel(groups)

    x = groups{i};
    x = x(~isnan(x));

    ns(i) = numel(x);
    means(i) = mean(x);
    sems(i) = std(x) / sqrt(ns(i));

end

figure('Color','w')

bar(1:4, means)

hold on

errorbar(1:4, means, sems, ...
    'k', ...
    'LineStyle', 'none', ...
    'LineWidth', 1.5)

set(gca, ...
    'XTick', 1:4, ...
    'XTickLabel', labels)

ylabel('Depth of modulation (spikes/s)')
xlabel('Condition')

title('Depth of Modulation')

box off

for i = 1:4
    text(i, means(i) + sems(i), ...
        sprintf('n = %d', ns(i)), ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'bottom')
end

%% ============================================================
% OPTIONAL: VIEW PREFERRED DIRECTION ASSIGNMENT
%% ============================================================

T = table( ...
    good_neurons(:), ...
    results.passive.pref_label, ...
    results.passive.pref_dom, ...
    results.active.pref_dom, ...
    'VariableNames', ...
    {'NeuronID','PreferredDirection', ...
     'PassiveDoM','ActiveDoM'})

disp(T)


%% ============================================================
% LOCAL FUNCTION
%% ============================================================

function [dom, peak_onset, peak_offset] = analyze_segments( ...
    fr, segments, fs, pre_samp, exclude_samp)

nTrials = size(segments,1);

dom = nan(nTrials,1);
peak_onset = nan(nTrials,1);
peak_offset = nan(nTrials,1);

for tr = 1:nTrials

    onset = segments(tr,1);
    offset = segments(tr,2);

    idx1 = onset - pre_samp;
    idx2 = offset;

    if idx1 < 1 || idx2 > numel(fr)
        continue
    end

    trial_fr = fr(idx1:idx2);

    baseline = mean(trial_fr(1:pre_samp),'omitnan');

    movement_start = pre_samp + 1;
    movement_end = movement_start + (offset - onset);

    search_start = movement_start + exclude_samp;
    search_end = movement_end - exclude_samp;

    if search_end <= search_start
        continue
    end

    search_idx = search_start:search_end;

    [peak_fr, peak_idx_rel] = max(trial_fr(search_idx));

    peak_idx = search_idx(peak_idx_rel);

    peak_sample = idx1 + peak_idx - 1;

    dom(tr) = peak_fr - baseline;

    peak_onset(tr) = (peak_sample - onset) / fs;
    peak_offset(tr) = (peak_sample - offset) / fs;

end

end
