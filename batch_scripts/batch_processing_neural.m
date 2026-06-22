clear all; close all; clc;
addpath(genpath(fullfile('..', 'functions')));

%% Config
session = 'Bert/BL_RW_003_Session_1';
[~, session_name] = fileparts(session);
[base_root, code_root, base_folder] = set_paths_cullen_lab(session);

metadata_csv  = fullfile(base_folder, 'Metadata',    [session_name, '_metadata.csv']);
summary_path  = fullfile(base_folder, 'Checkpoints', [session_name, '_summarized_metrics.mat']);
results_root  = fullfile(base_folder, 'results', 'checkpoints', 'sorting_results');

intan_folder  = fullfile(base_folder, 'Intan');
intan_folders_list = dir(intan_folder);
intan_folders_list = intan_folders_list([intan_folders_list.isdir] & ~startsWith({intan_folders_list.name}, '.'));
[~, sort_ord]      = sort({intan_folders_list.name});
intan_folders_list = intan_folders_list(sort_ord);

opts = detectImportOptions(metadata_csv);
opts = setvartype(opts, 'Stim_Delay', 'string');
T    = readtable(metadata_csv, opts);

load(summary_path, 'summary_struct');

win_pre_ms  = 800;
win_post_ms = 1200;
bin_edges   = -win_pre_ms : win_post_ms;
n_bins      = length(bin_edges) - 1;

%% Loop over trials in summary_struct
for i = 1:length(summary_struct)
    if isempty(summary_struct(i).merged_with_summary), continue; end

    br_id = summary_struct(i).BR_File;
    row   = find(T.BR_File == br_id);
    if isempty(row), continue; end

    intan_idx_trial = T.Intan_File(row);
    if intan_idx_trial > length(intan_folders_list), continue; end
    trial = intan_folders_list(intan_idx_trial).name;

    spike_train_path = fullfile(results_root, trial, 'NPRW', 'spike_trains.mat');
    if ~isfile(spike_train_path)
        fprintf('[SKIP] no spike_trains.mat for BR %d (%s)\n', br_id, trial); continue;
    end

    % Load Cal file for Intan_idx map
    cal_files = dir(fullfile(base_folder, 'Calibrated', '**', sprintf('*%d_Cal*.mat', br_id)));
    % Remove macOS metadata files
    cal_files = cal_files(~startsWith({cal_files.name}, '._'));
    if isempty(cal_files), continue; end
    stim_cal_idx = find(contains({cal_files.name}, 'Cal_stim'));
    if ~isempty(stim_cal_idx)
        cal_path = fullfile(cal_files(stim_cal_idx(1)).folder, cal_files(stim_cal_idx(1)).name);
    else
        cal_path = fullfile(cal_files(1).folder, cal_files(1).name);
    end
    beh_data = load(cal_path, 'Data');
    Data     = beh_data.Data;
    if ~isfield(Data, 'yaw_vel') && isfield(Data, 'headYawVel')
        Data.yaw_vel = Data.headYawVel;
    end
    intan_map_local  = double(Data.Intan_idx(1,:));
    sess_start_intan = intan_map_local(1);

    st_data    = load(spike_train_path);
    fs_neural  = st_data.fs;
    st_fields  = fieldnames(st_data);
    st_fields  = st_fields(~strcmp(st_fields, 'fs'));
    n_units_st = length(st_fields);

    % Loop over segment fields already in summary_struct
    seg_fields = fieldnames(summary_struct(i).merged_with_summary);
    seg_fields = seg_fields(~contains(seg_fields, 'summary')); % skip summary fields

    for f = 1:length(seg_fields)
        field = seg_fields{f};
        segments3    = summary_struct(i).merged_with_summary.(field).segments3;
        N     = size(segments3, 1);
        if N == 0, continue; end

        psth_st   = zeros(n_units_st, n_bins);
        raster_st = cell(n_units_st, N);

        for s = 1:N
            seg = segments3(s,:);
            bk_start_30k = seg(1) * 30;
            bk_end_30k   = seg(2) * 30;
            
            if bk_start_30k < 1 || bk_end_30k > length(intan_map_local), continue; end
            
            intan_start = intan_map_local(bk_start_30k) - sess_start_intan;
            intan_end   = intan_map_local(bk_end_30k)   - sess_start_intan;
            
            for u = 1:n_units_st
                st = double(st_data.(st_fields{u}));
                if isempty(st), continue; end
                in_win = st >= intan_start & st <= intan_end;
                rel_ms = (st(in_win) - intan_start) / fs_neural * 1000 - win_pre_ms;
                raster_st{u, s} = rel_ms;
                psth_st(u,:)    = psth_st(u,:) + histcounts(rel_ms, bin_edges);
            end
        end

        summary_struct(i).merged_with_summary.(field).spike_psth_hz = psth_st / N * 1000;
        summary_struct(i).merged_with_summary.(field).spike_raster  = raster_st;
        summary_struct(i).merged_with_summary.(field).spike_unit_ids = st_fields;
    end

    fprintf('[BR %d] %s done\n', br_id, trial);
    clear Data beh_data st_data
end

%% Save updated summary
% save(summary_path, 'summary_struct', '-append');
% fprintf('Saved updated summary_struct -> %s\n', summary_path);


%% Plot from summary_struct
trial_idx     = 11; % which summary_struct entry
segment_field = 'active_like_stim_neg';

s_data     = summary_struct(trial_idx).merged_with_summary.(segment_field);
raster     = s_data.spike_raster;    % (n_units, n_trials)
psth_hz    = s_data.spike_psth_hz;   % (n_units, n_bins)
unit_ids   = s_data.spike_unit_ids;  % cell of unit names
n_units    = size(psth_hz, 1);
n_trials   = s_data.n_trials;
t_centers  = bin_edges(1:end-1) + 0.5;

%% FR estimation per trial for heatmap
cutoff_freq = 5;
rate_mode   = 'kaiser';
ds_factor   = round(fs_neural / 1000);
fr_trials   = zeros(n_units, n_trials, n_bins);

for u = 1:n_units
    for s = 1:n_trials
        spk = raster{u, s};
        if isempty(spk), continue; end
        % Build binary spike train in window
        spike_vec = zeros(n_bins, 1);
        spk_idx   = round(spk + win_pre_ms) + 1; % ms -> index
        spk_idx   = spk_idx(spk_idx >= 1 & spk_idx <= n_bins);
        spike_vec(spk_idx) = 1;
        fr_full = fr_estimate(spike_vec, rate_mode, cutoff_freq, 1000); % already at 1kHz
        if length(fr_full) >= n_bins
            fr_trials(u, s, :) = fr_full(1:n_bins);
        else
            fr_trials(u, s, 1:length(fr_full)) = fr_full;
        end
    end
end

mean_fr = squeeze(mean(fr_trials, 2));
[~, sort_order_units] = sort(max(mean_fr, [], 2), 'descend');
mean_fr_sorted  = mean_fr(sort_order_units, :);
unit_ids_sorted = unit_ids(sort_order_units);

%% Z-score per unit across time
mu  = mean(mean_fr_sorted, 2);
sig = std(mean_fr_sorted, 0, 2);
sig = max(sig, 1e-6); % avoid division by zero
mean_fr_z = (mean_fr_sorted - mu) ./ sig;

%% Plot 1: Raster for example unit
UNIT_IDX = 4;
figure; hold on;
for s = 1:n_trials
    spk = raster{sort_order_units(UNIT_IDX), s};
    if isempty(spk), continue; end
    plot(spk, s * ones(size(spk)), '.', 'Color', [0.5 0.5 0.5], 'MarkerSize', 4);
end
xline(0, 'r--', 'LineWidth', 1.5);
xlabel('Time from movement onset (ms)');
ylabel('Trial');
title(sprintf('Raster - %s - %s', unit_ids_sorted{UNIT_IDX}, segment_field), 'Interpreter', 'none');
xlim([-win_pre_ms win_post_ms]);
box off;

%% Plot 2: FR heatmap
figure;
imagesc(t_centers, 1:n_units, mean_fr_sorted);
xline(0, 'r--', 'LineWidth', 1.5);
colorbar; colormap jet;
xlabel('Time from movement onset (ms)');
ylabel('Unit (sorted by peak FR)');
title(sprintf('FR heatmap - BR%d - %s', summary_struct(trial_idx).BR_File, segment_field), 'Interpreter', 'none');

%% Plot 3: FR heatmap (z-scored)
figure;
imagesc(t_centers, 1:n_units, mean_fr_z);
xline(0, 'r--', 'LineWidth', 1.5);
colorbar; colormap jet;
clim([-2 2]);
xlabel('Time from movement onset (ms)');
ylabel('Unit (sorted by peak FR)');
title(sprintf('FR heatmap z-scored - BR%d - %s', summary_struct(trial_idx).BR_File, segment_field), 'Interpreter', 'none');