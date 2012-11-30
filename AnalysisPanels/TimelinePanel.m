classdef TimelinePanel < AnalysisPanel
	
	properties
        timeLine
        selectionPatch
	end
	
	methods
		
		function obj = TimelinePanel(controller)
			obj = obj@AnalysisPanel(controller);
            
            % Use a line to indicate the current time in the axes.
            obj.timeLine = line([0 0], [-100000 200000], 'Color', [1 0 0]);
            set(obj.timeLine, 'HitTest', 'off');
            
            % Use a filled rectangle to indicate the current selection in the axes.
            obj.selectionPatch = patch([0 1 1 0], [-100000 -100000 200000 200000], 'r', 'FaceAlpha', 0.2, 'EdgeColor', 'none', 'Visible', 'off');
            set(obj.selectionPatch, 'HitTest', 'off');
            
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
		
	end
	
end
