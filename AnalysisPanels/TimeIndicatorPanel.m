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
        
        
        function handleSelectedRangeChanged(obj, ~, ~)
            if ~isempty(obj.controller.displayRange)
                obj.updateAxes([]);
            end
        end
        
        
        function updateAxes(obj, timeRange)
            set(obj.controller.figure, 'CurrentAxes', obj.axes);
            cla;
            
            if isempty(timeRange)
                timeRange = get(obj.axes, 'XLim');
            end
            
            axesPos = get(obj.axes, 'Position');
            timePixels = (obj.controller.displayRange(2) - obj.controller.displayRange(1)) / axesPos(3);
            charPixelWidth = 6;
            labelWidth = charPixelWidth * 8 * timePixels;
            
            textY = 0.05;
            textFont = 'FixedWidth';
            redColor = [0.5 0.0 0.0];
            
            % TODO: draw time ticks
            % Use obj.controller.displayRange(2) to determine number of ticks
% TODO:            
%             timeScale = fix(log10(obj.controller.displayRange(2) - obj.controller.displayRange(1)));
%             if obj.controller.displayRange(2) - obj.controller.displayRange(1) < 1
%                 timeScale = timeScale - 1;
%             end
%             tickSpacing = 10 ^ timeScale * sampleRate;
%             set(handles.oscillogram, 'XTick', tickSpacing-mod(minSample, tickSpacing):tickSpacing:windowSampleCount);
            
            % TODO: If the current time is off screen then the tick closest to the center should show the full time.
            
            if obj.controller.selectedRange(1) == obj.controller.selectedRange(2)
                % Draw current time indicator
                if obj.controller.currentTime > timeRange(1) && obj.controller.currentTime < timeRange(2)
                    line([obj.controller.currentTime obj.controller.currentTime], [0.8 1], 'Color', 'red');
                    text(obj.controller.currentTime, textY, secondstr(obj.controller.currentTime, obj.controller.timeLabelFormat, 2), ...
                        'VerticalAlignment', 'baseline', 'HorizontalAlignment', 'center', ...
                        'FontName', textFont, 'Color', redColor);
                end
            else
                % Draw range start, range end, range size and current time indicators
                startInRange = obj.controller.selectedRange(1) > timeRange(1) && obj.controller.selectedRange(1) < timeRange(2);
                endInRange = obj.controller.selectedRange(2) > timeRange(1) && obj.controller.selectedRange(2) < timeRange(2);
                if startInRange
                    line([obj.controller.selectedRange(1) obj.controller.selectedRange(1)], [0.8 1], 'Color', 'red');
                    text(obj.controller.selectedRange(1), textY, secondstr(obj.controller.selectedRange(1), obj.controller.timeLabelFormat, 2), ...
                        'VerticalAlignment', 'baseline', 'HorizontalAlignment', 'center', ...
                        'FontName', textFont, 'Color', redColor);
                end
                if endInRange
                    line([obj.controller.selectedRange(2) obj.controller.selectedRange(2)], [0.8 1], 'Color', 'red');
                    text(obj.controller.selectedRange(2), textY, secondstr(obj.controller.selectedRange(2), obj.controller.timeLabelFormat, 2), ...
                        'VerticalAlignment', 'baseline', 'HorizontalAlignment', 'center', ...
                        'FontName', textFont, 'Color', redColor);
                end
                selectionInRange = obj.controller.selectedRange(1) < timeRange(2) || obj.controller.selectedRange(2) > timeRange(1);
                currentTimeAmidRange = obj.controller.currentTime ~= obj.controller.selectedRange(1) && obj.controller.currentTime ~= obj.controller.selectedRange(2);
                if selectionInRange && ~currentTimeAmidRange % TODO: && there is room
                    midPoint = sum(obj.controller.selectedRange(1:2)) / 2.0;
                    grayColor = [0.75 0.5 0.5];
                    line([obj.controller.selectedRange(1) + labelWidth * 0.75, obj.controller.selectedRange(1) + labelWidth * 0.75], [0.2 0.6], 'Color', grayColor);
                    line([obj.controller.selectedRange(1) + labelWidth * 0.75, midPoint - labelWidth * 0.5], [0.4 0.4], 'Color', grayColor);
                    line([midPoint + labelWidth * 0.5, obj.controller.selectedRange(2) - labelWidth * 0.75], [0.4 0.4], 'Color', grayColor);
                    line([obj.controller.selectedRange(2) - labelWidth * 0.75, obj.controller.selectedRange(2) - labelWidth * 0.75], [0.2 0.6], 'Color', grayColor);
                    text(midPoint, textY, secondstr(obj.controller.selectedRange(2) - obj.controller.selectedRange(1), obj.controller.timeLabelFormat), ...
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
            if ~isempty(obj.controller.displayRange)
                obj.updateAxes([]);
            end
        end
        
	end
	
end
