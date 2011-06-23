classdef RoiansPulseDetector < FeatureDetector
    
    properties
        freqMin = 250;  %hz
        freqMax = 1000; %hz
        threshold = 3.0;
    end
    
    
    methods(Static)
        
        function n = typeName()
            n = 'Pulse Song';
        end
        
    end
    
    
    methods
        
        function obj = RoiansPulseDetector(recording)
            obj = obj@FeatureDetector(recording);
            obj.name = 'Pulses';
        end
        
        
        function editParams(obj, ~) %#ok<MANU>
            
        end
        
        
        function p = params(obj)
            p.freqMin = obj.freqMin;
            p.freqMax = obj.freqMax;
            p.threshold = obj.threshold;
        end
        
        
        function detectFeatures(obj)

            %[ban, ~, f] = r_specgram_noplot(data, sampleRate);
            window = ceil(obj.recording.sampleRate * .015);             % 15 ms hanning window (in samples)
            noverlap = ceil(window * 0);                                % degree of window overlap (in samples)
            nfft = 2^10;
            data = obj.recording.data - mean(obj.recording.data);                     % subtract any dc
            [b, f, ~] = spectrogram(obj.recording.data, window, noverlap, nfft, obj.recording.sampleRate);
            ba = abs(b);
            ban = 2 * (ba ./ (window / 2));                             % normalizing to amplitude

            startFreq = rpfind(f, obj.freqMin);
            stopFreq = rpfind(f, obj.freqMax);

            newban = sum(ban(startFreq:stopFreq, :));
            
            for pulseIndex = find(newban > obj.threshold) / numel(newban) * numel(data)
                obj.addFeature(Feature('Pulse', pulseIndex));
            end
        end
        
    end
    
end
