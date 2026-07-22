function plotStimControlComparison(stim,control,time,field)

figure('Color','w')

dirs = [1 -1];
titles = {'Positive movements','Negative movements'};

for d = 1:2

    direction = dirs(d);

    stimIdx = stim.direction == direction;
    ctrlIdx = control.direction == direction;

    stimData = stim.(field)(stimIdx,:);
    ctrlData = control.(field)(ctrlIdx,:);
    
allData = [
stim.(field)(:);
control.(field)(:)
];

yl = [min(allData) max(allData)];

%% ---------------- Control ----------------

subplot(3,2,d)

plotMeanSEM(ctrlData,time,[0 0 0])

xline(0,'k--')

title(['Control: ' titles{d}])

if strcmp(field,'vel')
    ylabel('Velocity (deg/s)')
else
    ylabel('Position (deg)')
end
ylim(yl)

%% ---------------- Stim ----------------

subplot(3,2,d+2)

plotMeanSEM(stimData,time,[0.8 0 0])

xline(0,'k--')

title(['Stim: ' titles{d}])

if strcmp(field,'vel')
    ylabel('Velocity (deg/s)')
else
    ylabel('Position (deg)')
end
ylim(yl)
    %% ---------------- Difference ----------------

    subplot(3,2,d+4)
    hold on

    mStim = mean(stimData,1,'omitnan');
    mCtrl = mean(ctrlData,1,'omitnan');

    semStim = std(stimData,[],1,'omitnan') ./ sqrt(size(stimData,1));
    semCtrl = std(ctrlData,[],1,'omitnan') ./ sqrt(size(ctrlData,1));

    diffTrace = mCtrl - mStim;
    diffSEM = sqrt(semStim.^2 + semCtrl.^2);

    fill([time fliplr(time)],...
         [diffTrace-diffSEM fliplr(diffTrace+diffSEM)],...
         [0.5 0.5 0.5],...
         'FaceAlpha',0.3,...
         'EdgeColor','none')

    plot(time,diffTrace,...
        'k','LineWidth',3)

    xline(0,'r--')
    yline(0,'k:')

    title(['Control - Stim: ' titles{d}])

    xlabel('Time (s)')

    if strcmp(field,'vel')
        ylabel('\Delta Velocity')
    else
        ylabel('\Delta Position')
    end

    box off
    ylim(yl)

end

sgtitle(field)

end