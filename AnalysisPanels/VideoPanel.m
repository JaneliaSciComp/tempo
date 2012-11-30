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
		end
        
        
        function createControls(obj, panelSize)
            obj.imageHandle = image(panelSize(1), panelSize(2), zeros(panelSize), ...
                'HitTest', 'off');
            set(obj.axes, 'XTick', [], 'YTick', []);
            axis image;
        end
        
        
        function resizeControls(obj, ~)
            set(gcf, 'CurrentAxes', obj.axes);
            cla;
            obj.imageHandle = image(obj.currentFrame);
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
