classdef NoldusImporter < FeatureImporter
    
    properties
    end
    
    
    methods(Static)
        
        function n = typeName()
            n = 'Noldus';
        end
        
        function [c, audioPath, channel] = canImportFromPath(featuresFilePath)
            c = false;
            audioPath = [];
            channel = [];
            
            if exist(featuresFilePath, 'file')
                [~, ~, ext] = fileparts(featuresFilePath);
                if strcmp(ext, '.txt')
                    fid = fopen(featuresFilePath);
                    line1 = fgetl(fid);
                    line2 = fgetl(fid);
                    line3 = fgetl(fid);
                    line4 = fgetl(fid);
                    line5 = fgetl(fid);
                    fclose(fid);
                    if ~isempty(regexp(line1, '^"Start Date:",".*"$', 'once')) && ...
                       ~isempty(regexp(line2, '^"Start Time:",".*"$', 'once')) && ...
                       ~isempty(regexp(line3, '^"Start Time \(ms\):",".*"$', 'once')) && ...
                       ~isempty(regexp(line4, '^"Header Lines:","5"$', 'once')) && ...
                       ~isempty(regexp(line5, '^"Relative Time \(seconds\)","Observation Name","Event Log File Name","Subject","Behavior","Event Type","Comment"$', 'once'))
                        c = true;
                    end
                end
            end
        end
    end
    
    
    methods
        
        function obj = NoldusImporter(recording, featuresFilePath)
            obj = obj@FeatureImporter(recording, featuresFilePath);
            obj.name = 'Noldus Importer';
        end
        
        
        function n = importFeatures(obj)
            obj.updateProgress('Loading events from file...', 0/3)
            
            fid = fopen(obj.featuresFilePath);
            rawEvents = textscan(fid, '"%f" %*q %*q %*q %q %q %*q', -1, 'HeaderLines', 5, 'delimiter', ',');
            fclose(fid);
            
            startIdxs = strcmp(rawEvents{3}, 'State start');
            stopIdxs = strcmp(rawEvents{3}, 'State stop');
            startTimes = rawEvents{1}(startIdxs);
            stopTimes = rawEvents{1}(stopIdxs);
            featureTypes = rawEvents{2}(startIdxs);
            
            n = length(featureTypes);
            
            for i = 1:n
                obj.addFeature(Feature(featureTypes{i}, [startTimes(i) stopTimes(i)]));
            end
        end
        
    end
    
end
