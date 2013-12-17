classdef RavbarImporter < FeatureImporter
    
    properties
        maxConfidence
        colorMap = jet(100);
    end
    
    
    methods(Static)
        
        function n = typeName()
            n = 'Ravbar';
        end
        
        function c = canImportFromPath(featuresFilePath)
            c = false;
            
            if exist(featuresFilePath, 'file')
                [~, ~, ext] = fileparts(featuresFilePath);
                if strcmp(ext, '.mat')
                    fieldInfo = whos('ethogram_machine', '-file', featuresFilePath);
                    if length(fieldInfo) == 1
                        c = true;
                    end
                end
            end
        end
    end
    
    
    methods
        
        function obj = RavbarImporter(controller, featuresFilePath)
            obj = obj@FeatureImporter(controller, featuresFilePath);
            obj.name = 'Ravbar Importer';
        end
        
        
        function n = importFeatures(obj)
            n = 0;
            
            colWidth = 0.1; % each column in ethogram_machine represents 1/10 of a second
            
            obj.updateProgress('Loading behaviors from file...')
            s = load(obj.featuresFilePath, 'ethogram_machine');
            obj.maxConfidence = max(s.ethogram_machine(:));
            [behaviorRows, behaviorCols] = ind2sub(size(s.ethogram_machine), find(s.ethogram_machine > 0.0));
            behaviorCount = length(behaviorRows);
            for i = 1:behaviorCount
                behaviorTime = behaviorCols(i) * colWidth;
                confidence = s.ethogram_machine(behaviorRows(i), behaviorCols(i));
                obj.addFeature(RavbarFeature(sprintf('Behavior %02d', behaviorRows(i)), ...
                                             [behaviorTime behaviorTime + colWidth], ...
                                             'confidence', confidence));
            end
            
            n = n + behaviorCount;
        end
        
    end
    
end
