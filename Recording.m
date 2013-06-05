classdef Recording < handle
    
    properties
        name
        filePath
        
        sampleRate
        sampleCount
        
        timeOffset = 0  % in seconds.  (allows recordings to be offset in time to sync up with other recordings)
    end
    
    properties (Transient)
        controller
        data
    end
    
    properties (Dependent = true)
        duration
    end
    
    
    methods (Static, Abstract)
        canLoad = canLoadFromPath(filePath)
    end
    
    
    methods
        
        function obj = Recording(controller, varargin)
            obj = obj@handle();
            
            parser = inputParser;
            obj.addParameters(parser);
            parse(parser, controller, varargin{:});
            
            obj.controller = controller;
            
            obj.loadParameters(parser);
            obj.loadData();
        end
        
        
        function addParameters(obj, parser) %#ok<INUSL>
            addRequired(parser, 'controller', @(x) isa(x, 'AnalysisController'));
            addOptional(parser, 'FilePath', '', @(x) ischar(x) && exist(x, 'file'));
            addParamValue(parser, 'Name', '', @(x) ischar(x));
            addParamValue(parser, 'SampleRate', [], @(x) isnumeric(x) && isscalar(x));
            addParamValue(parser, 'TimeOffset', 0, @(x) isnumeric(x) && isscalar(x));
        end
        
        
        function loadParameters(obj, parser)
            obj.filePath = parser.Results.FilePath;
            
            if ~isempty(parser.Results.Name)
                obj.name = parser.Results.Name;
            elseif ~isempty(obj.filePath)
                [~, obj.name, ~] = fileparts(obj.filePath);
            end
            
            obj.sampleRate = parser.Results.SampleRate;
            obj.timeOffset = parser.Results.TimeOffset;
        end
        
        
        function d = get.duration(obj)
            d = obj.sampleCount / obj.sampleRate;
        end
        
    end        
    
    
    methods (Abstract)
        % Subclasses must define this method.
        loadData(obj);
    end
    
end
