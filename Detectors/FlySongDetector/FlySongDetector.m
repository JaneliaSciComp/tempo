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
        
        % Pulse song properties
        ipiMin = 200;               % Fs/100...
        ipiMax = 5000;              % Fs/2...
        pulseMinAmp = 20;           % factor times the mean of xempty - only pulses larger than this amplitude are counted as true pulses
        pulseMaxScale = 700;        % if best matched scale is greater than this frequency, then don't include pulse as true pulse
        putativePulseFudge = 1.3;   % expand putative pulse by this number of steps on either side
        pulseMaxGapSize = 15;       % combine putative pulse if within this step size. i.e. this # * step_size in ms
        pulseMinRelAmp = 3;         % if pulse peak height is more than this times smaller than the pulse peaks on either side (within 100ms) then don't include
        
        backgroundNoise;
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
            
            % Set default background noise so you don't have to pick it every time...
            thisPath = mfilename('fullpath');
            parentDir = fileparts(thisPath);
            defaultBackgroundWav = fullfile(parentDir, 'BackgroundNoise.wav');
            backgroundNoisePath = getpref('FlySongDetector', 'BackgroundNoisePath', defaultBackgroundWav);
            try
                rec = Recording(backgroundNoisePath);
                obj.backgroundNoise = rec;
            catch ME
            end
        end
        
        
        function s = settingNames(~)
            s = {'taperTBP', 'taperNum', 'windowLength', 'windowStepSize', 'pValue', ...
                 'sineFreqMin', 'sineFreqMax', 'sineGapMaxPercent', 'sineEventsMin', ...
                 'ipiMin', 'ipiMax', 'pulseMinAmp', 'pulseMaxScale', 'putativePulseFudge', 'pulseMaxGapSize', 'pulseMinRelAmp'};
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
            
            obj.updateProgress('Running multitaper analysis on signal...', 0/6)
            [songSSF] = sinesongfinder(audioData, obj.recording.sampleRate, obj.taperTBP, obj.taperNum, obj.windowLength, obj.windowStepSize, obj.pValue);
            
            obj.updateProgress('Running multitaper analysis on background noise...', 1/6)
            [backgroundSSF] = sinesongfinder(obj.backgroundNoise.data, obj.recording.sampleRate, obj.taperTBP, obj.taperNum, obj.windowLength, obj.windowStepSize, obj.pValue);
            
            obj.updateProgress('Finding putative sine and power...', 2/6)
            [putativeSine] = lengthfinder4(songSSF, obj.sineFreqMin, obj.sineFreqMax, obj.sineGapMaxPercent, obj.sineEventsMin);
            
            obj.updateProgress('Finding segments of putative pulse...', 3/6)
            % TBD: expose this as a user-definable setting?
            cutoff_quantile = 0.8;
            [putativePulse] = putativepulse2(songSSF, putativeSine, backgroundSSF, cutoff_quantile, obj.putativePulseFudge, obj.pulseMaxGapSize);
            
            obj.updateProgress('Detecting pulses...', 4/6)
            % TBD: expose these as user-definable settings?
            a = 100:25:900; %wavelet scales: frequencies examined. 
            c = 2:4; %Derivative of Gaussian wavelets examined
            d = round(obj.recording.sampleRate/1000);  %Minimum distance for DoG wavelet peaks to be considered separate. (peak detection step) If you notice that individual cycles of the same pulse are counted as different pulses, increase this parameter
            e = round(obj.recording.sampleRate/1000); %Minimum distance for morlet wavelet peaks to be considered separate. (peak detection step)                            
            f = round(obj.recording.sampleRate/3000); %factor for computing window around pulse peak (this determines how much of the signal before and after the peak is included in the pulse, and sets the paramters w0 and w1.)
            h = round(obj.recording.sampleRate/50); % Width of the window to measure peak-to-peak voltage for a single pulse
            [~, pulses, ~] = PulseSegmentation(audioData, obj.backgroundNoise.data, putativePulse, a, obj.recording.sampleRate, c, d, e, f, obj.pulseMinAmp, h, obj.ipiMax, obj.pulseMinRelAmp, obj.pulseMaxScale, obj.ipiMin, obj.recording.sampleRate);

            obj.updateProgress('Removing overlapping sine song...', 5/6)
            % TBD: expose this as a user-definable setting?
            max_pulse_pause = 0.200; %max_pulse_pause in seconds, used to winnow apparent sine between pulses        
            if putativeSine.num_events > 0
                winnowedSine = winnow_sine(putativeSine, pulses, songSSF, max_pulse_pause, obj.sineFreqMin, obj.sineFreqMax);
            else
                winnowedSine = putativeSine;
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
        end
        
    end
    
end
