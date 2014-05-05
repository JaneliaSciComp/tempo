classdef VideoRecording < Recording
    
    properties (Transient)
        videoReader
    end
    
    properties
        videoSize = [0 0]
        timeStamps = []
    end
    
    
    methods (Static)
        function canLoad = canLoadFromPath(filePath)
            canLoad = false;
            try
                info = mmfileinfo(filePath);
                if ~isempty(info) && isfield(info, 'Video') && isfield(info.Video, 'Height') && ~isempty(info.Video.Height) && info.Video.Height > 0
                    canLoad = true;
                end
            catch ME
                if ~strcmp(ME.identifier, 'MATLAB:audiovideo:VideoReader:InitializationFailed') && ...
                   ~strcmp(ME.identifier, 'MATLAB:audiovideo:VideoReader:NoVideo') && ...
                   ~strcmp(ME.identifier, 'MATLAB:audiovideo:VideoReader:FileCorrupt')
                    disp('Tempo could not check if a file is video:');
                    disp(getReport(ME));
                end
            end
        end
    end
    
    methods
        
        function obj = VideoRecording(controller, varargin)
            obj = obj@Recording(controller, varargin{:});
        end
        
        
        function loadData(obj)
            obj.videoReader = VideoReader(obj.filePath);
            obj.sampleRate = get(obj.videoReader, 'FrameRate');
            obj.sampleCount = get(obj.videoReader, 'NumberOfFrames');
            obj.videoSize = [get(obj.videoReader, 'Height') get(obj.videoReader, 'Width')];
            [d,n,~]=fileparts(obj.filePath);
            tmp=fullfile(d,[n '.ts']);
            if exist(tmp,'file')
                fid=fopen(tmp,'r');
                obj.timeStamps=fread(fid,'double');
                obj.timeStamps(end)=inf;
                fclose(fid);
            end
        end
        
        
        function [frameImage, frameNum] = frameAtTime(obj, time)
            if isempty(obj.timeStamps)
                frameNum = floor((time + obj.timeOffset) * obj.sampleRate + 1);
            else
                frameNum = find((time + obj.timeOffset) < obj.timeStamps,1);
            end
            frameNum = min(frameNum,obj.sampleCount);
            frameImage = read(obj.videoReader, frameNum);
        end
        
        
        function ret_val = saveData(obj)
            ret_val = [tempname 'v.mp4'];
            frameBegin = min([floor((obj.controller.selectedRange(1) + obj.timeOffset) * obj.sampleRate + 1) obj.sampleCount]);
            frameEnd = min([floor((obj.controller.selectedRange(2) + obj.timeOffset) * obj.sampleRate + 1) obj.sampleCount]);
            d = read(obj.videoReader, [frameBegin frameEnd]);
            out=VideoWriter(ret_val,'MPEG-4');
            set(out,'FrameRate',obj.sampleRate);
            open(out);
            writeVideo(out,d);
            close(out);

       end

        
% Previous frame buffering code in case it's ever useful again:
%         function newHandles = updateVideo(handles)
%             % Display the current frame of video.
%             frameNum = min([floor(handles.currentTime * handles.video.sampleRate + 1) handles.video.videoReader.NumberOfFrames]);
%             if isfield(handles, 'videoBuffer')
%                 if frameNum >= handles.videoBufferStartFrame && frameNum < handles.videoBufferStartFrame + handles.videoBufferSize
%                     % TODO: is it worth optimizing the overlap case?
%                     %['Grabbing ' num2str(handles.videoBufferSize) ' more frames']
%                     handles.videoBuffer = read(handles.video.videoReader, [frameNum frameNum + handles.videoBufferSize - 1]);
%                     handles.videoBufferStartFrame = frameNum;
%                     guidata(get(handles.videoFrame, 'Parent'), handles);    % TODO: necessary with newFeatures?
%                 end
%                 frame = handles.videoBuffer(:, :, :, frameNum - handles.videoBufferStartFrame + 1);
%             else
%                 frame = read(handles.video.videoReader, frameNum);
%             end
%         end
        
    end
    
end
