classdef MouseVocImporter < FeatureImporter
    
    properties
    end
    
    
    methods(Static)
        
        function n = typeName()
            n = 'Mouse Vocalization';
        end
        
        function ft = possibleFeatureTypes()
            ft = {'Vocalization'};
        end
        
        function c = canImportFromPath(featuresFilePath)
            c = false;
            
            if exist(featuresFilePath, 'file')
                [~, name, ext] = fileparts(featuresFilePath);
                if strncmp(ext, '.voc', 4) || strcmp([name ext],'voc.txt')
                    voclist=load(featuresFilePath,'-ascii');
                    if size(voclist,2) == 4
                        c = true;
                    end
                end
            end
        end
    end
    
    
    methods
        
        function obj = MouseVocImporter(controller, featuresFilePath)
            obj = obj@FeatureImporter(controller, featuresFilePath);
        end
        
        
        function features = importFeatures(obj)
            features = {};
            
            obj.updateProgress('Loading events from file...', 0/2)
            s = load(obj.featuresFilePath, '-ascii');
            
            obj.updateProgress('Adding events...', 1/2)
            for i = 1:size(s, 1)
                features{end + 1} = Feature('Vocalization', s(i,1:4)); %#ok<AGROW>
            end
        end
        
    end
    
end
