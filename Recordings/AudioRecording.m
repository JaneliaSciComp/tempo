classdef AudioRecording < Recording
    
    properties (Constant)
        bufferSize = 16 * 1024 * 1024;  % The maximum number of samples to load at any time.
    end
    
    properties (Transient)
        dataStartSample = -Inf
    end
    
    properties
        maxAmp
        channel
    end
    
    properties(Transient,GetAccess=protected)
        audioPlayer
    end
    
    
    methods (Static)
        function canLoad = canLoadFromPath(filePath)
            canLoad = false;
            if isempty(which('audioinfo'))
                try
                    if ~isempty(wavfinfo(filePath))
                        canLoad = true;
                    end
                    
                catch
                end
            else
                try
                    audioinfo(filePath);
                    canLoad = true;
                catch
                end
            end
        end
    end
    
    methods
        
        function obj = AudioRecording(controller, varargin)
            obj = obj@Recording(controller, varargin{:});
        end
        
        
        function addParameters(obj, parser)
            addParameters@Recording(obj, parser);
            
            addParamValue(parser, 'Channel', [], @(x) isnumeric(x) && isscalar(x));
        end
        
        
        function loadParameters(obj, parser)
            loadParameters@Recording(obj, parser);
            obj.channel = parser.Results.Channel;
            
            if isempty(obj.channel)
                if isempty(which('audioinfo'))
                    wavread(obj.filePath,'size');
                    nchan=ans(2);
                else
                    audioinfo(obj.filePath);
                    nchan=ans.NumChannels;
                end
                
                obj.channel=1;
                if nchan>1
                    [obj.channel, ok] = listdlg('ListString', cellstr(num2str((1:nchan)')), ...
                                                'PromptString', {'Choose the channel to open:'}, ...
                                                'SelectionMode', 'single', ...
                                                'Name', 'Open WAV File');
                    if ~ok
                        error('Tempo:UserCancelled', 'The user cancelled opening the WAV file.');
                    end
                end
            end
        end
        
        
        function loadData(obj)
            if ~isempty(obj.filePath)
                if isempty(which('audioread'))
                    info = wavread(obj.filePath, 'size');
                    obj.sampleCount = info(1);
                else
                    info = audioinfo(obj.filePath);
                    obj.sampleCount = info.TotalSamples;
                end
                obj.loadDataBuffer(1);
            end
        end
        

        function loadDataBuffer(obj, startSample)
            startSample = max([1, min([startSample, obj.sampleCount - obj.bufferSize])]);
            
            if startSample ~= obj.dataStartSample
                % Only read the data that we don't already have.
                endSample = startSample + obj.bufferSize;
                if startSample < obj.dataStartSample || startSample > obj.dataStartSample + obj.bufferSize
                    readStart = startSample;
                else
                    readStart = obj.dataStartSample + obj.bufferSize;
                end
                if endSample < obj.dataStartSample || endSample > obj.dataStartSample + obj.bufferSize
                    readEnd = endSample;
                else
                    readEnd = obj.dataStartSample;
                end
                readLength = min(obj.sampleCount-1, readEnd - readStart);
                newData = obj.readData(readStart, readLength);
                
                % Piece together the new data buffer from what we already had and what was just read in.
                oldDataSize = (obj.bufferSize - readLength);
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
        

        function newData = readData(obj, readStart, readLength)
            if isempty(which('audioread'))
                [data, obj.sampleRate] = wavread(obj.filePath, [readStart readStart+readLength], 'native');
            else
                [data, obj.sampleRate] = audioread(obj.filePath, [readStart readStart+readLength], 'native');
            end
            newData = double(data(:,obj.channel));
        end
        
        
        function p = player(obj)
            if isempty(obj.audioPlayer) && ~isempty(obj.data)
                % Check if the data is playable.
                devID = audiodevinfo(0, obj.sampleRate, 16, 1);
                if devID ~= -1
                    obj.audioPlayer = audioplayer(obj.data, obj.sampleRate);
                    obj.audioPlayer.TimerPeriod = 1.0 / 15.0;
                end
            end
            
            p = obj.audioPlayer;
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
            
            if sampleRange(2) - sampleRange(1) > obj.bufferSize
                % The requested range is too big to load in all at once.
                data = [];
            else
                if sampleRange(1) < obj.dataStartSample || sampleRange(2) > obj.dataStartSample + obj.bufferSize
                    % At least some of the requested data is not currently loaded.
                    obj.loadDataBuffer(sampleRange(1));
                end
                data = obj.data((sampleRange(1)) - obj.dataStartSample + 1:(sampleRange(2) - obj.dataStartSample));
            end
            offset = (sampleRange(1) - fullRange(1)) / obj.sampleRate;
        end
        
        
        function m = maxAmplitude(obj)
            if isempty(obj.maxAmp)
                obj.maxAmp = max(obj.data);
            end
            m = obj.maxAmp;
        end
        
        function ret_val = saveData(obj)
            ret_val = [tempname 'a.mp4'];
            frameBegin = min([floor((obj.controller.selectedRange(1) + obj.timeOffset) * obj.sampleRate - obj.dataStartSample + 1) obj.sampleCount]);
            frameEnd = min([floor((obj.controller.selectedRange(2) + obj.timeOffset) * obj.sampleRate - obj.dataStartSample + 1) obj.sampleCount]);
            obj.data(frameBegin:frameEnd);
            resample(ans,48000,obj.sampleRate);
            ans./(max(abs(ans))+eps);
            audiowrite(ret_val,ans,48000);
        end
    end
    
end
