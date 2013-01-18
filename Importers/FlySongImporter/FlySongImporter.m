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
        
        function obj = FlySongImporter(controller, featuresFilePath)
            obj = obj@FeatureImporter(controller, featuresFilePath);
            obj.name = 'Fly Song Importer';
        end
        
        
        function n = importFeatures(obj)
            n = 0;
            
            fieldInfo = whos('song_path', 'daq_channel', '-file', obj.featuresFilePath);
            if length(fieldInfo) == 2
                % Load the audio file indicating in the features file.
                S = load(obj.featuresFilePath, 'song_path', 'daq_channel');
                [parentDir, ~, ~] = fileparts(obj.featuresFilePath);
                audioPath = fullfile(parentDir, S.song_path);
                if ~exist(audioPath, 'file')
                    % If it's not next to the features file then check the next folder up.
                    [parentDir, ~, ~] = fileparts(parentDir);
                    audioPath = fullfile(parentDir, S.song_path);
                    if ~exist(audioPath, 'file')
                        audioPath = [];
                    end
                end
                if ~isempty(audioPath)
                    obj.updateProgress('Loading audio file...', 0/4)
                    
                    % TODO: check if audio file is already open
                    
                    channel = S.daq_channel;
                    rec = Recording(audioPath, [], channel);
                    obj.controller.addAudioRecording(rec);
                end
            else
                % Require an audio file to already be open?
            end
            
            obj.updateProgress('Loading events from file...', 1/4)
            s = load(obj.featuresFilePath, 'winnowed_sine', 'pulseInfo2');
            
            obj.updateProgress('Adding sine song events...', 2/4)
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
            
            obj.updateProgress('Adding pulse events...', 3/4)
            pulseCount = length(s.pulseInfo2.wc);
            for i = 1:pulseCount
                x = double(s.pulseInfo2.wc(i)) / rec.sampleRate;
                a = double(s.pulseInfo2.w0(i)) / rec.sampleRate;
                b = double(s.pulseInfo2.w1(i)) / rec.sampleRate;
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
