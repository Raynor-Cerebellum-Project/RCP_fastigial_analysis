%% ============================================================
% Fastigial neuron modulation analysis
%
% Computes:
%   - Depth of modulation
%   - Peak timing relative to movement onset
%   - Peak timing relative to movement offset
%
% Compares:
%   - Active vs Passive
%   - Ipsi vs Contra movements
%% ============================================================

clear
close all

good_neurons = [107 38 42 18 43 111 47 24 10 40 76 55 31 28];

load('BL_closed_loop_STIM_003_003_Cal.mat')
pas_Data = Data;

load('BL_closed_loop_STIM_003_004_Cal.mat')
act_Data = Data;


%% USER PARAMETERS

fs = 1000;      % Hz

fc = 5;         % low-pass cutoff (Hz)

[b,a] = butter(2, fc/(fs/2), 'low');
%% USER PARAMETERS

pre_time = 0.5;             % baseline before movement onset (s)
post_time = 0.5;            % analysis window after movement end (s)

pre_samp = round(pre_time * fs);
post_samp = round(post_time * fs);

%% ANALYZE BOTH CONDITIONS

results.passive = analyze_condition( ...
    pas_Data, good_neurons, fs, pre_samp, post_samp);

results.active = analyze_condition( ...
    act_Data, good_neurons, fs, pre_samp, post_samp);



%% ============================================================
% PEAK TIMING RELATIVE TO MOVEMENT ONSET
%% ============================================================

figure

subplot(2,2,1)
histogram(results.passive.ipsi.all_peak_onset, 25)
xlabel('Peak time from onset (s)')
ylabel('Count')
title('Passive Ipsi')

subplot(2,2,2)
histogram(results.passive.contra.all_peak_onset, 25)
xlabel('Peak time from onset (s)')
ylabel('Count')
title('Passive Contra')

subplot(2,2,3)
histogram(results.active.ipsi.all_peak_onset, 25)
xlabel('Peak time from onset (s)')
ylabel('Count')
title('Active Ipsi')

subplot(2,2,4)
histogram(results.active.contra.all_peak_onset, 25)
xlabel('Peak time from onset (s)')
ylabel('Count')
title('Active Contra')

%% ============================================================
% PEAK TIMING RELATIVE TO MOVEMENT OFFSET
%% ============================================================

figure

subplot(2,2,1)
histogram(results.passive.ipsi.all_peak_offset, 25)
xlabel('Peak time from offset (s)')
ylabel('Count')
title('Passive Ipsi')

subplot(2,2,2)
histogram(results.passive.contra.all_peak_offset, 25)
xlabel('Peak time from offset (s)')
ylabel('Count')
title('Passive Contra')

subplot(2,2,3)
histogram(results.active.ipsi.all_peak_offset, 25)
xlabel('Peak time from offset (s)')
ylabel('Count')
title('Active Ipsi')

subplot(2,2,4)
histogram(results.active.contra.all_peak_offset, 25)
xlabel('Peak time from offset (s)')
ylabel('Count')
title('Active Contra')

%% ============================================================
% DEPTH OF MODULATION
%% ============================================================

figure

dom_data = {
    results.passive.ipsi.all_dom
    results.passive.contra.all_dom
    results.active.ipsi.all_dom
    results.active.contra.all_dom};

boxplot(vertcat(dom_data{:}), ...
    repelem(1:4, cellfun(@numel, dom_data)))

set(gca,'XTickLabel', ...
    {'Pass Ipsi','Pass Contra','Act Ipsi','Act Contra'})

ylabel('Peak FR - baseline (spikes/s)')
title('Depth of modulation')


function out = analyze_condition(Data, good_neurons, fs, pre_samp, post_samp)

dirs = {'ipsi','contra'};

for d = 1:numel(dirs)

    direction = dirs{d};

    segments = Data.segments.(direction);

    all_peak_onset = [];
    all_peak_offset = [];
    all_dom = [];

    neuron_results = struct();

    for n = 1:numel(good_neurons)

        neuron_id = good_neurons(n);

        fr_name = sprintf('fr_%d', neuron_id);

        if ~isfield(Data, fr_name)
            warning('%s not found', fr_name)
            continue
        end

        fr = Data.(fr_name);

        fr = fillmissing(fr,'linear');

        fr = filtfilt(b, a, fr);

        peak_onset = nan(size(segments,1),1);
        peak_offset = nan(size(segments,1),1);
        dom = nan(size(segments,1),1);

        for tr = 1:size(segments,1)

            onset = segments(tr,1);
            offset = segments(tr,2);

            idx1 = onset - pre_samp;
            idx2 = offset + post_samp;

            if idx1 < 1 || idx2 > length(fr)
                continue
            end

            fr_trial = fr(idx1:idx2);

            baseline = mean(fr_trial(1:pre_samp));

            movement_start = pre_samp + 1;
            movement_end = movement_start + (offset - onset);

            analysis_idx = movement_start:movement_end;

            [peak_fr, peak_idx_rel] = max(fr_trial(analysis_idx));

            peak_idx = analysis_idx(peak_idx_rel);

            dom(tr) = peak_fr - baseline;

            peak_sample = idx1 + peak_idx - 1;

            peak_onset(tr) = (peak_sample - onset) / fs;
            peak_offset(tr) = (peak_sample - offset) / fs;

        end

        neuron_results(n).id = neuron_id;
        neuron_results(n).peak_onset = peak_onset;
        neuron_results(n).peak_offset = peak_offset;
        neuron_results(n).dom = dom;

        all_peak_onset = [all_peak_onset; peak_onset];
        all_peak_offset = [all_peak_offset; peak_offset];
        all_dom = [all_dom; dom];

    end

    out.(direction).neurons = neuron_results;

    out.(direction).all_peak_onset = all_peak_onset(~isnan(all_peak_onset));
    out.(direction).all_peak_offset = all_peak_offset(~isnan(all_peak_offset));
    out.(direction).all_dom = all_dom(~isnan(all_dom));

end
end
