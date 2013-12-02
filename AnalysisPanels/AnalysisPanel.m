classdef AnalysisPanel < handle
    
    properties
        controller
        panel
        
        titlePanel
        closeButton
        hideButton
        infoButton
        infoMenu
        
        axes
        
        visible = true
        
        axesBorder = [16 0 0 0]  % left, bottom, right, top
        
        listeners = {}
    end
    
    methods
        
        function obj = AnalysisPanel(controller)
            obj.controller = controller;
            
            obj.panel = uipanel(obj.controller.figure, ...
                'BorderType', 'none', ...
                'BorderWidth', 0, ...
                'BackgroundColor', 'white', ...
                'SelectionHighlight', 'off', ...
                'Units', 'pixels', ...
                'Position', [-200 -200 100 100], ...
                'ResizeFcn', @(source, event)handleResize(obj, source, event));
            
            if obj.hasTitleBar()
                obj.titlePanel = uipanel(obj.panel, ...
                    'BorderType', 'none', ...
                    'BorderWidth', 0, ...
                    'BackgroundColor', [0.75 0.75 0.75], ...
                    'SelectionHighlight', 'off', ...
                    'Units', 'pixels', ...
                    'Position', [0 0 16 100]);
                baseCData = ones(12, 12, 3);
                baseCData(:, 1, :) = ones(12, 3) * 0.5;
                baseCData(:, 12, :) = ones(12, 3) * 0.5;
                baseCData(1, :, :) = ones(12, 3) * 0.5;
                baseCData(12, :, :) = ones(12, 3) * 0.5;
                
                closeCData = baseCData;
                iconColor = 0.9;
                shadeColor = 0.7;
                for i = 3:10
                    if i < 10
                        closeCData(12 - i, i, :) = ones(1, 3) * iconColor;
                        closeCData(13 - i, i + 1, :) = ones(1, 3) * iconColor;
                        closeCData(i, i + 1, :) = ones(1, 3) * iconColor;
                        closeCData(i + 1, i, :) = ones(1, 3) * iconColor;
                    end
                    closeCData(i, i, :) = ones(1, 3) * shadeColor;
                    closeCData(13 - i, i, :) = ones(1, 3) * shadeColor;
                end
                obj.closeButton = uicontrol(...
                    'Parent', obj.titlePanel, ...
                    'Style', 'pushbutton', ...
                    'CData', closeCData, ...
                    'Units', 'pixels', ...
                    'Position', [3 86 12 12], ...
                    'Callback', @(hObject,eventdata)handleClosePanel(obj, hObject, eventdata), ...
                    'Tag', 'closeButton');
                
                hideCData = baseCData;
                hideColor = 0.75;
                hideCData(6:7, 3:10, :) = ones(2, 8, 3) * hideColor;
                obj.hideButton = uicontrol(...
                    'Parent', obj.titlePanel, ...
                    'Style', 'pushbutton', ...
                    'CData', hideCData, ...
                    'Units', 'pixels', ...
                    'Position', [3 72 12 12], ...
                    'Callback', @(hObject,eventdata)handleHidePanel(obj, hObject, eventdata), ...
                    'Tag', 'hideButton');
                
                infoCData = baseCData;
                infoColor = 0.75;
                infoCData(3:4, 6:7, :) = ones(2, 2, 3) * infoColor;
                infoCData(6:10, 6:7, :) = ones(5, 2, 3) * infoColor;
                obj.infoMenu = uicontextmenu;
                uimenu(obj.infoMenu, ...
                    'Label', 'Hide', ...
                    'Callback', @(hObject,eventdata)handleHidePanel(obj, hObject, eventdata));
                uimenu(obj.infoMenu, ...
                    'Label', 'Close', ...
                    'Callback', @(hObject,eventdata)handleClosePanel(obj, hObject, eventdata));
                obj.addInfoMenuItems(obj.infoMenu);
                obj.infoButton = uicontrol(...
                    'Parent', obj.titlePanel, ...
                    'Style', 'pushbutton', ...
                    'CData', infoCData, ...
                    'Units', 'pixels', ...
                    'Position', [3 58 12 12], ...
                    'Callback', @(hObject,eventdata)handleShowInfo(obj, hObject, eventdata), ...
                    'UIContextMenu', obj.infoMenu, ...
                    'Tag', 'infoButton');
            end
            
            obj.axes = axes('Parent', obj.panel, ...
                'Units', 'pixels', ...
                'Position', [16 0 100 - 16 100], ...
                'XLim', [0 1], ...
                'XTick', [], ...
                'YLim', [0 1], ...
                'YTick', []); %#ok<CPROP>
            
            obj.createControls([100 - 16 100]);
            
            % Add listeners so we know when the current time and selection change.
            obj.listeners{end + 1} = addlistener(obj.controller, 'currentTime', 'PostSet', @(source, event)handleCurrentTimeChanged(obj, source, event));
            
            obj.handleCurrentTimeChanged([], []);
        end
        
        
        function h = hasTitleBar(obj) %#ok<MANU>
            h = true;
        end
        
        
        function addInfoMenuItems(obj, infoMenu) %#ok<INUSD>
            % Sub-classes can override to add additional items to the info menu.
        end
        
        
        function handleResize(obj, ~, ~)
            if obj.visible
                % Position the axes within the panel, leaving enough room for any controls needed by subclasses.
                prevUnits = get(obj.panel, 'Units');
                set(obj.panel, 'Units', 'pixels');
                panelPos = get(obj.panel, 'Position');
                set(obj.panel, 'Units', prevUnits);
                
                panelPos(4) = panelPos(4) + 1;
                
                if obj.hasTitleBar()
                    titlePos = [0 0 16 panelPos(4)];
                    set(obj.titlePanel, 'Position', titlePos);
                    buttonPos = [3, panelPos(4) - 14, 12, 12];
                    set(obj.closeButton, 'Position', buttonPos);
                    buttonPos = [3, panelPos(4) - 28, 12, 12];
                    set(obj.hideButton, 'Position', buttonPos);
                    buttonPos = [3, panelPos(4) - 42, 12, 12];
                    set(obj.infoButton, 'Position', buttonPos);
                end
                
                axesPos = [obj.axesBorder(1), ...
                    obj.axesBorder(2), ...
                    panelPos(3) - obj.axesBorder(1) - obj.axesBorder(3), ...
                    panelPos(4) - obj.axesBorder(2) - obj.axesBorder(4) - 1];
                set(obj.axes, 'Units', 'pixels');
                set(obj.axes, 'Position', axesPos);
                
                % Let subclasses reposition their controls.
                obj.resizeControls([panelPos(3) panelPos(4)]);
            end
        end
        
        
        function handleClosePanel(obj, ~, ~)
            % TODO
        end
        
        
        function handleHidePanel(obj, ~, ~)
            % TODO
        end
        
        
        function handleShowInfo(obj, ~, ~)
            % Show the contextual menu at
            mousePos = get(obj.controller.figure, 'CurrentPoint');
            set(obj.infoMenu, ...
                'Position', mousePos, ...
                'Visible', 'on');
        end
        
        
        function createControls(obj, panelSize) %#ok<INUSD>
        end
        
        
        function resizeControls(obj, panelSize) %#ok<INUSD>
        end
        
        
        function setVisible(obj, visible)
            if obj.visible ~= visible
                obj.visible = visible;
                
                if obj.visible
                    set(obj.panel, 'Visible', 'on');
                    
                    % Make sure everything is in sync.
                    obj.handleCurrentTimeChanged([], []);
                    obj.handleSelectedRangeChanged([], []);
                    obj.handleTimeWindowChanged([], []);
                else
                    set(obj.panel, 'Visible', 'off');
                end
            end
        end
        
        
        function handled = keyWasPressed(obj, event) %#ok<INUSD>
            handled = false;
        end
        
        
        function handled = keyWasReleased(obj, event) %#ok<INUSD>
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
        
        
        function delete(obj)
            cellfun(@(x) delete(x), obj.listeners);
            
            if ishandle(obj.panel)
                delete(obj.panel);
            end
        end
        
    end
    
end
