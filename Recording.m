classdef Recording < handle
    
    properties
        name
        filePath
        data
        sampleRate
        duration
        videoReader
        isAudio = false
        isVideo = false
    end
    
    
    properties (Access = private)
        detectorList = {};
    end
    
    
    methods
        
        function obj = Recording(filePath, varargin)
            obj = obj@handle();
            
            obj.filePath = filePath;
            [~, obj.name, ext] = fileparts(filePath);
            
            if strcmp(ext, '.wav')
                obj.isAudio = true;
                [obj.data, obj.sampleRate] = wavread(filePath, 'native');
                obj.data = double(obj.data);
                obj.duration = length(obj.data) / obj.sampleRate;
            elseif strcmp(ext, '.avi')
                obj.isVideo = true;
                obj.videoReader = VideoReader(filePath);
                obj.data = [];
                obj.sampleRate = get(obj.videoReader, 'FrameRate');
                obj.duration = get(obj.videoReader, 'Duration');
            end
        end
        
        
        function addDetector(obj, detector)
            obj.detectorList{end + 1} = detector;
        end
        
        
        function removeDetector(obj, detector)
            index = find(obj.detectorList == detector);
            obj.detectorList{index} = []; %#ok<FNDSB>
        end
        
        
        function d = detectors(obj)
            % This function allows one detector to use the results of another, e.g. detecting pulse trains from a list of pulses.
            
            d = obj.detectorList;
        end
        
    end
    
end
