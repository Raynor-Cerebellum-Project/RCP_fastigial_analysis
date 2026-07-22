function trials = extractControl(Data,preSamp,postSamp)

%==============================================================
% Extract control movement trials
%
% Aligns each movement to the first crossing of ±85 deg/s.
%
% Output:
%   trials.vel
%   trials.pos
%   trials.alignIndex
%   trials.direction
%==============================================================

yawVel = Data.headYawVel;
yawPos = Data.headYawPos;

threshold = 85;    % deg/s

%% Allocate

trials.vel = [];
trials.pos = [];
trials.alignIndex = [];
trials.direction = [];

%% ---------- POSITIVE MOVEMENTS ----------

segments = Data.segments.active_like_stim_pos;

fprintf('\nPositive control movements: %d\n',size(segments,1));

for k = 1:size(segments,1)

    segStart = segments(k,1);
    segEnd   = segments(k,2);

    % First crossing of +85 deg/s
    idx = find(yawVel(segStart:segEnd) >= threshold,1,'first');

    if isempty(idx)
        continue
    end

    align = segStart + idx - 1;

    if align-preSamp < 1
        continue
    end

    if align+postSamp > length(yawVel)
        continue
    end

    trials.vel(end+1,:) = ...
        yawVel(align-preSamp:align+postSamp);

    trials.pos(end+1,:) = ...
        yawPos(align-preSamp:align+postSamp);

    trials.alignIndex(end+1) = align;
    trials.direction(end+1) = 1;

end

%% ---------- NEGATIVE MOVEMENTS ----------

segments = Data.segments.active_like_stim_neg;

fprintf('Negative control movements: %d\n',size(segments,1));

for k = 1:size(segments,1)

    segStart = segments(k,1);
    segEnd   = segments(k,2);

    % First crossing of -85 deg/s
    idx = find(yawVel(segStart:segEnd) <= -threshold,1,'first');

    if isempty(idx)
        continue
    end

    align = segStart + idx - 1;

    if align-preSamp < 1
        continue
    end

    if align+postSamp > length(yawVel)
        continue
    end

    trials.vel(end+1,:) = ...
        yawVel(align-preSamp:align+postSamp);

    trials.pos(end+1,:) = ...
        yawPos(align-preSamp:align+postSamp);

    trials.alignIndex(end+1) = align;
    trials.direction(end+1) = -1;

end

trials.vel_pos = trials.vel(trials.direction==1,:);
trials.vel_neg = trials.vel(trials.direction==-1,:);

trials.pos_pos = trials.pos(trials.direction==1,:);
trials.pos_neg = trials.pos(trials.direction==-1,:);

fprintf('Extracted control trials: %d\n\n',size(trials.vel,1));

end