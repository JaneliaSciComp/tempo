% [RUNS, LENGTHS, STARTS] = EXTRACT_RUNS(X, INDS)
%
% Examines X and returns in RUNS a cell array of clips for which 
% INDS>0. INDS must be of type double, so in case of an error try 
% passing double(INDS) instead of INDS, particularly if INDS is
% logical.
%
% LENGTHS is a vector containing the lengths of RUNS, and STARTS is
% a vector containing the starting bins. So 
%
%        RUNS{k} = X(STARTS(k):STARTS(k)+LENGTHS(k)-1);

 