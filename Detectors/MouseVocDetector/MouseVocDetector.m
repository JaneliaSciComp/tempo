classdef MouseVocDetector < FeatureDetector
    
    properties
        NW=22;
        K=43;
        PVal=0.01;
        NFFT=[0.001 0.0005 0.00025];

        ObjSize=1500;
        ConvWidth=15;
        ConvHeight=7;
        FreqLow=20e3;
        FreqHigh=120e3;

        NSeg=1;

        MergeTime=0.005;
        MergeFreq=0;
        MergeFreqOverlap=0;
        MergeFreqRatio=0;
        MergeFreqFraction=0;
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
                 'ObjSize', 'ConvWidth', 'ConvHeight', 'FreqLow', 'FreqHigh', 'NSeg', ...
                 'MergeTime', 'MergeFreq', 'MergeFreqOverlap', 'MergeFreqRatio', 'MergeFreqFraction'};
        end
        
        
        function setRecording(obj, recording)
            setRecording@FeatureDetector(obj, recording);
        end
        
        
        function n = detectFeatures(obj, timeRange)

            for i=1:length(obj.NFFT)
              obj.updateProgress('Running multitaper analysis on signal...', (i-1)/(1+length(obj.NFFT)));
              [p,n,~]=fileparts(obj.recording.filePath);
              mtbp(fullfile(p,n),['tmp' num2str(i)],obj.recording.sampleRate,...
                  obj.NFFT(i),obj.NW,obj.K,obj.PVal,timeRange(1),timeRange(2));
            end

            tmp=dir([fullfile(p,n) '*tmp*.mtbp']);
            cellfun(@(x) regexp(x,'.*tmp.\.mtbp'),{tmp.name});
            tmp=tmp(logical(ans));
            for i=1:length(tmp)
              movefile(fullfile(p,tmp(i).name),tempdir);
            end

            obj.updateProgress('Heuristically segmenting syllables...', ...
                length(obj.NFFT)/(1+length(obj.NFFT)));
            mtbp2(fullfile(tempdir,n),[],...
                obj.ObjSize, [obj.ConvHeight obj.ConvWidth], obj.FreqLow, obj.FreqHigh, ...
                obj.NSeg, obj.MergeTime, obj.MergeFreq, ...
                obj.MergeFreqOverlap, obj.MergeFreqRatio, obj.MergeFreqFraction);

            obj.updateProgress('Adding features...', 1);
            tmp=dir([fullfile(tempdir,n) '.voc*']);
            voclist=load(fullfile(tempdir,tmp.name));

            for i = 1:size(voclist, 1)
                %x_start = timeRange(1) + voclist(i,1)./obj.recording.sampleRate;
                %x_stop = timeRange(1) + voclist(i,2)./obj.recording.sampleRate;
                x_start = timeRange(1) + voclist(i,1);
                x_stop = timeRange(1) + voclist(i,2);
                obj.addFeature(Feature('Vocalization', [x_start x_stop], ...
                                       'FreqRange', voclist(i,3:4)));
            end
            n=size(voclist,1);

            obj.timeRangeDetected(timeRange);


%            n = 0;
%            
%            dataRange = round(timeRange * obj.recording.sampleRate);
%            if dataRange(1) < 1
%                dataRange(1) = 1;
%            end
%            if dataRange(2) > length(obj.recording.data)
%                dataRange(2) = length(obj.recording.data);
%            end
%            if dataRange(2) - dataRange(1) < 4096
%                error('MouseVocDetector:SampleTooSmall', 'The selected range is too small for detection.');
%            end
%            audioData = obj.recording.data(dataRange(1):dataRange(2));
%            
%            obj.updateProgress('Running multitaper analysis on signal...', 0/9)
%            [songSSF] = sinesongfinder(audioData, obj.recording.sampleRate, obj.taperTBP, obj.taperNum, obj.windowLength, obj.windowStepSize, obj.pValue, obj.lowFreqCutoff, obj.highFreqCutoff);
%            
%            if isempty(obj.backgroundNoise)
%                obj.updateProgress('Calculating noise from the signal...', 1/9);
%                obj.backgroundNoise = Recording('');
%                obj.backgroundNoise.isAudio = true;
%                warning('off', 'stats:gmdistribution:FailedToConverge');
%                obj.backgroundNoise.data = segnspp(audioData, songSSF, obj.noiseCutoffSD);
%                warning('on', 'stats:gmdistribution:FailedToConverge');
%                obj.backgroundNoise.sampleRate = obj.recording.sampleRate;
%                obj.backgroundNoise.duration = length(obj.backgroundNoise.data) / obj.backgroundNoise.sampleRate;
%                
%                obj.updateProgress('Running multitaper analysis on background noise...', 2/9)
%                [obj.backgroundSSF] = sinesongfinder(obj.backgroundNoise.data, obj.backgroundNoise.sampleRate, obj.taperTBP, obj.taperNum, obj.windowLength, obj.windowStepSize, obj.pValue, obj.lowFreqCutoff, obj.highFreqCutoff);
%            end
%            
%            obj.updateProgress('Finding putative sine and power...', 3/9)
%            [putativeSine] = lengthfinder4(songSSF, obj.sineFreqMin, obj.sineFreqMax, obj.sineGapMaxPercent, obj.sineEventsMin);
%            
%            obj.updateProgress('Finding segments of putative pulse...', 4/9)
%            % TBD: expose this as a user-definable setting?
%            cutoff_quantile = 0.8;
%            [putativePulse] = putativepulse2(songSSF, putativeSine, obj.backgroundSSF, cutoff_quantile, obj.putativePulseFudge, obj.pulseMaxGapSize);
%            
%            clear putativeSine
%            
%            if numel(putativePulse.start) > 0
%                obj.updateProgress('Detecting pulses...', 5/9)
%                % TBD: expose these as user-definable settings?
%                a = 100:25:750;                             % wavelet scales: frequencies examined. 
%                b = 2:3;                                    % Derivative of Gaussian wavelets examined
%                c = round(obj.recording.sampleRate/250)+1;  % pWid:  Approx Pulse Width in points (odd, rounded)
%                d = round(obj.recording.sampleRate/80);     % buff: Points to take around each pulse for finding pulse peaks
%                e = obj.ipiMin;                             % lowIPI: estimate of a very low IPI (even, rounded)
%                f = 1.1;                                    % pulse peak height has to be at least k times the side windows
%                g = 5;                                      % thresh: Proportion of smoothed threshold over which pulses are counted. (wide mean, then set threshold as a fifth of that mean) - key for eliminating sine song.....
%                
%                %parameters for winnowing pulses: 
%                %first winnow: (returns pulseInfo)
%                h = obj.pulseMinHeight;                     %factor times the mean of xempty - only pulses larger than this amplitude are counted as true pulses
%                
%                %second winnow: (returns pulseInfo2)
%                i = obj.ipiMax;                             % if no other pulse within this many samples, do not count as a pulse (the idea is that a single pulse, not within IPI range of another pulse, is likely not a true pulse)
%                j = obj.pulseMaxScale;                      % if best matched scale is greater than this frequency, then don't include pulse as true pulse
%                k = obj.pulseMinDist;                       % if pulse peaks are this close together, only keep the larger pulse (this value should be less than the species-typical IPI)
%                
%                if true
%                    [~, pulses, ~, ~, ~, ~, ~] = PulseSegmentation(audioData, obj.backgroundNoise.data, putativePulse, a, b, c, d, e, f, g, h, i, j, k, obj.recording.sampleRate);
%                else
%                    % Split and loop
%                    pulses = {};
%                    windowSamples = 4000;   %640000;
%                    windowOverlap = windowSamples / 16;
%                    windows = ceil((length(audioData) - windowOverlap) / windowSamples);
%                    for window = 1:windows
%                        startSample = max(1, (window - 1) * windowSamples - windowOverlap);
%                        endSample = min(window * windowSamples + windowOverlap, length(audioData));
%                        windowPulses = putativePulse;
%                        for pulse = 1:length(windowPulses)
%                            windowPulses(pulse).start = windowPulses(pulse).start - startSample;
%                            windowPulses(pulse).stop = windowPulses(pulse).stop - startSample;
%                        end
%                        posInd = windowPulses.start >= 0;
%                        windowPulses.start = windowPulses.start(posInd);
%                        windowPulses.stop = windowPulses.stop(posInd);
%                        [~, windowPulses, ~, ~, ~, ~, ~] = PulseSegmentation(audioData(startSample:endSample), obj.backgroundNoise.data, windowPulses, a, b, c, d, e, f, g, h, i, j, k, obj.recording.sampleRate);
%
%                        % Merge new pulses with existing.
%                        if isempty(pulses)
%                            pulses = windowPulses;
%                        else
%                        end
%                    end
%                end
%            else
%                pulses = {};
%            end
%            
%            clear putativePulse
%            
%            if isfield(pulses, 'x')
%                obj.updateProgress('Running multitaper analysis on pulse-masked signal...', 6/9)
%                maskedAudioData = pulse_mask(audioData, pulses);
%                maskedSSF = sinesongfinder(maskedAudioData, obj.recording.sampleRate, obj.taperTBP, obj.taperNum, obj.windowLength, obj.windowStepSize, obj.pValue, obj.lowFreqCutoff, obj.highFreqCutoff);
%                clear maskedAudioData
%            else
%                maskedSSF = songSSF;
%            end
%            
%            obj.updateProgress('Finding putative sine and power...', 7/9)
%            maskedSine = lengthfinder4(maskedSSF, obj.sineFreqMin, obj.sineFreqMax, obj.sineGapMaxPercent, obj.sineEventsMin);
%            
%            obj.updateProgress('Removing overlapping sine song...', 8/9)
%            % TBD: expose this as a user-definable setting?
%            max_pulse_pause = 0.200; %max_pulse_pause in seconds, used to winnow apparent sine between pulses        
%            if maskedSine.num_events == 0 || numel(pulses.w0) == 0 || ...
%                (numel(pulses.w0) > 1000 && strcmp(questdlg(['More than 1000 pulses were detected.' char(10) char(10) 'Do you wish to continue?'], 'Fly Song Analysis', 'No', 'Yes', 'Yes'), 'No'))
%                winnowedSine = maskedSine;
%            else
%                winnowedSine = winnow_sine(maskedSine, pulses, maskedSSF, max_pulse_pause, obj.sineFreqMin, obj.sineFreqMax);
%            end
%            
%            obj.updateProgress('Adding features...', 9/9)
%            if winnowedSine.num_events > 0
%                for i = 1:size(winnowedSine.start, 1)
%                    x_start = timeRange(1) + winnowedSine.start(i);
%                    x_stop = timeRange(1) + winnowedSine.stop(i);
%                    obj.addFeature(Feature('Sine Song', [x_start x_stop], ...
%                                           'duration', winnowedSine.length(i), ...
%                                           'meanFundFreq', winnowedSine.MeanFundFreq(i), ...
%                                           'medianFundFreq', winnowedSine.MedianFundFreq(i)));
%                end
%                n = n + size(winnowedSine.start, 1);
%            end
%            
%            if isfield(pulses, 'wc')
%                pulseCount = length(pulses.wc);
%                for i = 1:pulseCount
%                    x = timeRange(1) + double(pulses.wc(i)) / obj.recording.sampleRate;
%                    a = timeRange(1) + double(pulses.w0(i)) / obj.recording.sampleRate;
%                    b = timeRange(1) + double(pulses.w1(i)) / obj.recording.sampleRate;
%                    obj.addFeature(Feature('Pulse', x, ...
%                                           'pulseWindow', [a b], ...
%                                           'dogOrder', pulses.dog(i), ...
%                                           'frequencyAtMax', pulses.fcmx(i), ...
%                                           'scaleAtMax', pulses.scmx(i)));
%                end
%                n = n + pulseCount;
%            end
%            
%            obj.timeRangeDetected(timeRange);
        end
        
    end
    
end
