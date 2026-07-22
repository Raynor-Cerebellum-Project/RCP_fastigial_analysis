%Pooled data:
% cd('\\cullenstor\data\Current Project Databases - NHP\2025 Cerebellum prosthesis\Pooled_Fastigial_data')


%Bert's data
%cd('\\cullenstor\data\Current Project Databases - NHP\2025 Cerebellum prosthesis\Bert\BL_RW_003_Session_1\Calibrated\IntanFile_5')

preSamp = 500;
postSamp = 1000;

%Bert's stim file
path = ('\\cullenstor\data\Current Project Databases - NHP\2025 Cerebellum prosthesis\Bert\BL_RW_003_Session_1\Calibrated\IntanFile_5');
load([path '\BL_closed_loop_STIM_003_008_Cal_stim.mat'])
stim_Data = Data;

%Nike's stim file
% path = ('\\cullenstor\data\Current Project Databases - NHP\2025 Cerebellum prosthesis\Nike\20260326_NRR_RW027_fastig\Calibrated\IntanFile_13');
% load([path '\NRR_RW027_013_Cal.mat']) %session 027
% path = ('\\cullenstor\data\Current Project Databases - NHP\2025 Cerebellum prosthesis\Nike\20260423_NRR_RW033_fastig\Calibrated\IntanFile_3');
% load([path '\NRR_RW033_003_Cal.mat']) %session 033
% stim_Data = Data;
% stim_Data.headYawVel = Data.yaw_vel;
% stim_Data.headYawPos = Data.head_pos;
% stim_Data.segments.active_like_stim_pos = Data.segments.contra;
% stim_Data.segments.active_like_stim_neg = Data.segments.ipsi;
% stim_Data.Neural(:,1) = Data.Neural(:,3);

stimMoveTrials = extractStimMovement(stim_Data,preSamp,postSamp);

%% Split stimulated trials by movement direction

stimMoveTrials.vel_pos = stimMoveTrials.vel(stimMoveTrials.direction==1,:);
stimMoveTrials.vel_neg = stimMoveTrials.vel(stimMoveTrials.direction==-1,:);

stimMoveTrials.pos_pos = stimMoveTrials.pos(stimMoveTrials.direction==1,:);
stimMoveTrials.pos_neg = stimMoveTrials.pos(stimMoveTrials.direction==-1,:);

%Bert's control data
path = ('\\cullenstor\data\Current Project Databases - NHP\2025 Cerebellum prosthesis\Bert\BL_RW_003_Session_1\Calibrated\IntanFile_1');
load('BL_closed_loop_STIM_003_004_Cal.mat')
control_Data = Data;

%Nike's control data
% path = ('\\cullenstor\data\Current Project Databases - NHP\2025 Cerebellum prosthesis\Nike\20260326_NRR_RW027_fastig\Calibrated\IntanFile_14');
% load([path '\NRR_RW027_014_Cal.mat'])
% path = ('\\cullenstor\data\Current Project Databases - NHP\2025 Cerebellum prosthesis\Nike\20260423_NRR_RW033_fastig\Calibrated\IntanFile_1');
% load([path '\NRR_RW033_001_Cal.mat']) %session 033
% control_Data = Data;
% control_Data.headYawVel = Data.yaw_vel;
% control_Data.headYawPos = Data.head_pos;
% control_Data.segments.active_like_stim_pos = Data.segments.contra;
% control_Data.segments.active_like_stim_neg = Data.segments.ipsi;

controlTrials = extractControl(control_Data,preSamp,postSamp); 

%% Split control trials by movement direction

controlTrials.vel_pos = controlTrials.vel(controlTrials.direction==1,:);
controlTrials.vel_neg = controlTrials.vel(controlTrials.direction==-1,:);

controlTrials.pos_pos = controlTrials.pos(controlTrials.direction==1,:);
controlTrials.pos_neg = controlTrials.pos(controlTrials.direction==-1,:);

t = (-preSamp:postSamp)/1000;

%diagnostic plot
figure
plot(t,stimMoveTrials.vel','Color',[0.8 0.8 0.8])
hold on
plot(t,mean(stimMoveTrials.vel,1,'omitnan'),'k','LineWidth',3)

xline(0,'r--')
xlabel('Time (s)')
ylabel('Velocity (deg/s)')

plotStimControlComparison(stimMoveTrials,controlTrials,t,'vel')
plotStimControlComparison(stimMoveTrials,controlTrials,t,'pos')

%%
%plot rest trials in a similar way
%Bert's rest data
path = ('\\cullenstor\data\Current Project Databases - NHP\2025 Cerebellum prosthesis\Bert\BL_RW_003_Session_1\Calibrated\IntanFile_8');
load('BL_closed_loop_STIM_003_010_Cal_stim_curated.mat')
rest_Data = Data;

%Nike's rest data
% path = ('\\cullenstor\data\Current Project Databases - NHP\2025 Cerebellum prosthesis\Nike\20260326_NRR_RW027_fastig\Calibrated\IntanFile_11');
% load([path '\NRR_RW027_011_Cal.mat'])
% path = ('\\cullenstor\data\Current Project Databases - NHP\2025 Cerebellum prosthesis\Nike\20260423_NRR_RW033_fastig\Calibrated\IntanFile_6');
% load([path '\NRR_RW033_006_Cal.mat']) %session 033
% rest_Data = Data;
% rest_Data.headYawVel = Data.yaw_vel;
% rest_Data.headYawPos = Data.head_pos;
% rest_Data.segments.active_like_stim_pos = Data.segments.contra;
% rest_Data.segments.active_like_stim_neg = Data.segments.ipsi;
% rest_Data.Neural(:,1) = Data.Neural(:,3);

restTrials = extractStimMovement(rest_Data,preSamp,postSamp); 

%% Split rest stimulation trials by "movement direction"

restTrials.vel_pos = restTrials.vel(restTrials.direction==1,:);
restTrials.vel_neg = restTrials.vel(restTrials.direction==-1,:);

restTrials.pos_pos = restTrials.pos(restTrials.direction==1,:);
restTrials.pos_neg = restTrials.pos(restTrials.direction==-1,:);

plotStimControlComparison(restTrials,controlTrials,t,'vel')
plotStimControlComparison(restTrials,controlTrials,t,'pos')

%% ============================================================
% RMS RESPONSE (0-400 ms)
%% ============================================================

respIdx = t >= 0 & t <= 0.4;
baselineIdx = t < 0;

%% ---------- Positive movements ----------

ctrlMeanVel_pos = mean(controlTrials.vel_pos,1,'omitnan');
ctrlMeanPos_pos = mean(controlTrials.pos_pos,1,'omitnan');

stimVelResidual_pos = stimMoveTrials.vel_pos - ctrlMeanVel_pos;
stimPosResidual_pos = stimMoveTrials.pos_pos - ctrlMeanPos_pos;

rmsMoveVel_pos = sqrt(mean(stimVelResidual_pos(:,respIdx).^2,2,'omitnan'));
rmsMovePos_pos = sqrt(mean(stimPosResidual_pos(:,respIdx).^2,2,'omitnan'));

restVel_pos = restTrials.vel_pos;
restVel_pos = restVel_pos - mean(restVel_pos(:,baselineIdx),2,'omitnan');

restPos_pos = restTrials.pos_pos;
restPos_pos = restPos_pos - mean(restPos_pos(:,baselineIdx),2,'omitnan');

rmsRestVel_pos = sqrt(mean(restVel_pos(:,respIdx).^2,2,'omitnan'));
rmsRestPos_pos = sqrt(mean(restPos_pos(:,respIdx).^2,2,'omitnan'));

%% ---------- Negative movements ----------

ctrlMeanVel_neg = mean(controlTrials.vel_neg,1,'omitnan');
ctrlMeanPos_neg = mean(controlTrials.pos_neg,1,'omitnan');

stimVelResidual_neg = stimMoveTrials.vel_neg - ctrlMeanVel_neg;
stimPosResidual_neg = stimMoveTrials.pos_neg - ctrlMeanPos_neg;

rmsMoveVel_neg = sqrt(mean(stimVelResidual_neg(:,respIdx).^2,2,'omitnan'));
rmsMovePos_neg = sqrt(mean(stimPosResidual_neg(:,respIdx).^2,2,'omitnan'));

restVel_neg = restTrials.vel_neg;
restVel_neg = restVel_neg - mean(restVel_neg(:,baselineIdx),2,'omitnan');

restPos_neg = restTrials.pos_neg;
restPos_neg = restPos_neg - mean(restPos_neg(:,baselineIdx),2,'omitnan');

rmsRestVel_neg = sqrt(mean(restVel_neg(:,respIdx).^2,2,'omitnan'));
rmsRestPos_neg = sqrt(mean(restPos_neg(:,respIdx).^2,2,'omitnan'));
%% ============================================================
% RMS BAR PLOTS of QUANTIFICATION
%% ============================================================

%% Velocity

plotRMS(rmsMoveVel_pos,rmsRestVel_pos,...
    'Velocity RMS (deg/s)',...
    'Positive Movements')

plotRMS(rmsMoveVel_neg,rmsRestVel_neg,...
    'Velocity RMS (deg/s)',...
    'Negative Movements')

%These are the variables we want to save and concatenate across animals (Bert and Nike)

Bert_rmsMoveVel_pos = rmsMoveVel_pos;
Bert_rmsRestVel_pos = rmsRestVel_pos;

Bert_rmsMoveVel_neg = rmsMoveVel_neg;
Bert_rmsRestVel_neg = rmsRestVel_neg;

%% Position

plotRMS(rmsMovePos_pos,rmsRestPos_pos,...
    'Position RMS (deg)',...
    'Positive Movements')

plotRMS(rmsMovePos_neg,rmsRestPos_neg,...
    'Position RMS (deg)',...
    'Negative Movements')

%%
%CONCATENATE across animals and sessions: (comment out up to the function line if not concatenating!)
rmsMoveVel_pos = cat(1,Bert_rmsMoveVel_pos,Nike_S27_rmsMoveVel_pos,Nike_S33_rmsMoveVel_pos);
rmsRestVel_pos = cat(1,Bert_rmsRestVel_pos,Nike_S27_rmsRestVel_pos,Nike_S33_rmsRestVel_pos);

rmsMoveVel_neg = cat(1,Bert_rmsMoveVel_neg,Nike_S27_rmsMoveVel_neg,Nike_S33_rmsMoveVel_neg);
rmsRestVel_neg = cat(1,Bert_rmsRestVel_neg,Nike_S27_rmsRestVel_neg,Nike_S33_rmsRestVel_neg);


plotRMS(rmsMoveVel_pos,rmsRestVel_pos,...
    'Velocity RMS (deg/s)',...
    'Positive Movements')

plotRMS(rmsMoveVel_neg,rmsRestVel_neg,...
    'Velocity RMS (deg/s)',...
    'Negative Movements')

%
function plotRMS(moveRMS,restRMS,ylabelText,titleText)


figure('Color','w')
hold on

groups = {moveRMS,restRMS};

means = cellfun(@mean,groups);

sems = cellfun(@(x) std(x)/sqrt(numel(x)),groups);

bar(1:2,means,'FaceColor',[0.8 0.8 0.8])

errorbar(1:2,means,sems,...
    'k',...
    'LineStyle','none',...
    'LineWidth',1.5)

for i = 1:2

    jitter = 0.08*randn(numel(groups{i}),1);

    scatter(i+jitter,...
        groups{i},...
        35,...
        'filled')

end

set(gca,...
    'XTick',[1 2],...
    'XTickLabel',{'Ctrl-Stim','Stim at Rest'})

ylabel(ylabelText)

box off

[p,~,stats] = ranksum(moveRMS,restRMS);

title({titleText; sprintf('Ranksum p = %.4g',p)})

fprintf('\n%s\n',ylabelText)
fprintf('Ctrl-Stim: %.2f ± %.2f\n', ...
    mean(moveRMS), std(moveRMS)/sqrt(numel(moveRMS)))

fprintf('Stim at Rest: %.2f ± %.2f\n', ...
    mean(restRMS), std(restRMS)/sqrt(numel(restRMS)))

fprintf('Ranksum p = %.4g\n',p)

end
