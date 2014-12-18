classdef MouseVocDetector < FeaturesDetector
    
    properties
        recording
        
        NW=3;
        K=5;
        PVal=0.01;
        NFFT=[32 64 128];

        FreqLow=20e3;
        FreqHigh=120e3;
        ConvWidth=0.001;
        ConvHeight=1300;
        MinObjArea=18.75;

        MergeHarmonics=0;
        MergeHarmonicsOverlap=0;
        MergeHarmonicsRatio=0;
        MergeHarmonicsFraction=0;

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
            obj = obj@FeaturesDetector(recording);
        end
        
        
        function s = settingNames(~)
            s = {'NW', 'K', 'PVal', 'NFFT', ...
                 'FreqLow', 'FreqHigh', 'ConvWidth', 'ConvHeight', 'MinObjArea', ...
                 'MergeHarmonics', 'MergeHarmonicsOverlap', 'MergeHarmonicsRatio', 'MergeHarmonicsFraction', ...
                 'MinLength'};
        end
        
        
        function setRecording(obj, recording)
            setRecording@FeaturesDetector(obj, recording);
        end
        
        
        function features = detectFeatures(obj, timeRange)

            persistent sampleRate2 NFFT2 NW2 K2 PVal2 timeRange2
            
            features = {};
            
            [p,n,e]=fileparts(obj.recording{1}.filePath);

            if(isempty(sampleRate2) || (sampleRate2~=obj.recording{1}.sampleRate) || ...
                isempty(NFFT2) || any(NFFT2~=obj.NFFT) || ...
                isempty(NW2) || (NW2~=obj.NW) || ...
                isempty(K2) || (K2~=obj.K) || ...
                isempty(PVal2) || (PVal2~=obj.PVal) || ...
                isempty(timeRange2) || any(timeRange2~=timeRange(1:2)))
              delete([fullfile(p,n) '*tmp*.ax']);
              nsteps=(2+length(obj.NFFT));
              filename = fullfile(p,n);
              if(strcmp(e,'.wav'))
                filename = [filename '.wav'];
              end
              for i=1:length(obj.NFFT)
                obj.updateProgress('Running multitaper analysis on signal...', (i-1)/nsteps);
                ax1(obj.recording{1}.sampleRate, obj.NFFT(i), obj.NW, obj.K, obj.PVal,...
                    filename,['tmp' num2str(i)],...
                    timeRange(1), timeRange(2));
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
            timeRange2=timeRange(1:2);

            %rmdir([fullfile(tempdir,n) '-out*'],'s');
            tmp=dir([fullfile(tempdir,n) '-out*']);
            if(~isempty(tmp))
              rmdir([fullfile(tempdir,n) '-out*'],'s');
            end

            obj.updateProgress('Heuristically segmenting syllables...', (nsteps-2)/nsteps);
            tmp=dir(fullfile(tempdir,[n '*tmp*.ax']));
            ax_files = cellfun(@(x) fullfile(tempdir,x), {tmp.name}, 'uniformoutput', false);
            ax2(obj.FreqLow, obj.FreqHigh, [obj.ConvHeight obj.ConvWidth], obj.MinObjArea, ...
                obj.MergeHarmonics, obj.MergeHarmonicsOverlap, obj.MergeHarmonicsRatio, obj.MergeHarmonicsFraction,...
                obj.MinLength, [], ax_files, fullfile(tempdir,n));

            obj.updateProgress('Adding features...', (nsteps-1)/nsteps);
            tmp=dir([fullfile(tempdir,n) '.voc*']);
            voclist=load(fullfile(tempdir,tmp.name));

            for i = 1:size(voclist, 1)
                if(i==1)
                  feature = Feature('Vocalization', voclist(i,1:4), ...
                                    'HotPixels', hotpixels);
                else
                  feature = Feature('Vocalization', voclist(i,1:4));
                end
                features{end + 1} = feature; %#ok<AGROW>
            end
        end
        
    end
    
end
