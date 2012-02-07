%function SSF=sinesongfinder(d,fs,NW,K,dT,dS,pval)
%
%d=decimate(d,4);  fs=fs/4;  % if fs>10e3
%ssf=sinesongfinder(d,fs,11,21,0.02,0.01,0.01)  % mosquito
%ssf=sinesongfinder(d,fs,12,20,0.1,0.01,0.05)  % fruit fly
%SINEsongfinder_plot(ssf);
%
%NW = time-bandwidth product for tapers
%K = num independent tapers to average over, must be < 2*NW
%dT = window length
%dS = window step size
%pval = criterion for F-test
%
%might need to:
%addpath chronux\spectral_analysis\helper\
%addpath chronux\spectral_analysis\continuous\

function SSF=sinesongfinder(d,fs,NW,K,dT,dS,pval,low_freq_cutoff,high_freq_cutoff)

dT2=round(dT*fs);
dS2=round(dS*fs);

% [d t]=daqread(filename);  % do it this way when pipelined
% d=d(:,chan);
d=d-repmat(mean(d),size(d,1),1);
% fs=1/max(diff(t));

[tapers,~]=dpsschk([NW K],dT2,fs);

params=[];
params.tapers=tapers;
params.Fs=fs;
params.pad=0;
params.fpass=[0 fs/2];

kk=ceil((length(d)-dT2+1)/dS2);

pos = 1:dS2:dS2*kk;
[f,~]=getfgrid(params.Fs,max(2^(nextpow2(dT2)+params.pad),dT2),params.fpass);
dim1 = length(f);
Fval=zeros(dim1,kk);A=zeros(dim1,kk); 
[~,~,f,sig,~] = ftestc(d(1:(1+dT2-1)),params,pval/dT2,'n');

for k=1:kk
    [Fval(:,k),A(:,k),~,~,~] = ftestc(d(pos(k):(pos(k)+dT2-1)),params,pval/dT2,'n');
end
t=(0:(size(Fval,2)-1))*dS2/fs;
events=[];
for i=1:size(Fval,2)
  fmax=crx_findpeaks(Fval(:,i),sig); %this function name is a hack. chronux 'findpeaks' conflicts with Matlab 'findpeaks'.
  %I have renamed the chronux function as crx_findpeaks and changed this line too.
  %This means this code is incompatible with the public version of chronux.
  %Users must use our version. Future versions of chronux are expected to
  %fix this namespace conflict, which will require rewrite of this line.
  events=[events; ...
        repmat(t(i)+dT/2,length(fmax(1).loc),1) f(fmax(1).loc)']; %#ok<AGROW>
end

SSF.fs=fs;
SSF.NW=NW;
SSF.K=K;
SSF.dT=dT;
SSF.dS=dS;
SSF.pval=pval;
SSF.t=t;
SSF.f=f;
low_freq_index = find(f > low_freq_cutoff, 1, 'first');
high_freq_index = find(f < high_freq_cutoff, 1, 'last');
SSF.summedPower = sum(abs(A(low_freq_index:high_freq_index,1:size(A,2))));
SSF.events=events;
