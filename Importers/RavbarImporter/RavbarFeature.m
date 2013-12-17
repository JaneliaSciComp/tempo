classdef RavbarFeature < Feature
    
    methods
        
        function obj = RavbarFeature(featureType, featureRange, varargin)
            obj = obj@Feature(featureType, featureRange, varargin{:});
        end
        
        
        function c = color(obj)
            colors = obj.reporter.colorMap;
            colorIndex = floor(size(colors) * obj.confidence / obj.reporter.maxConfidence) + 1;
            c = colors(colorIndex, :);
        end
        
    end
    
end