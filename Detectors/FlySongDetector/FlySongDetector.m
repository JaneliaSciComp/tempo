classdef FlySongDetector < FeatureDetector
    
    properties
        % Multi-spectral analysis properties
        taperTBP = 12;
        taperNum = 20;
        windowLength = 0.1;
        windowStepSize = 0.01;
        pValue = 0.02;
        
        % Sine song properties
        sineFreqMin = 100;          %hz
        sineFreqMax = 300;          %hz
        sineGapMaxPercent = 0.2;    % "search within ± this percent to determine whether consecutive events are continuous sine"
        sineEventsMin = 3;
        lowFreqCutoff = 80;
        highFreqCutoff = 1000;
        
        % Pulse song properties
        ipiMin = 200;               % lowIPI: estimate of a very low IPI (even, rounded)  (Fs/50)
        ipiMax = 5000;              % if no other pulse within this many samples, do not count as a pulse (the idea is that a single pulse, not within IPI range of another pulse, is likely not a true pulse) (Fs/2)
        pulseMaxScale = 700;        % if best matched scale is greater than this frequency, then don't include pulse as true pulse
        pulseMinDist = 250;         % Fs/40, if pulse peaks are this close together, only keep the larger pulse (this value should be less than the species-typical IPI)
        
        noiseCutoffSD = 3;
    end
    
    
    methods(Static)
        
        function n = typeName()
            n = 'Fly Song';
        end
        
        function initialize()
            classFile = mfilename('fullpath');
            parentDir = fileparts(classFile);
            addpath(genpath(fullfile(parentDir, 'chronux')));
        end
        
    end
    
    
    methods
        
        function obj = FlySongDetector(recording)
            obj = obj@FeatureDetector(recording);
            obj.name = 'Fly Song Detector';
        end
        
        
        function s = settingNames(~)
            s = {'taperTBP', 'taperNum', 'windowLength', 'windowStepSize', 'pValue', ...
                 'sineFreqMin', 'sineFreqMax', 'sineGapMaxPercent', 'sineEventsMin', ...
                 'ipiMin', 'ipiMax', 'pulseMaxScale'};
        end
        
        
        function detectFeatures(obj, timeRange)
            dataRange = round(timeRange * obj.recording.sampleRate);
            if dataRange(1) < 1
                dataRange(1) = 1;
            end
            if dataRange(2) > length(obj.recording.data)
                dataRange(2) = length(obj.recording.data);
            end
            audioData = obj.recording.data(dataRange(1):dataRange(2));
            
            obj.updateProgress('Running multitaper analysis on signal...', 0/7)
            [songSSF] = sinesongfinder(audioData, obj.recording.sampleRate, obj.taperTBP, obj.taperNum, obj.windowLength, obj.windowStepSize, obj.pValue, obj.lowFreqCutoff, obj.highFreqCutoff);
            
            obj.updateProgress('Calculating noise from the signal...', 1/7);
            backgroundNoise = Recording('');
            backgroundNoise.isAudio = true;
            %warning('off', '');
            backgroundNoise.data = segnspp(audioData, songSSF, obj.noiseCutoffSD);
            lastwarn
            %warning('on', '');
            backgroundNoise.sampleRate = obj.recording.sampleRate;
            backgroundNoise.duration = length(backgroundNoise.data) / backgroundNoise.sampleRate;
            
            obj.updateProgress('Running multitaper analysis on background noise...', 2/7)
            [backgroundSSF] = sinesongfinder(backgroundNoise.data, backgroundNoise.sampleRate, obj.taperTBP, obj.taperNum, obj.windowLength, obj.windowStepSize, obj.pValue, obj.lowFreqCutoff, obj.highFreqCutoff);
            
            obj.updateProgress('Finding putative sine and power...', 3/7)
            [putativeSine] = lengthfinder4(songSSF, obj.sineFreqMin, obj.sineFreqMax, obj.sineGapMaxPercent, obj.sineEventsMin);
            
            obj.updateProgress('Finding segments of putative pulse...', 4/7)
            % TBD: expose this as a user-definable setting?
            cutoff_quantile = 0.8;
            [putativePulse] = putativepulse2(songSSF, putativeSine, backgroundSSF, cutoff_quantile, obj.putativePulseFudge, obj.pulseMaxGapSize);
            
            if numel(putativePulse.start) > 0
                obj.updateProgress('Detecting pulses...', 5/7)
                % TBD: expose these as user-definable settings?
                a = 100:50:900;                             %wavelet scales: frequencies examined. 
                b = 2:8;                                    %Derivative of Gaussian wavelets examined
                c = round(obj.recording.sampleRate/2500);   %factor for computing window around pulse peak (this determines how much of the signal before and after the peak is included in the pulse, and sets the parameters w0 and w1.)
                d = 4;
                
                e = 8;                                      % pwr: Power to raise signal by
                f = round(obj.recording.sampleRate/500)+1;  % pWid:  Approx Pulse Width in points (odd, rounded)
                g = round(obj.recording.sampleRate/80);     % buff: Points to take around each pulse for finding pulse peaks
                i = 1.1;                                    % pulse peak height has to be at least k times the side windows
                j = 5;                                      % thresh: Proportion of smoothed threshold over which pulses are counted. (wide mean, then set threshold as a fifth of that mean) - key for eliminating sine song.....
                
                [~, pulses, ~, ~, ~, ~, ~] = PulseSegmentation(audioData, backgroundNoise.data, putativePulse, a, b, c, d, e, f, g, obj.ipiMin, i, j, obj.ipiMax, obj.pulseMaxScale, obj.pulseMinDist, obj.recording.sampleRate);
            else
                pulses = {};
            end

            obj.updateProgress('Removing overlapping sine song...', 6/7)
            % TBD: expose this as a user-definable setting?
            max_pulse_pause = 0.200; %max_pulse_pause in seconds, used to winnow apparent sine between pulses        
            if putativeSine.num_events == 0 || numel(pulses.w0) == 0
                winnowedSine = putativeSine;
            else
                winnowedSine = winnow_sine(putativeSine, pulses, songSSF, max_pulse_pause, obj.sineFreqMin, obj.sineFreqMax);
            end

            % Add all of the detected features.
            for n = 1:size(winnowedSine.start, 1)
                x_start = timeRange(1) + winnowedSine.start(n);
                x_stop = timeRange(1) + winnowedSine.stop(n);
                obj.addFeature(Feature('Sine Song', x_start, x_stop));
            end

            for i = 1:length(pulses.x)
                x = timeRange(1) + pulses.wc(i) / obj.recording.sampleRate;
                obj.addFeature(Feature('Pulse', x, x, 'maxVoltage', pulses.mxv(i)));
            end

            for i = 1:length(pulses.x);
                a = timeRange(1) + pulses.w0(i) / obj.recording.sampleRate;
                b = timeRange(1) + pulses.w1(i) / obj.recording.sampleRate;
                obj.addFeature(Feature('Pulse Window', a, b));
            end

            for n = 1:length(putativePulse.start);
                x_start = timeRange(1) + putativePulse.start(n);
                x_stop = timeRange(1) + putativePulse.stop(n);
                obj.addFeature(Feature('Putative Pulse Region', x_start, x_stop));
            end

            % TBD: Is there any value in holding on to the winnowedSine, putativePulse or pulses structs?
            %      They could be set as properties of the detector...
            
            obj.timeRangeDetected(timeRange);
        end
        
    end
    
end
