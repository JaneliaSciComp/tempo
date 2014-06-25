classdef EgnorRecording < AudioRecording
    
    properties (Constant)
        bufferSize = 16 * 1024 * 1024;  % The maximum number of samples to load at any time.
    end
    
    properties (Transient)
        dataStartSample = -Inf
    end
    
    
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
            obj.channel=str2num(obj.audio.filePath(end));
            
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
        
        
        function loadDataBuffer(obj, startSample)
            startSample = max([1, min([startSample, obj.sampleCount - EgnorRecording.bufferSize])]);
            
            if startSample ~= obj.dataStartSample
                % Only read the data that we don't already have.
                endSample = startSample + EgnorRecording.bufferSize;
                if startSample < obj.dataStartSample || startSample > obj.dataStartSample + EgnorRecording.bufferSize
                    readStart = startSample;
                else
                    readStart = obj.dataStartSample + EgnorRecording.bufferSize;
                end
                if endSample < obj.dataStartSample || endSample > obj.dataStartSample + EgnorRecording.bufferSize
                    readEnd = endSample;
                else
                    readEnd = obj.dataStartSample;
                end
                readLength = readEnd - readStart;
                fid = fopen(obj.filePath, 'r');
                try
                    fseek(fid, readStart * 4, 'bof');
                    newData = fread(fid, readLength, 'single');
                catch ME
                    fclose(fid);
                    rethrow(ME);
                end
                fclose(fid);
                
                % Piece together the new data buffer from what we already had and what was just read in.
                oldDataSize = (EgnorRecording.bufferSize - readLength);
                if readStart > startSample
                    obj.data = [obj.data((end - oldDataSize + 1):end); newData];
                elseif readEnd < endSample
                    obj.data = [newData; obj.data(1:oldDataSize)];
                else
                    obj.data = newData;
                end
                
                % Remember which chunk we've got loaded.
                obj.dataStartSample = startSample;
            end
        end
        
        
        function [data, offset] = dataInTimeRange(obj, timeRange)
            fullRange = floor((timeRange + obj.timeOffset) * obj.sampleRate);
            sampleRange = fullRange;
            if sampleRange(1) < 1
                sampleRange(1) = 1;
            end
            if sampleRange(2) > obj.sampleCount
                sampleRange(2) = obj.sampleCount;
            end
            
            if sampleRange(2) - sampleRange(1) > EgnorRecording.bufferSize
                % The requested range is too big to load in all at once.
                data = [];
            else
                if sampleRange(1) < obj.dataStartSample || sampleRange(2) > obj.dataStartSample + EgnorRecording.bufferSize
                    % At least some of the requested data is not currently loaded.
                    obj.loadDataBuffer(sampleRange(1));
                end
                data = obj.data((sampleRange(1)) - obj.dataStartSample + 1:(sampleRange(2) - obj.dataStartSample));
            end
            offset = (sampleRange(1) - fullRange(1)) / obj.sampleRate;
        end
        
        % TODO: override maxAmplitude?
        
        
        function f = format(obj) %#ok<MANU>
            f = 'Egnor lab ''.ch'' audio';
        end
        
    end
    
end
