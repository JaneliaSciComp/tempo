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
        
        function initialize()
            %classFile = mfilename('fullpath');
            %parentDir = fileparts(classFile);
            %addpath(genpath(fullfile(parentDir, 'chronux')));
        end
        
        function c = canImportFromPath(featuresFilePath)
            c = false;
            
            if exist(featuresFilePath, 'file')
                [~, ~, ext] = fileparts(featuresFilePath);
                if strncmp(ext, '.voc', 4)
                    voclist=load(featuresFilePath,'-ascii');
                    if size(voclist,2) == 4
                        c = true;
                    end
                end
            end
%            if exist(featuresFilePath, 'file')
%                [~, ~, ext] = fileparts(featuresFilePath);
%                if strcmp(ext, '.mat')
%                    fieldInfo = whos('winnowed_sine', 'pulseInfo2', '-file', featuresFilePath);
%                    if length(fieldInfo) == 2
%                        c = true;
%                        fieldInfo = whos('song_path', 'daq_channel', '-file', featuresFilePath);
%                        if length(fieldInfo) == 2
%                            S = load(featuresFilePath, 'song_path', 'daq_channel');
%                            [parentDir, ~, ~] = fileparts(featuresFilePath);
%                            audioPath = fullfile(parentDir, S.song_path);
%                            if ~exist(audioPath, 'file')
%                                [parentDir, ~, ~] = fileparts(parentDir);
%                                audioPath = fullfile(parentDir, S.song_path);
%                                if ~exist(audioPath, 'file')
%                                    audioPath = [];
%                                end
%                            end
%                            if ~isempty(audioPath)
%                                channel = S.daq_channel;
%                            end
%                        end
%                    end
%                end
%            end
        end
    end
    
    
    methods
        
        function obj = MouseVocImporter(controller, featuresFilePath)
            obj = obj@FeatureImporter(controller, featuresFilePath);
            obj.name = 'Mouse Vocalization Importer';
        end
        
        
        function n = importFeatures(obj)
            obj.updateProgress('Loading events from file...', 0/2)
            s = load(obj.featuresFilePath, '-ascii');
            
            obj.updateProgress('Adding events...', 1/2)
            for i = 1:size(s, 1)
                obj.addFeature(Feature('Vocalization', s(i,1:2), ...
                                       'FreqRange', s(i,3:4)));
            end
            n=size(s,1);
        end
        
    end
    
end
