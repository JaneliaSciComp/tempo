function bin=hz_to_bin(hz,num_bins,fc)
% hz_to_bins: function to return corresponding spectrogram bin for a particular frequency
%
% form: bin=hz_to_bin(hz,num_bins,fc);
%
% hz=frequency in kHz, num_bins=number of frequency bins in spectrogram (nfft/2+1,size(ban,1))
% fc=sampling rate

bin=(hz/(fc/2))*num_bins;