function y = dbmean(x,dim)

% DBMEAN Average or mean decibel value of two decibel quantities
%    For vectors, DBMEAN(X) is the mean decibel value of the elements in X.
%    For matrices, DBMEAN(X) is the row vector containing the mean decibel
%    value of each column.  For N-D arrays, DBMEAN(X) is the mean decibel
%    value of the elements along the first non-singleton dimension of X.
%
%    DBMEAN(X,DIM) takes the mean along the dimension DIM of X.

y = 10*log10(mean(10.^(x/10),dim));
