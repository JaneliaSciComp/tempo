function new_indx=detect_sine_runs(indx,min_run_length)
% detect_sine_runs: function to take indices with power in sine band and
% remove short runs
%
% form: new_indx=detect_sine_runs(indx,min_run_length)
%
% indx=1 where there is sine song, 0 where there isn't
% min_run_length=minimum length sine song sections to return indices for
% (will discard runs this length or shorter)
% e.g. if min_run_length=1, then will return length 2 or greater
%
% new_indx=3 columns, num sine sections rows
% col 1=index of sine song start
% col 2=index of sine song stop

start_vals=find(diff(indx)==1)+1;
stop_vals=find(diff(indx)==-1);

if stop_vals(1) < start_vals(1)
    stop_vals=stop_vals(2:end);
end

if start_vals(end)>stop_vals(end)
    start_vals=start_vals(1:end-1);
end

new_indx(:,1)=start_vals;
new_indx(:,2)=stop_vals;
length_val=stop_vals-start_vals;

new_indx=new_indx(length_val>min_run_length,:);
   
    