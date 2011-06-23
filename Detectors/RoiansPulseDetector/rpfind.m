function [indx]=rpfind(coiltrace,playtime)

% function to find the row number of playtime in the coil timestamps.
% returns the index if successful, and 0 if unsuccessful.
%
% form: [indx]=rpfind(coiltrace,playtime)
%
% find the index where coiltrace(i,1) is larger than playtime.

indx=-1;

for i=1:length(coiltrace)
     if coiltrace(i,1)>playtime
	indx=i-1;
	break;
     end;
end;




% notes:  since coil is started before sound is played, the first timestamp
% in coil will be smaller than playtime.  the timestamps will get bigger as
% time goes along and the point where they get bigger than playtime is the 
% closest coil timestamp to the actual playtime.  can't look precisely for
% playtime b/c the coil doesn't return a sample at every time stamp.

% choosing i-1, instead of i, b/c the coil doesn't return samples while the 
% sound is playing, so the ith timestamp is actually at the end of the blank 
% period during play, which is 100 ms long (hopefully to be reduced to 10-20
% ms), and it will produce latencies which look impossibly long.
