classdef SineSongDetector < FeatureDetector
    
    properties
        freqMin = 100;  %hz
        freqMax = 300; %hz
        threshold = 3.0;
    end
    
    
    methods(Static)
        
        function n = typeName()
            n = 'Roian''s Sine Song';
        end
        
    end
    
    
    methods
        
        function obj = SineSongDetector(recording)
            obj = obj@FeatureDetector(recording);
            obj.name = 'Roian''s Sine Song';
        end
        
        
        function edited = editSettings(obj) %#ok<*MANU>
            edited = true;
        end
        
        
        function n = detectFeatures(obj, timeRange)
            dataRange = round(timeRange * obj.recording.sampleRate);
            if dataRange(1) < 1
                dataRange(1) = 1;
            end
            if dataRange(2) > length(obj.recording.data)
                dataRange(2) = length(obj.recording.data);
            end
            audioData = obj.recording.data(dataRange(1):dataRange(2));
            
            y = sine_song_detector(audioData, obj.recording.sampleRate);
            if any(y)
                scale = length(audioData) / length(y);
                sineRuns = detect_sine_runs(y, 3);
                sineRuns = (sineRuns * scale + dataRange(1)) / obj.recording.sampleRate;

                for i = 1:size(sineRuns, 1)
                    obj.addFeature(Feature('Sine Song', [sineRuns(i, 1) sineRuns(i, 2)]));
                end
                n = size(sineRuns, 1);
            else
                n = 0;
            end
            
            obj.timeRangeDetected(timeRange);
        end
        
    end
    
end
