function ban=r_specgram_fly_wind(x,fc,wind)
% function to plot a properly normalized spectrogram of input
%
% form: r_specgram_fly_wind(x,fc,wind);
%
% x is the time series, fc is the sampling rate in Hz, wind=window width in
% seconds
%
%
% note: currently using a 25 ms window and 50% overlap
% might want to change once see how pulse song looks on it

% defaults
%window=ceil(fc*.025);                               % 25 ms hanning window
window=ceil(fc*wind);
%noverlap=ceil(window*.5);                           % degree of window overlap
noverlap=0;

nfft=2^10;

x=x-mean(x);  % subtract any dc

[b,~,~]=spectrogram(x,window,noverlap,nfft);    %0:512,fc);
ba=abs(b);
ban=2*(ba./(window/2));                                 % normalizing to amplitude (1)
% h=image(size(ban,1),size(ban,2),ban);
% set(h,'CDataMapping','scaled'); % (5)
% axis xy;
% ha=gca;
% xmax=get(ha,'Xlim');
% 
% colormap('jet');
% %colorbar('vert');
% 
% axis([0 xmax(2) 0 1000]);


% notes:
%
% (1)   if there was no windowing (i.e. if the window was a boxcar with amplitude=1 and 
%       length=window, then should divide by window.  however, specgram uses a hanning
%       window.  the area of a hanning window is half that of a boxcar the same length.
%       therefore we divide by window/2.  the reason it's length window, rather than length
%       nfft is that the specgram algorithm uses length window and then zeropads to length 
%       nfft, so dividing by window seems to produce more sensible numbers. [later: or, more
%       specifically--b/c it is zeropadding it doesn't add any amplitude.  i'm pretty sure
%       it's normalizing by the area, which is N in the case of a boxcar of amplitude 1 and 
%       N/2 in the case of a hanning window with min=0 and max=1.

% modifications
%
% 11.21.02 re changed nfft to 2^10 (faster, and looks fine)