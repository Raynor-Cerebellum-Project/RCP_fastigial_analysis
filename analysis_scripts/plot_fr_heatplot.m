 close all
clear
colordef white
paradigms = {  

%      'BL_closed_loop_STIM_003_004_Cal',... 
  'NRR_RW030_014_Cal',... 
  
     };

%  
 stim_var = 'head_pos';
 stim_var2 = 'yaw_vel';
 stim_var3 = 'yaw_vel';

 
 input_names = { 
     'head_pos','yaw_vel'; 
 };

colors = [75 75 250; 75 150 75 ; 75 150 150; 250 75 75; 125 125 125;  125 125 125;  125 125 125]/255;

sides = {'ipsi','contra'};

Dyn = [-1 0 1];
df = .01;
f_max = 5;
f_target = 1;
f_vector = 0:df:f_max;
f_target_index = round(1 + f_target/df);

w_peak = 500;
w_expand = 200;

N_paradigms = length(paradigms);
N_sides = length(sides);
h_size = 1/(N_sides*N_paradigms+1);
v_size = .8;


% input_name = input_names{paradigm_index};

for paradigm_index = 1:length(paradigms)
    paradigm = paradigms{paradigm_index};
    load([paradigm '.mat'])
    
     
        unit = Data.ua_49;
        fr = Data.fr_42;
        
        
    for side_index = 1:length(sides)
        side = sides{side_index};
        M = Data.segments.(side);
        
        M_peak = zeros(size(M));
%         
        try
            ua = unit;
        catch
            ua = unit;
        end
    

        output = fr;
        output_est = fr;
%           output_est = Data.(['fr_est_' side]); %'ua1_est_'
        
        
        for M_index = 1:size(M_peak,1)
            tmp = Data.(input_names{paradigm_index,1});
            [~,idx] = max(abs(tmp(M(M_index,1):M(M_index,2))));
            M_peak(M_index,:) = [M(M_index,1)+idx-w_peak    M(M_index,1)+idx+w_peak];
        end
        M_peak(M_peak(:,1)<1,:) = [];
        M_peak(M_peak(:,2)>length(output),:) = [];
        
        ua_mat = zeros(2*w_peak+1,size(M_peak,1));
        fr_mat = zeros(2*w_peak+1,size(M_peak,1));
        fr_est_mat = zeros(2*w_peak+1,size(M_peak,1));
        stim_mat = zeros(2*w_peak+1,size(M_peak,1),size(input_names,2));
        
        
        for M_index = 1:size(M_peak,1)
            ua_mat(:,M_index) = ua(M_peak(M_index,1):M_peak(M_index,2));
            fr_mat(:,M_index) = output(M_peak(M_index,1):M_peak(M_index,2));
            fr_est_mat(:,M_index) = output_est(M_peak(M_index,1):M_peak(M_index,2));
            
            for sen_index = 1:size(input_names,2)
                tmp = Data.(input_names{paradigm_index,sen_index});
                stim_mat(:,M_index,sen_index) = tmp(M_peak(M_index,1):M_peak(M_index,2));
            end
        end
        
        
        figure((paradigm_index-1)*length(sides)+side_index)
        set(gcf,'Units','normalized','Position',[((paradigm_index-1)*length(sides)+side_index-1)*h_size (1-v_size)/2 h_size v_size])
        
        
        ax(1,(paradigm_index-1)*length(sides)+side_index) = subplot('Position',[0 0 1 1/5]);
        imagesc(fr_mat',[0 120])
        hold on
        for M_index = 1:size(M_peak)
            idx = find(ua_mat(:,M_index));
            %                 plot(idx,M_index*ones(size(idx)),'|k','LineWidth',.25)
        end
        xlim([0 2*w_peak])
        colormap jet
        axis off
        
        ax(2,(paradigm_index-1)*length(sides)+side_index) = subplot('Position',[0 1/5 1 1/5]);
        hold on
        t = 0:2*w_peak;
        t_fill = [t t(end:-1:1) t(1)];
        fr_mean = mean(fr_mat,2);
        fr_mean_fill = [fr_mean;zeros(size(fr_mean));fr_mean(1)];
        fr_est_mean = mean(fr_est_mat,2);
        
        fill(t_fill,fr_mean_fill,colors(paradigm_index,:),'FaceAlpha',.3,'EdgeAlpha',0)
        plot(t,fr_est_mean,'color',colors(paradigm_index,:),'LineWidth',3)

        xlim([0 2*w_peak+1])
        ylim([0 inf])
        axis off
        
        ax(3,(paradigm_index-1)*length(sides)+side_index) = subplot('Position',[0 2/5 1 1/5]);
        hold on
        STDplot(t,stim_mat(:,:,1)',colors(paradigm_index,:));
        plot(t,zeros(size(t)),'k');
        axis off
        
        ax(4,(paradigm_index-1)*length(sides)+side_index) = subplot('Position',[0 3/5 1 1/5]);
        hold on
        STDplot(t,stim_mat(:,:)',colors(paradigm_index,:));
        plot(t,zeros(size(t)),'k');
        axis off
        
        
        
file_index = paradigm_index;


    end
end

% linkaxes(ax(1,:),'xy')
linkaxes(ax(2,:),'xy')
linkaxes(ax(3,:),'xy')
linkaxes(ax(4,:),'xy')




 sides = {'ipsi','contra'};
 for side_idx = 1:length(sides)
     side = sides{side_idx}
    
     for i = 1:length(Data.segments.(side)) %align to peak velocity
    
        vel = (Data.(stim_var)(Data.segments.(side)(i,1):Data.segments.(side)(i,2))); %**Stim var 2 for pitch
        vel = vel - mean(vel(1:10));
        [pk loc] = max(abs(vel));
        abs_loc = loc+Data.segments.(side)(i,1)
        Data.segments2.(side)(i,1)=abs_loc-800; %-500 ***modify this window for motor command condition to not align with peak
        Data.segments2.(side)(i,2)=abs_loc+400; %500
        
     end

     for i = 1:length(Data.segments2.(side))
    
        accel = (Data.(stim_var2)(Data.segments2.(side)(i,1):Data.segments2.(side)(i,2))); %**Stim var 2 for pitch
        accel = accel - mean(accel(1:10)); %**sometimes using accel and a 100:600 window works for WB!!!
        jerk = diff(accel)/0.001;
%         [pk loc] = max(abs(accel(1:400))); %look for the abs max value only in the first half of the segment to align to the first peak/trough
        [pk loc] = max(abs(jerk(200:600)));
%         [pk loc] = max(jerk(150:500)*-1);
        abs_loc = loc+Data.segments2.(side)(i,1)+200;
        Data.segments3.(side)(i,1)=abs_loc-800; %-500 ***modify this window for motor command condition to not align with peak
        Data.segments3.(side)(i,2)=abs_loc+400; %500
        
     end
     
 end
 
 
 seg = 'segments2';
for side_idx = 1:length(sides)
    side = sides{side_idx}

    for i = 1:length(Data.segments2.(side))
    
        hsx = (Data.(stim_var2)(Data.(seg).(side)(i,1):Data.(seg).(side)(i,2)));
        hsx = hsx - mean(hsx(1:10));
%         hsx_resampled = resample(hsx,round(1000/length(hsx)*10000),10000);
        hsx_stim(:,i) = hsx(1:1000);
    
        hsx_vel = (Data.(stim_var)(Data.(seg).(side)(i,1):Data.(seg).(side)(i,2)));
        hsx_vel = hsx_vel - mean(hsx_vel(1:10));
%         hsx_vel_resampled = resample(hsx_vel,round(1000/length(hsx)*10000),10000);
        hsx_vel_stim(:,i) = hsx_vel(1:1000);
        
               
        hsx_jerk = (Data.(stim_var3)(Data.(seg).(side)(i,1):Data.(seg).(side)(i,2)));
        hsx_jerk = hsx_jerk - mean(hsx_jerk(1:10));
%         hsx_jerk_resampled = resample(hsx_jerk,round(1000/length(hsx)*10000),10000);
        hsx_jerk_stim(:,i) = hsx_jerk(1:1000);
        
        fr_datas = (output(Data.(seg).(side)(i,1):Data.(seg).(side)(i,2)));
        fr_data(:,i) = fr_datas(1:1000);
        


    
    end
    time = 1:1000;
    x_ax = [00 1000];
    figure; 
    subplot(4,1,1)
    STDplot(time(1:1000),hsx_stim',colors(paradigm_index,:));
    box off
    xlim(x_ax);
    subplot(4,1,2)
    STDplot(time(1:1000),hsx_vel_stim',colors(paradigm_index,:));
    box off
    xlim(x_ax);
    subplot(4,1,3)
    fr_datar = fr_data; %fr_datar(:,8)=[];
    fr_datar(fr_datar<0) = 0;
    area(mean(fr_datar,2))
%     ylim([0 120])
    hold on
%         mn_fr(1:1000) = mean(mean(fr_datar,2)); %to plot mean +/- std for motor commmand condition
%         plot(mn_fr, 'k');
%         std_fr_pos(1:1000) = mean(std(fr_datar))+mn_fr; 
%         plot(std_fr_pos, '-k')
%         std_fr_neg(1:1000) = mean(std(fr_datar))-mn_fr;
%         plot(std_fr_neg, '-k')
    newcolors = [.7 .7 .7];
    colororder(newcolors)
    hold on
    box off
    xlim(x_ax);

    subplot(4,1,4)
    imagesc(fr_data',[0 160])
    colormap jet
    box off
    xlim(x_ax);
    
    clear fr_data
    
end

