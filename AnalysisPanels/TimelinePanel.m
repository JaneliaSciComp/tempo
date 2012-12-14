classdef TimelinePanel < AnalysisPanel
	
	properties
        timeLine
        selectionPatch
	end
	
	methods
		
		function obj = TimelinePanel(controller)
			obj = obj@AnalysisPanel(controller);
            
            obj.axesBorder = [0 0 16 0];
            
            % Use a line to indicate the current time in the axes.
            obj.timeLine = line([0 0], [-100000 200000], 'Color', [1 0 0], 'HitTest', 'off', 'HandleVisibility', 'off');
            
            % Use a filled rectangle to indicate the current selection in the axes.
            obj.selectionPatch = patch([0 1 1 0], [-100000 -100000 200000 200000], 'r', 'FaceAlpha', 0.2, 'EdgeColor', 'none', 'Visible', 'off', 'HitTest', 'off', 'HandleVisibility', 'off');
            
            % Add listeners so we know when the current time and selection change.
            addlistener(obj.controller, 'displayedTime', 'PostSet', @(source, event)handleTimeWindowChanged(obj, source, event));
            addlistener(obj.controller, 'timeWindow', 'PostSet', @(source, event)handleTimeWindowChanged(obj, source, event));
            addlistener(obj.controller, 'selectedTime', 'PostSet', @(source, event)handleSelectedTimeChanged(obj, source, event));
            
            obj.handleSelectedTimeChanged();
            obj.handleTimeWindowChanged();
		end
        
        
        function handleSelectedTimeChanged(obj, ~, ~)
            if obj.visible
                % Update the position and visibility of the current selection indicator.
                if obj.controller.selectedTime(1) ~= obj.controller.selectedTime(2)
                    selectionStart = min(obj.controller.selectedTime);
                    selectionEnd = max(obj.controller.selectedTime);
                    set(obj.selectionPatch, 'XData', [selectionStart selectionEnd selectionEnd selectionStart], 'Visible', 'on');
                else
                    set(obj.selectionPatch, 'Visible', 'off');
                end
            end
        end
        
        
        function handleTimeWindowChanged(obj, ~, ~)
            if obj.visible
                % Update the range of time being displayed in the axes.
                minTime = obj.controller.displayedTime - obj.controller.timeWindow / 2;
                if minTime < 0
                    minTime = 0;
                end
                maxTime = minTime + obj.controller.timeWindow;
                if maxTime > obj.controller.duration
                    maxTime = obj.controller.duration;
                    minTime = maxTime - obj.controller.timeWindow;
                end
                set(obj.axes, 'XLim', [minTime maxTime]);
                
                % Let the subclass update the axes content.
                obj.updateAxes([minTime maxTime])
            end
        end
        
        
        function showSelection(obj, flag)
            if obj.visible
                % Show or hide the current time line and selected time indicators.
                if flag
                    set(obj.timeLine, 'Visible', 'on');
                    if obj.controller.selectedTime(1) ~= obj.controller.selectedTime(2)
                        set(obj.selectionPatch, 'Visible', 'on');
                    else
                        set(obj.selectionPatch, 'Visible', 'off');
                    end
                else
                    set([obj.timeLine, obj.selectionPatch], 'Visible', 'off');
                end
            end
        end
        
        
        function currentTimeChanged(obj)
            % Update the position of the current time indicator.
            set(obj.timeLine, 'XData', [obj.controller.currentTime obj.controller.currentTime]);
        end
        
        
        function updateAxes(obj, timeRange) %#ok<INUSD,MANU>
            % TODO: make abstract?
        end
		
        
        function handled = keyWasPressed(obj, keyEvent)
            % Handle keyboard navigation of the timeline.
            % Arrow keys move the display left/right by one tenth of the displayed range.
            % Page up/down moves left/right by a full window's worth.
            % Command+arrow keys moves to the beginning/end of the timeline.
            % Option+left/right arrow key moves to the previous/next feature.
            % Shift plus any of the above extends the selection.
            % Up/down arrow keys zoom out/in
            % Command+up arrow zooms all the way out
            timeChange = 0;
            timeRange = obj.controller.displayedTimeRange();
            pageSize = timeRange(2) - timeRange(1);
            stepSize = pageSize / 10;
            shiftDown = any(ismember(keyEvent.Modifier, 'shift'));
            altDown = any(ismember(keyEvent.Modifier, 'alt'));
            cmdDown = any(ismember(keyEvent.Modifier, 'command'));
            if strcmp(keyEvent.Key, 'leftarrow')
                if cmdDown
                    timeChange = -obj.controller.currentTime;
                elseif ~altDown
                    timeChange = -stepSize;
                end
            elseif strcmp(keyEvent.Key, 'rightarrow')
                if cmdDown
                    timeChange = obj.controller.duration - obj.controller.currentTime;
                elseif ~altDown
                    timeChange = stepSize;
                end
            elseif strcmp(keyEvent.Key, 'pageup')
                timeChange = -pageSize;
            elseif strcmp(keyEvent.Key, 'pagedown')
                timeChange = pageSize;
            elseif strcmp(keyEvent.Key, 'uparrow')
                if cmdDown
                    obj.controller.setZoom(1);
                else
                    obj.controller.setZoom(obj.controller.zoom / 2);
                end
            elseif strcmp(keyEvent.Key, 'downarrow')
                % TODO: is there a maximum zoom that could be set if command was down?
                obj.controller.setZoom(obj.controller.zoom * 2);
            end

            if timeChange ~= 0
                set(obj.controller.figure, 'Pointer', 'watch'); drawnow
                
                newTime = max([0 min([obj.controller.duration obj.controller.currentTime + timeChange])]);
                if shiftDown
                    if obj.controller.currentTime == obj.controller.selectedTime(1)
                        obj.controller.selectedTime = sort([obj.controller.selectedTime(2) newTime]);
                    else
                        obj.controller.selectedTime = sort([newTime obj.controller.selectedTime(1)]);
                    end
                else
                    obj.controller.selectedTime = [newTime newTime];
                end
                obj.controller.currentTime = newTime;
                obj.controller.displayedTime = newTime;
                
                set(obj.controller.figure, 'Pointer', 'arrow'); drawnow update
                
                handled = true;
            else
                handled = keyWasPressed@AnalysisPanel(obj, keyEvent);
            end
        end
        
	end
	
end
