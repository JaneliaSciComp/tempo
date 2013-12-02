function [vpp,vp,vrms,watts,dbw] = dbm_to_vpp (dbm, load)

% Converts dbm to peak-to-peak voltage
%
% P(dBm) = 10log_10(v2/(R*p0)) where p0 is the reference wattage, 1mW or 1E-3W

% Joe Henning - Fall 2008

if nargin < 1 | nargin > 2
   help dbm_to_vpp;
   vpp = -999;
   return
end

if nargin == 1
   load = 50;
end

vpp = sqrt(1e-3*load)*10^(dbm/20)*sqrt(2)*2;
vp = sqrt(1e-3*load)*10^(dbm/20)*sqrt(2);
vrms = sqrt(1e-3*load)*10^(dbm/20);
watts = 10^(dbm/10)*1e-3;
dbw = 10*log10(watts);
