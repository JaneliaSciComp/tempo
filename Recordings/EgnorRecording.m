classdef EgnorRecording < AudioRecording
    
    methods (Static)
        
        function canLoad = canLoadFromPath(filePath)
            % See if the file's extension is .ch1, .ch2, etc.
            [~, ~, fileExt] = fileparts(filePath);
            canLoad = ~isempty(regexp(fileExt, '^\.ch[0-9]$', 'once'));
        end
        
    end
    
    
    methods
        
        function obj = EgnorRecording(controller, varargin)
            obj = obj@AudioRecording(controller, varargin{:});
        end
        
        
        function loadParameters(obj, parser)
            loadParameters@Recording(obj, parser);
            obj.channel=str2num(obj.filePath(end));
            
            if isempty(obj.sampleRate)
                % See if there is another .ch file loaded whose sample rate we can copy.
                % TODO: add a recordingsOfClass method to TempoController?
                audioInd = [];
                for i = 1:length(obj.controller.recordings)
                    if isa(obj.controller.recordings{i}, 'EgnorRecording') && obj ~= obj.controller.recordings{i}
                        audioInd = i;
                    end
                end
                if ~isempty(audioInd)
                    % Use the sample rate and time window from the existing recording.
                    obj.sampleRate = obj.controller.recordings{audioInd}.sampleRate;
                else
                    % Ask the user for the sample rate.
                    rate = inputdlg('Enter the sample rate:', '', 1, {'450450'});
                    if isempty(rate)
                        error('Tempo:UserCancelled', 'The user cancelled opening the .ch file.');
                    else
                        obj.sampleRate = str2double(rate{1});
                    end
                end
            end
        end
        
        
        function loadData(obj)
            info = dir(obj.filePath);
            obj.sampleCount = info.bytes / 4;
            
            obj.loadDataBuffer(1);
        end
        
        
        function newData = readData(obj, readStart, readLength)
            fid = fopen(obj.filePath, 'r');
            try
                fseek(fid, readStart * 4, 'bof');
                newData = fread(fid, readLength, 'single');
            catch ME
                fclose(fid);
                rethrow(ME);
            end
            fclose(fid);
        end
                
        
        % TODO: override maxAmplitude?
        
        
        function f = format(obj) %#ok<MANU>
            f = 'Egnor lab ''.ch'' audio';
        end
        
    end
    
end
