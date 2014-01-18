classdef FeaturesImporter < FeaturesReporter
    
    properties
        featuresFilePath
    end
    
    
    methods(Static)
        
        function n = typeName()
            % Return a name for this type of importer.
            
            n = 'Feature';
        end
        
        function initialize
            % Perform any set up for all instances of this importer type.
        end
        
        function n = actionName()
            n = 'Importing features...';
        end
        
    end
    
    
    methods(Static, Abstract)
        c = canImportFromPath(featuresFilePath)
    end
    
    
    methods
        
        function obj = FeaturesImporter(controller, featuresFilePath, varargin)
            obj = obj@FeaturesReporter(controller, varargin{:});
            
            obj.featuresFilePath = featuresFilePath;
            
            % Default the name of the reporter to the file name.
            [~, obj.name, ~] = fileparts(featuresFilePath);
        end
       
    end
    
    
    methods (Abstract)
        
        % Subclasses must define this method.
        n = importFeatures(obj)
        
    end
    
end
