%% plot_3_freq_comparison_traces.m
clear; clc;
%% === Paths ===
server_root  = '/Volumes/data/Current Project Databases - NHP/2025 Cerebellum prosthesis';
utils_path   = fullfile(server_root, 'Bryan/RCP_fastigial_analysis/functions/utils');
addpath(utils_path);

%% === User Configuration ===
session    = '20260423_NRR_RW033_fastig';
subject    = 'Nike'; % 'Bert' or 'Nike'
side       = 'contra'; % 'ipsi' or 'contra'
cond_nums  = [9, 8, 3];
offset     = false;
use_ci     = true;

server_root = '/Volumes/data/Current Project Databases - NHP/2025 Cerebellum prosthesis';

if strcmp(subject, 'Bert')
    base_folder  = fullfile(server_root, 'Bert', session);
    summary_path = fullfile(base_folder, 'Checkpoints', [session '_summarized_metrics.mat']);
    meta_path    = fullfile(base_folder, 'Metadata', [session '_metadata.csv']);
elseif strcmp(subject, 'Nike')
    base_folder  = fullfile(server_root, 'Nike', session);
    summary_path = fullfile(base_folder, 'Checkpoints', [session '_summarized_metrics.mat']);
    meta_path    = fullfile(base_folder, 'Metadata', [session '_metadata.csv']);
end

%% === Load Data ===
load(summary_path, 'summary_struct', 'merged_baseline_summary');
T         = readtable(meta_path);
base_data = merged_baseline_summary;

cond_data = cell(1, 3);
meta_cond = cell(1, 3);
for k = 1:3
    cond_data{k} = summary_struct(cond_nums(k)).merged_with_summary;
    meta_cond{k} = T(T.BR_File == cond_nums(k), :);
end

%% === Resolve field names per subject ===
% Bert: fields are 'active_like_stim_pos' / 'active_like_stim_neg'
%       summary fields are 'ipsi_pos_summary' / 'contra_neg_summary'
% Nike: fields are 'ipsi' / 'contra' directly
%       summary fields are 'ipsi_summary' / 'contra_summary'
if strcmp(subject, 'Bert')
    is_ipsi    = strcmp(side, 'ipsi');
    polarity   = ternary(is_ipsi, 'pos', 'neg');
    base_field = sprintf('active_like_stim_%s', polarity);
    summ_field = sprintf('%s_%s_summary', side, polarity);
elseif strcmp(subject, 'Nike')
    base_field = side; % 'ipsi' or 'contra'
    summ_field = sprintf('%s_summary', side);
end

%% === Extract Metadata Scalars ===
freqs      = arrayfun(@(k) extract_scalar(meta_cond{k}, 'Stim_Frequency_Hz'), 1:3);
trial_nums = arrayfun(@(k) extract_scalar(meta_cond{k}, 'BR_File'),           1:3);
delay      = parse_numeric_field(meta_cond{1}, 'Stim_Delay');
duration   = extract_scalar(meta_cond{1}, 'Stim_Duration_ms');
delay_str  = ternary(isnan(delay), 'N/A', sprintf('%dms', round(delay)));

trig_val = meta_cond{1}.Movement_Trigger;
if iscell(trig_val),       trig_str = trig_val{1};
elseif isstring(trig_val), trig_str = char(trig_val);
else,                      trig_str = num2str(trig_val);
end

%% === Layout Constants ===
t             = linspace(-800, 1200, 2001);
trace_spacing = 20 * offset;
n_sets        = 4; % baseline + 3 conditions

condition_colors = [
    0.6 0.6 0.6;
    0.2 0.7 0.2;
    0.0 0.4 1.0;
    1.0 0.8 0.0;
];
legend_labels = [{'Baseline'}, arrayfun(@(f) sprintf('%d Hz', f), freqs, 'UniformOutput', false)];
trace_gray    = [0.7 0.7 0.7];

%% === Initialize Figure ===
fig    = figure('Visible', 'on', 'Position', [100, 100, 1400, 800]);
layout = tiledlayout(3, 6, 'TileSpacing', 'compact', 'Padding', 'tight');

%% === Compute global y-limits ===
vel_all = base_data.(base_field).velocity_traces;
pos_all = base_data.(base_field).position_traces;
for k = 1:3
    vel_all = [vel_all; cond_data{k}.(base_field).velocity_traces];
    pos_all = [pos_all; cond_data{k}.(base_field).position_traces];
end
% vel_range = max(vel_all(:)) - min(vel_all(:));
% yl_vel = [min(vel_all(:)) - 0.05*vel_range, max(vel_all(:)) + 0.05*vel_range];
yl_vel = [-50 350]; % manual

pos_range = max(pos_all(:)) - min(pos_all(:));
yl_pos = [min(pos_all(:)) - 0.05*pos_range, max(pos_all(:)) + 0.05*pos_range];

%% === Velocity: baseline (1) + 3 conditions (2,3,4) + overlaid (5-6) ===
ax_vel    = gobjects(1, 5);
all_data  = [{base_data}, cond_data];
all_titles = [{'Baseline Vel'}, arrayfun(@(f) sprintf('%d Hz Vel', f), freqs, 'UniformOutput', false)];

for k = 1:4
    ax_vel(k) = nexttile(layout, k); hold on;
    title(all_titles{k}); ylabel('Velocity (deg/s)'); box off; set(gca, 'TickDir', 'out');

    vel_mat = all_data{k}.(base_field).velocity_traces;
    trace_fade = 0.85;
    light_color = [0.6 0.6 0.6]*trace_fade + [1 1 1]*(1-trace_fade);
    for i = 1:size(vel_mat, 1)
        plot(t, vel_mat(i,:) + i*trace_spacing, 'Color', light_color, 'LineWidth', 0.75);
    end
    plot(t, nanmean(vel_mat,1) + (size(vel_mat,1)+1)*trace_spacing, ...
        'Color', ternary(k==1, [0 0 0], condition_colors(k,:)), 'LineWidth', 2);
    xline(0, '--k');
    if k > 1
        fill([delay delay+duration delay+duration delay], ...
             [yl_vel(1) yl_vel(1) yl_vel(2) yl_vel(2)], ...
             [0.8 0.1 0.1], 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    end
    ylim(yl_vel); xlim([-800 1200]);
end

ax_vel(5) = nexttile(layout, 5, [1 2]); hold on;
title('Overlaid Vel'); ylabel('Velocity (deg/s)'); box off; set(gca, 'TickDir', 'out');
for k = 1:4
    STDplot(t, all_data{k}.(base_field).velocity_traces, ternary(k==1, [0 0 0], condition_colors(k,:)));
end
xline(0, '--k');
if ~isnan(delay) && ~isnan(duration)
    fill([delay delay+duration delay+duration delay], ...
         [yl_vel(1) yl_vel(1) yl_vel(2) yl_vel(2)], ...
         [0.8 0.1 0.1], 'FaceAlpha', 0.2, 'EdgeColor', 'none');
end
ylim(yl_vel); xlim([-800 1200]);

%% === Position: baseline (7) + 3 conditions (8,9,10) + overlaid (11-12) ===
ax_pos    = gobjects(1, 5);
all_titles_pos = [{'Baseline Pos'}, arrayfun(@(f) sprintf('%d Hz Pos', f), freqs, 'UniformOutput', false)];

for k = 1:4
    ax_pos(k) = nexttile(layout, k+6); hold on;
    title(all_titles_pos{k}); ylabel('Position (deg)'); box off; set(gca, 'TickDir', 'out');

    pos_mat = all_data{k}.(base_field).position_traces;
    trace_fade = 0.5;
    light_color = [0.6 0.6 0.6]*trace_fade + [1 1 1]*(1-trace_fade);
    for i = 1:size(pos_mat, 1)
        plot(t, pos_mat(i,:) + i*trace_spacing, 'Color', light_color, 'LineWidth', 0.75);
    end
    % In the baseline pos panel (k=1 iteration):
    plot(t, nanmean(pos_mat,1) + (size(pos_mat,1)+1)*trace_spacing, ...
        'Color', ternary(k==1, [0 0 0], condition_colors(k,:)), 'LineWidth', 2);
    if k > 1
        fill([delay delay+duration delay+duration delay], ...
             [yl_pos(1) yl_pos(1) yl_pos(2) yl_pos(2)], ...
             [0.8 0.1 0.1], 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    end
    ylim(yl_pos); xlim([-800 1200]);
end

ax_pos(5) = nexttile(layout, 11, [1 2]); hold on;
title('Overlaid Pos'); ylabel('Position (deg)'); box off; set(gca, 'TickDir', 'out');
for k = 1:4
    STDplot(t, all_data{k}.(base_field).position_traces, ternary(k==1, [0 0 0], condition_colors(k,:)));
end
xline(0, '--k');
if ~isnan(delay) && ~isnan(duration)
    fill([delay delay+duration delay+duration delay], ...
         [yl_pos(1) yl_pos(1) yl_pos(2) yl_pos(2)], ...
         [0.8 0.1 0.1], 'FaceAlpha', 0.2, 'EdgeColor', 'none');
end
ylim(yl_pos); xlim([-800 1200]);

%% === Endpoint Error (tile 13) ===
nexttile(layout, 13); hold on;
box off; set(gca, 'TickDir', 'out', 'FontSize', 10);
[e_means, e_sems, e_sig] = compute_metric_stats(base_data, cond_data, base_field, 'all_err', false);
plot_bar_group(e_means, e_sems, e_sig, condition_colors, {'EndpointError'}, 'Endpoint Error (deg)');

%% === Group 1: Kinematic Metrics (tiles 14-15) ===
nexttile(layout, 14, [1 2]); hold on;
box off; set(gca, 'TickDir', 'out');
group1_metrics = {'all_err_abs', 'var_500ms', 'all_var'};
group1_labels  = {'AbsEndpointError', 'VarAfterStim', 'VarAfterEndpoint'};
plot_grouped_bars(base_data, cond_data, base_field, group1_metrics, group1_labels, condition_colors, 'deg/s');

%% === Speed Metrics (tile 16) + legend ===
nexttile(layout, 16); hold on;
box off; set(gca, 'TickDir', 'out');
group2_metrics = {'max_speed', 'avg_speed'};
group2_labels  = {'MaxSpeed', 'AvgSpeed'};
sample_sizes   = plot_grouped_bars(base_data, cond_data, base_field, group2_metrics, group2_labels, condition_colors, 'deg/s');

h_legend = gobjects(1, n_sets);
for i = 1:n_sets
    h_legend(i) = bar(nan, nan, 'FaceColor', condition_colors(i,:), 'HandleVisibility', 'on');
end
legend(h_legend, arrayfun(@(i) sprintf('%s (n=%d)', legend_labels{i}, sample_sizes(i)), ...
    1:n_sets, 'UniformOutput', false), ...
    'Orientation', 'horizontal', 'Location', 'northoutside', 'Box', 'off', 'FontSize', 9);

%% === Oscillations (tile 17) ===
nexttile(layout, 17); hold on;
box off; set(gca, 'TickDir', 'out', 'FontSize', 10);
[o_means, o_sems, o_sig] = compute_metric_stats(base_data, cond_data, base_field, 'oscillations', false);
plot_bar_group(o_means, o_sems, o_sig, condition_colors, {'EndpointOscillation'}, 'Count');

%% === FFT Power (tile 18) ===
nexttile(layout, 18); hold on;
box off; set(gca, 'TickDir', 'out', 'FontSize', 10);
[f_means, f_sems, f_sig] = compute_metric_stats(base_data, cond_data, base_field, 'fft_power', false);
plot_bar_group(f_means, f_sems, f_sig, condition_colors, {'FFTPowerAfterEnd'}, 'Power');
%% === Title ===
title_str = sprintf('Conditions %03d/%03d/%03d (%d/%d/%d Hz) - %s - %s', ...
    trial_nums(1), trial_nums(2), trial_nums(3), freqs(1), freqs(2), freqs(3), subject, side);
stim_str = sprintf('Ch: %g | Curr: %g uA | Dur: %g ms | Delay: %s | Depth: %g mm | Trig: %s', ...
    extract_scalar(meta_cond{1}, 'Channels'),         extract_scalar(meta_cond{1}, 'Current_uA'), ...
    extract_scalar(meta_cond{1}, 'Stim_Duration_ms'), delay_str, ...
    extract_scalar(meta_cond{1}, 'Depth_mm'),         trig_str);
sgtitle({title_str, stim_str}, 'FontWeight', 'bold', 'FontSize', 13);

outerpos    = get(layout, 'OuterPosition');
outerpos(2) = outerpos(2) + 0.08;
outerpos(4) = outerpos(4) - 0.08;
set(layout, 'OuterPosition', outerpos);

annotation('textbox', [0.35, 0.01, 0.3, 0.06], ...
    'String', {'Significance:  *  p<0.05    **  p<0.01    ***  p<0.001    n.s. not significant'}, ...
    'EdgeColor', 'k', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
    'FontSize', 10, 'FitBoxToText', 'on', 'BackgroundColor', 'white');

%% === Save ===
save_base = sprintf('%dCh_Cond_%03d_%03d_%03d_%s_%s_FreqComparison', ...
    extract_scalar(meta_cond{1}, 'Channels'), trial_nums(1), trial_nums(2), trial_nums(3), subject, side);
save_root = fullfile(base_folder, 'Figures', 'Behavior', 'FrequencyComparison');
for sf = {'pngFigs', 'svgFigs', 'figFigs'}
    p = fullfile(save_root, sf{1});
    if ~exist(p, 'dir'), mkdir(p); end
end
print(fig, fullfile(save_root, 'pngFigs', [save_base '.png']), '-dpng', '-r300');
set(fig, 'Renderer', 'painters');
print(fig, fullfile(save_root, 'svgFigs', [save_base '.svg']), '-dsvg', '-painters');
savefig(fig, fullfile(save_root, 'figFigs', [save_base '.fig']));
fprintf('Saved: %s\n', save_base);

%% =========================================================================
%% Local Functions
%% =========================================================================

function plot_bar_group(means, sems, sig, colors, xlbl, ylbl)
    n       = numel(means);
    bw      = 0.12;
    offsets = linspace(-1, 1, n) * bw * 1.8;

    for i = 1:n
        bar(1 + offsets(i), means(i), bw, 'FaceColor', colors(i,:));
        errorbar(1 + offsets(i), means(i), sems(i), 'k', 'linestyle', 'none', 'LineWidth', 1.5);
    end

    yrange = max(range([means - sems, means + sems]), eps);
    ylim([min(means-sems) - 0.15*yrange, max(means+sems) + 0.25*yrange]);
    xticks(1); xticklabels(xlbl); xtickangle(45);
    ylabel(ylbl); yline(0, '--k');
    set(gca, 'FontSize', 10);

    for i = 2:n
        text(1 + offsets(i), means(i)+sems(i)+0.07*yrange, sig(i-1), ...
            'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold');
    end
end

function sample_sizes = plot_grouped_bars(base_data, cond_data, base_field, metrics, xlbls, colors, ylbl)
    n_sets    = 1 + numel(cond_data);
    n_metrics = numel(metrics);
    bar_data  = nan(n_sets, n_metrics);
    bar_std   = nan(n_sets, n_metrics);
    sig_mat   = strings(n_metrics, n_sets - 1);
    sample_sizes = zeros(n_sets, 1);

    for m = 1:n_metrics
        use_abs   = strcmp(metrics{m}, 'all_err_abs');
        raw_field = ternary(use_abs, 'all_err', metrics{m});
        base_vals = get_metric_vals(base_data, base_field, raw_field, use_abs);
        sample_sizes(1) = numel(base_vals);
        bar_data(1, m)  = mean(base_vals);
        bar_std(1, m)   = std(base_vals);
        for i = 2:n_sets
            vals = get_metric_vals(cond_data{i-1}, base_field, raw_field, use_abs);
            sample_sizes(i) = numel(vals);
            bar_data(i, m)  = mean(vals);
            bar_std(i, m)   = std(vals);
            [~, p] = ttest2(base_vals, vals);
            sig_mat(m, i-1) = significance_label(p);
        end
    end

    x         = 1:n_metrics;
    bar_width = 0.12;
    offsets   = linspace(-1, 1, n_sets) * bar_width * 1.8;
    for i = 1:n_sets
        bar(x + offsets(i), bar_data(i,:), bar_width, 'FaceColor', colors(i,:));
        errorbar(x + offsets(i), bar_data(i,:), bar_std(i,:), 'k', 'linestyle', 'none', 'LineWidth', 1);
    end
    yl = ylim;
    for m = 1:n_metrics
        for i = 2:n_sets
            text(x(m)+offsets(i), bar_data(i,m)+bar_std(i,m)+0.05*range(yl), sig_mat(m,i-1), ...
                'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold');
        end
    end
    xticks(x); xticklabels(xlbls); xtickangle(45);
    ylabel(ylbl); set(gca, 'FontSize', 11); yline(0, '--k');
end

function [means, sems, sig] = compute_metric_stats(base_data, cond_data, base_field, metric, use_abs)
    n_conds = numel(cond_data);
    n_sets  = 1 + n_conds;
    means   = nan(1, n_sets);
    sems    = nan(1, n_sets);
    sig     = strings(1, n_sets - 1);
    base_vals = get_metric_vals(base_data, base_field, metric, use_abs);
    means(1)  = mean(base_vals);
    sems(1)   = std(base_vals) / sqrt(numel(base_vals));
    for i = 1:n_conds
        vals       = get_metric_vals(cond_data{i}, base_field, metric, use_abs);
        means(i+1) = mean(vals);
        sems(i+1)  = std(vals) / sqrt(numel(vals));
        [~, p]     = ttest2(base_vals, vals);
        sig(i)     = significance_label(p);
    end
end

function vals = get_metric_vals(data, field1, metric, use_abs)
    vals = data.(field1).(metric);
    if use_abs, vals = abs(vals); end
    vals = vals(~isnan(vals));
end

function add_stim_patch(ax_arr, delay, duration)
    if isnan(delay) || isnan(duration), return; end
    linkaxes(ax_arr, 'y'); drawnow;
    yl = ylim(ax_arr(end));
    px = [delay delay+duration delay+duration delay];
    py = [yl(1) yl(1) yl(2) yl(2)];
    for ii = 1:numel(ax_arr)
        fill(ax_arr(ii), px, py, [0.8 0.1 0.1], 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    end
end

function v = extract_scalar(meta, field)
    raw = meta.(field);
    if iscell(raw), raw = raw{1}; end
    if ischar(raw) || isstring(raw), v = str2double(raw); else, v = raw(1); end
end

function v = parse_numeric_field(meta, field)
    raw = meta.(field);
    if iscell(raw), raw = raw{1}; end
    if isnumeric(raw)
        v = raw(1);
    else
        s = strtrim(char(raw));
        if ismember(s, {'-', 'Random', 'NaN', ''}), v = NaN;
        else, v = str2double(s);
        end
    end
end

function label = significance_label(p)
    if p < 0.001,    label = '***';
    elseif p < 0.01, label = '**';
    elseif p < 0.05, label = '*';
    else,            label = 'n.s.';
    end
end

function val = ternary(cond, a, b)
    if cond, val = a; else, val = b; end
end