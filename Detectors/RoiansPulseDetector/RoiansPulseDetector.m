classdef RoiansPulseDetector < FeatureDetector
    
    properties
        freqMin = 250;  %hz
        freqMax = 1000; %hz
        threshold = 0.75;
    end
    
    
    methods(Static)
        
        function n = typeName()
            n = 'Roian''s Pulse Song';
        end
        
    end
    
    
    methods
        
        function obj = RoiansPulseDetector(recording)
            obj = obj@FeatureDetector(recording);
            obj.name = 'Roian''s Pulse Song';
        end
        
        
        function edited = editSettings(obj) %#ok<*MANU>
            edited = true;
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

            %[ban, ~, f] = r_specgram_noplot(data, sampleRate);
            window = ceil(obj.recording.sampleRate * .015);             % 15 ms hanning window (in samples)
            noverlap = ceil(window * 0);                                % degree of window overlap (in samples)
            nfft = 2^10;
            audioData = audioData - mean(audioData);                     % subtract any dc
            [b, f, ~] = spectrogram(audioData, window, noverlap, nfft, obj.recording.sampleRate);
            ba = abs(b);
            ban = 2 * (ba ./ (window / 2));                             % normalizing to amplitude

            startFreq = rpfind(f, obj.freqMin);
            stopFreq = rpfind(f, obj.freqMax);

            newban = sum(ban(startFreq:stopFreq, :)) / 2^15;
            
            for pulseIndex = find(newban > obj.threshold) / length(newban) * length(audioData)
                obj.addFeature(Feature('Pulse', (dataRange(1) + pulseIndex) / obj.recording.sampleRate));
            end
        end
        
    end
    
end
