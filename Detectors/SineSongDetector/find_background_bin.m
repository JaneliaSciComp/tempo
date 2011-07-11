function indx=find_background_bin(ban,num_bins,lf_bin,hf_bin,p)
% find_background_bin: function to find a bin in a spectrogram that is likely to be background
%
% form: indx=find_background_bin(ban,num_bins,lf_bin,hf_bin,p);
%
% ban=spectrogram
% num_bins=number of bins to check for
% if p==1
% indx=sample of start of num_bin long chunk of minimum amplitude signal 
% if p==2
% indx=indices of num_bin smallest signals, smallest first

max_spec=sum(ban(lf_bin:hf_bin,:),1); % sum the spectrogram

if size(max_spec,2)<num_bins
    num_bins=size(max_spec,2);
end;

if p==1
    reps=floor(length(max_spec)/num_bins);

    for i=1:reps
        start_bin=((i-1)*num_bins)+1;
        stop_bin=num_bins*i;
        std_vals(i)=std(max_spec(start_bin:stop_bin));    
    end;
    indx=find(std_vals==min(std_vals));
    indx=((indx(1)-1)*num_bins)+1;
elseif p==2
    new(:,1)=[1:1:length(max_spec)];
    new(:,2)=max_spec';
    out=sortrows(new,2);
    indx=out(1:num_bins,1);
end;

