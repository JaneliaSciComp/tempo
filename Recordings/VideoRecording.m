classdef VideoRecording < Recording
    
    properties (Transient)
        videoReader
    end
    
    properties
        videoSize = [0 0]
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
                disp(getReport(ME));
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
        end
        
        
        function d = frameAtTime(obj, time)
            frameNum = min([floor((time + obj.timeOffset) * obj.sampleRate + 1) obj.sampleCount]);
            d = read(obj.videoReader, frameNum);
            
            if ndims(d) == 2 %#ok<ISMAT>
                % Convert monochrome to grayscale.
                d=repmat(d,[1 1 3]);
            end
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
