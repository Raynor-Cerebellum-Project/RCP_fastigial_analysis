%% combine_conditions.m
% Combines specific conditions across sessions for bar graph comparison

clear all; close all; clc;
addpath(genpath(fullfile('..', 'functions')));

[base_root, ~, ~] = set_paths_cullen_lab('');

%% --- Define which conditions to combine ---
% {session, br_file, ipsi_label, contra_label}
condition_list = {
    'Bert/BL_RW_003_Session_1',       8,  'active_like_stim_pos', 'active_like_stim_neg';
    'Nike/20260326_NRR_RW027_fastig', 13,  'ipsi',                 'contra';
    'Nike/20260423_NRR_RW033_fastig',  3,  'ipsi',                 'contra';
};
%% --- Metrics and units ---
metrics      = {'all_err',  'all_var', 'max_speed', 'avg_speed', 'var_500ms', 'oscillations', 'fft_power'};
metric_units = {'deg',      'deg',     'deg/s',     'deg/s',     'deg/s',     'count',         'power'};
%% --- Load and concatenate (paired per session, both sides) ---
sides = {'ipsi', 'contra'};
combined = struct();
for s = sides
    for m = 1:numel(metrics)
        combined.(s{1}).(metrics{m}) = struct('baseline', [], 'condition', []);
    end
    combined.(s{1}).n_trials = struct('baseline', [], 'condition', []);
end

for k = 1:size(condition_list, 1)
    session      = condition_list{k, 1};
    br_file      = condition_list{k, 2};
    ipsi_label   = condition_list{k, 3};
    contra_label = condition_list{k, 4};
    % is_nike      = contains(session, 'Nike');

    [~, session_name] = fileparts(session);
    [~, ~, base_folder] = set_paths_cullen_lab(session);
    summary_path         = fullfile(base_folder, 'Checkpoints', [session_name '_summarized_metrics.mat']);
    merged_baseline_path = fullfile(base_folder, 'Checkpoints', [session_name '_merged_baseline.mat']);

    S = load(summary_path, 'summary_struct');
    B = load(merged_baseline_path, 'merged_baseline_summary');

    idx = [];
    for j = 1:numel(S.summary_struct)
        if ~isempty(S.summary_struct(j).BR_File) && S.summary_struct(j).BR_File == br_file
            idx = j; break;
        end
    end
    if isempty(idx)
        warning('BR_File %d not found in %s', br_file, session_name); continue;
    end

    cond_data = S.summary_struct(idx).merged_with_summary;
    base_data = B.merged_baseline_summary;

    % Map canonical side name to session-specific field name
    side_map = containers.Map({'ipsi', 'contra'}, {ipsi_label, contra_label});

    for s = sides
        canonical  = s{1};
        field_name = side_map(canonical);  % e.g. 'ipsi' -> 'ipsi' or 'active_like_stim_pos'

        if ~isfield(base_data, field_name)
            warning('No field %s in merged_baseline for %s (%s)', field_name, session_name, canonical); continue;
        end
        if ~isfield(cond_data, field_name)
            warning('No field %s in cond_data for %s BR%d (%s)', field_name, session_name, br_file, canonical); continue;
        end

        combined.(canonical).n_trials.condition = [combined.(canonical).n_trials.condition; sum(cond_data.(field_name).n_trials)];
        combined.(canonical).n_trials.baseline  = [combined.(canonical).n_trials.baseline;  sum(base_data.(field_name).n_trials)];
        
        for m = 1:numel(metrics)
            mf = metrics{m};

            if isfield(cond_data.(field_name), mf)
                vals = cond_data.(field_name).(mf);
                vals = vals(~isnan(vals));
                combined.(canonical).(mf).condition = [combined.(canonical).(mf).condition; vals];
            end

            if isfield(base_data.(field_name), mf)
                vals = base_data.(field_name).(mf);
                vals = vals(~isnan(vals));
                combined.(canonical).(mf).baseline = [combined.(canonical).(mf).baseline; vals];
            end
        end
    end
end
%% --- Plot bar graphs ---
n_metrics = numel(metrics);
sides = {'ipsi', 'contra'};

figure('Position', [100 100 1000 550]);
t = tiledlayout(2, n_metrics, 'TileSpacing', 'compact', 'Padding', 'compact');
t.OuterPosition = [0.02, 0.12, 0.96, 0.80];

for si = 1:2
    canonical = sides{si};
    for m = 1:n_metrics
        mf = metrics{m};
        base_vals = combined.(canonical).(mf).baseline;
        cond_vals = combined.(canonical).(mf).condition;

        means = [mean(base_vals), mean(cond_vals)];
        sems  = [std(base_vals)/sqrt(numel(base_vals)), std(cond_vals)/sqrt(numel(cond_vals))];

        [~, p] = ttest2(base_vals, cond_vals);
        if p < 0.001, sig = '***'; elseif p < 0.01, sig = '**'; elseif p < 0.05, sig = '*'; else, sig = 'n.s.'; end

        nexttile; hold on; box off; set(gca, 'TickDir', 'out', 'FontSize', 9);
        b = bar(1:2, means, 0.6, 'FaceColor', 'flat');
        b.CData = [0.6 0.6 0.6; 0 0.4 1];
        errorbar(1:2, means, sems, 'k', 'linestyle', 'none', 'LineWidth', 1.2);
        yline(0, '--k');

        yl = ylim;
        if strcmp(mf, 'all_err')
            bar_bottom = min(means - sems);
            y_sig = bar_bottom - 0.15 * range(yl);
            text(1.5, y_sig, sig, 'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold');
            ylim([y_sig - 0.08 * range(yl), yl(2)]);
        else
            bar_top = max(means + sems);
            y_sig = bar_top + 0.08 * range(yl);
            text(1.5, y_sig, sig, 'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold');
            ylim([yl(1), y_sig + 0.08 * range(yl)]);
        end

        xticks([1 2]); xticklabels({}); xlim([0.5 2.5]);
        ylabel(metric_units{m}, 'FontSize', 9);

        if m == ceil(n_metrics/2) && si == 1
            title('Ipsi', 'FontSize', 11, 'FontWeight', 'bold');
        elseif m == ceil(n_metrics/2) && si == 2
            title('Contra', 'FontSize', 11, 'FontWeight', 'bold');
        end

        if si == 2
            xlabel(strrep(mf, '_', ' '), 'FontSize', 10);
        end
    end
end

% Legend — ipsi and contra side by side
session_short = {'Bert 003', 'Nike 027', 'Nike 033'};
sides_leg = {'ipsi', 'contra'};
side_labels_leg = {'Ipsi', 'Contra'};
col_offsets = [0, 0.45];

for si = 1:2
    canonical = sides_leg{si};
    col_x = col_offsets(si);

    base_per = combined.(canonical).n_trials.baseline;
    cond_per = combined.(canonical).n_trials.condition;

    annotation('textbox', [0.08 + col_x, 0.068, 0.4, 0.02], ...
        'String', side_labels_leg{si}, ...
        'EdgeColor', 'none', 'FontSize', 9, 'FontWeight', 'bold', ...
        'VerticalAlignment', 'middle');

    annotation('rectangle', [0.08 + col_x, 0.044, 0.035, 0.020], ...
        'FaceColor', [0.6 0.6 0.6], 'EdgeColor', 'k', 'LineWidth', 0.5);
    base_str = sprintf('  Baseline: n=%d  (Bert 003: %d, Nike 027: %d, Nike 033: %d)', ...
        sum(base_per), base_per(1), base_per(2), base_per(3));
    annotation('textbox', [0.12 + col_x, 0.032, 0.40, 0.03], ...
        'String', base_str, 'EdgeColor', 'none', 'FontSize', 9, 'VerticalAlignment', 'middle');

    annotation('rectangle', [0.08 + col_x, 0.016, 0.035, 0.020], ...
        'FaceColor', [0 0.4 1], 'EdgeColor', 'k', 'LineWidth', 0.5);
    cond_str = sprintf('  Condition: n=%d  (Bert 003: %d, Nike 027: %d, Nike 033: %d)', ...
        sum(cond_per), cond_per(1), cond_per(2), cond_per(3));
    annotation('textbox', [0.12 + col_x, 0.004, 0.40, 0.03], ...
        'String', cond_str, 'EdgeColor', 'none', 'FontSize', 9, 'VerticalAlignment', 'middle');
end

sgtitle('Baseline vs Condition (Pooled Nike and Bert)', 'FontWeight', 'bold', 'FontSize', 12);

%% Save
save_name = 'pooled_baseline_vs_condition';
save_folder = fullfile(pwd, '..', 'pooled_figures');
subfolders = {'figFigs', 'svgFigs', 'pngFigs'};
for k = 1:numel(subfolders)
    if ~exist(fullfile(save_folder, subfolders{k}), 'dir')
        mkdir(fullfile(save_folder, subfolders{k}));
    end
end

savefig(gcf, fullfile(save_folder, 'figFigs', [save_name '.fig']));
set(gcf, 'Renderer', 'painters');
print(gcf, fullfile(save_folder, 'svgFigs', [save_name '.svg']), '-dsvg');
print(gcf, fullfile(save_folder, 'pngFigs', [save_name '.png']), '-dpng', '-r300');
fprintf('Saved to %s\n', save_folder);