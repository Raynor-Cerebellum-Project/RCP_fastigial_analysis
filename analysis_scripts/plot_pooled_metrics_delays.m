% Combines random-delay conditions across sessions, split by delay

clear all; close all; clc;
addpath(genpath(fullfile('..', 'functions')));

%% --- Define which conditions to combine ---
% {session, br_file, ipsi_label, contra_label}
condition_list = {
    'Bert/BL_RW_003_Session_1',       7,  'active_like_stim_pos', 'active_like_stim_neg';
    'Nike/20260326_NRR_RW027_fastig', 9,  'ipsi',                 'contra';
    'Nike/20260423_NRR_RW033_fastig',  4,  'ipsi',                 'contra';
};

%% --- Metrics and units ---
metrics      = {'all_err',  'all_var', 'max_speed', 'avg_speed', 'var_500ms', 'oscillations', 'fft_power'};
metric_units = {'deg',      'deg',     'deg/s',     'deg/s',     'deg/s',     'count',        'power'};

delays = {nan, 0, 100, 200};

%% --- Initialize combined struct ---
sides = {'ipsi', 'contra'};
combined = struct();

for s = sides
    for d = 1:numel(delays)
        delay_val = delays{d};
        if isnan(delay_val)
            delay_key = sprintf('%s_baseline', s{1});
        else
            delay_key = sprintf('%s_%d', s{1}, delay_val);
        end
        for m = 1:numel(metrics)
            combined.(delay_key).(metrics{m}) = [];
        end
        combined.(delay_key).n_trials = [];
    end
end

%% --- Load and concatenate ---
for k = 1:size(condition_list, 1)
    session      = condition_list{k, 1};
    br_file      = condition_list{k, 2};
    ipsi_label   = condition_list{k, 3};
    contra_label = condition_list{k, 4};

    [~, session_name] = fileparts(session);
    [~, ~, base_folder] = set_paths_cullen_lab(session);
    summary_path         = fullfile(base_folder, 'Checkpoints', [session_name '_summarized_metrics.mat']);

    S = load(summary_path, 'summary_struct');

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

    plain_map = containers.Map({'ipsi','contra'}, {ipsi_label, contra_label});

    for s = sides
        canonical  = s{1};
        plain_name = plain_map(canonical);
        nan_name   = [plain_name '_nan'];

        for d = 1:numel(delays)
            delay_val = delays{d};
            if isnan(delay_val)
                delay_key  = sprintf('%s_baseline', canonical);
                field_name = nan_name;
            else
                delay_key  = sprintf('%s_%d', canonical, delay_val);
                field_name = sprintf('%s_%d', plain_name, delay_val);
            end

            if ~isfield(cond_data, field_name)
                warning('No field %s in cond_data for %s BR%d', field_name, session_name, br_file); continue;
            end

            combined.(delay_key).n_trials = [combined.(delay_key).n_trials; sum(cond_data.(field_name).n_trials)];

            for m = 1:numel(metrics)
                mf = metrics{m};
                if isfield(cond_data.(field_name), mf)
                    v = cond_data.(field_name).(mf);
                    combined.(delay_key).(mf) = [combined.(delay_key).(mf); v(~isnan(v))];
                end
            end
        end
    end
end

%% --- Plot bar graphs ---
n_metrics = numel(metrics);
delay_labels = {'Baseline', '0 ms', '100 ms', '200 ms'};
delay_keys_ipsi   = {'ipsi_baseline',   'ipsi_0',   'ipsi_100',   'ipsi_200'};
delay_keys_contra = {'contra_baseline', 'contra_0', 'contra_100', 'contra_200'};
delay_keys_all    = {delay_keys_ipsi; delay_keys_contra};

trace_colors = [
    0.3 0.3 0.3;
    0.0 0.45 0.7;
    0.8 0.4 0.0;
    0.2 0.7 0.3
];

n_delays = numel(delays);

figure('Position', [100 100 1300 600]);
t = tiledlayout(2, n_metrics, 'TileSpacing', 'compact', 'Padding', 'compact');
t.OuterPosition = [0.02, 0.10, 0.96, 0.82];

for si = 1:2
    canonical = sides{si};
    delay_keys = delay_keys_all{si};

    for m = 1:n_metrics
        mf = metrics{m};

        means = nan(1, n_delays);
        sems  = nan(1, n_delays);
        all_vals = cell(1, n_delays);

        for d = 1:n_delays
            dk = delay_keys{d};
            vals = combined.(dk).(mf);
            all_vals{d} = vals;
            means(d) = mean(vals);
            sems(d)  = std(vals) / sqrt(numel(vals));
        end

        nexttile; hold on; box off; set(gca, 'TickDir', 'out', 'FontSize', 9);
        for d = 1:n_delays
            bar(d, means(d), 0.6, 'FaceColor', trace_colors(d,:));
        end
        errorbar(1:n_delays, means, sems, 'k', 'linestyle', 'none', 'LineWidth', 1.2);
        yline(0, '--k');

        % Significance vs baseline
        yl = ylim;
        for d = 2:n_delays
            [~, p] = ttest2(all_vals{1}, all_vals{d});
            if p < 0.001, sig = '***'; elseif p < 0.01, sig = '**'; elseif p < 0.05, sig = '*'; else, sig = 'n.s.'; end

            if strcmp(mf, 'all_err')
                bar_bottom = min(means(d) - sems(d), means(1) - sems(1));
                y_sig = bar_bottom - 0.15 * range(yl);
                text(d, y_sig, sig, 'HorizontalAlignment', 'center', 'FontSize', 9, 'FontWeight', 'bold');
            else
                bar_top = means(d) + sems(d);
                y_sig = bar_top + 0.08 * range(yl);
                text(d, y_sig, sig, 'HorizontalAlignment', 'center', 'FontSize', 9, 'FontWeight', 'bold');
            end
        end

        yl = ylim;
        if strcmp(mf, 'all_err')
            ylim([yl(1) - 0.1 * range(yl), yl(2) + 0.1 * range(yl)]);
        else
            ylim([yl(1), yl(2) + 0.1 * range(yl)]);
        end
        
        xticks(1:n_delays); xticklabels({}); xlim([0.5 n_delays+0.5]);
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
% Per-session n counts — both ipsi and contra
session_short = {'Bert 003', 'Nike 027', 'Nike 033'};
side_labels_short = {'Ipsi', 'Contra'};
delay_keys_sides = {delay_keys_ipsi, delay_keys_contra};

swatch_x = 0.05;
swatch_w = 0.03;
swatch_h = 0.018;
text_x   = 0.09;
text_w   = 0.88;
y_start  = 0.085;
y_step   = 0.024;
max_label_len = max(cellfun(@numel, delay_labels)) + 6;

% Two columns: ipsi on left, contra on right
col_offsets = [0, 0.45];  % x offset for ipsi vs contra columns

for si = 1:2
    delay_keys_side = delay_keys_sides{si};
    col_x = col_offsets(si);

    % Side header
    annotation('textbox', [swatch_x + col_x, y_start + 0.025, 0.4, 0.02], ...
        'String', side_labels_short{si}, ...
        'EdgeColor', 'none', 'FontSize', 9, 'FontWeight', 'bold', ...
        'VerticalAlignment', 'middle');

    for d = 1:n_delays
        dk = delay_keys_side{d};
        n_k = combined.(dk).n_trials;
        raw_label = [delay_labels{d} ':'];
        label_part = [raw_label, repmat(' ', 1, max_label_len - numel(raw_label) + 4)];
        counts_part = '';
        for k = 1:size(condition_list, 1)
            if k <= numel(n_k)
                entry = sprintf('%s: %d', session_short{k}, n_k(k));
                counts_part = [counts_part, entry, repmat(' ', 1, 24 - numel(entry))];
            end
        end
        n_line = [label_part, counts_part];

        y_pos = y_start - (d-1) * y_step;
        annotation('rectangle', [swatch_x + col_x, y_pos, swatch_w, swatch_h], ...
            'FaceColor', trace_colors(d,:), 'EdgeColor', 'k', 'LineWidth', 0.5);
        annotation('textbox', [text_x + col_x, y_pos - 0.003, 0.40, swatch_h + 0.01], ...
            'String', n_line, ...
            'EdgeColor', 'none', 'FontSize', 9, 'VerticalAlignment', 'middle');
    end
end

t.OuterPosition = [0.02, 0.10 + (n_delays * y_step) + 0.03, 0.96, 0.82 - (n_delays * y_step) - 0.01];
sgtitle('Delay Comparison (Pooled Nike and Bert)', 'FontWeight', 'bold', 'FontSize', 12);
%% Save
save_folder = fullfile(pwd, '..', 'pooled_figures');
subfolders = {'figFigs', 'svgFigs', 'pngFigs'};
for k = 1:numel(subfolders)
    if ~exist(fullfile(save_folder, subfolders{k}), 'dir')
        mkdir(fullfile(save_folder, subfolders{k}));
    end
end

save_name = 'pooled_delay_comparison';
savefig(gcf, fullfile(save_folder, 'figFigs', [save_name '.fig']));
set(gcf, 'Renderer', 'painters');
print(gcf, fullfile(save_folder, 'svgFigs', [save_name '.svg']), '-dsvg');
print(gcf, fullfile(save_folder, 'pngFigs', [save_name '.png']), '-dpng', '-r300');
fprintf('Saved to %s\n', save_folder);