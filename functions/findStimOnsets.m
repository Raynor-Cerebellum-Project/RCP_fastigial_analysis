function stimOnsets = findStimOnsets(stimSignal,fs)

% Detect first pulse of each stimulation train

stimSignal = abs(stimSignal);

thr = 0.5*max(stimSignal);

pulseIdx = find(stimSignal > thr);

if isempty(pulseIdx)

    stimOnsets = [];
    return

end

refractory = round(0.20*fs);     % 200 ms

stimOnsets = pulseIdx(1);

for k = 2:length(pulseIdx)

    if pulseIdx(k)-stimOnsets(end) > refractory

        stimOnsets(end+1) = pulseIdx(k);

    end

end

end