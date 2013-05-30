classdef VideoPanel < AnalysisPanel

	properties
        video
        
        currentFrame
        currentTime
        
        imageHandle
	end
	
	methods
	
		function obj = VideoPanel(controller, recording)
			obj = obj@AnalysisPanel(controller);
            
            obj.video = recording;
            
            %frameNum = min([floor(obj.controller.currentTime * obj.video.sampleRate + 1) obj.video.videoReader.NumberOfFrames]);
            %obj.currentFrame = read(obj.video.videoReader, frameNum);
            obj.currentFrame = obj.video.frameAtTime(obj.controller.currentTime);
            obj.currentTime = obj.controller.currentTime;
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
            
            if obj.controller.currentTime ~= obj.currentTime
                obj.currentFrame = obj.video.frameAtTime(obj.controller.currentTime);
                set(obj.imageHandle, 'CData', obj.currentFrame);
                obj.currentTime = obj.controller.currentTime;
            end
        end
        
        
        function handled = keyWasPressed(obj, keyEvent)
            % Handle keyboard navigation of the video.
            % Arrow keys move the display left/right by one frame.
            % Command+arrow keys moves to the beginning/end of the video.
            timeChange = 0;
            stepSize = 1 / obj.video.sampleRate;
            cmdDown = any(ismember(keyEvent.Modifier, 'command'));
            
            if strcmp(keyEvent.Key, 'leftarrow')
                if cmdDown
                    timeChange = -obj.controller.currentTime;
                elseif isempty(keyEvent.Modifier)
                    timeChange = -stepSize;
                end
            elseif strcmp(keyEvent.Key, 'rightarrow')
                if cmdDown
                    timeChange = obj.controller.duration - obj.controller.currentTime;
                elseif isempty(keyEvent.Modifier)
                    timeChange = stepSize;
                end
            end

            if timeChange ~= 0
                newTime = max([0 min([obj.controller.duration obj.controller.currentTime + timeChange])]);
                obj.controller.currentTime = newTime;
                obj.controller.centerDisplayAtTime(newTime);
                
                handled = true;
            else
                handled = keyWasPressed@AnalysisPanel(obj, keyEvent);
            end
        end
        
        
	end
	
end
