
function plotMeanSEM(X,time,color)

hold on

m = mean(X,1,'omitnan');

sem = std(X,[],1,'omitnan') ./ sqrt(size(X,1));

fill([time fliplr(time)],...
     [m-sem fliplr(m+sem)],...
     color,...
     'FaceAlpha',0.25,...
     'EdgeColor','none')

plot(time,m,...
    'Color',color,...
    'LineWidth',3)

box off

end

