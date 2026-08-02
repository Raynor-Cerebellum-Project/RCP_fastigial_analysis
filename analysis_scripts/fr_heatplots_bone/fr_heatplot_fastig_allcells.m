%% ================================================================
% Population heat maps
% Control vs Stimulation
% Bert closed-loop stimulation
%% ================================================================

colordef white
clear
clc

%% ---------------- Parameters ----------------

stim_var2 = 'headYawVel';

FsSpike = 30000;      % spike timestamps
FsBeh   = 1000;       % behavioral sampling

preTime  = 300;       % ms before stim
postTime = 600;       % ms after stim

win = -preTime:postTime;

sigma = 30;           % Gaussian kernel width

x = -4*sigma:4*sigma;
g = exp(-(x.^2)/(2*sigma^2));
g = g/sum(g);



%% ================================================================
%% ======================= CONTROL FILE ===========================
%% ================================================================

Path = '\\cullenstor\data\Current Project Databases - NHP\2025 Cerebellum prosthesis\Bert\BL_RW_003_Session_1\Calibrated\IntanFile_1\';
paradigm = 'BL_closed_loop_STIM_003_004_Cal_stitched';

% Path = '\\cullenstor\data\Current Project Databases - NHP\2025 Cerebellum prosthesis\Bert\BL_RW_003_Session_1\Calibrated\IntanFile_3';
% paradigm = 'BL_closed_loop_STIM_003_006_Cal_stim_stitched_individual';

load(fullfile(Path,[paradigm '.mat']))


%% Find neurons

fields = fieldnames(Data);
unitFields = fields(startsWith(fields,'unit_'));

unitNumbers = cellfun(@(x) sscanf(x,'unit_%d'), unitFields);

fprintf('Control: found %d neurons\n',length(unitFields))

%% Neurons to include in BOTH conditions

% common_units2 = [6 59 75 83 84 97 103 105 113 117 ... %IF you want to specify the unit numbers
%                 130 162 163 164 187 24 95 100 151];
common_units = unitNumbers'; %ALL the units

% indices of neurons used in both conditions

[tf,keepIdx] = ismember(common_units,unitNumbers);

keepIdx = keepIdx(tf);
control_units = common_units(tf);


%% Initialize

fr_preferred = [];
velocity_neg = [];
velocity_pos = [];


%% Loop neurons

for n = 1:length(unitFields)

    fprintf('Control neuron %d/%d\n',n,length(unitFields))


    spikeTimes = double(Data.(unitFields{n}));


    % convert spikes to behavior sampling rate

    spikeSamples = round(spikeTimes/FsSpike*FsBeh);

    spikeSamples(spikeSamples<1)=[];
    spikeSamples(spikeSamples>length(Data.(stim_var2)))=[];


    spikeTrain = zeros(length(Data.(stim_var2)),1);

    spikeTrain(spikeSamples)=spikeTrain(spikeSamples)+1;


    % firing rate

    FR = conv(spikeTrain*1000,g,'same');


    sides = {'active_like_stim_neg','active_like_stim_pos'};

    clear FRmean VelMean


    for s = 1:2

        side = sides{s};

        segs = Data.segments.(side);


        FRtrials=[];
        VelTrials=[];


       for k = 1:size(segs,1)

    % original stimulation segment
    seg_start = segs(k,1);
    seg_end   = segs(k,2);


    % velocity threshold alignment
    vel_segment = Data.(stim_var2)(seg_start:seg_end);

%     vel_segment = vel_segment - mean(vel_segment(1:min(50,length(vel_segment))));

    threshold = 85;

    cross_idx = find(abs(vel_segment)>=threshold,1,'first');


    % skip trials without a movement
    if isempty(cross_idx)
        continue
    end


    % new alignment point
    onset = seg_start + cross_idx - 1;


    % extract firing rate window
    idx = onset-preTime:onset+postTime;


    if idx(1)<1 || idx(end)>length(FR)
        continue
    end


    FRtrials(:,end+1)=FR(idx);


    vel = Data.(stim_var2)(idx);
%     vel = vel - mean(vel(1:50));

    VelTrials(:,end+1)=vel;
    
    disp(['Raw velocity at onset = ' num2str(Data.(stim_var2)(onset))])
    disp(['Baseline corrected velocity = ' num2str(vel_segment(cross_idx))])
end


        FRmean.(side)=mean(FRtrials,2,'omitnan');
        VelMean.(side)=mean(VelTrials,2,'omitnan');


    end



    if n==1

        velocity_neg = VelMean.active_like_stim_neg;
        velocity_pos = VelMean.active_like_stim_pos;

    end



    % preferred direction

    baseline = mean(FRmean.active_like_stim_neg(1:preTime));

    modNeg = max(FRmean.active_like_stim_neg(preTime+1:end))-baseline;


    baseline = mean(FRmean.active_like_stim_pos(1:preTime));

    modPos = max(FRmean.active_like_stim_pos(preTime+1:end))-baseline;



    if modPos >= modNeg

        pref = FRmean.active_like_stim_pos;

    else

        pref = FRmean.active_like_stim_neg;

    end


% Normalize using only the response from 0–400 ms
normWindow = preTime+1 : preTime+351;

peak = max(pref(normWindow));

if peak <= 0 || isnan(peak)
    peak = 1;
end

peak_control(n) = peak;

fr_preferred(:,n) = pref / peak;
% 
% baseline = mean(pref(1:preTime));
% 
% normWindow = preTime+1 : preTime+351;
% 
% peak = max(pref(normWindow) - baseline);
% 
% if peak <= 0 || isnan(peak)
%     peak = 1;
% end
% 
% fr_preferred(:,n) = (pref - baseline) / peak;


end


%% Keep only common neurons

fr_control_common = fr_preferred(:,keepIdx);



%% Sort neurons using CONTROL peak timing

searchWindow = preTime+1:preTime+250;

[~,peakLoc]=max(fr_control_common(searchWindow,:),[],1);

[~,order]=sort(peakLoc);


control_sorted = flipud(fr_control_common(:,order)');



save('Control_heatmap_order.mat',...
    'common_units',...
    'control_units',...
    'order',...
    'control_sorted',...
    'velocity_neg',...
    'velocity_pos',...
    'peak_control');


%% ================================================================
%% ======================= STIM FILE ==============================
%% ================================================================


clear Data fr_preferred


Path = '\\cullenstor\data\Current Project Databases - NHP\2025 Cerebellum prosthesis\Bert\BL_RW_003_Session_1\Calibrated\IntanFile_5\';

paradigm = 'BL_closed_loop_STIM_003_008_Cal_stim_stitched';

load(fullfile(Path,[paradigm '.mat']))

load('Control_heatmap_order.mat',...
    'common_units',...
    'order',...
    'peak_control');


%% Find stimulation train onsets

%addpath('\\cullenstor\data\Current Project Databases - NHP\2025 Cerebellum prosthesis\Bryan\RCP_fastigial_analysis\functions')
stimOnsets = findStimOnsets(Data.Neural(:,1),FsSpike,FsBeh);

fprintf('Detected %d stimulation trains\n',length(stimOnsets))

figure
plot(Data.headYawVel)
hold on
% xline(stimOnsets,'r')
ylabel('Yaw velocity')
xlabel('Time (samp)')
title('Detected stimulation trains')

%% Find neurons again

fields = fieldnames(Data);
unitFields = fields(startsWith(fields,'unit_'));

unitNumbers = cellfun(@(x) sscanf(x,'unit_%d'), unitFields);


fprintf('Stim: found %d neurons\n',length(unitFields))



fr_preferred=[];


%% Repeat neuron processing

for n = 1:length(unitFields)

    fprintf('Stim neuron %d/%d\n',n,length(unitFields))


    spikeTimes=double(Data.(unitFields{n}));


    spikeSamples=round(spikeTimes/FsSpike*FsBeh);

    spikeSamples(spikeSamples<1)=[];
    spikeSamples(spikeSamples>length(Data.(stim_var2)))=[];


    spikeTrain=zeros(length(Data.(stim_var2)),1);

    spikeTrain(spikeSamples)=spikeTrain(spikeSamples)+1;


    FR=conv(spikeTrain*1000,g,'same');


    sides={'active_like_stim_neg','active_like_stim_pos'};

    clear FRmean


    for s=1:2

        side=sides{s};

        segs=Data.segments.(side);

        FRtrials=[];


    for k=1:size(segs,1)

        % Find stimulation train occurring during this movement segment
        stim_idx = find(stimOnsets >= segs(k,1) & ...
                    stimOnsets <= segs(k,2));


    % Skip if no stimulation occurred in this segment
    if isempty(stim_idx)
        continue
    end


    % Align to first pulse of stimulation train
    onset = stimOnsets(stim_idx(1));


    idx = onset-preTime:onset+postTime;

            if idx(1)<1 || idx(end)>length(FR)
                continue
            end


            FRtrials(:,end+1)=FR(idx);

        end


        FRmean.(side)=mean(FRtrials,2,'omitnan');

    end



    baseline=mean(FRmean.active_like_stim_neg(1:preTime));

    modNeg=max(FRmean.active_like_stim_neg(preTime+1:end))-baseline;


    baseline=mean(FRmean.active_like_stim_pos(1:preTime));

    modPos=max(FRmean.active_like_stim_pos(preTime+1:end))-baseline;



    if modPos>=modNeg

        pref=FRmean.active_like_stim_pos;

    else

        pref=FRmean.active_like_stim_neg;

    end

% peak = peak_control(n);
% 
% if peak<=0
%     peak=1;
% end
% 
% fr_preferred(:,n)=pref/peak;

    peak=max(pref(preTime+1:end));

    if peak==0
        peak=1;
    end


    fr_preferred(:,n)=pref/peak;


end



%% Match neurons and apply CONTROL ordering


[tf,stimIdx]=ismember(common_units,unitNumbers);


stimIdx=stimIdx(tf);

order_stim=order(tf);


fr_stim_common=fr_preferred(:,stimIdx);


stim_sorted=flipud(fr_stim_common(:,order_stim)');

%% ==========================================================
%% Sort by post-stimulation response (120-400 ms)
%% ==========================================================

% Window for stimulation effect
sortWindow = preTime+121 : preTime+401;

% Baseline
baseline = mean(fr_stim_common(1:preTime,:),1);

% Mean response after stimulation
postResp = mean(fr_stim_common(sortWindow,:),1);

% Mean modulation
deltaResp = postResp - baseline;

% Largest excitation first
[~,stimResponseOrder] = sort(deltaResp,'descend');

% Heatmap
stim_sorted_response = flipud(fr_stim_common(:,stimResponseOrder)');



%% ================================================================
%% =========================== PLOT ===============================
%% ================================================================

figure('Color','w')


subplot(2,3,1)

plot(win,velocity_neg,'k','LineWidth',2)

xline(0,'r--')

title('Control velocity')

ylabel('Yaw velocity')

box off



subplot(2,3,2)

imagesc(win,1:size(control_sorted,1),control_sorted)

axis xy

title('Control')

xlabel('Time (ms)')

ylabel('Neuron')

caxis([0 1])

colormap(bone)

xline(0,'r--')

box off



subplot(2,3,3)

imagesc(win,1:size(stim_sorted,1),stim_sorted)

axis xy

title('Stimulation')

xlabel('Time (ms)')

ylabel('Neuron')

caxis([0 1])

colormap(bone)

xline(0,'r--')

box off


% load('Control_heatmap_order.mat','velocity_neg','velocity_pos')
subplot(2,3,4)

imagesc(win,1:size(stim_sorted,1),stim_sorted-control_sorted)

axis xy

title('Stim - Control')

xlabel('Time (ms)')

ylabel('Neuron')

colormap(bone)

colorbar

xline(0,'r--')

box off