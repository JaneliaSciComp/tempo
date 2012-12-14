classdef TimeIndicatorPanel < TimelinePanel

	properties
        currentTimeHandle
        selectedTimeStartHandle
        selectedTimeEndHandle
	end
	
	methods
	
		function obj = TimeIndicatorPanel(controller, varargin)
			obj = obj@TimelinePanel(controller, varargin{:});
        end
	    
        
	    function createControls(obj, ~)
            set(obj.controller.figure, 'CurrentAxes', obj.axes);
            
%             obj.currentTimeHandle = text(0, 0.5, '', 'HitTest', 'off');
%             obj.selectedTimeStartHandle = text(0, 0.5, '', 'Visible', 'off', 'HitTest', 'off');
%             obj.selectedTimeEndHandle = text(0, 0.5, '', 'Visible', 'off', 'HitTest', 'off');
            
            % Get rid of the default current time and selection indicators.
            delete(obj.timeLine);
            obj.timeLine = [];
            delete(obj.selectionPatch);
            obj.selectionPatch = [];
        end
        
        
        function handleSelectedTimeChanged(obj, ~, ~)
            obj.updateAxes([]);
        end
        
        
        function updateAxes(obj, timeRange)
            set(obj.controller.figure, 'CurrentAxes', obj.axes);
            cla;
            
            if isempty(timeRange)
                timeRange = get(obj.axes, 'XLim');
            end
            
            axesPos = get(obj.axes, 'Position');
            timePixels = obj.controller.timeWindow / axesPos(3);
            charPixelWidth = 6;
            labelWidth = charPixelWidth * 8 * timePixels;
            
            textY = 0.05;
            textFont = 'FixedWidth';
            redColor = [0.5 0.0 0.0];
            
            
            if obj.controller.selectedTime(1) == obj.controller.selectedTime(2)
                % TODO: draw time ticks and current time indicator
                % Use obj.controller.timeWindow to determine number of ticks
                % If the current time is off screen then the tick closest to the center should show the full time.
                if obj.controller.currentTime > timeRange(1) && obj.controller.currentTime < timeRange(2)
                    line([obj.controller.currentTime obj.controller.currentTime], [0.8 1], 'Color', 'red');
                    text(obj.controller.currentTime, textY, secondstr(obj.controller.currentTime, obj.controller.timeLabelFormat, 2), ...
                        'VerticalAlignment', 'baseline', 'HorizontalAlignment', 'center', ...
                        'FontName', textFont, 'Color', redColor);
                end
            else
                % TODO: draw range start, range end, range size and current time indicators
                startInRange = obj.controller.selectedTime(1) > timeRange(1) && obj.controller.selectedTime(1) < timeRange(2);
                endInRange = obj.controller.selectedTime(2) > timeRange(1) && obj.controller.selectedTime(2) < timeRange(2);
                if startInRange
                    line([obj.controller.selectedTime(1) obj.controller.selectedTime(1)], [0.8 1], 'Color', 'red');
                    text(obj.controller.selectedTime(1), textY, secondstr(obj.controller.selectedTime(1), obj.controller.timeLabelFormat, 2), ...
                        'VerticalAlignment', 'baseline', 'HorizontalAlignment', 'center', ...
                        'FontName', textFont, 'Color', redColor);
                end
                if endInRange
                    line([obj.controller.selectedTime(2) obj.controller.selectedTime(2)], [0.8 1], 'Color', 'red');
                    text(obj.controller.selectedTime(2), textY, secondstr(obj.controller.selectedTime(2), obj.controller.timeLabelFormat, 2), ...
                        'VerticalAlignment', 'baseline', 'HorizontalAlignment', 'center', ...
                        'FontName', textFont, 'Color', redColor);
                end
                selectionInRange = obj.controller.selectedTime(1) < timeRange(2) || obj.controller.selectedTime(2) > timeRange(1);
                currentTimeAmidRange = obj.controller.currentTime ~= obj.controller.selectedTime(1) && obj.controller.currentTime ~= obj.controller.selectedTime(2);
                if selectionInRange && ~currentTimeAmidRange % TODO: && there is room
                    midPoint = sum(obj.controller.selectedTime) / 2.0;
                    grayColor = [0.75 0.5 0.5];
                    line([obj.controller.selectedTime(1) + labelWidth * 0.75, obj.controller.selectedTime(1) + labelWidth * 0.75], [0.2 0.6], 'Color', grayColor);
                    line([obj.controller.selectedTime(1) + labelWidth * 0.75, midPoint - labelWidth * 0.5], [0.4 0.4], 'Color', grayColor);
                    line([midPoint + labelWidth * 0.5, obj.controller.selectedTime(2) - labelWidth * 0.75], [0.4 0.4], 'Color', grayColor);
                    line([obj.controller.selectedTime(2) - labelWidth * 0.75, obj.controller.selectedTime(2) - labelWidth * 0.75], [0.2 0.6], 'Color', grayColor);
                    text(midPoint, textY, secondstr(obj.controller.selectedTime(2) - obj.controller.selectedTime(1), obj.controller.timeLabelFormat), ...
                        'VerticalAlignment', 'baseline', 'HorizontalAlignment', 'center', ...
                        'FontName', textFont, 'Color', grayColor);
                end
            end
        end
        
        
        function addTimeLabel(obj, time, color)
        end
        
        
        function showSelection(obj, flag)
            % TODO: hide range size indicator?
        end
        
        
        function currentTimeChanged(obj)
            obj.updateAxes([]);
        end
        
	end
	
end
