function p = nextpow10(n)
%NEXTPOW10 Next higher power of 10.
%   NEXTPOW10(N) returns the first P such that 10^P >= abs(N).
%
%   Class support for input N or X:
%      float: double, single
%
%   See also LOG10.

%  Joe Henning - 25 Jul 2007

f = log10(abs(n));

% Check if n is an exact power of 10.
p = floor(f) + 1;
i = find((floor(f)-f) == 0);
if ~isempty(i)
   p(i) = f(i);
end
