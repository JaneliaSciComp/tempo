classdef FlySongImporter < FeatureImporter
    
    properties
    end
    
    
    methods(Static)
        
        function n = typeName()
            n = 'Fly Song';
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
            if ~isempty(s.winnowed_sine.events)
                for i = 1:size(s.winnowed_sine.start, 1)
                    x_start = s.winnowed_sine.start(i);
                    x_stop = s.winnowed_sine.stop(i);
                    obj.addFeature(Feature('Sine Song', [x_start x_stop]));
                end
                n = n + size(s.winnowed_sine.start, 1);
            end
            
            obj.updateProgress('Adding pulse events...', 2/3)
            for i = 1:length(s.pulseInfo2.x)
                x = s.pulseInfo2.wc(i) / obj.recording.sampleRate;
                a = s.pulseInfo2.w0(i) / obj.recording.sampleRate;
                b = s.pulseInfo2.w1(i) / obj.recording.sampleRate;
                obj.addFeature(Feature('Pulse', x));    %, 'maxVoltage', s.pulseInfo2.mxv(i), 'pulseWindow', [a b]));
            end
            n = n + length(s.pulseInfo2.x);
            
            % TBD: Is there any value in holding on to the winnowedSine, putativePulse or pulses structs?
            %      They could be set as properties of the detector...
        end
        
    end
    
end
