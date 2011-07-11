classdef PulseTrainDetector% < FeatureDetector
    
    properties
        ipiMin = .015;  %seconds
        ipiMax = .065;  %seconds
    end
    
    
    methods(Static)
        
        function n = typeName()
            n = 'Pulse Train';
        end
        
    end
    
    
    methods
        
        function obj = PulseTrainDetector(varargin)
            obj = obj@FeatureDetector();
            obj.name = 'Pulse Trains';
        end
        
        
        function editParams(obj, ~)
            
        end
        
        
        function p = params(obj)
            p = {};
        end
        
        
        function detectFeatures(obj, data, sampleRate, ~)
            
        end
        
    end
    
end
