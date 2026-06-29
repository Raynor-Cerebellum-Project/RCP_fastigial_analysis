function trials = extractStimMovement(Data,preSamp,postSamp,fs)

%------------------------------------------------------------
% Extract movement stimulation trials
%
% Returns:
%   trials.vel   [nTrials x nSamples]
%   trials.pos   [nTrials x nSamples]
%
% aligned to first stimulation pulse
%------------------------------------------------------------

yawVel = Data.headYawVel;
yawPos = Data.headYawPos;

stimSignal = Data.Neural(:,1);

%% Find first pulse of every stimulation train

stimOnsets = findStimOnsets(stimSignal,fs);

fprintf('Detected %d stimulation trains\n',length(stimOnsets));

%% Movement segments

segments = [
    Data.segments.active_like_stim_pos
    Data.segments.active_like_stim_neg];

trials.vel = [];
trials.pos = [];

for k = 1:size(segments,1)

    segStart = segments(k,1);
    segEnd   = segments(k,2);

    % Find stim onset occurring inside this movement
    idx = find(stimOnsets >= segStart & stimOnsets <= segEnd,1);

    if isempty(idx)
        continue
    end

    align = stimOnsets(idx);

    % Skip incomplete windows
    if align-preSamp < 1
        continue
    end

    if align+postSamp > length(yawVel)
        continue
    end

    vel = yawVel(align-preSamp : align+postSamp);
    pos = yawPos(align-preSamp : align+postSamp);

    trials.vel(end+1,:) = vel;
    trials.pos(end+1,:) = pos;

end

fprintf('Extracted %d trials\n',size(trials.vel,1));

end