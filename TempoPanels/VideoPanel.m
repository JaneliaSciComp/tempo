classdef VideoPanel < TempoPanel

	properties
        video
        
        currentFrameImage
        currentFrameNum
        currentTime
        
        imageHandle
        frameCountHandle
	end
	
	methods
	
		function obj = VideoPanel(controller, recording)
			obj = obj@TempoPanel(controller);
            
            obj.video = recording;
            
            [obj.currentFrameImage, obj.currentFrameNum] = obj.frameAtTime(obj.controller.currentTime);
            obj.currentTime = obj.controller.currentTime;
            
            set(obj.panel, 'BackgroundColor', 'black');
        end
        
        
        function [frameImage, frameNum] = frameAtTime(obj, frameTime)
            [frameImage, frameNum] = obj.video.frameAtTime(frameTime);
            if ismatrix(frameImage)
                % Convert monochrome to grayscale.
                frameImage = repmat(frameImage, [1 1 3]);
            end
        end
        
        
        function createControls(obj, ~)
            obj.imageHandle = image(obj.currentFrameImage, 'HitTest', 'off');
            axis(obj.axes, 'image');
            set(obj.axes, 'XTick', [], 'YTick', [], 'Color', 'black');
            
            obj.frameCountHandle = uicontrol(...
                'Parent', obj.panel,...
                'Units', 'points', ...
                'FontSize', 12, ...
                'HorizontalAlignment', 'left', ...
                'Position', [21 80 90 18], ...
                'String',  'Frame 123', ...
                'Style', 'text');
        end
        
        
        function resizeControls(obj, ~)
            % Have the image object fill the entire axes.
            set(gcf, 'CurrentAxes', obj.axes);
            cla;
            obj.imageHandle = image(obj.currentFrameImage, 'HitTest', 'off');
            axis(obj.axes, 'image');
            set(obj.axes, 'XTick', [], 'YTick', []);
            
            % Position the frame count label in the lower-left corner.
            axesPos = get(obj.axes, 'Position');
            set(obj.frameCountHandle, 'Position', [axesPos(1) + 5, axesPos(2) + 5, 70, 12]);
        end
        
        
        function currentTimeChanged(obj)
            if isempty(obj.video)
                return
            end
            
            if obj.controller.currentTime ~= obj.currentTime
                [frameImage, frameNum] = obj.frameAtTime(obj.controller.currentTime);
                
                if frameNum ~= obj.currentFrameNum
                    obj.currentFrameImage = frameImage;
                    obj.currentFrameNum = frameNum;
                    
                    set(obj.imageHandle, 'CData', obj.currentFrameImage);
                    
                    set(obj.frameCountHandle, 'String', sprintf('Frame %d', frameNum));
                    
                    % Force a redraw of the frame and allow non-timer events to be processed so we don't lock up MATLAB.
                    drawnow
                    
                    obj.currentTime = obj.controller.currentTime;
                    
                    % For FPS calculation.
                    obj.controller.frameCount = obj.controller.frameCount + 1;
                end
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
                handled = keyWasPressed@TempoPanel(obj, keyEvent);
            end
        end
        
        
	end
	
end
