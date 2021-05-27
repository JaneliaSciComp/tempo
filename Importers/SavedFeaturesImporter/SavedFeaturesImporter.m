classdef SavedFeaturesImporter < FeaturesImporter
    
    properties
    end
    
    
    methods(Static)
        
        function n = typeName()
            n = 'Saved Features';
        end
        
        function c = canImportFromPath(featuresFilePath)
            c = false;
            
            if exist(featuresFilePath, 'file')
                [~, ~, ext] = fileparts(featuresFilePath);
                if strcmp(ext, '.mat')
                    fieldInfo = whos('features', 'featureTypes', 'startTimes', 'stopTimes', '-file', featuresFilePath);
                    if length(fieldInfo) == 4
                        c = true;
                    end
                end
            end
        end
        
        function obj = loadobj(data)
            obj = SavedFeaturesImporter([], data.featuresFilePath);
            obj.name = data.name;
            obj.setFeatures(data.featureList(1:data.featureCount));
            obj.featuresColor = data.featuresColor;
        end
        
    end
    
    
    methods
        
        function obj = SavedFeaturesImporter(controller, featuresFilePath)
            obj = obj@FeaturesImporter(controller, featuresFilePath);
        end
        
        
        function features = importFeatures(obj)
            obj.updateProgress('Loading events from file...', 0/3)
            
            s = load(obj.featuresFilePath, 'features');
            features = s.features;
        end
        
    end
    
end
