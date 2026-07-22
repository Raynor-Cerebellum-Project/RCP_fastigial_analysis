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

%% Load conditions
cal_file    = load('/Volumes/data/Current Project Databases - NHP/2025 Cerebellum prosthesis/Bert/BL_RW_003_Session_1/Calibrated/IntanFile_5/BL_closed_loop_STIM_003_008_Cal_stim.mat');
spike_train = load('/Volumes/data/Current Project Databases - NHP/2025 Cerebellum prosthesis/Bert/BL_RW_003_Session_1/results/checkpoints/sorting_results/BL_closed_loop_STIM_003_250528_145904/NPRW/spike_trains.mat');
%%
cutoff_freq = 5;
rate_mode   = 'kaiser';
fs_vel      = 1000;

% Manually specified movement peak times (seconds)
peak_times_ipsi   = cal_file.Data.segments.active_like_stim_pos(:, 1)/1000;
peak_times_contra = cal_file.Data.segments.active_like_stim_neg(:, 1)/1000;

win_pre_s  = 0.4;
win_post_s = 0.4;

data_cond  = cal_file.Data;
cond_title = 'Stim';

% all units present in spike_train, excluding any non-unit fields
all_unit_names = fieldnames(spike_train);
all_unit_names = all_unit_names(startsWith(all_unit_names, 'unit_'));
n_units = length(all_unit_names);

%% Plot per-unit summary figures (vel / counts / rate / raster / PSTH)
for u = 2
    unit_name = all_unit_names{u};
    unit_spike_train = spike_train.(unit_name);

    [t_vel, t_bin, counts, rate, t_rate] = compute_condition(data_cond, unit_spike_train, cutoff_freq, rate_mode, fs_vel);

    for direction = 1:2  % 1 = contra, 2 = ipsi
        if direction == 1
            peak_times_cur = peak_times_contra;
            dir_label = 'Contra';
        else
            peak_times_cur = peak_times_ipsi;
            dir_label = 'Ipsi';
        end

        figure;

        % Row 1: head yaw velocity
        subplot(6, 1, 1)
        plot(t_vel, data_cond.headYawVel);
        ylabel('Yaw Vel (deg/s)');
        title(sprintf('Head Yaw Velocity - %s (%s)', cond_title, dir_label));
        xlim([0 t_vel(end)]);
        ylim([-500 500]);
        for p = 1:length(peak_times_cur)
            xline(peak_times_cur(p), 'r--', 'Alpha', 0.5);
        end

        % Row 2: spike counts
        subplot(6, 1, 2)
        bar(t_bin, counts, 1, 'k');
        ylabel('Spike count');
        title('Spike counts (20ms bins)');
        xlim([0 t_vel(end)]);
        ylim([0 10]);
        for p = 1:length(peak_times_cur)
            xline(peak_times_cur(p), 'r--', 'Alpha', 0.5);
        end

        % Row 3: smoothed firing rate
        subplot(6, 1, 3)
        plot(t_rate, rate, 'k');
        ylabel('FR (sp/s)');
        title('Firing rate (Kaiser)');
        xlim([0 t_vel(end)]);
        ylim([0 150]);
        for p = 1:length(peak_times_cur)
            xline(peak_times_cur(p), 'r--', 'Alpha', 0.5);
        end

        % Row 4: trial-aligned average +/- std kinematics
        peaks    = peak_times_cur;
        n_trials = length(peaks);
        bin_edges_psth = -win_pre_s : 1/fs_vel : win_post_s;
        n_bins_psth    = length(bin_edges_psth) - 1;
        t_psth         = bin_edges_psth(1:end-1) + 1/(2*fs_vel);
        psth_acc       = zeros(1, n_bins_psth);
        n_valid        = 0;

        intan_start   = data_cond.Intan_idx(1);
        spk_all       = double(unit_spike_train(unit_spike_train >= intan_start));
        spike_t_s_all = (spk_all - intan_start) / 30000;

        vel        = data_cond.headYawVel(:);
        kin_trials = nan(n_trials, n_bins_psth);
        for tr = 1:n_trials
            t0        = peaks(tr);
            idx_start = round((t0 - win_pre_s) * fs_vel) + 1;
            idx_end   = idx_start + n_bins_psth - 1;
            if idx_start < 1 || idx_end > length(vel), continue; end
            kin_trials(tr, :) = vel(idx_start:idx_end);
        end
        kin_mean = nanmean(kin_trials, 1);
        kin_std  = nanstd(kin_trials, 0, 1);

        ax_kin = subplot(6, 1, 4);
        hold(ax_kin, 'on');
        fill(ax_kin, [t_psth, fliplr(t_psth)], ...
             [kin_mean + kin_std, fliplr(kin_mean - kin_std)], ...
             [0.6 0.8 1], 'EdgeColor', 'none', 'FaceAlpha', 0.5);
        plot(ax_kin, t_psth, kin_mean, 'b', 'LineWidth', 1.5);
        xline(ax_kin, 0, 'r--', 'LineWidth', 1.5);
        xlim(ax_kin, [-win_pre_s win_post_s]);
        ylabel(ax_kin, 'Yaw Vel (deg/s)');
        title(ax_kin, sprintf('Average vel - %s (trial aligned)', cond_title));
        box(ax_kin, 'off');

        % Row 5: raster
        ax_raster = subplot(6, 1, 5);
        hold(ax_raster, 'on');
        for tr = 1:n_trials
            t0      = peaks(tr);
            in_win  = spike_t_s_all >= (t0 - win_pre_s) & spike_t_s_all <= (t0 + win_post_s);
            spk_rel = spike_t_s_all(in_win) - t0;
            plot(ax_raster, spk_rel, tr * ones(size(spk_rel)), '.', 'Color', [0.3 0.3 0.3], 'MarkerSize', 4);
            counts_tr = histcounts(spk_rel, bin_edges_psth);
            psth_acc  = psth_acc + counts_tr;
            n_valid   = n_valid + 1;
        end
        xline(ax_raster, 0, 'r--', 'LineWidth', 1.5);
        xlim(ax_raster, [-win_pre_s win_post_s]);
        ylim(ax_raster, [0 n_trials+1]);
        ylabel(ax_raster, 'Trial');
        title(ax_raster, 'Raster (trial aligned)');
        box(ax_raster, 'off');

        % Row 6: trial-averaged PSTH
        ax_psth = subplot(6, 1, 6);
        if n_valid > 0
            mean_spike_vec   = psth_acc / n_valid;
            mean_psth_smooth = fr_estimate(mean_spike_vec(:), rate_mode, cutoff_freq, fs_vel);
            plot(ax_psth, t_psth, mean_psth_smooth, 'k');
        end
        title(ax_psth, 'Firing rate (Kaiser, trial aligned)');
        xline(ax_psth, 0, 'r--', 'LineWidth', 1.5);
        xlim(ax_psth, [-win_pre_s win_post_s]);
        ylabel(ax_psth, 'FR (sp/s)');
        xlabel(ax_psth, 'Time from peak (s)');
        box(ax_psth, 'off');

        sgtitle(sprintf('%s - %s reaches', strrep(unit_name, '_', ' '), dir_label), 'Fontsize', 13);
    end
end

%% Heatmap: one row per unit, single condition, two figures (contra, ipsi)
bin_edges_psth = -win_pre_s : 1/fs_vel : win_post_s;
n_bins_psth    = length(bin_edges_psth) - 1;
t_psth         = bin_edges_psth(1:end-1) + 1/(2*fs_vel);
for direction = 1:2
    if direction == 1
        peak_times_cur = peak_times_contra;
        dir_label = 'Contra';
    else
        peak_times_cur = peak_times_ipsi;
        dir_label = 'Ipsi';
    end
    heatmap_data = zeros(n_units, n_bins_psth);  % (units, time)
    unit_total_spikes = zeros(n_units, 1);
    for u = 1:n_units
        unit_st = double(spike_train.(all_unit_names{u}));
        peaks    = peak_times_cur;
        n_trials = length(peaks);
        psth_acc = zeros(1, n_bins_psth);
        intan_start   = data_cond.Intan_idx(1);
        spk_all       = unit_st(unit_st >= intan_start);
        spike_t_s_all = (spk_all - intan_start) / 30000;
        for tr = 1:n_trials
            t0        = peaks(tr);
            in_win    = spike_t_s_all >= (t0 - win_pre_s) & spike_t_s_all <= (t0 + win_post_s);
            spk_rel   = spike_t_s_all(in_win) - t0;
            psth_acc  = psth_acc + histcounts(spk_rel, bin_edges_psth);
        end
        unit_total_spikes(u) = sum(psth_acc);
        mean_spike_vec = psth_acc / n_trials;
        heatmap_data(u, :) = fr_estimate(mean_spike_vec(:), rate_mode, cutoff_freq, fs_vel);
    end

    % Drop units with zero spikes in the window before z-scoring/plotting
    active_mask = unit_total_spikes > 0;
    heatmap_data = heatmap_data(active_mask, :);
    unit_labels  = strrep(all_unit_names(active_mask), 'unit_', '');
    n_units_active = sum(active_mask);

    heatmap_data_raw = heatmap_data;  % save BEFORE z-scoring
    % Z-score each unit across time
    for u = 1:n_units_active
        mu = mean(heatmap_data(u, :));
        sg = std(heatmap_data(u, :));
        if sg < 1e-6, sg = 1; end
        heatmap_data(u, :) = (heatmap_data(u, :) - mu) / sg;
    end
    heatmap_data_zscore_unordered = heatmap_data;
    % Sort by peak time
    [~, peak_idx]      = max(heatmap_data, [], 2);
    [~, sort_order]    = sort(peak_idx);
    heatmap_data_sorted = heatmap_data(sort_order, :);
    unit_labels_sorted  = unit_labels(sort_order);
    figure;
    subplot(1, 3, 1)
    imagesc(t_psth, 1:n_units_active, heatmap_data_raw);
    xline(0, 'r--', 'LineWidth', 1.5);
    colormap(gca, 'bone');
    colorbar;
    xlabel('Time from peak (s)');
    title(sprintf('Raw FR (%s)', cond_title));
    yticks(1:10:n_units_active);
    yticklabels(unit_labels(1:10:n_units_active));
    box off;
    subplot(1, 3, 2)
    imagesc(t_psth, 1:n_units_active, heatmap_data_zscore_unordered);
    xline(0, 'r--', 'LineWidth', 1.5);
    colormap(gca, 'bone');
    clim([-2 2]);
    colorbar;
    xlabel('Time from peak (s)');
    title('Z-scored, by unit ID');
    yticks(1:10:n_units_active);
    yticklabels(unit_labels(1:10:n_units_active));
    box off;
    subplot(1, 3, 3)
    imagesc(t_psth, 1:n_units_active, heatmap_data_sorted);
    xline(0, 'r--', 'LineWidth', 1.5);
    colormap(gca, 'bone');
    clim([-2 2]);
    colorbar;
    xlabel('Time from peak (s)');
    title('Z-scored, ordered by peak time');
    yticks(1:10:n_units_active);
    yticklabels(unit_labels_sorted(1:10:n_units_active));
    box off;
    sgtitle(sprintf('FR heatmaps of all units - %s (%d/%d units active)', dir_label, n_units_active, n_units), 'Fontsize', 13);
end

%% Local functions
function [t_vel, t_bin, spike_counts, spike_rate, t_bin_rate] = compute_condition(Data, unit_spk, cutoff_freq, rate_mode, fs_vel)
    intan_start  = Data.Intan_idx(1);
    intan_end    = Data.Intan_idx(end);
    spk          = unit_spk(unit_spk >= intan_start & unit_spk <= intan_end);
    spike_t_s    = double(spk - intan_start) / 30000;
    t_vel        = (0:length(Data.headYawVel)-1) / fs_vel;
    dur_s        = t_vel(end);
    bin_size_s   = 0.02;
    bin_edges    = 0:bin_size_s:dur_s;
    spike_counts = histcounts(spike_t_s, bin_edges);
    t_bin        = bin_edges(1:end-1) + bin_size_s/2;
    spike_vec    = zeros(round(dur_s * fs_vel), 1);
    spk_idx      = round(spike_t_s * fs_vel) + 1;
    spk_idx      = spk_idx(spk_idx >= 1 & spk_idx <= length(spike_vec));
    spike_vec(spk_idx) = 1;
    spike_rate   = fr_estimate(spike_vec, rate_mode, cutoff_freq, fs_vel);
    t_bin_rate   = (0:length(spike_rate)-1) / fs_vel;
end