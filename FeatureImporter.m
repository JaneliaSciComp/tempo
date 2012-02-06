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
        
        function obj = FeatureImporter(recording, featuresFilePath, varargin)
            obj = obj@FeatureReporter(recording, varargin{:});
            
            obj.featuresFilePath = featuresFilePath;
        end
       
    end
    
    
    methods (Abstract)
        
        % Subclasses must define this method.
        n = importFeatures(obj)
        
    end
    
end
