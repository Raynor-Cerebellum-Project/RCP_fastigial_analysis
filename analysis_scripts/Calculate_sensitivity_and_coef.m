%% ============================================================
% REGRESSION ANALYSIS
% pooled data stored: cd('\\cullenstor\data\Current Project Databases - NHP\2025 Cerebellum prosthesis\Bryan\RCP_fastigial_analysis\Pooled_neural_data')
% 
% Fits firing rate using:
%   Position
%   Velocity
%   Acceleration
%
% Regression is performed separately for
%   Passive Preferred
%   Passive Nonpreferred
%   Active Preferred
%   Active Nonpreferred
%
% Preferred direction is defined from PASSIVE activity.
%
% Uses existing mul_reg() function (from analysis code)
%
% Saves only:
%   Position gain
%   Velocity gain
%   Acceleration gain
%   Sensitivity
%   Phase
%   VAF
%% ============================================================

clear
close all

%% PARAMETERS

fs = 1000;
N_bootstrap = 2000;

f_target = 0.5;          % Hz (change if needed)

fc = 5;
mode = 'kaiser';

threshold = 0;

step = 1;
Range = [0 0];
multi_lat = ones(1,3);

%% ============================================================
%% LOAD DATA
%% ============================================================

%-----BERT-----------
good_neurons = [107 38 42 18 43 111 47 24 10 40 76 55 31 28];

load(fullfile('\\cullenstor\data\Current Project Databases - NHP\2025 Cerebellum prosthesis\Bert\BL_RW_003_Session_1\Calibrated\IntanFile_1\Seperate cells',...
    'BL_closed_loop_STIM_003_003_Cal.mat'))
pas_Data = Data;

load(fullfile('\\cullenstor\data\Current Project Databases - NHP\2025 Cerebellum prosthesis\Bert\BL_RW_003_Session_1\Calibrated\IntanFile_1\Seperate cells',...
    'BL_closed_loop_STIM_003_004_Cal.mat'))
act_Data = Data;

%% -----NIKE----------

% good_neurons = [49 50 19 17 16 22 46 51]; %Active condition good neurons Nike session 030
% good_neurons = [7 34 39 36 11 1 20]; %Active condition good neurons Nike session 027
% % 
% load(fullfile('\\cullenstor\data\Current Project Databases - NHP\2025 Cerebellum prosthesis\Nike\20260326_NRR_RW027_fastig\Calibrated\IntanFile_10\Seperate cells',...
%     'NRR_RW027_010_Cal.mat')) %Session 27 passive
% load(fullfile('\\cullenstor\data\Current Project Databases - NHP\2025 Cerebellum prosthesis\Nike\20260410_NRR_RW030_fastig\Calibrated\IntanFile_6\Seperate cells',...
%     'NRR_RW030_006_Cal.mat')) %Session 30 passive

% Data.headYawVel = Data.yaw_vel;
% Data.headYawPos = Data.head_pos;
% pas_Data = Data;
% % 
% pas_Data.fr_7 = pas_Data.fr_1; %Conversion Nike S027 passive to active neurons
% pas_Data.fr_34 = pas_Data.fr_58;
% pas_Data.fr_39 = pas_Data.fr_11;
% pas_Data.fr_36 = pas_Data.fr_12;
% pas_Data.fr_11 = pas_Data.fr_23;
% pas_Data.fr_1 = pas_Data.fr_8;
% pas_Data.fr_20 = pas_Data.fr_17;

% pas_Data.fr_49 = pas_Data.fr_36; %Conversion Nike S030 passive to active neurons
% pas_Data.fr_50 = pas_Data.fr_42;
% pas_Data.fr_19 = pas_Data.fr_37;
% pas_Data.fr_17 = pas_Data.fr_44;
% pas_Data.fr_16 = pas_Data.fr_47;
% pas_Data.fr_22 = pas_Data.fr_46;
% pas_Data.fr_46 = pas_Data.fr_31;
% pas_Data.fr_51 = pas_Data.fr_22;
% 
% 
% load(fullfile('\\cullenstor\data\Current Project Databases - NHP\2025 Cerebellum prosthesis\Nike\20260326_NRR_RW027_fastig\Calibrated\IntanFile_6\Seperate cells',...
%     'NRR_RW027_006_Cal.mat')) %Session 27 active
% % load(fullfile('\\cullenstor\data\Current Project Databases - NHP\2025 Cerebellum prosthesis\Nike\20260410_NRR_RW030_fastig\Calibrated\IntanFile_14\Seperate cells',...
% %     'NRR_RW030_014_Cal.mat')) %Session 30 active
% 
% Data.headYawVel = Data.yaw_vel;
% Data.headYawPos = Data.head_pos;
% act_Data = Data;

%% ============================================================
% CALCULATE ACCELERATION
%% ============================================================

pas_Data.headYawAcc = [0; diff(pas_Data.headYawVel)]*fs;
act_Data.headYawAcc = [0; diff(act_Data.headYawVel)]*fs;

%% ============================================================
% RESULTS STRUCTURE
%% ============================================================

results = struct();

%% ============================================================
% MAIN LOOP
%% ============================================================

for n = 1:length(good_neurons)

    neuron = good_neurons(n);

    fprintf('\nNeuron %d (%d/%d)\n', ...
        neuron,n,length(good_neurons))

    fr_name = sprintf('fr_%d',neuron);

    fr_passive = pas_Data.(fr_name);
    fr_active  = act_Data.(fr_name);

    %% Determine preferred direction

ipsiMod = segmentPeakModulation(fr_passive,pas_Data.segments.ipsi);

contraMod = segmentPeakModulation(fr_passive,pas_Data.segments.contra);

if mean(ipsiMod) >= mean(contraMod)

        prefLabel = 'ipsi';

        prefSeg_pas = pas_Data.segments.ipsi;
        nonprefSeg_pas = pas_Data.segments.contra;

        prefSeg_act = act_Data.segments.ipsi;
        nonprefSeg_act = act_Data.segments.contra;

    else

        prefLabel = 'contra';

        prefSeg_pas = pas_Data.segments.contra;
        nonprefSeg_pas = pas_Data.segments.ipsi;

        prefSeg_act = act_Data.segments.contra;
        nonprefSeg_act = act_Data.segments.ipsi;

    end

    results(n).id = neuron;
    results(n).preferredDirection = prefLabel;

    %% Passive preferred

    results(n).passive.pref = ...
        runBootstrapRegression( ...
        fr_passive,...
        pas_Data,...
        prefSeg_pas,...
        N_bootstrap,...
        Range,...
        threshold,...
        multi_lat,...
        step,...
        f_target);

    %% Passive nonpreferred

    results(n).passive.nonpref = ...
        runBootstrapRegression( ...
        fr_passive,...
        pas_Data,...
        nonprefSeg_pas,...
        N_bootstrap,...
        Range,...
        threshold,...
        multi_lat,...
        step,...
        f_target);

    %% Active preferred

    results(n).active.pref = ...
        runBootstrapRegression( ...
        fr_active,...
        act_Data,...
        prefSeg_act,...
        N_bootstrap,...
        Range,...
        threshold,...
        multi_lat,...
        step,...
        f_target);

    %% Active nonpreferred

    results(n).active.nonpref = ...
        runBootstrapRegression( ...
        fr_active,...
        act_Data,...
        nonprefSeg_act,...
        N_bootstrap,...
        Range,...
        threshold,...
        multi_lat,...
        step,...
        f_target);

end

%% HELPER FUNCTION 1

function stats = runBootstrapRegression( ...
    fr, Data, M, N_bootstrap, Range, threshold, multi_lat, step, f_target)

fs = 1000;

%% ------------------------------------------------------------
% Build input matrix
%% ------------------------------------------------------------

input = [ ...
    Data.headYawPos ...
    Data.headYawVel ...
    Data.headYawAcc];

output = fr;

NN = size(input,2);

before = -round(min(0,Range(1)));
after  =  round(max(0,Range(2)));

input_extended = [zeros(before,NN); input; zeros(after,NN)];


%% ------------------------------------------------------------
% Bootstrap by resampling movement segments
%% ------------------------------------------------------------

Gain = nan(N_bootstrap,3);
VAF  = nan(N_bootstrap,1);

nSeg = size(M,1);

for b = 1:N_bootstrap

    % sample movement segments with replacement
    idx = randi(nSeg,nSeg,1);

    Mboot = M(idx,:);

    [~, ...
     VAF(b), ...
     Gain(b,:), ...
     ~, ...
     ~,~,~,~,~,~,~] = ...
        mul_reg( ...
            output,...
            input,...
            Mboot,...
            Range,...
            threshold,...
            multi_lat,...
            step,...
            'linear');

end

%% ------------------------------------------------------------
% Mean gains
%% ------------------------------------------------------------

GainMean = mean(Gain,1,'omitnan');

Gp = GainMean(1);
Gv = GainMean(2);
Ga = GainMean(3);

%% ------------------------------------------------------------
% Sensitivity / Phase
%% ------------------------------------------------------------

omega = 2*pi*f_target;

Sensitivity = sign(Gv) * ...
    sqrt( ...
    ((omega^2*Ga-Gp).^2 + (omega*Gv).^2) ...
    / omega^2);

Phase = atan2( ...
    (omega^2*Ga-Gp), ...
    (omega*Gv)) * 180/pi;

%% ------------------------------------------------------------
% Store
%% ------------------------------------------------------------

stats.positionGain     = Gp;
stats.velocityGain     = Gv;
stats.accelerationGain = Ga;

stats.sensitivity = Sensitivity;
stats.phase       = Phase;

stats.VAF = mean(VAF,'omitnan');

end

%%HELPER FUNCTION 2
function dom = segmentPeakModulation(fr,segments)

% Calculates depth of modulation for each movement
% (largest deviation from baseline)

fs = 1000;

baselineTime = 0.5;              % 500 ms
preSamp = round(baselineTime*fs);

excludeTime = 0.05;              % ignore first/last 50 ms
excludeSamp = round(excludeTime*fs);

dom = nan(size(segments,1),1);

for k = 1:size(segments,1)

    onset  = segments(k,1);
    offset = segments(k,2);

    if onset-preSamp < 1
        continue
    end

    trialFR = fr(onset-preSamp:offset);

    baseline = mean(trialFR(1:preSamp),'omitnan');

    movementStart = preSamp + 1;
    movementEnd   = movementStart + (offset-onset);

    searchStart = movementStart + excludeSamp;
    searchEnd   = movementEnd - excludeSamp;

    if searchEnd <= searchStart
        continue
    end

    searchFR = trialFR(searchStart:searchEnd);

    % largest deviation from baseline
    dom(k) = max(abs(searchFR - baseline));

end

end