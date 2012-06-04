classdef FlySongImporter < FeatureImporter
    
    properties
    end
    
    
    methods(Static)
        
        function n = typeName()
            n = 'Fly Song';
        end
        
        function ft = possibleFeatureTypes()
            ft = {'Sine Song', 'Pulse'};
        end
        
        function initialize()
            classFile = mfilename('fullpath');
            parentDir = fileparts(classFile);
            addpath(genpath(fullfile(parentDir, 'chronux')));
        end
        
        function c = canImportFromPath(featuresFilePath)
            c = false;
            
            if exist(featuresFilePath, 'file')
                [~, ~, ext] = fileparts(featuresFilePath);
                if strcmp(ext, '.mat')
                    fieldInfo = whos('winnowed_sine', 'pulseInfo2', '-file', featuresFilePath);
                    if length(fieldInfo) == 2
                        c = true;
                    end
                end
            end
        end
    end
    
    
    methods
        
        function obj = FlySongImporter(recording, featuresFilePath)
            obj = obj@FeatureImporter(recording, featuresFilePath);
            obj.name = 'Fly Song Importer';
        end
        
        
        function n = importFeatures(obj)
            n = 0;
            
            obj.updateProgress('Loading events from file...', 0/3)
            s = load(obj.featuresFilePath, 'winnowed_sine', 'pulseInfo2');
            
            obj.updateProgress('Adding sine song events...', 1/3)
            if s.winnowed_sine.num_events > 0 && ~isempty(s.winnowed_sine.events)
                for i = 1:size(s.winnowed_sine.start, 1)
                    x_start = s.winnowed_sine.start(i);
                    x_stop = s.winnowed_sine.stop(i);
                    obj.addFeature(Feature('Sine Song', [x_start x_stop], ...
                                           'duration', s.winnowed_sine.length(i), ...
                                           'meanFundFreq', s.winnowed_sine.MeanFundFreq(i), ...
                                           'medianFundFreq', s.winnowed_sine.MedianFundFreq(i)));
                end
                n = n + size(s.winnowed_sine.start, 1);
            end
            
            obj.updateProgress('Adding pulse events...', 2/3)
            pulseCount = length(s.pulseInfo2.wc);
            for i = 1:pulseCount
                x = double(s.pulseInfo2.wc(i)) / obj.recording.sampleRate;
                a = double(s.pulseInfo2.w0(i)) / obj.recording.sampleRate;
                b = double(s.pulseInfo2.w1(i)) / obj.recording.sampleRate;
                obj.addFeature(Feature('Pulse', x, ...
                                       'pulseWindow', [a b], ...
                                       'dogOrder', s.pulseInfo2.dog(i), ...
                                       'frequencyAtMax', s.pulseInfo2.fcmx(i), ...
                                       'scaleAtMax', s.pulseInfo2.scmx(i)));
            end
            n = n + pulseCount;
        end
        
    end
    
end
