classdef AnalysisPanel < handle
    
    properties
        controller
        panel
        axes
        
        visible = true
        
        axesBorder = [0 0 0 0]  % left, bottom, right, top
    end
    
    methods
        
        function obj = AnalysisPanel(controller)
            obj.controller = controller;
            
            obj.panel = uipanel(obj.controller.figure, ...
                'BorderType', 'none', ...
                'BorderWidth', 0, ...
                'BackgroundColor', [0.4 0.4 0.4], ...
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
            
            % Add listeners so we know when the current time and selection change.
            addlistener(obj.controller, 'currentTime', 'PostSet', @(source, event)handleCurrentTimeChanged(obj, source, event));
            
            obj.handleCurrentTimeChanged([], []);
        end
        
        
        function handleResize(obj, ~, ~)
            if obj.visible
                % Position the axes within the panel, leaving enough room for any controls needed by subclasses.
                prevUnits = get(obj.panel, 'Units');
                set(obj.panel, 'Units', 'pixels');
                panelPos = get(obj.panel, 'Position');
                set(obj.panel, 'Units', prevUnits);
                
                axesPos = [obj.axesBorder(1), ...
                    obj.axesBorder(2), ...
                    panelPos(3) - obj.axesBorder(1) - obj.axesBorder(3), ...
                    panelPos(4) - obj.axesBorder(2) - obj.axesBorder(4)];
                set(obj.axes, 'Units', 'pixels');
                set(obj.axes, 'Position', axesPos);
                
                % Let subclasses reposition their controls.
                obj.resizeControls([panelPos(3) panelPos(4)]);
            end
        end
        
        
        function createControls(obj, panelSize) %#ok<INUSD,MANU>
        end
        
        
        function resizeControls(obj, panelSize) %#ok<INUSD,MANU>
        end
        
        
        function setVisible(obj, visible)
            if obj.visible ~= visible
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
        end
        
        
        function handled = keyWasPressed(obj, event) %#ok<INUSD,MANU>
            handled = false;
        end
        
        
        function handled = keyWasReleased(obj, event) %#ok<INUSD,MANU>
            handled = false;
        end
        
        
        function handleCurrentTimeChanged(obj, ~, ~)
            if obj.visible
                obj.currentTimeChanged();
            end
        end
        
        
        function currentTimeChanged(obj) %#ok<MANU>
            % TODO: make abstract?
        end
        
    end
    
end
