classdef FlySongDetector < FeaturesDetector
    
    properties
        recording
        
        % Multi-spectral analysis properties
        taperTBP = 12;
        taperNum = 20;
        windowLength = 0.1;
        windowStepSize = 0.01;
        pValue = 0.05;
        
        % Sine song properties
        sineFreqMin = 100;          %hz
        sineFreqMax = 300;          %hz
        sineGapMaxPercent = 0.2;    % "search within ± this percent to determine whether consecutive events are continuous sine"
        sineEventsMin = .03;        % min length in secs. of sine song (bad name)
        
        % Pulse song properties
        ipiMin = 100;               % lowIPI: estimate of a very low IPI (even, rounded)  (Fs/100)
        ipiMax = 2000;              % if no other pulse within this many samples, do not count as a pulse (the idea is that a single pulse, not within IPI range of another pulse, is likely not a true pulse) (Fs/5)
        pulseMaxScale = 700;        % if best matched scale is greater than this frequency, then don't include pulse as true pulse
        pulseMinDist = 200;         % Fs/50, if pulse peaks are this close together, only keep the larger pulse (this value should be less than the species-typical IPI)
        pulseMinHeight = 6;
        
        % Noise properties
        lowFreqCutoff = 80;
        highFreqCutoff = 1000;
        noiseCutoffSD = 3;
    end
    
    properties (Transient)
        backgroundNoise;
        backgroundSSF;
    end
    
    
    methods(Static)
        
        function n = typeName()
            n = 'Fly Song';
        end
        
        function ft = possibleFeatureTypes()
            ft = {'Sine Song', 'Pulse'};
        end
        
        function initialize()
            classFile = mfilename('fullpath');
            parentDir = fileparts(classFile);
            addpath(fullfile(parentDir, 'FlySongSegmenter'));
            addpath(fullfile(parentDir, 'FlySongSegmenter', 'chronux'));
            addpath(fullfile(parentDir, 'FlySongSegmenter', 'order'));
            addpath(fullfile(parentDir, 'FlySongSegmenter', 'padcat2'));
        end
        
    end
    
    
    methods
        
        function obj = FlySongDetector(controller)
            obj = obj@FeaturesDetector(controller);
        end
        
        
        function s = settingNames(~)
            s = {'taperTBP', 'taperNum', 'windowLength', 'windowStepSize', 'pValue', ...
                 'sineFreqMin', 'sineFreqMax', 'sineGapMaxPercent', 'sineEventsMin', 'lowFreqCutoff', 'highFreqCutoff', 'noiseCutoffSD', ...
                 'ipiMin', 'ipiMax', 'pulseMaxScale', 'pulseMinDist', 'pulseMinHeight'};
        end
        
        
        function features = detectFeatures(obj, timeRange)
            features = {};
            
            dataRange = round(timeRange * obj.recording.sampleRate);
            if dataRange(1) < 1
                dataRange(1) = 1;
            end
            if dataRange(2) > length(obj.recording.data)
                dataRange(2) = length(obj.recording.data);
            end
            if dataRange(2) - dataRange(1) < 4096
                error('FlySongDetector:SampleTooSmall', 'The selected range is too small for detection.');
            end
            Data.d = obj.recording.data(dataRange(1):dataRange(2));
            
            % Map our GUI settings to the FlySongSegmenter Params structure.
            FetchParams
            Params.Fs = obj.recording.sampleRate;
            Params.NW = obj.taperTBP;
            Params.K = obj.taperNum;
            Params.dT = obj.windowLength;
            Params.dS = obj.windowStepSize;
            Params.pval = obj.pValue;
            Params.sine_low_freq = obj.sineFreqMin;
            Params.sine_high_freq = obj.sineFreqMax;
            Params.sine_range_percent = obj.sineGapMaxPercent;
            
            Params.low_freq_cutoff = obj.lowFreqCutoff;
            Params.high_freq_cutoff = obj.highFreqCutoff;
            Params.cutoff_sd = obj.noiseCutoffSD;
            
            Params.pWid = round(Params.Fs / 250) + 1;
            Params.minIPI = obj.ipiMin;
            Params.maxIPI = obj.ipiMax;
            Params.minAmplitude = obj.pulseMinHeight;
            Params.frequency = obj.pulseMaxScale;
            Params.close = obj.pulseMinDist;
            Params.discard_less_sec = obj.sineEventsMin;
            
            obj.updateProgress('Running multitaper analysis...');
            Sines.MultiTaper = MultiTaperFTest(Data.d, Params.Fs, Params.NW, Params.K, Params.dT, Params.dS, Params.pval, Params.fwindow);
            Sines.TimeHarmonicMerge = SineSegmenter(Data.d, Sines.MultiTaper, Params.Fs, Params.dT, Params.dS, ...
                                                    Params.sine_low_freq, Params.sine_high_freq, Params.sine_range_percent);
            xsong = MaskSines(Data.d, Sines.TimeHarmonicMerge);
            
            obj.updateProgress('Finding noise floor...', 0/9);
            noise = EstimateNoise(xsong, Sines.MultiTaper, Params, Params.low_freq_cutoff, Params.high_freq_cutoff);
            
            obj.updateProgress('Running wavelet transformation...');
            [Pulses.cmhSong, Pulses.cmhNoise, Pulses.cmh_dog, Pulses.cmh_sc, Pulses.sc] = ...
                WaveletTransform(xsong, noise.d, Params.fc, Params.DoGwvlt, Params.Fs);

            obj.updateProgress('Segmenting pulses...');
            Pulses.Wavelet = PulseSegmenter(Pulses.cmhSong, Pulses.cmhNoise, Params.pWid, Params.minIPI, Params.thresh, Params.Fs);

            obj.updateProgress('Culling pulses heuristically...');
            [Pulses.Wavelet, Pulses.AmpCull, Pulses.IPICull] = CullPulses(Pulses.Wavelet, Pulses.cmh_dog, Pulses.cmh_sc, Pulses.sc, ...
                                                                          xsong, noise.d, Params.fc, Params.pWid, Params.minAmplitude, ...
                                                                          Params.maxIPI, Params.frequency, Params.close);
            
            obj.updateProgress('Culling pulses with likelihood model...');
            [Pulses.pulse_model, Pulses.Lik_pulse] = FitPulseModel(cpm, Pulses.AmpCull.x);
            [Pulses.pulse_model2, Pulses.Lik_pulse2] = FitPulseModel(cpm, Pulses.IPICull.x);
            Pulses.ModelCull = ModelCullPulses(Pulses.AmpCull, Pulses.Lik_pulse.LLR_fh, [0 max(Pulses.Lik_pulse.LLR_fh)+1]);
            Pulses.ModelCull2 = ModelCullPulses(Pulses.IPICull, Pulses.Lik_pulse2.LLR_fh, [0 max(Pulses.Lik_pulse2.LLR_fh)+1]);
            Pulses.OldPulseModel = cpm;
            
            if ~isempty(Pulses.(Params.mask_pulses))
                obj.updateProgress('Masking pulses...');
                tmp = MaskPulses(Data.d, Pulses.(Params.mask_pulses));
            else
                tmp = Data.d;
            end

            obj.updateProgress('Running multitaper analysis...');
            Sines.MultiTaper = MultiTaperFTest(tmp, Params.Fs, Params.NW, Params.K, Params.dT, Params.dS, Params.pval, Params.fwindow);

            obj.updateProgress('Segmenting sine song...');
            Sines.TimeHarmonicMerge = SineSegmenter(tmp, Sines.MultiTaper, Params.Fs, Params.dT, Params.dS, ...
                                                    Params.sine_low_freq, Params.sine_high_freq, Params.sine_range_percent);

            obj.updateProgress('Winnowing sine song...');
            [Sines.PulsesCull, Sines.LengthCull] = WinnowSine(tmp, Sines.TimeHarmonicMerge, Pulses.(Params.mask_pulses), Sines.MultiTaper, ...
                                                              Params.Fs, Params.dS, Params.max_pulse_pause, Params.sine_low_freq, ...
                                                              Params.sine_high_freq, Params.discard_less_sec);
            
            obj.updateProgress('Adding features...', 9/9)
            for i = 1:length(Sines.LengthCull.start)
                x_start = timeRange(1) + Sines.LengthCull.start(i) / obj.recording.sampleRate;
                x_stop = timeRange(1) + Sines.LengthCull.stop(i) / obj.recording.sampleRate;
                if false    %isfield(winnowedSine, 'MeanFundFreq')
                    feature = Feature('Sine Song', [x_start x_stop], ...
                                      'meanFundFreq', winnowedSine.MeanFundFreq(i), ...
                                      'medianFundFreq', winnowedSine.MedianFundFreq(i));
                    features{end + 1} = feature; %#ok<AGROW>
                else
                    feature = Feature('Sine Song', [x_start x_stop]);
                    features{end + 1} = feature; %#ok<AGROW>
                end
            end
            
            for i = 1:length(Pulses.ModelCull2.wc)
                x = timeRange(1) + double(Pulses.ModelCull2.wc(i)) / obj.recording.sampleRate;
                a = timeRange(1) + double(Pulses.ModelCull2.w0(i)) / obj.recording.sampleRate;
                b = timeRange(1) + double(Pulses.ModelCull2.w1(i)) / obj.recording.sampleRate;
                feature = Feature('Pulse', x, ...
                                  'pulseWindow', [a b], ...
                                  'dogOrder', Pulses.ModelCull2.dog(i), ...
                                  'frequencyAtMax', Pulses.ModelCull2.fcmx(i), ...
                                  'scaleAtMax', Pulses.ModelCull2.scmx(i));
                features{end + 1} = feature; %#ok<AGROW>
            end
        end
        
    end
    
end
