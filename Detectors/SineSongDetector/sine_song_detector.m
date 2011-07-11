function y=sine_song_detector(x,fc)
% sing_song_detector: function to return sine song probability from time
% waveform
%
% form: y=sine_song_detector(x,fc)
%
% x=sampled time waveform, fc=sampling rate
%
%
% what if x is too long to take a spectrogram of?  then break it up and
% return a warning?  no, just write something that works, can make it
% robust later.  
%
% counting on songs being sparse in x, so there are 10 background bins,
% later can pass in num_bins or test?
%
% also later--pass in values for low and high frequency sine song range
%
% currently returning 1 for "sine song" and 0 for "not sine song" but could
% imagine returning something more continuous

% basic idea:
%
% (a) look for things with power above background in the sine song band
% (b) of the things in (a), look for things that *don't* have power in the pulse band



% defaults
num_bins=20;
target_sine=135;
target_width=15; % 1/2 width of target frequency range
lf=target_sine-target_width; % low frequency of sine song range in hz
hf=target_sine+target_width; % high frequency " "
window_width=(1/target_sine)*4; % window width should be about 4 cycles of the target sine period (0)
low_pulse=200;
high_pulse=260;

% calculate spectrogram
ban=r_specgram_fly_wind(x,fc,window_width);

% shift frequency range values to bins from hz
lf_bin=floor(hz_to_bin(lf,size(ban,1),fc));
hf_bin=ceil(hz_to_bin(hf,size(ban,1),fc));
low_pulse_bin=floor(hz_to_bin(low_pulse,size(ban,1),fc));
high_pulse_bin=ceil(hz_to_bin(high_pulse,size(ban,1),fc));

% calculate background level for this sequence
[~,bckgnd,stdbckgnd]=m_calc_average_background_noise_local(ban,num_bins,lf_bin,hf_bin);
indx=find_background_bin(ban,num_bins,lf_bin,hf_bin,2);
thresh_mean=mean(bckgnd(lf_bin:hf_bin));
thresh_std=mean(stdbckgnd(lf_bin:hf_bin));
thresh=(hf_bin-lf_bin)*(thresh_mean+(6*thresh_std));

% calculate sine song power
sine_sum=sum(ban(lf_bin:hf_bin,:));
sine_sum_indx=sine_sum>thresh;

% calculate pulse song power
pulse_sum=sum(ban(low_pulse_bin:high_pulse_bin,:));
pulse_sum_indx=pulse_sum<sine_sum;

y=(sine_sum_indx==1 & pulse_sum_indx==1);

% return as 0 or 1 for each sample (seems wasteful) or as start and stop
% samples for each section of sine song?  two columns, col 1=start sample,
% col 2=stop sample, each row is an occurence of sine song

% notes:
%
% (0)  this is just by playing around, shortest window width that looked
% good
%
%
% in general sine song is lower amplitude than pulse song
% pulse song has a strong on/off character in the spectrogram
%
% OK, obviously, window widths that are good at delineating pulse song are
% terrible at capturing sine song
% the longer the window the better, 40 and 50 ms are good, 60 is too much
% actually, 30 is pretty good
%
% increasing nfft doesn't seem to help all that much, probably b/c pulse and
% sine really do overlap in f.
% seems like the dif in specgram with window length is likely to be more
% reliable, which is nice, can stick with 2^10.
