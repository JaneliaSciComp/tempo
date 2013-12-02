classdef TimeIndicatorPanel < TimelinePanel

	methods
	
		function obj = TimeIndicatorPanel(controller, varargin)
			obj = obj@TimelinePanel(controller, varargin{:});
        end
	    
        
	    function createControls(obj, ~)
            set(obj.controller.figure, 'CurrentAxes', obj.axes);
            
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
            
            textY = 0.15;
            textFont = 'FixedWidth';
            redColor = [0.5 0.0 0.0];
            
            % Draw regular time ticks.
            % Get as close to ten ticks as possible and align to integral (or certain fraction of) times, e.g. 1:40.0 or 1:40.25.
            % Don't draw ticks inside any selection.
            displayRange = obj.controller.displayRange(2) - obj.controller.displayRange(1);
            upperBound = 10.^nextpow10(displayRange);
            possibleSpacings = upperBound .* [1 / 2, 1 / 4, 1 / 5, 1 / 10, 1 / 20, 1 / 40, 1 / 50];
            tickCounts = displayRange ./ possibleSpacings;
            tickSpacing = possibleSpacings(find((tickCounts < 10), 1, 'last'));
            tickBase = floor(obj.controller.displayRange(1) / tickSpacing) * tickSpacing;
            tickCount = ceil(displayRange / tickSpacing);
            for i = 0:tickCount
                tickTime = tickBase + i * tickSpacing;
                if tickTime > (obj.controller.displayRange(1) - labelWidth) && ...
                   tickTime < (obj.controller.displayRange(2) + labelWidth) && ...
                   (tickTime < min(obj.controller.selectedRange(1:2)) - labelWidth || ...
                    tickTime > max(obj.controller.selectedRange(1:2)) + labelWidth)
                    line([tickTime tickTime], [0 1], 'Color', 'black');
                    text(tickTime, textY, secondstr(tickTime, obj.controller.timeLabelFormat, 2), ...
                        'VerticalAlignment', 'baseline', 'HorizontalAlignment', 'center', ...
                        'FontName', textFont, 'Color', 'black', 'BackgroundColor', 'white', 'Margin', 1);
                end
            end
            
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
                    % Draw the start time of the selection.
                    line([obj.controller.selectedRange(1) obj.controller.selectedRange(1)], [0.8 1], 'Color', 'red');
                    text(obj.controller.selectedRange(1), textY, secondstr(obj.controller.selectedRange(1), obj.controller.timeLabelFormat, 2), ...
                        'VerticalAlignment', 'baseline', 'HorizontalAlignment', 'center', ...
                        'FontName', textFont, 'Color', redColor);
                end
                if endInRange
                    % Draw the end time of the selection.
                    line([obj.controller.selectedRange(2) obj.controller.selectedRange(2)], [0.8 1], 'Color', 'red');
                    text(obj.controller.selectedRange(2), textY, secondstr(obj.controller.selectedRange(2), obj.controller.timeLabelFormat, 2), ...
                        'VerticalAlignment', 'baseline', 'HorizontalAlignment', 'center', ...
                        'FontName', textFont, 'Color', redColor);
                end
                % Draw the size of the selection if it's on screen, the current time is not within the range and there is room.
                selectionInRange = obj.controller.selectedRange(1) < timeRange(2) || obj.controller.selectedRange(2) > timeRange(1);
                currentTimeAmidRange = obj.controller.currentTime ~= obj.controller.selectedRange(1) && obj.controller.currentTime ~= obj.controller.selectedRange(2);
                if selectionInRange && ~currentTimeAmidRange && (obj.controller.selectedRange(2) - obj.controller.selectedRange(1)) > labelWidth * 2.5
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
