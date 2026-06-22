clear all; close all; clc;
addpath(genpath(fullfile('..', 'functions')));
%% Config
session       = 'Bert/BL_RW_003_Session_1';
br_id         = 11; % <-- change this to switch trials
segment_field = 'active_like_stim_pos';
MIN_SPIKES = 500; % adjust as needed

[~, session_name] = fileparts(session);
base_folder      = '/Volumes/data/Current Project Databases - NHP/2025 Cerebellum prosthesis/Bert/BL_RW_003_Session_1';
metadata_csv     = fullfile(base_folder, 'Metadata',    [session_name, '_metadata.csv']);
summary_path     = fullfile(base_folder, 'Checkpoints', [session_name, '_summarized_metrics.mat']);

%% Load metadata
opts = detectImportOptions(metadata_csv);
opts = setvartype(opts, 'Stim_Delay', 'string');
T = readtable(metadata_csv, opts);

%% BR_File -> Intan index -> sess_name
row_idx = find(T.BR_File == br_id);
if isempty(row_idx)
    error('BR_File %d not found in metadata', br_id);
end
intan_idx = T.Intan_File(row_idx);

intan_root    = fullfile(base_folder, 'Intan');
intan_folders = dir(intan_root);
intan_folders = intan_folders([intan_folders.isdir] & ~startsWith({intan_folders.name}, '.'));
[~, sort_order] = sort({intan_folders.name});
intan_folders   = intan_folders(sort_order);

sess_name        = intan_folders(intan_idx).name;
spike_train_path = fullfile(base_folder, 'results', 'checkpoints', 'sorting_results', sess_name, 'NPRW', 'spike_trains.mat');
fprintf('BR_File %d -> Intan index %d -> %s\n', br_id, intan_idx, sess_name);

%% Load Cal file
cal_files = dir(fullfile(base_folder, 'Calibrated', '**', sprintf('*%d_Cal*.mat', br_id)));
if isempty(cal_files)
    error('No Cal file found for BR_File %d', br_id);
end

% Prioritize Cal_stim over Cal
stim_idx = find(contains({cal_files.name}, 'Cal_stim'));
if ~isempty(stim_idx)
    cal_path = fullfile(cal_files(stim_idx(1)).folder, cal_files(stim_idx(1)).name);
else
    cal_path = fullfile(cal_files(1).folder, cal_files(1).name);
end
fprintf('Loaded Cal file: %s\n', cal_path);
beh  = load(cal_path, 'Data');
Data = beh.Data;

%% Load spike trains and summary
spike_trains       = load(spike_train_path);
summarized_metrics = load(summary_path);
fs_neural = spike_trains.fs; % 30000

unit_fields = fieldnames(spike_trains);
unit_fields = unit_fields(~strcmp(unit_fields, 'fs'));
n_units = length(unit_fields);

%% Filter units by minimum spike count
keep = false(n_units, 1);
for u = 1:n_units
    st = double(spike_trains.(unit_fields{u}));
    keep(u) = length(st) >= MIN_SPIKES;
end
unit_fields = unit_fields(keep);
n_units = length(unit_fields);
fprintf('Units after spike count threshold (>=%d): %d\n', MIN_SPIKES, n_units);
%% Get segments from summary
trial_struct = summarized_metrics.summary_struct(row_idx).merged_with_summary;
if ~isfield(trial_struct, segment_field)
    error('segment_field %s not found in summary_struct for BR_File %d', segment_field, br_id);
end
segments3 = trial_struct.(segment_field).segments3; % (N_trials, 2) in BK 1kHz samples
n_trials  = size(segments3, 1);
fprintf('Found %d trials for segment field: %s\n', n_trials, segment_field);

%% Build peri-event spike trains aligned to movement onset
win_pre_ms  = 800;
win_post_ms = 1200;
bin_edges   = -win_pre_ms : win_post_ms;
n_bins      = length(bin_edges) - 1;

psth   = zeros(n_units, n_bins);
raster = cell(n_units, n_trials);

intan_map           = double(Data.Intan_idx(1,:));
session_start_intan = intan_map(1);
session_end_intan = intan_map(end);

for s = 1:n_trials
    seg_start_bk = segments3(s,1);
    seg_end_bk   = segments3(s,2);
    
    if seg_start_bk <= session_start_intan || seg_end_bk > session_end_intan, continue; end

    intan_start = intan_map(seg_start_bk) - session_start_intan;
    intan_end   = intan_map(seg_end_bk)   - session_start_intan;

    for u = 1:n_units
        st = double(spike_trains.(unit_fields{u}));
        if isempty(st), continue; end

        % spikes within this window, relative to window start in ms
        in_win = st >= intan_start & st <= intan_end;
        rel_ms = (st(in_win) - intan_start) / fs_neural * 1000 - win_pre_ms;
        raster{u, s} = rel_ms;

        counts = histcounts(rel_ms, bin_edges);
        psth(u,:) = psth(u,:) + counts;
    end
end
psth_hz = psth / n_trials * 1000;


%% FR estimation params
cutoff_freq    = 5;
rate_mode      = 'kaiser';
target_fs      = 1000;
ds_factor      = round(fs_neural / target_fs);

%% Compute peri-event FR per unit per trial
% For each trial, extract spike train in window, estimate FR, downsample
fr_trials = zeros(n_units, n_trials, n_bins); % (n_units, n_trials, n_bins)

for u = 1:n_units
    st = double(spike_trains.(unit_fields{u}));
    if isempty(st), continue; end

    for s = 1:n_trials
        bk_onset = segments3(s,1) + win_pre_ms;
        if bk_onset <= 0 || bk_onset > length(intan_map), continue; end
        intan_onset = intan_map(bk_onset) - session_start_intan;

        % Window in samples
        win_start_samp = round(intan_onset - win_pre_ms  / 1000 * fs_neural);
        win_end_samp   = round(intan_onset + win_post_ms / 1000 * fs_neural);
        if win_start_samp < 1, continue; end

        % Build binary spike train in window
        win_len   = win_end_samp - win_start_samp + 1;
        spike_vec = zeros(win_len, 1);
        in_win    = st >= win_start_samp & st <= win_end_samp;
        local_idx = st(in_win) - win_start_samp + 1;
        spike_vec(local_idx) = 1;

        % FR estimate
        fr_full = fr_estimate(spike_vec, rate_mode, cutoff_freq, fs_neural);
        fr_ds   = downsample(fr_full, ds_factor); % now at 1kHz

        % Resample to n_bins (2000 bins at 1ms each = 2000 samples at 1kHz)
        if length(fr_ds) >= n_bins
            fr_trials(u, s, :) = fr_ds(1:n_bins);
        else
            fr_trials(u, s, 1:length(fr_ds)) = fr_ds;
        end
    end
end

% Mean FR per unit across trials
mean_fr = squeeze(mean(fr_trials, 2)); % (n_units, n_bins)

% Sort units by peak mean FR
[~, sort_order_units] = sort(max(mean_fr, [], 2), 'descend');
mean_fr_sorted   = mean_fr(sort_order_units, :);
unit_fields_sorted = unit_fields(sort_order_units);

%% Plot 1: Raster for example unit (grey dots, trial x time)
UNIT_IDX = 1;
figure;
hold on;
for s = 1:n_trials
    spk = raster{sort_order_units(UNIT_IDX), s};
    if isempty(spk), continue; end
    plot(spk, s * ones(size(spk)), '.', 'Color', [0.5 0.5 0.5], 'MarkerSize', 4);
end
xline(0, 'r--', 'LineWidth', 1.5);
xlabel('Time from movement onset (ms)');
ylabel('Trial');
title(sprintf('Raster - %s - %s', unit_fields_sorted{UNIT_IDX}, segment_field), 'Interpreter', 'none');
xlim([-win_pre_ms win_post_ms]);
box off;

%% Plot 2: FR heatmap (units x time), sorted by peak FR
figure;
imagesc(t_centers, 1:n_units, mean_fr_sorted);
xline(0, 'r--', 'LineWidth', 1.5);
colorbar; colormap jet;
xlabel('Time from movement onset (ms)');
ylabel('Unit (sorted by peak FR)');
title(sprintf('FR heatmap - %s - %s', sess_name, segment_field), 'Interpreter', 'none');