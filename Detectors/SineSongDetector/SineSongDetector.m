classdef SineSongDetector < FeatureDetector
    
    properties
        freqMin = 250;  %hz
        freqMax = 1000; %hz
        threshold = 3.0;
    end
    
    
    methods(Static)
        
        function n = typeName()
            n = 'Sine Song';
        end
        
    end
    
    
    methods
        
        function obj = SineSongDetector(varargin)
            obj = obj@FeatureDetector();
            obj.name = 'Sine Song';
        end
        
        
        function detectFeatures(obj, data, sampleRate, ~)
            %y = sine_song_detector(handles.audioData, handles.audioSampleRate);
            %z = detect_sine_runs(y, 3);
            %z(:,3) = z(:,2) - z(:,1);
            
            %obj.features = find(newban > obj.threshold);
        end
        
    end
    
end
