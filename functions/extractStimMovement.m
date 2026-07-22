function trials = extractStimMovement(Data,preSamp,postSamp)

%==============================================================
% Extract movement stimulation trials
%
% Aligns each trial to the FIRST pulse of each stimulation train.
%
% Output:
%   trials.vel   [nTrials x nSamples]
%   trials.pos   [nTrials x nSamples]
%==============================================================

%% Sampling rates

fsBehavior = 1000;
fsNeural   = 30000;

%% Signals

yawVel = Data.headYawVel;
yawPos = Data.headYawPos;

%% Find stimulation train onsets (returned in BEHAVIOR samples)

stimOnsets = findStimOnsets(Data.Neural(:,1),fsNeural,fsBehavior);

%% Movement segments

segments = [
    Data.segments.active_like_stim_pos;
    Data.segments.active_like_stim_neg];

fprintf('\n------------------------------------\n')
fprintf('Positive movement segments : %d\n', ...
    size(Data.segments.active_like_stim_pos,1));

fprintf('Negative movement segments : %d\n', ...
    size(Data.segments.active_like_stim_neg,1));

fprintf('Total movement segments    : %d\n', ...
    size(segments,1));

fprintf('Detected stim trains       : %d\n', ...
    numel(stimOnsets));

%% Allocate

trials.vel = [];
trials.pos = [];
trials.alignIndex = [];
trials.direction = [];

nMissing = 0;

%% Loop through movements

for k = 1:size(segments,1)

    segStart = segments(k,1);
    segEnd   = segments(k,2);
    
    nPos = size(Data.segments.active_like_stim_pos,1);

if k <= nPos
    direction = 1;      % positive movement
else
    direction = -1;     % negative movement
end

    % Find first stimulation train inside movement

    idx = find( ...
        stimOnsets >= segStart & ...
        stimOnsets <= segEnd, ...
        1,'first');

    if isempty(idx)

        nMissing = nMissing + 1;
        continue

    end

    align = stimOnsets(idx);

    %% Skip incomplete windows

    if align-preSamp < 1
        continue
    end

    if align+postSamp > length(yawVel)
        continue
    end

    trials.vel(end+1,:) = ...
        yawVel(align-preSamp : align+postSamp);

    trials.pos(end+1,:) = ...
        yawPos(align-preSamp : align+postSamp);
    
    trials.alignIndex(end+1) = align;
    
    trials.direction(end+1) = direction;

end

fprintf('Extracted trials           : %d\n', ...
    size(trials.vel,1));

fprintf('Segments without stim      : %d\n', ...
    nMissing);

fprintf('------------------------------------\n\n')

figure
plot(yawVel,'k')
hold on

yl = ylim;

for i = 1:numel(stimOnsets)
    xline(stimOnsets(i),'r')
end

title('Detected stimulation train onsets')

trials.vel_pos = trials.vel(trials.direction==1,:);
trials.vel_neg = trials.vel(trials.direction==-1,:);

trials.pos_pos = trials.pos(trials.direction==1,:);
trials.pos_neg = trials.pos(trials.direction==-1,:);

end

