classdef VideoPanel < TempoPanel

	properties (SetAccess = private)
        video
        
        showFrameNum = true
    end
    
    properties (Access = private, Transient)
        currentFrameImage
        currentFrameNum
        
        imageHandle
        frameNumHandle
        
        lastDrawNowUpdate
    end
	
    
	methods
	
		function obj = VideoPanel(controller, recording)
			obj = obj@TempoPanel(controller, recording);
            
            obj.panelType = 'Video';
            
            obj.video = recording;
            obj.setTitle(obj.video.name);
            
            [obj.currentFrameImage, obj.currentFrameNum] = obj.frameAtTime(obj.controller.currentTime);
            
            set(obj.panel, 'BackgroundColor', 'black');
            
            obj.lastDrawNowUpdate = now;
        end
        
        
        function [frameImage, frameNum] = frameAtTime(obj, frameTime)
            [frameImage, frameNum] = obj.video.frameAtTime(frameTime);
            if ismatrix(frameImage)
                % Convert monochrome to grayscale.
                frameImage = repmat(frameImage, [1 1 3]);
            end
        end
        
        
        function createControls(obj, ~, ~)
            obj.imageHandle = image(obj.currentFrameImage, 'HitTest', 'off');
            axis(obj.axes, 'image');
            set(obj.axes, 'XTick', [], 'YTick', [], 'Color', 'black');
            
            obj.frameNumHandle = uicontrol(...
                'Parent', obj.panel,...
                'Units', 'points', ...
                'FontSize', 12, ...
                'HorizontalAlignment', 'left', ...
                'Position', [16 16 90 18], ...
                'String',  'Frame 1', ...
                'Style', 'text');
            if ~obj.showFrameNum
                set(obj.frameNumHandle, 'Visible', 'off');
            end
        end
        
        
        function showFrameNumber(obj, show)
            if obj.showFrameNum ~= show
                obj.showFrameNum = show;
                if obj.showFrameNum
                    set(obj.frameNumHandle, 'Visible', 'on');
                else
                    set(obj.frameNumHandle, 'Visible', 'off');
                end
            end
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
            set(obj.frameNumHandle, 'Position', [axesPos(1), axesPos(2), 80, 14]);
        end
        
        
        function currentTimeChanged(obj)
            if isempty(obj.video)
                return
            end
            
            [frameImage, frameNum] = obj.frameAtTime(obj.controller.currentTime);
            
            if isempty(obj.currentFrameNum) || frameNum ~= obj.currentFrameNum
                obj.currentFrameImage = frameImage;
                obj.currentFrameNum = frameNum;
                
                set(obj.imageHandle, 'CData', obj.currentFrameImage);
                
                set(obj.frameNumHandle, 'String', sprintf('Frame %d', frameNum));
                
                % Force a redraw of the frame.
                % Also check for events twice a second to allow non-timer events to be processed so we don't lock up MATLAB.
                % This gives us a 30+% increase in frame rate.
                if now - obj.lastDrawNowUpdate > 0.5 / (24 * 60 * 60)
                    % Redraw the frame and check for events.
                    drawnow
                    obj.lastDrawNowUpdate = now;
                else
                    % Just redraw the frame.
                    drawnow expose
                end
                
                % For FPS calculation.
                obj.controller.fpsFrameCount = obj.controller.fpsFrameCount + 1;
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
                    timeChange = -obj.controller.currentTime + stepSize / 2.0;
                elseif isempty(keyEvent.Modifier)
                    timeChange = -stepSize;
                end
            elseif strcmp(keyEvent.Key, 'rightarrow')
                if cmdDown
                    timeChange = obj.controller.duration - obj.controller.currentTime - stepSize / 2.0;
                elseif isempty(keyEvent.Modifier)
                    timeChange = stepSize;
                end
            end
            
            if timeChange ~= 0
                newTime = max([stepSize / 2.0, min([obj.controller.duration - stepSize / 2.0, obj.controller.currentTime + timeChange])]);
                obj.controller.currentTime = newTime;
                obj.controller.centerDisplayAtTime(newTime);
                
                handled = true;
            else
                handled = keyWasPressed@TempoPanel(obj, keyEvent);
            end
        end
        
        
	end
	
end
