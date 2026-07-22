%%
%Data storage to post: cd('\\cullenstor\data\Current Project Databases - NHP\2025 Cerebellum prosthesis\Pooled_Fastigial_data')

%Pooled analysis - comparing onset and offset timing
%Directory: cd('\\cullenstor\data\Current Project Databases - NHP\2025 Cerebellum prosthesis\Bryan\RCP_fastigial_analysis\Pooled_neural_data')

clear
close all

load('Bert_S003_fastig_neurons.mat')
load('Nike_S027_fastig_neurons.mat')
load('Nike_S030_fastig_neurons.mat')
%Onset
pool.passive.pref_onset = [
    results_Bert_RW003.passive.pref_peak_onset(:);
    results_Nike_RW027.passive.pref_peak_onset(:);
    results_Nike_RW030.passive.pref_peak_onset(:)];

pool.passive.nonpref_onset = [
    results_Bert_RW003.passive.nonpref_peak_onset(:);
    results_Nike_RW027.passive.nonpref_peak_onset(:);
    results_Nike_RW030.passive.nonpref_peak_onset(:)];

pool.active.pref_onset = [
    results_Bert_RW003.active.pref_peak_onset(:);
    results_Nike_RW027.active.pref_peak_onset(:);
    results_Nike_RW030.active.pref_peak_onset(:)];

pool.active.nonpref_onset = [
    results_Bert_RW003.active.nonpref_peak_onset(:);
    results_Nike_RW027.active.nonpref_peak_onset(:);
    results_Nike_RW030.active.nonpref_peak_onset(:)];
%Offset
pool.passive.pref_offset = [
    results_Bert_RW003.passive.pref_peak_offset(:);
    results_Nike_RW027.passive.pref_peak_offset(:);
    results_Nike_RW030.passive.pref_peak_offset(:)];

pool.passive.nonpref_offset = [
    results_Bert_RW003.passive.nonpref_peak_offset(:);
    results_Nike_RW027.passive.nonpref_peak_offset(:);
    results_Nike_RW030.passive.nonpref_peak_offset(:)];

pool.active.pref_offset = [
    results_Bert_RW003.active.pref_peak_offset(:);
    results_Nike_RW027.active.pref_peak_offset(:);
    results_Nike_RW030.active.pref_peak_offset(:)];

pool.active.nonpref_offset = [
    results_Bert_RW003.active.nonpref_peak_offset(:);
    results_Nike_RW027.active.nonpref_peak_offset(:);
    results_Nike_RW030.active.nonpref_peak_offset(:)];

%Histogram re onset
edges_onset = -200:50:1000;

figure('Color','w')

subplot(2,2,1)
histogram(1000*pool.passive.pref_onset,edges_onset)
title(sprintf('Passive Preferred (n=%d)', ...
    sum(~isnan(pool.passive.pref_onset))))
xlabel('Peak time from onset (ms)')
ylabel('Neurons')
xlim([-200 800])
ylim([0 12])
xline(0,'k--','LineWidth',1.5)

subplot(2,2,2)
histogram(1000*pool.passive.nonpref_onset,edges_onset)
title(sprintf('Passive Nonpreferred (n=%d)', ...
    sum(~isnan(pool.passive.nonpref_onset))))
xlabel('Peak time from onset (ms)')
ylabel('Neurons')
xlim([-200 800])
ylim([0 12])
xline(0,'k--','LineWidth',1.5)

subplot(2,2,3)
histogram(1000*pool.active.pref_onset,edges_onset)
title(sprintf('Active Preferred (n=%d)', ...
    sum(~isnan(pool.active.pref_onset))))
xlabel('Peak time from onset (ms)')
ylabel('Neurons')
xlim([-200 800])
ylim([0 12])
xline(0,'k--','LineWidth',1.5)

subplot(2,2,4)
histogram(1000*pool.active.nonpref_onset,edges_onset)
title(sprintf('Active Nonpreferred (n=%d)', ...
    sum(~isnan(pool.active.nonpref_onset))))
xlabel('Peak time from onset (ms)')
ylabel('Neurons')
xlim([-200 800])
ylim([0 12])
xline(0,'k--','LineWidth',1.5)

sgtitle('Pooled Fastigial Population: Peak Timing Relative to Onset')

%Histogram re offset
edges_offset = -1000:50:200;

figure('Color','w')

subplot(2,2,1)
histogram(1000*pool.passive.pref_offset,edges_offset)
title(sprintf('Passive Preferred (n=%d)', ...
    sum(~isnan(pool.passive.pref_offset))))
xlabel('Peak time from offset (ms)')
ylabel('Neurons')
xlim([-800 200])
ylim([0 12])
xline(0,'k--','LineWidth',1.5)

subplot(2,2,2)
histogram(1000*pool.passive.nonpref_offset,edges_offset)
title(sprintf('Passive Nonpreferred (n=%d)', ...
    sum(~isnan(pool.passive.nonpref_offset))))
xlabel('Peak time from offset (ms)')
ylabel('Neurons')
xlim([-800 200])
ylim([0 12])
xline(0,'k--','LineWidth',1.5)

subplot(2,2,3)
histogram(1000*pool.active.pref_offset,edges_offset)
title(sprintf('Active Preferred (n=%d)', ...
    sum(~isnan(pool.active.pref_offset))))
xlabel('Peak time from offset (ms)')
ylabel('Neurons')
xlim([-800 200])
ylim([0 12])
xline(0,'k--','LineWidth',1.5)

subplot(2,2,4)
histogram(1000*pool.active.nonpref_offset,edges_offset)
title(sprintf('Active Nonpreferred (n=%d)', ...
    sum(~isnan(pool.active.nonpref_offset))))
xlabel('Peak time from offset (ms)')
ylabel('Neurons')
xlim([-800 200])
ylim([0 12])
xline(0,'k--','LineWidth',1.5)

sgtitle('Pooled Fastigial Population: Peak Timing Relative to Offset')

%%
%Statistics
%1) clustering test: chi2 goodness of fit relative to uniform distribution 
%not sure this makes sense as uniform is a flat horizontal line
% PASSIVE PREFERRED ONSET
%repeat for: 
% pool.passive.nonpref_onset
% pool.active.pref_onset
% pool.active.nonpref_onset
% 
% pool.passive.pref_offset
% pool.passive.nonpref_offset
% pool.active.pref_offset
% pool.active.nonpref_offset

x = 1000 * pool.passive.pref_onset;
x = x(~isnan(x));

edges = -200:50:800;

obs = histcounts(x,edges);

expected = repmat(mean(obs),size(obs));

chi2 = sum((obs-expected).^2 ./ expected);

df = numel(obs)-1;

p = 1 - chi2cdf(chi2,df);

fprintf('\nPassive Preferred Onset\n')
fprintf('Chi2 = %.2f, df = %d, p = %.4f\n',chi2,df,p)

clustering_test( ...
    1000*pool.passive.pref_onset, ...
    -200:50:800, ...
    'Passive Preferred Onset')

%%
%Compare locking to the onset vs the offset
%Smaller value means more closely locked to that time point (onset or offset)

%Passive preferred
paired_ttest( ...
    abs(1000*pool.passive.pref_onset), ...
    abs(1000*pool.passive.pref_offset), ...
    'Onset','Offset', ...
    'Passive Preferred')

%passive nonpref
paired_ttest( ...
    abs(1000*pool.passive.nonpref_onset), ...
    abs(1000*pool.passive.nonpref_offset), ...
    'Onset','Offset', ...
    'Passive NonPreferred')

%Active pref
paired_ttest( ...
    abs(1000*pool.active.pref_onset), ...
    abs(1000*pool.active.pref_offset), ...
    'Onset','Offset', ...
    'Active Preferred')

%Active nonpref
paired_ttest( ...
    abs(1000*pool.active.nonpref_onset), ...
    abs(1000*pool.active.non    `pref_offset), ...
    'Onset','Offset', ...
    'Passive Preferred')

%%
%Compare timing of peak response between active and passive conditions

%Preferred onset
passive = 1000*pool.passive.pref_onset;
active = 1000*pool.active.pref_onset;

valid = ~isnan(passive) & ~isnan(active);

[p,h,stats] = signrank( ...
    passive(valid), ...
    active(valid));

fprintf('\nPreferred Onset Timing\n')
fprintf('Passive median = %.1f ms\n',median(passive(valid)))
fprintf('Active median = %.1f ms\n',median(active(valid)))
fprintf('p = %.4f\n',p)

%nonpreferred onset
passive = 1000*pool.passive.nonpref_onset;
active = 1000*pool.active.nonpref_onset;

valid = ~isnan(passive) & ~isnan(active);

[p,h,stats] = signrank( ...
    passive(valid), ...
    active(valid));

fprintf('\nNonpreferred Onset Timing\n')
fprintf('p = %.4f\n',p)

%preferred offset
passive = 1000*pool.passive.pref_offset;
active = 1000*pool.active.pref_offset;

valid = ~isnan(passive) & ~isnan(active);

[p,h,stats] = signrank( ...
    passive(valid), ...
    active(valid));

fprintf('\nPreferred Offset Timing\n')
fprintf('p = %.4f\n',p)

%nonpreferred offset
passive = 1000*pool.passive.nonpref_offset;
active = 1000*pool.active.nonpref_offset;

valid = ~isnan(passive) & ~isnan(active);

[p,h,stats] = signrank( ...
    passive(valid), ...
    active(valid));

fprintf('\nNonpreferred Offset Timing\n')
fprintf('p = %.4f\n',p)


pref_data = [ ...
    abs(1000*pool.passive.pref_onset(:)), ...
    abs(1000*pool.passive.pref_offset(:)), ...
    abs(1000*pool.active.pref_onset(:)), ...
    abs(1000*pool.active.pref_offset(:)) ];

figure('Color','w')
hold on

means = mean(pref_data,'omitnan');
sems  = std(pref_data,'omitnan') ./ ...
    sqrt(sum(~isnan(pref_data)));

bar(1:4,means,'FaceColor',[0.8 0.8 0.8])

errorbar(1:4,means,sems,...
    'k','LineStyle','none','LineWidth',1.5)

nNeurons = size(pref_data,1);

for n = 1:nNeurons

    row = pref_data(n,:);

%     plot(1:4,row,'-','Color',[0.7 0.7 0.7])

   xj = (1:4) + 0.03*randn(1,4);

scatter(xj,row,40,...
    'filled',...
    'MarkerFaceColor','k',...
    'MarkerFaceAlpha',0.6)
end

set(gca,...
    'XTick',1:4,...
    'XTickLabel',{'Pass On','Pass Off',...
                  'Act On','Act Off'})

ylabel('|Peak time| (ms)')
title('Preferred Direction')
box off

%nonprefer
nonpref_data = [ ...
    abs(1000*pool.passive.nonpref_onset(:)), ...
    abs(1000*pool.passive.nonpref_offset(:)), ...
    abs(1000*pool.active.nonpref_onset(:)), ...
    abs(1000*pool.active.nonpref_offset(:)) ];

figure('Color','w')
hold on

means = mean(nonpref_data,'omitnan');
sems  = std(nonpref_data,'omitnan') ./ ...
    sqrt(sum(~isnan(nonpref_data)));

bar(1:4,means,'FaceColor',[0.8 0.8 0.8])

errorbar(1:4,means,sems,...
    'k','LineStyle','none','LineWidth',1.5)

nNeurons = size(nonpref_data,1);

for n = 1:nNeurons

    row = nonpref_data(n,:);

%     plot(1:4,row,'-','Color',[0.7 0.7 0.7])
xj = (1:4) + 0.03*randn(1,4);

scatter(xj,row,40,...
    'filled',...
    'MarkerFaceColor','k',...
    'MarkerFaceAlpha',0.6)
end

set(gca,...
    'XTick',1:4,...
    'XTickLabel',{'Pass On','Pass Off',...
                  'Act On','Act Off'})

ylabel('|Peak time| (ms)')
title('Non preferred Direction')
box off

%RM ANOVA

T = array2table(pref_data,...
    'VariableNames',{'PassOn','PassOff','ActOn','ActOff'});

Within = table( ...
    categorical({'Passive';'Passive';'Active';'Active'}), ...
    categorical({'Onset';'Offset';'Onset';'Offset'}), ...
    'VariableNames',{'Condition','Event'});

rm = fitrm(T,...
    'PassOn-ActOff ~ 1',...
    'WithinDesign',Within);

ranovatbl = ranova(rm,...
    'WithinModel','Condition*Event');

ranovatbl(:,{'SumSq','DF','F','pValue'})
%%
function clustering_test(peak_times_ms, edges, plot_title)

peak_times_ms = peak_times_ms(~isnan(peak_times_ms));

obs = histcounts(peak_times_ms, edges);

expected = repmat(mean(obs), size(obs));

chi2 = sum((obs - expected).^2 ./ expected);
df = numel(obs)-1;
p = 1 - chi2cdf(chi2, df);

figure('Color','w')

histogram(peak_times_ms, edges, ...
    'FaceColor',[0.6 0.6 0.6], ...
    'EdgeColor','k')

hold on

bin_centers = edges(1:end-1) + diff(edges)/2;

plot(bin_centers, expected, ...
    'r--', ...
    'LineWidth',2)

xlabel('Peak timing (ms)')
ylabel('Neuron count')

title(sprintf('%s\n\\chi^2 = %.2f, p = %.4f', ...
    plot_title, chi2, p))

legend({'Observed','Uniform expectation'})
box off

end

function paired_ttest(x,y,label1,label2,titleText)

valid = ~isnan(x) & ~isnan(y);

x = x(valid);
y = y(valid);

[~,p,~,stats] = ttest(x,y);

fprintf('\n%s\n',titleText)

fprintf('%s = %.1f ± %.1f (n=%d)\n', ...
    label1, mean(x), std(x), numel(x))

fprintf('%s = %.1f ± %.1f (n=%d)\n', ...
    label2, mean(y), std(y), numel(y))

fprintf('Paired t-test: t(%d)=%.2f, p=%.4f\n', ...
    stats.df, stats.tstat, p)
end