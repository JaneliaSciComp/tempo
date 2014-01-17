classdef VCodeImporter < FeatureImporter
    
    properties
    end
    
    
    methods(Static)
        
        function n = typeName()
            n = 'VCode';
        end
        
        function c = canImportFromPath(featuresFilePath)
            c = false;
            
            if exist(featuresFilePath, 'file')
                [~, ~, ext] = fileparts(featuresFilePath);
                if strcmp(ext, '.txt')
                    fid = fopen(featuresFilePath);
                    line1 = fgetl(fid);
                    line2 = fgetl(fid);
                    line3 = fgetl(fid);
                    fclose(fid);
                    if ~isempty(regexp(line1, '^Offset: [0-9]*, Movie: .*, DataFile: .*$', 'once')) && ...
                       ~isempty(regexp(line2, '^Tracks: .*$', 'once')) && ...
                       ~isempty(regexp(line3, '^Time,Duration,TrackName,comment$', 'once'))
                        c = true;
                    end
                end
            end
        end
    end
    
    
    methods
        
        function obj = VCodeImporter(controller, featuresFilePath)
            obj = obj@FeatureImporter(controller, featuresFilePath);
        end
        
        
        function features = importFeatures(obj)
            obj.updateProgress('Loading events from file...', 0/3)
            
            fid = fopen(obj.featuresFilePath);
            c = textscan(fid, '%f %f %s %s', -1, 'HeaderLines', 4, 'delimiter', ',');
            fclose(fid);
            
            n = length(c{1});
            features = cell(1, n);
            for i = 1:n
                features{i} = Feature(c{3}{i}, [c{1}(i) c{1}(i)+c{2}(i)] / 1000);
            end
        end
        
    end
    
end
