classdef FeatureImporter < FeatureReporter
    
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
        
        function obj = FeatureImporter(controller, featuresFilePath, varargin)
            obj = obj@FeatureReporter(controller, varargin{:});
            
            obj.featuresFilePath = featuresFilePath;
        end
       
    end
    
    
    methods (Abstract)
        
        % Subclasses must define this method.
        n = importFeatures(obj)
        
    end
    
end
