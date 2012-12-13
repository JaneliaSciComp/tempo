classdef SavedFeaturesImporter < FeatureImporter
    
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
    end
    
    
    methods
        
        function obj = SavedFeaturesImporter(controller, featuresFilePath)
            obj = obj@FeatureImporter(controller, featuresFilePath);
            obj.name = 'Saved Features Importer';
        end
        
        
        function n = importFeatures(obj)
            obj.updateProgress('Loading events from file...', 0/3)
            
            s = load(obj.featuresFilePath, 'features', 'featureTypes', 'startTimes', 'stopTimes');
            
            n = length(s.features);
            for i = 1:n
                s.features(i).contextualMenu = [];
                obj.addFeature(s.features(i));
            end
        end
        
    end
    
end
