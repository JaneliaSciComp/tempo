classdef MouseVocDetector < FeatureDetector
    
    properties
        recording
        
        NW=22;
        K=43;
        PVal=0.01;
        NFFT=[0.001 0.0005 0.00025];

        FreqLow=20e3;
        FreqHigh=120e3;
        ConvWidth=15;
        ConvHeight=7;
        ObjSize=1500;

        MergeFreq=0;
        MergeFreqOverlap=0;
        MergeFreqRatio=0;
        MergeFreqFraction=0;

        MergeTime=0.005;

        NSeg=1;

        MinLength=0;
    end
    
    
    methods(Static)
        
        function n = typeName()
            n = 'Mouse Vocalization';
        end
        
        function ft = possibleFeatureTypes()
            ft = {'Vocalization'};
        end
        
        function initialize()
            %classFile = mfilename('fullpath');
            %parentDir = fileparts(classFile);
            %addpath(genpath(fullfile(parentDir, 'chronux')));
        end
        
    end
    
    
    methods
        
        function obj = MouseVocDetector(recording)
            obj = obj@FeatureDetector(recording);
            obj.name = 'Mouse Vocalization Detector';
        end
        
        
        function s = settingNames(~)
            s = {'NW', 'K', 'PVal', 'NFFT', ...
                 'FreqLow', 'FreqHigh', 'ConvWidth', 'ConvHeight', 'ObjSize', ...
                 'MergeFreq', 'MergeFreqOverlap', 'MergeFreqRatio', 'MergeFreqFraction', ...
                 'MergeTime', 'NSeg', 'MinLength'};
        end
        
        
        function setRecording(obj, recording)
            setRecording@FeatureDetector(obj, recording);
        end
        
        
        function n = detectFeatures(obj, timeRange)

            persistent sampleRate2 NFFT2 NW2 K2 PVal2 timeRange2

            [p,n,~]=fileparts(obj.recording{1}.filePath);

            if(isempty(sampleRate2) || (sampleRate2~=obj.recording{1}.sampleRate) || ...
                isempty(NFFT2) || (sum(NFFT2~=obj.NFFT)>0) || ...
                isempty(NW2) || (NW2~=obj.NW) || ...
                isempty(K2) || (K2~=obj.K) || ...
                isempty(PVal2) || (PVal2~=obj.PVal) || ...
                isempty(timeRange) || (sum(timeRange2~=timeRange)>0))
              delete([fullfile(p,n) '*tmp*.ax']);
              nsteps=(2+length(obj.NFFT));
              for i=1:length(obj.NFFT)
                obj.updateProgress('Running multitaper analysis on signal...', (i-1)/nsteps);
                ax1(obj.recording{1}.sampleRate, obj.NFFT(i), obj.NW, obj.K, obj.PVal,...
                    fullfile(p,n),['tmp' num2str(i)],...
                    60*(obj.recording{1}.dataStartSample-1)+timeRange(1),...
                    60*(obj.recording{1}.dataStartSample-1)+timeRange(2));
              end

              delete([tempdir '*tmp*.ax']);
              movefile([fullfile(p,n) '*tmp*.ax'],tempdir);
            else
              nsteps=2;
            end

            tmp=dir(fullfile(tempdir,[n '*tmp*.ax']));
            cellfun(@(x) regexp(x,'.*tmp.\.ax'),{tmp.name});
            tmp=tmp(logical(ans));
            hotpixels={};
            for i=1:length(tmp)
              fid=fopen(fullfile(tempdir,tmp(i).name),'r');
              fread(fid,3,'uint8');
              fread(fid,2,'uint32');
              dT=ans(2)/ans(1)/2;
              fread(fid,2,'uint16');
              fread(fid,2,'double');
              dF=ans(2);
              foo=fread(fid,[4 inf],'double');
              foo(1,:)=foo(1,:)*dT;
              hotpixels{i}={foo([1 2 4],:)', dT, dF};
              fclose(fid);
            end

            sampleRate2=obj.recording{1}.sampleRate;
            NFFT2=obj.NFFT;
            NW2=obj.NW;
            K2=obj.K;
            PVal2=obj.PVal;
            timeRange2=timeRange;

            %rmdir([fullfile(tempdir,n) '-out*'],'s');
            tmp=dir([fullfile(tempdir,n) '-out*']);
            if(~isempty(tmp))
              rmdir([fullfile(tempdir,n) '-out*'],'s');
            end

            obj.updateProgress('Heuristically segmenting syllables...', (nsteps-2)/nsteps);
            ax2(obj.FreqLow, obj.FreqHigh, [obj.ConvHeight obj.ConvWidth], obj.ObjSize, ...
                obj.MergeFreq, obj.MergeFreqOverlap, obj.MergeFreqRatio, obj.MergeFreqFraction,...
                obj.MergeTime, obj.NSeg, obj.MinLength, [], fullfile(tempdir,n));

            obj.updateProgress('Adding features...', (nsteps-1)/nsteps);
            %tmp=dir([fullfile(tempdir,n) '.voc*']);
            tmp=dir([fullfile(tempdir,n) '-out*']);
            tmp2=dir([fullfile(tempdir,tmp.name,'voc*')]);
            voclist=load(fullfile(tempdir,tmp.name,tmp2.name));

            for i = 1:size(voclist, 1)
                %x_start = timeRange(1) + voclist(i,1)./obj.recording.sampleRate;
                %x_stop = timeRange(1) + voclist(i,2)./obj.recording.sampleRate;
                x_start = timeRange(1) + voclist(i,1);
                x_stop = timeRange(1) + voclist(i,2);
                if(i==1)
                  obj.addFeature(Feature('Vocalization', [x_start x_stop voclist(i,3:4)], ...
                                         'HotPixels', hotpixels));
                else
                  obj.addFeature(Feature('Vocalization', [x_start x_stop voclist(i,3:4)]));
                end
            end
            n=size(voclist,1);

            obj.timeRangeDetected(timeRange);

        end
        
    end
    
end
