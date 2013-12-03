classdef AudioRecording < Recording
    
    properties
        maxAmp
    end
    
    properties(Transient)
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
        
        
        function loadData(obj)
            if ~isempty(obj.filePath)
                if isempty(which('audioread'))
                    [obj.data, obj.sampleRate] = wavread(obj.filePath, 'native');
                else
                    [obj.data, obj.sampleRate] = audioread(obj.filePath, 'native');
                end
                obj.data = double(obj.data);
                obj.sampleCount = length(obj.data);

                obj.audioPlayer = audioplayer(obj.data, obj.sampleRate);
                obj.audioPlayer.TimerPeriod = 1.0 / 15.0;
            end
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
