function [outban,bckgnd,stdbckgnd]=m_calc_average_background_noise_local(ban,num_bins,lf_bin,hf_bin)
% calc_average_background_noise_local: calculate average background noise given a spectrogram
%
% form:  outban=m_calc_average_background_noise_local(ban,num_bins,lf_bin,hf_bin);
%
% ban is the spectrogram
%
% outban is the spectrogram with the average background noise subtracted 
%

outban=ban;

indx=find_background_bin(ban,num_bins,lf_bin,hf_bin,2); % returns the num_bins quietest time bins in the spectrogram

newban=[];
for i=1:length(indx)
    newban=cat(2,newban,outban(:,indx(i)));
end;

bckgnd=(sum(newban,2)/num_bins);
stdbckgnd=std(newban,0,2);

for i=1:size(ban,2)
    outban(:,i)=outban(:,i)-bckgnd;
end;

