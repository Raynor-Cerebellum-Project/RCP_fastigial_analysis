clear
close all

%POOL across monkeys and sessions:
%data located: cd('\\cullenstor\data\Current Project Databases - NHP\2025 Cerebellum prosthesis\Bryan\RCP_fastigial_analysis\Pooled_neural_data')

load Bert_S003_sensit_fastig_neurons.mat
R1 = results_Bert_003;

load Nike_S027_sensit_fastig_neurons.mat
R2 = results_Nike_027;

load Nike_S030_sensit_fastig_neurons.mat
R3 = results_Nike_030;

results = [R1(:); R2(:); R3(:)];

fprintf('Total neurons = %d\n',length(results))

%% EXTRACT variables

N = length(results);

pass_pref_sens = nan(N,1);
pass_pref_phase = nan(N,1);

pass_nonpref_sens = nan(N,1);
pass_nonpref_phase = nan(N,1);

act_pref_sens = nan(N,1);
act_pref_phase = nan(N,1);

act_nonpref_sens = nan(N,1);
act_nonpref_phase = nan(N,1);

for i = 1:N

    pass_pref_sens(i)  = results(i).passive.pref.sensitivity;
    pass_pref_phase(i) = results(i).passive.pref.phase;

    pass_nonpref_sens(i)  = results(i).passive.nonpref.sensitivity;
    pass_nonpref_phase(i) = results(i).passive.nonpref.phase;

    act_pref_sens(i)  = results(i).active.pref.sensitivity;
    act_pref_phase(i) = results(i).active.pref.phase;

    act_nonpref_sens(i)  = results(i).active.nonpref.sensitivity;
    act_nonpref_phase(i) = results(i).active.nonpref.phase;

end

%% ============================================================
% Define preferred coordinate system from passive responses
%% ============================================================

for i = 1:N

    %% Preferred direction

    if pass_pref_sens(i) < 0

        % Passive
        pass_pref_sens(i) = -pass_pref_sens(i);
        pass_pref_phase(i) = wrap180(pass_pref_phase(i) + 180);

        % Apply same transform to active
        act_pref_sens(i) = -act_pref_sens(i);
        act_pref_phase(i) = wrap180(act_pref_phase(i) + 180);

    end

    %% Nonpreferred direction

    if pass_nonpref_sens(i) < 0

        % Passive
        pass_nonpref_sens(i) = -pass_nonpref_sens(i);
        pass_nonpref_phase(i) = wrap180(pass_nonpref_phase(i) + 180);

        % Apply same transform to active
        act_nonpref_sens(i) = -act_nonpref_sens(i);
        act_nonpref_phase(i) = wrap180(act_nonpref_phase(i) + 180);

    end

end

%% Sensitivity histogram
figure('Color','w')

subplot(2,2,1)
histogram(pass_pref_sens)
xlabel('Sensitivity')
ylabel('Neurons')
title('Passive Preferred')

subplot(2,2,2)
histogram(pass_nonpref_sens)
xlabel('Sensitivity')
title('Passive Nonpreferred')

subplot(2,2,3)
histogram(act_pref_sens)
xlabel('Sensitivity')
title('Active Preferred')

subplot(2,2,4)
histogram(act_nonpref_sens)
xlabel('Sensitivity')
title('Active Nonpreferred')

%% Polar plots

figure('Color','w')

subplot(2,2,1)
polarplot(deg2rad(pass_pref_phase),pass_pref_sens,'ko')
title('Passive Preferred')

subplot(2,2,2)
polarplot(deg2rad(pass_nonpref_phase),pass_nonpref_sens,'ko')
title('Passive Nonpreferred')

subplot(2,2,3)
polarplot(deg2rad(act_pref_phase),act_pref_sens,'ko')
title('Active Preferred')

subplot(2,2,4)
polarplot(deg2rad(act_nonpref_phase),act_nonpref_sens,'ko')
title('Active Nonpreferred')

%% Passive vs active

figure('Color','w')
hold on

x = [pass_pref_sens act_pref_sens];

for i = 1:N
    plot([1 2],x(i,:),'Color',[0.8 0.8 0.8])
end

scatter(ones(N,1),pass_pref_sens,40,'filled')
scatter(2*ones(N,1),act_pref_sens,40,'filled')

errorbar(1,...
    mean(pass_pref_sens,'omitnan'),...
    std(pass_pref_sens,'omitnan')/sqrt(sum(~isnan(pass_pref_sens))),...
    'k','LineWidth',2)

errorbar(2,...
    mean(act_pref_sens,'omitnan'),...
    std(act_pref_sens,'omitnan')/sqrt(sum(~isnan(act_pref_sens))),...
    'k','LineWidth',2)

set(gca,'XTick',[1 2],...
    'XTickLabel',{'Passive','Active'})

ylabel('Sensitivity')

[p,~,stats] = signrank(pass_pref_sens,act_pref_sens);

title(sprintf('Preferred Direction (p = %.4f)',p))

%% ============================================================
% Preferred Direction
%% ============================================================

figure('Color','w')
hold on

means = [mean(pass_pref_sens,'omitnan') ...
         mean(act_pref_sens,'omitnan')];

sems = [std(pass_pref_sens,'omitnan')/sqrt(sum(~isnan(pass_pref_sens))) ...
        std(act_pref_sens,'omitnan')/sqrt(sum(~isnan(act_pref_sens)))];

bar(1:2,means,...
    'FaceColor',[0.8 0.8 0.8],...
    'EdgeColor','k')

errorbar(1:2,means,sems,...
    'k',...
    'LineStyle','none',...
    'LineWidth',1.5)

% jittered dots
jitter = 0.08;

scatter(1 + jitter*randn(N,1),...
    pass_pref_sens,...
    35,...
    'filled',...
    'MarkerFaceColor','k',...
    'MarkerFaceAlpha',0.6)

scatter(2 + jitter*randn(N,1),...
    act_pref_sens,...
    35,...
    'filled',...
    'MarkerFaceColor','k',...
    'MarkerFaceAlpha',0.6)

set(gca,...
    'XTick',[1 2],...
    'XTickLabel',{'Passive','Active'})

ylabel('Sensitivity')

box off

%% Label neuron IDs on Active Preferred points
jitterAct = 0.08*randn(N,1);
for i = 1:N

    text(2 + jitterAct(i), ...
         act_pref_sens(i), ...
         sprintf('%d',results(i).id), ...
         'FontSize',8,...
         'HorizontalAlignment','left',...
         'VerticalAlignment','middle');

end

%% paired t-test

valid = ~isnan(pass_pref_sens) & ~isnan(act_pref_sens);

[~,p,~,stats] = ttest( ...
    pass_pref_sens(valid), ...
    act_pref_sens(valid));

fprintf('\nPreferred direction\n')
fprintf('Passive: %.2f ± %.2f\n', ...
    mean(pass_pref_sens(valid)), ...
    std(pass_pref_sens(valid))/sqrt(sum(valid)));

fprintf('Active : %.2f ± %.2f\n', ...
    mean(act_pref_sens(valid)), ...
    std(act_pref_sens(valid))/sqrt(sum(valid)));

fprintf('t(%d)=%.2f   p=%.4f\n', ...
    stats.df,stats.tstat,p);

title(sprintf('Preferred Direction (paired t-test, p = %.4f)',p))

%% ============================================================
% Nonpreferred Direction
%% ============================================================

figure('Color','w')
hold on

means = [mean(pass_nonpref_sens,'omitnan') ...
         mean(act_nonpref_sens,'omitnan')];

sems = [std(pass_nonpref_sens,'omitnan')/sqrt(sum(~isnan(pass_nonpref_sens))) ...
        std(act_nonpref_sens,'omitnan')/sqrt(sum(~isnan(act_nonpref_sens)))];

bar(1:2,means,...
    'FaceColor',[0.8 0.8 0.8],...
    'EdgeColor','k')

errorbar(1:2,means,sems,...
    'k',...
    'LineStyle','none',...
    'LineWidth',1.5)

jitter = 0.08;

scatter(1 + jitter*randn(N,1),...
    pass_nonpref_sens,...
    35,...
    'filled',...
    'MarkerFaceColor','k',...
    'MarkerFaceAlpha',0.6)

scatter(2 + jitter*randn(N,1),...
    act_nonpref_sens,...
    35,...
    'filled',...
    'MarkerFaceColor','k',...
    'MarkerFaceAlpha',0.6)

set(gca,...
    'XTick',[1 2],...
    'XTickLabel',{'Passive','Active'})

ylabel('Sensitivity')

box off

%% paired t-test

valid = ~isnan(pass_nonpref_sens) & ~isnan(act_nonpref_sens);

[~,p,~,stats] = ttest( ...
    pass_nonpref_sens(valid), ...
    act_nonpref_sens(valid));

fprintf('\nNonpreferred direction\n')
fprintf('Passive: %.2f ± %.2f\n', ...
    mean(pass_nonpref_sens(valid)), ...
    std(pass_nonpref_sens(valid))/sqrt(sum(valid)));

fprintf('Active : %.2f ± %.2f\n', ...
    mean(act_nonpref_sens(valid)), ...
    std(act_nonpref_sens(valid))/sqrt(sum(valid)));

fprintf('t(%d)=%.2f   p=%.4f\n', ...
    stats.df,stats.tstat,p);

title(sprintf('Nonpreferred Direction (paired t-test, p = %.4f)',p))

%% polar plots

pass_nonpref_phase_plot = wrapTo180(pass_nonpref_phase + 180);
act_nonpref_phase_plot  = wrapTo180(act_nonpref_phase + 180);

figure;
pax = polaraxes;
hold(pax,'on')

maxSens = max(abs(pass_pref_sens));

rlim([0 maxSens])

%% Mean preferred vector

x = pass_pref_sens .* cosd(pass_pref_phase);
y = pass_pref_sens .* sind(pass_pref_phase);

meanPrefX = mean(x,'omitnan');
meanPrefY = mean(y,'omitnan');

meanPrefPhase = atan2d(meanPrefY,meanPrefX);
meanPrefSens  = hypot(meanPrefX,meanPrefY);

%% Mean nonpreferred vector

x = pass_nonpref_sens .* cosd(pass_nonpref_phase_plot);
y = pass_nonpref_sens .* sind(pass_nonpref_phase_plot);

meanNonprefX = mean(x,'omitnan');
meanNonprefY = mean(y,'omitnan');

meanNonprefPhase = atan2d(meanNonprefY,meanNonprefX);
meanNonprefSens  = hypot(meanNonprefX,meanNonprefY);

for i = 1:N

    polarplot(pax,...
        deg2rad([pass_pref_phase(i) pass_pref_phase(i)]),...
        [0 pass_pref_sens(i)],...
        'b','LineWidth',1.5)

    polarplot(pax,...
        deg2rad([pass_nonpref_phase_plot(i) pass_nonpref_phase_plot(i)]),...
        [0 pass_nonpref_sens(i)],...
        'r','LineWidth',1.5)

end
%% Mean vectors

polarplot(pax,...
    deg2rad([meanPrefPhase meanPrefPhase]),...
    [0 meanPrefSens],...
    'k','LineWidth',5)

polarplot(pax,...
    deg2rad(meanPrefPhase),...
    meanPrefSens,...
    'ko',...
    'MarkerFaceColor','k',...
    'MarkerSize',9)

polarplot(pax,...
    deg2rad([meanNonprefPhase meanNonprefPhase]),...
    [0 meanNonprefSens],...
    'k','LineWidth',5)

polarplot(pax,...
    deg2rad(meanNonprefPhase),...
    meanNonprefSens,...
    'ko',...
    'MarkerFaceColor','k',...
    'MarkerSize',9)

figure;
pax = polaraxes;
hold(pax,'on')

maxSens = max(abs(act_pref_sens));

rlim([0 maxSens])

%% Mean preferred vector

x = act_pref_sens .* cosd(act_pref_phase);
y = act_pref_sens .* sind(act_pref_phase);

meanPrefX = mean(x,'omitnan');
meanPrefY = mean(y,'omitnan');

meanPrefPhase = atan2d(meanPrefY,meanPrefX);
meanPrefSens  = hypot(meanPrefX,meanPrefY);

%% Mean nonpreferred vector

x = act_nonpref_sens .* cosd(act_nonpref_phase_plot);
y = act_nonpref_sens .* sind(act_nonpref_phase_plot);

meanNonprefX = mean(x,'omitnan');
meanNonprefY = mean(y,'omitnan');

meanNonprefPhase = atan2d(meanNonprefY,meanNonprefX);
meanNonprefSens  = hypot(meanNonprefX,meanNonprefY);

for i = 1:N

    polarplot(pax,...
        deg2rad([act_pref_phase(i) act_pref_phase(i)]),...
        [0 act_pref_sens(i)],...
        'b','LineWidth',1.5)

    polarplot(pax,...
        deg2rad([act_nonpref_phase_plot(i) act_nonpref_phase_plot(i)]),...
        [0 act_nonpref_sens(i)],...
        'r','LineWidth',1.5)

end

%% Mean vectors

polarplot(pax,...
    deg2rad([meanPrefPhase meanPrefPhase]),...
    [0 meanPrefSens],...
    'k','LineWidth',5)

polarplot(pax,...
    deg2rad(meanPrefPhase),...
    meanPrefSens,...
    'ko',...
    'MarkerFaceColor','k',...
    'MarkerSize',9)

polarplot(pax,...
    deg2rad([meanNonprefPhase meanNonprefPhase]),...
    [0 meanNonprefSens],...
    'k','LineWidth',5)

polarplot(pax,...
    deg2rad(meanNonprefPhase),...
    meanNonprefSens,...
    'ko',...
    'MarkerFaceColor','k',...
    'MarkerSize',9)

%% Phase scatterplot
figure
hold on

plot([-180 360],[-180 360],'k--')%nonpref
plot([-180 360],[-180 360],'k--')%nonpref

% scatter(pass_nonpref_phase +180,... %nonpref add 180
%         act_nonpref_phase +180,...
%         70,...
%         'filled')
scatter(pass_pref_phase,... %nonpref add 180
        act_pref_phase,...
        70,...
        'filled')

xlabel('Passive phase')
ylabel('Active phase')

axis equal
xlim([-180 180])
ylim([-180 180])
% xlim([0 360])%nonpref
% ylim([0 360])%nonpref
% ticks = 0:45:360; %nonpref
ticks = -180:45:180; %nonpref

xticks(ticks)
yticks(ticks)

box off

%% stats on phase
% addpath('\\cullenstor\data\Current-Members\Robyn\rFN & Cerebellum\Nodulus_Uvula\Code\Circ_Stat')

%Releigh's test (normal distribution)
[Rel_p_pass,Rel_z_pass] = circ_rtest(deg2rad(pass_nonpref_phase));
[Rel_p_act,Rel_z_act] = circ_rtest(deg2rad(act_nonpref_phase));

%Mean vector length
VL_pass = circ_r(deg2rad(pass_nonpref_phase));
VL_act = circ_r(deg2rad(act_nonpref_phase));

%Circular standard deviation
circ_std_pass = circ_std(deg2rad(pass_nonpref_phase));
circ_std_act = circ_std(deg2rad(act_nonpref_phase));

%V-test: are phases clustered around a particular angle? 0deg
[vtest_p_pass,vtest_v_pass] = circ_vtest(...
    deg2rad(pass_nonpref_phase),...
    deg2rad(0));

[vtest_p_act,vtest_v_act] = circ_vtest(...
    deg2rad(act_nonpref_phase),...
    deg2rad(0));
%% Helper function
function phase = wrap180(phase)

phase = mod(phase + 180,360) - 180;

end