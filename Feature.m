classdef Feature < dynamicprops
    
    properties
        type
        sampleRange
    end
    
    
    methods
        
        function obj = Feature(featureType, sampleRange, varargin)
            obj = obj@dynamicprops();
            
            if mod(numel(varargin), 2) == 1
                error 'Additional feature properties must be specified as pairs of names and values.'
            end
            
            obj.type = featureType;
            
            if isscalar(sampleRange)
                obj.sampleRange = [sampleRange sampleRange];
            else
                obj.sampleRange = sampleRange;
            end
            
            %% Add any optional attributes.
            % TODO: any value in having known attribute types like 'confidence'?
            for argIndex = 1:numel(varargin) / 2;
                addprop(obj, varargin{argIndex * 2 - 1});
                obj.(varargin{argIndex * 2 - 1}) = varargin{argIndex * 2};
            end
        end
        
    end
    
end
