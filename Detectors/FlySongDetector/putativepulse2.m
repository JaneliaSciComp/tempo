%%input ssf, lengthfinder2 output, noise ssf, noise cutoff (rec = 0.9)

%%simple function to identify start and stop times of signal above noise
%%user enters ssf result, lengthfinder result = sine and ssf_noise




function pps = putativepulse2(ssf,sine,noise_ssf,cutoff_quantile,range,combine_time)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%These parameters have been moved to Process_Song
%user definable parameters to increase range of putative pulse
%range = 1.5;%expand putative pulse by this number of steps on either side
%combine_time = 10;%metric is step_size. i.e. this * step_size in ms
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%get summed power of noise
noise_power = noise_ssf.summedPower;

step_size = ssf.dS;

%get summed power of signal
signal_power = ssf.summedPower;

%determine cutoff power value
cutoff = quantile(noise_power,cutoff_quantile);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%select only time points > cutoff
%signal = signal_power(signal_power>cutoff);   %returns times of power values > cutoff
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

signal_idx = signal_power>cutoff;    %returns indices of power values > cutoff as integers
signal_t = ssf.t(signal_idx);    %get times for indices

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%remove times that overlap with sine song
%get sine times
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
sine_times=[];
if sine.num_events ~= 0;%if there is sine song
    for x = 1:numel(sine.start)
        sine_times = [sine_times,sine.start(x)+.005:step_size:sine.stop(x)];

    end
    %get non sine song, also convert to sample rate
    putative_pulse_t=setdiff(round(signal_t*ssf.fs),round(sine_times*ssf.fs));
    
else
    putative_pulse_t=round(signal_t*ssf.fs);
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%use contiguous_segments function to pull out real start and stop times and clips 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

[put_start,put_stop] = contiguous_sequence(putative_pulse_t,step_size*ssf.fs);
[put_start,put_stop] = combine_briefly_interrupted_pulses(put_start,put_stop,step_size*ssf.fs,combine_time);

num_clips = 0;
start=[];
stop =[];
for y = 1:numel(put_start)
    if put_start(y) ~= put_stop(y);
        num_clips = num_clips+1;
        
        if put_start(y) < 2*step_size*ssf.fs;
            start_t = 1;
        else
            start_t = put_start(y)-step_size*ssf.fs*range;
        end
        stop_t=put_stop(y)+step_size*ssf.fs*range;
        start(num_clips) = start_t./ssf.fs;
        stop(num_clips) = stop_t./ssf.fs;
    end
end

pps.start = start;
pps.stop = stop;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%function to identify contiguous segments of data with a defined step size
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [start,stop] = contiguous_sequence(array,step_size)
start = [];
stop=[];
start(1) = array(1);
N_runs = 1;
for x = 1:numel(array)-1%for all but last sample
    if round(array(x+1)/step_size) == round(array(x)/step_size) + 1%if next sample is step_size away, then part of same contiguous sequence
        
    else%record stop and next start
        stop(N_runs) = array(x);
        N_runs = N_runs+1;
        start(N_runs) = array(x+1);
    end
end
%for last sample
 stop(N_runs)=array(x+1);
    
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%function to combine two runs of pulses that are interrupted by brief
%interruption, brevity set by parameter combine_time
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [put_start,put_stop] = combine_briefly_interrupted_pulses(put_start,put_stop,step_size,combine_time)
temp_start = [];
temp_stop = [];
temp_start(1) = put_start(1);
temp_stop(1) = put_stop(1);
temp_x = 1;
for x = 2:numel(put_start);
    if put_start(x) < temp_stop(temp_x) + step_size*combine_time
        temp_stop(temp_x) = put_stop(x);
    else
        temp_x = temp_x + 1;
        temp_start(temp_x) = put_start(x);
        temp_stop(temp_x) = put_stop(x);
    end
    
end

put_start = temp_start;
put_stop = temp_stop;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%function to identify continuous runs of integers in indices
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function runs = contiguous_segments(indices)
runs= [];
num_indices = size(indices,2);
start = 1;
finish = 1;

while finish < num_indices
    if indices(finish+1) - indices(finish) == 1;
        
        finish = finish + 1;
    else
        runs = cat(1,runs,[indices(start) indices(finish)]);
        
        start = finish+1;
        finish = finish+1;
        
    end
end
%may have one last run left over after finish if data ends on run
if finish>start
    runs = cat(1,runs,[indices(start) indices(finish)]);
end