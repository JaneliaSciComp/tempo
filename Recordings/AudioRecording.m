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
            try
                audioinfo(filePath);
                canLoad = true;
            catch
            end
        end
    end
    
    methods
        
        function obj = AudioRecording(controller, varargin)
            obj = obj@Recording(controller, varargin{:});
        end
        
        
        function loadData(obj)
            if ~isempty(obj.filePath)
                [obj.data, obj.sampleRate] = audioread(obj.filePath, 'native');
                obj.data = double(obj.data);
                obj.sampleCount = length(obj.data);

                obj.audioPlayer = audioplayer(obj.data, obj.sampleRate);
                obj.audioPlayer.TimerPeriod = 1.0 / 15.0;
            end
        end
        
        
        function d = dataInTimeRange(obj, timeRange)
            sampleRange = floor((timeRange + obj.timeOffset) * obj.sampleRate);
            if sampleRange(1) < 1
                sampleRange(1) = 1;
            end
            if sampleRange(2) > length(obj.data)
                sampleRange(2) = length(obj.data);
            end
            d = obj.data(sampleRange(1):sampleRange(2));
        end
        
        
        function m = maxAmplitude(obj)
            if isempty(obj.maxAmp)
                obj.maxAmp = max(obj.data);
            end
            m = obj.maxAmp;
        end
        
    end
    
end
