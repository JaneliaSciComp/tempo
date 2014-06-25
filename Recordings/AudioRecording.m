classdef AudioRecording < Recording
    
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
                    [obj.data, obj.sampleRate] = wavread(obj.filePath, 'native');
                else
                    [obj.data, obj.sampleRate] = audioread(obj.filePath, 'native');
                end
                obj.data = double(obj.data(:,obj.channel));
                obj.sampleCount = length(obj.data);
            end
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
            % If the returned data doesn't begin at the start of the time range then a non-zero offset will be returned.
            
            fullRange = floor((timeRange + obj.timeOffset) * obj.sampleRate);
            sampleRange = fullRange;
            if sampleRange(1) < 1
                sampleRange(1) = 1;
            end
            if sampleRange(2) > length(obj.data)
                sampleRange(2) = length(obj.data);
            end
            data = obj.data(sampleRange(1):sampleRange(2));
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
            frameBegin = min([floor((obj.controller.selectedRange(1) + obj.timeOffset) * obj.sampleRate + 1) obj.sampleCount]);
            frameEnd = min([floor((obj.controller.selectedRange(2) + obj.timeOffset) * obj.sampleRate + 1) obj.sampleCount]);
            obj.data(frameBegin:frameEnd);
            resample(ans,48000,obj.sampleRate);
            ans./(max(abs(ans))+eps);
            audiowrite(ret_val,ans,48000);
        end
    end
    
end
