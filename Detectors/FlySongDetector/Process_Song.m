function [ssf,noise_ssf,winnowed_sine, pps, pulseInfo2, pulseInfo, pcndInfo] = Process_Song(xsong, xempty, Fs)

addpath(genpath('chronux'))

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%ALL USER DEFINED PARAMETERS ARE SET HERE%%%%%%%%%%%%%%%%%%%%%

%SET THE PARAMETERS FOR sinesongfinder
%Fs=sampling frequency
NW = 12;%NW = time-bandwidth product for tapers
K = 20;%K = num independent tapers to average over, must be < 2*NW
dT = 0.1;%dT = window length
dS = 0.01;%dS = window step size
pval = 0.05;%pval = criterion for F-test


%SET THE PARAMETERS FOR lengthfinder3
%freq1 and freq2 define the bounds between which the fundamental frequency 
%of sine song is expected
freq1 = 100;%lowest frequency to include as sine
freq2 = 300;%highest frequency to include as sine
%search within ± this percent to determine whether consecutive events are
%continuous sine
sine_range_percent = 0.2;
%remove putative sine smaller than n events long
discard_less_n_steps = 3;

%SET THE PARAMETERS FOR putativepulse2(ssf,sine,noise_ssf,cutoff_quantile,range,combine_time)
cutoff_quantile = 0.8;
%user definable parameters to increase range of putative pulse
range = 1.3;%expand putative pulse by this number of steps on either side
combine_time = 15;%combine putative pulse if within this step size. i.e. this # * step_size in ms


%SET THE PARAMETERS FOR PulseSegmentation

%general parameters:
a = [100:25:900]; %wavelet scales: frequencies examined. 
b = Fs; %sampling frequency
c = [2:4]; %Derivative of Gaussian wavelets examined
d = round(Fs/1000);  %Minimum distance for DoG wavelet peaks to be considered separate. (peak detection step) If you notice that individual cycles of the same pulse are counted as different pulses, increase this parameter
e = round(Fs/1000); %Minimum distance for morlet wavelet peaks to be considered separate. (peak detection step)                            
f = round(Fs/3000); %factor for computing window around pulse peak (this determines how much of the signal before and after the peak is included in the pulse, and sets the paramters w0 and w1.)

%parameters for winnowing pulses:
g = 5; %factor times the mean of xempty - only pulses larger than this amplitude are counted as true pulses
h = round(Fs/50); % Width of the window to measure peak-to-peak voltage for a single pulse
i = round(Fs/2); %if no other pulse within this many samples, do not count as a pulse (the idea is that a single pulse, not within IPI range of another pulse, is likely not a true pulse
j = 3; %if pulse peak height is more than j times smaller than the pulse peaks on either side (within 100ms), don't include
k = 700; %if best matched scale is greater than this frequency, then don't include pulse as true pulse
l = round(Fs/100); %if pulse peaks are this close together, only keep the larger pulse


%SET THE PARAMETERS FOR winnow_sine
max_pulse_pause = 0.200; %max_pulse_pause in seconds, used to winnow apparent sine between pulses

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


fprintf('Running multitaper analysis on signal.\n')
[ssf] = sinesongfinder(xsong,Fs,NW,K,dT,dS,pval); %returns ssf, which is structure containing the following fields: ***David, please explain each field in ssf
fprintf('Running multitaper analysis on empty chamber.\n')
[noise_ssf] = sinesongfinder(xempty,Fs,NW,K,dT,dS,pval); %returns noise_ssf

%Run lengthfinder3 on ssf and noise_ssf, where:

%freq1 = min value for fundamental frequency of sine song (to determine this value run the compute_spectrogram and plot_computed_spectrogram functions in the spectrogram folder on example data.
%freq2 = max value for fundamental frequency of sine song
fprintf('Finding putative sine and power in signal.\n')
[sine] = lengthfinder4(ssf, freq1, freq2,sine_range_percent,discard_less_n_steps); %returns sine, which is a structure containing the following fields: 

%ssf is structure returned by sinesongfinder, containing results of F test,
%among other things
%freq1 and freq2 define the bottom and top of the frequency band that you
%believe contains the fundamental frequency of true sine song


%start:
%stop:
%length:
%MeanFundFreq:
%MedianFundFreq:
%clips: a cell array containing each sine song clip - each clip is possibly a different length
%fprintf('Finding power in empty chamber.\n')
%[noise_sine] = lengthfinder3(noise_ssf, freq1, freq2);

%Run putativepulse2 on sine and noise_sine, where:

%cutoff_quantile = 


fprintf('Finding segments of putative pulse in signal.\n')
[pps] = putativepulse2(ssf,sine,noise_ssf,cutoff_quantile,range,combine_time); %returns pps, which is a structure containing the following fields:
%start: times at which putative pulse trains start
%stop: times at which putative pulse trains stop
%clips: the actual clips of the putative pulse trains; these are handed off to PulseSegmentation

%Run PulseSegmentation using xsong, xempty, and pps as inputs (and a list of parameters defined above):

fprintf('Running wavelet transformation on putative pulse segments.\n')
[pulseInfo, pulseInfo2, pcndInfo] = PulseSegmentation(xsong, xempty, pps, a, b, c, d, e, f, g, h, i, j, k, l, Fs);

% Grab the pulse information
numPulses  = numel(pulseInfo2.w0);
pulseStart = pulseInfo2.w0;
pulseEnd   = pulseInfo2.w1;
pulseCenter= pulseInfo2.wc;
pulseFreq  = pulseInfo2.fcmx;

% Show information for a random pulse, to demonstrate the
% meaning of values above.
whichPulse = min(10, numel(pulseStart));
fprintf('\n\nPulse %d occured between indices %d and %d in the song clip.\n', whichPulse, pulseStart(whichPulse), pulseEnd(whichPulse));
fprintf('It was centered at index %d.\n', pulseCenter(whichPulse));
fprintf('It''s center frequency was ~%d Hz.\n', pulseFreq(whichPulse));

% Use results of PulseSegmentation to winnow sine song (remove sine that overlaps pulse)
%Run only if there is any sine 
if sine.num_events > 0
    winnowed_sine = winnow_sine(sine,pulseInfo2,ssf,max_pulse_pause,freq1,freq2);
else
    winnowed_sine = sine;
end
