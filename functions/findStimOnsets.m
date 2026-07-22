function stimOnsets = findStimOnsets(stimSignal,fsNeural,fsBehavior)

% Detect onset of each stimulation train

stimSignal = abs(stimSignal);

%% Threshold

thr = 0.5 * max(stimSignal);

stimBinary = stimSignal > thr;

%% Fill gaps between individual pulses

% Any gap shorter than 150 ms is considered part of the same train
gapSamples = round(0.15*fsNeural);

d = diff([0; stimBinary; 0]);

starts = find(d==1);
ends   = find(d==-1)-1;

% Merge trains separated by short gaps
newStarts = starts(1);
newEnds = [];

currentStart = starts(1);
currentEnd   = ends(1);

for k = 2:length(starts)

    if starts(k) - currentEnd < gapSamples
        currentEnd = ends(k);
    else
        newEnds(end+1) = currentEnd;
        newStarts(end+1) = starts(k);
        currentStart = starts(k);
        currentEnd = ends(k);
    end

end

newEnds(end+1) = currentEnd;

%% Convert to behavior samples

stimOnsets = round(newStarts * fsBehavior / fsNeural);

end