classdef VideoPanel < AnalysisPanel

	properties
        video
        
        currentFrame
        
        imageHandle
	end
	
	methods
	
		function obj = VideoPanel(controller, recording)
			obj = obj@AnalysisPanel(controller);
            
            obj.video = recording;
            
            frameNum = min([floor(obj.controller.currentTime * obj.video.sampleRate + 1) obj.video.videoReader.NumberOfFrames]);
            obj.currentFrame = read(obj.video.videoReader, frameNum);
		end
        
        
        function createControls(obj, ~)
            obj.imageHandle = image(obj.currentFrame, 'HitTest', 'off');
            axis(obj.axes, 'image');
            set(obj.axes, 'XTick', [], 'YTick', []);
        end
        
        
        function resizeControls(obj, ~)
            set(gcf, 'CurrentAxes', obj.axes);
            cla;
            obj.imageHandle = image(obj.currentFrame, 'HitTest', 'off');
            axis(obj.axes, 'image');
            set(obj.axes, 'XTick', [], 'YTick', []);
        end
        
        
        function currentTimeChanged(obj)
            if isempty(obj.video)
                return
            end
            
            frameNum = min([floor(obj.controller.currentTime * obj.video.sampleRate + 1) obj.video.videoReader.NumberOfFrames]);
            obj.currentFrame = read(obj.video.videoReader, frameNum);
            set(obj.imageHandle, 'CData', obj.currentFrame);
        end
        
	end
	
end
