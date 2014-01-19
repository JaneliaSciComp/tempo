classdef Feature < dynamicprops
    
    properties
        type
        range
        color
    end
    
    properties (Dependent = true)
        startTime
        endTime
        duration
        lowFreq
        highFreq
    end
    
    
    events
        RangeChanged
    end
    
    
    methods
        
        function obj = Feature(featureType, featureRange, varargin)
            %% Create a new feature with the given type that exists in the given time and frequency ranges.
            %
            % The range can be a 1, 2 or 4 element vector:
            %  * 1 element = the feature exists at one point in time with no frequency limit.
            %  * 2 elements = the feature starts and ends at the given time points and has no frequency limit.
            %  * 4 elements = elements 1 and 2 are the start and stop time, elements 3 and 4 are the low and high frequencies.
            % Additional properties can be assigned by adding name/value pairs of arguments.
            %
            % Examples:
            % >> f1 = Feature('pulse', [72.6]);
            % >> f2 = Feature('sine song', [12.34 13.56], 'fundamentalFrequency', 264.8);
            % >> f3 = Feature('vocalization', [12.34 13.56 218.7 342.3]);
            
            obj = obj@dynamicprops();
            
            if mod(numel(varargin), 2) == 1
                error 'Additional feature properties must be specified as pairs of names and values.'
            end
            
            obj.type = featureType;
            
            if isscalar(featureRange)
                obj.range = [featureRange featureRange 0 inf];
            elseif size(featureRange, 2) == 2
                obj.range = [featureRange 0 inf];
            elseif size(featureRange, 2) == 4
                obj.range = featureRange;
            else
                error('Feature ranges must have 1, 2 or 4 elements.')
            end
            
            %% Add any optional attributes.
            % TODO: any value in having known attribute types like 'confidence'?
            for argIndex = 1:numel(varargin) / 2;
                propName = varargin{argIndex * 2 - 1};
                propValue = varargin{argIndex * 2};
                if strcmpi(propName, 'color')
                    obj.color = propValue;
                else
                    addprop(obj, propName);
                    obj.(varargin{argIndex * 2 - 1}) = varargin{argIndex * 2};
                end
            end
        end
        
        
        function t = get.startTime(obj)
            t = obj.range(1);
        end
        
        
        function set.startTime(obj, time)
            if obj.range(1) ~= time
                obj.range(1) = time;
                
                notify('RangeChanged');
            end
        end
        
        
        function t = get.endTime(obj)
            t = obj.range(2);
        end
        
        
        function set.endTime(obj, time)
            if obj.range(2) ~= time
                obj.range(2) = time;
                
                notify('RangeChanged');
            end
        end
        
        
        function t = get.duration(obj)
            t = obj.range(2) - obj.range(1);
        end
        
        
        function t = get.lowFreq(obj)
            t = obj.range(3);
        end
        
        
        function set.lowFreq(obj, freq)
            if obj.range(3) ~= freq
                obj.range(3) = freq;
                
                notify('RangeChanged');
            end
        end
        
        
        function t = get.highFreq(obj)
            t = obj.range(4);
        end
        
        
        function set.highFreq(obj, freq)
            if obj.range(4) ~= freq
                obj.range(4) = freq;
                
                notify('RangeChanged');
            end
        end
        
        
        function c = get.color(obj)
            if isempty(obj.color)
                c = obj.reporter.featuresColor;
            else
                c = obj.color;
            end
        end
        
        
        function [obj, idx] = sort(obj, varargin)
            [~, idx] = sort([obj.startTime], varargin{:});
            obj = obj(idx);
        end
        
    end
    
end
