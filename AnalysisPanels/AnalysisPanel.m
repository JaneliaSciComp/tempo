classdef AnalysisPanel < handle
    
    properties
        controller
        panel
        axes
        
        timeLine
        selectionPatch
        
        visible = true
    end
    
    methods
        
        function obj = AnalysisPanel(controller)
            obj.controller = controller;
            
            obj.panel = uipanel(obj.controller.figure, ...
                'BorderType', 'none', ...
                'BorderWidth', 0, ...
                'SelectionHighlight', 'off', ...
                'Units', 'pixels', ...
                'Position', [0 0 100 100], ...
                'ResizeFcn', @(source, event)handleResize(obj, source, event));
            obj.axes = axes('Parent', obj.panel, ...
                'Units', 'pixels', ...
                'Position', [0 0 100 - 16 100], ...
                'XLim', [0 1], ...
                'XTick', [], ...
                'YLim', [0 1], ...
                'YTick', []); %#ok<CPROP>
            
            % TODO: defer this until the first resize so all of the panels' controls aren't all on top of each other?
            obj.createControls([100 - 16 100]);
            
%            hold on
            
            % Use a line to indicate the current time in the axes.
            obj.timeLine = line([0 0], [-100000 200000], 'Color', [1 0 0]);
            set(obj.timeLine, 'HitTest', 'off');
            
            % Use a filled rectangle to indicate the current selection in the axes.
%            obj.selectionRect = rectangle('Position', [0 -100000 1 200000], 'EdgeColor', 'none', 'FaceColor', [1 0.9 0.9], 'Visible', 'off');
            obj.selectionPatch = patch([0 1 1 0], [-100000 -100000 200000 200000], 'r', 'FaceAlpha', 0.2, 'EdgeColor', 'none', 'Visible', 'off');
            set(obj.selectionPatch, 'HitTest', 'off');
            
            % Add listeners so we know when the current time and selection change.
            addlistener(obj.controller, 'displayedTime', 'PostSet', @(source, event)handleTimeWindowChanged(obj, source, event));
            addlistener(obj.controller, 'timeWindow', 'PostSet', @obj.handleTimeWindowChanged);
            addlistener(obj.controller, 'currentTime', 'PostSet', @obj.handleCurrentTimeChanged);
            addlistener(obj.controller, 'selectedTime', 'PostSet', @obj.handleSelectedTimeChanged);
            
            obj.handleCurrentTimeChanged();
            obj.handleSelectedTimeChanged();
            obj.handleTimeWindowChanged();
        end
        
        
        function handleResize(obj, ~, ~)
            if obj.visible
                % Position the axes within the panel, leaving enough room for any controls needed by subclasses.
                prevUnits = get(obj.panel, 'Units');
                set(obj.panel, 'Units', 'pixels');
                panelPos = get(obj.panel, 'Position');
                set(obj.panel, 'Units', prevUnits);
                
                axesPos = [0, 0, panelPos(3) - 16, panelPos(4)];
                set(obj.axes, 'Units', 'pixels');
                set(obj.axes, 'Position', axesPos);
                
                % Let subclasses reposition their controls.
                obj.resizeControls([panelPos(3) panelPos(4)]);
            end
        end
        
        
        function createControls(obj, panelSize)
        end
        
        
        function resizeControls(obj, panelSize)
        end
        
        
        function setVisible(obj, visible)
            obj.visible = visible;
            
            if obj.visible
                set(obj.panel, 'Visible', 'on');
                
                % Make sure everything is in sync.
                obj.handleCurrentTimeChanged([], []);
                obj.handleSelectedTimeChanged([], []);
                obj.handleTimeWindowChanged([], []);
            else
                set(obj.panel, 'Visible', 'off');
            end
        end
        
        
        function handleCurrentTimeChanged(obj, ~, ~)
            if obj.visible
                % Update the position of the current time indicator.
                set(obj.timeLine, 'XData', [obj.controller.currentTime obj.controller.currentTime]);
            end
        end
        
        
        function handleSelectedTimeChanged(obj, ~, ~)
            if obj.visible
                % Update the position and visibility of the current selection indicator.
                if obj.controller.selectedTime(1) ~= obj.controller.selectedTime(2)
                    selectionStart = min(obj.controller.selectedTime);
                    selectionEnd = max(obj.controller.selectedTime);
                    set(obj.selectionPatch, 'XData', [selectionStart selectionEnd selectionEnd selectionStart], 'Visible', 'on');
%                    set(obj.selectionRect, 'Position', [selectionStart -100000 selectionEnd - selectionStart 200000], 'Visible', 'on');
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
        
        
        function updateAxes(obj, timeRange) %#ok<INUSD,MANU>
            % TODO: make abstract?
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
        
    end
    
end
