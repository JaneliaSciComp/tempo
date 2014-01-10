classdef TempoPanel < handle
    
    properties
        controller
        panel
        
        titlePanel
        hideButton
        closeButton
        actionButton
        actionMenu
        
        panelType = ''
        title = ''
        
        hiddenTitlePanel
        showButton
        hiddenCloseButton
        hiddenTitleText
        
        axes
        
        isHidden = false
        
        axesBorder = [16 0 0 0]  % left, bottom, right, top
        
        listeners = {}
    end
    
    methods
        
        function obj = TempoPanel(controller)
            obj.controller = controller;
            
            if isa(obj, 'VideoPanel')
                parentPanel = obj.controller.videosPanel;
            else
                parentPanel = obj.controller.timelinesPanel;
            end
            
            titleColor = [0.75 0.75 0.75];
            
            obj.panel = uipanel(parentPanel, ...
                'BorderType', 'none', ...
                'BorderWidth', 0, ...
                'BackgroundColor', 'white', ...
                'SelectionHighlight', 'off', ...
                'Units', 'pixels', ...
                'Position', [-200 -200 100 100], ...
                'ResizeFcn', @(source, event)handleResize(obj, source, event));
            
            obj.titlePanel = uipanel(obj.panel, ...
                'BorderType', 'none', ...
                'BorderWidth', 0, ...
                'BackgroundColor', titleColor, ...
                'SelectionHighlight', 'off', ...
                'Units', 'pixels', ...
                'Position', [0 0 16 100]);
            
            obj.hiddenTitlePanel = uipanel(obj.panel, ...
                'BorderType', 'none', ...
                'BorderWidth', 0, ...
                'BackgroundColor', titleColor, ...
                'SelectionHighlight', 'off', ...
                'Units', 'pixels', ...
                'Position', [0 0 100 16], ...
                'Visible', 'off');
            
            [tempoRoot, ~, ~] = fileparts(mfilename('fullpath'));
            [tempoRoot, ~, ~] = fileparts(tempoRoot);
            iconRoot = fullfile(tempoRoot, 'Icons');
            
            if obj.hasTitleBarControls()
                obj.hideButton = uicontrol(...
                    'Parent', obj.titlePanel, ...
                    'Style', 'pushbutton', ...
                    'CData', double(imread(fullfile(iconRoot, 'PanelHide.png'))) / 255.0, ...
                    'Units', 'pixels', ...
                    'Position', [3 86 12 12], ...
                    'Callback', @(hObject,eventdata)handleHidePanel(obj, hObject, eventdata), ...
                    'Tag', 'hideButton');
                
                obj.closeButton = uicontrol(...
                    'Parent', obj.titlePanel, ...
                    'Style', 'pushbutton', ...
                    'CData', double(imread(fullfile(iconRoot, 'PanelClose.png'))) / 255.0, ...
                    'Units', 'pixels', ...
                    'Position', [3 72 12 12], ...
                    'Callback', @(hObject,eventdata)handleClosePanel(obj, hObject, eventdata), ...
                    'Tag', 'closeButton');
                
                obj.actionMenu = uicontextmenu;
                uimenu(obj.actionMenu, ...
                    'Label', 'Hide', ...
                    'Callback', @(hObject,eventdata)handleHidePanel(obj, hObject, eventdata));
                uimenu(obj.actionMenu, ...
                    'Label', 'Close', ...
                    'Callback', @(hObject,eventdata)handleClosePanel(obj, hObject, eventdata));
                obj.addActionMenuItems(obj.actionMenu);
                obj.actionButton = uicontrol(...
                    'Parent', obj.titlePanel, ...
                    'Style', 'pushbutton', ...
                    'CData', double(imread(fullfile(iconRoot, 'PanelAction.png'))) / 255.0, ...
                    'Units', 'pixels', ...
                    'Position', [3 58 12 12], ...
                    'Callback', @(hObject,eventdata)handleShowActionMenu(obj, hObject, eventdata), ...
                    'UIContextMenu', obj.actionMenu, ...
                    'Tag', 'actionButton');
                
                obj.showButton = uicontrol(...
                    'Parent', obj.hiddenTitlePanel, ...
                    'Style', 'pushbutton', ...
                    'CData', double(imread(fullfile(iconRoot, 'PanelShow.png'))) / 255.0, ...
                    'Units', 'pixels', ...
                    'Position', [3 2 12 12], ...
                    'Callback', @(hObject,eventdata)handleShowPanel(obj, hObject, eventdata), ...
                    'Tag', 'hideButton');
                
                obj.hiddenCloseButton = uicontrol(...
                    'Parent', obj.hiddenTitlePanel, ...
                    'Style', 'pushbutton', ...
                    'CData', double(imread(fullfile(iconRoot, 'PanelClose.png'))) / 255.0, ...
                    'Units', 'pixels', ...
                    'Position', [17 2 12 12], ...
                    'Callback', @(hObject,eventdata)handleClosePanel(obj, hObject, eventdata), ...
                    'Tag', 'hiddenCloseButton');
                
                obj.hiddenTitleText = uicontrol(...
                    'Parent', obj.hiddenTitlePanel, ...
                    'Style', 'text', ...
                    'String', [obj.panelType ': ' obj.title], ...
                    'Units', 'pixels', ...
                    'Position', [21 2 100 12], ...
                    'HorizontalAlignment', 'left', ...
                    'ForegroundColor', titleColor * 0.5, ...
                    'BackgroundColor', titleColor, ...
                    'HitTest', 'off', ...
                    'Tag', 'hiddenTitleText');
            end
            
            obj.axes = axes('Parent', obj.panel, ...
                'Units', 'pixels', ...
                'Position', [16 0 100 - 16 100], ...
                'XLim', [0 1], ...
                'XTick', [], ...
                'YLim', [0 1], ...
                'YTick', []); %#ok<CPROP>
            
            obj.createControls([100 - 16, 100]);
            
            % Add listeners so we know when the current time and selection change.
            obj.listeners{end + 1} = addlistener(obj.controller, 'currentTime', 'PostSet', @(source, event)handleCurrentTimeChanged(obj, source, event));
            
            obj.handleCurrentTimeChanged([], []);
        end
        
        
        function h = hasTitleBarControls(obj) %#ok<MANU>
            h = true;
        end
        
        
        function addActionMenuItems(obj, actionMenu) %#ok<INUSD>
            % Sub-classes can override to add additional items to the action menu.
        end
        
        
        function handleResize(obj, ~, ~)
            % Get the pixel size of the whole panel.
            prevUnits = get(obj.panel, 'Units');
            set(obj.panel, 'Units', 'pixels');
            panelPos = get(obj.panel, 'Position');
            set(obj.panel, 'Units', prevUnits);
            
            panelPos(4) = panelPos(4) + 1;
            
            if obj.isHidden
                % Position the panel.
                titlePos = [0 0 panelPos(3) 16];
                set(obj.hiddenTitlePanel, 'Position', titlePos);
                
                % Resize the text box.
                set(obj.hiddenTitleText, 'Position', [34, 2, titlePos(3) - 34 - 5,  12]);
            else
                % Position the axes within the panel, leaving enough room for any controls needed by subclasses.
                titlePos = [0 0 16 panelPos(4)];
                set(obj.titlePanel, 'Position', titlePos);
                if obj.hasTitleBarControls()
                    buttonPos = [3, panelPos(4) - 14, 12, 12];
                    set(obj.hideButton, 'Position', buttonPos);
                    buttonPos = [3, panelPos(4) - 28, 12, 12];
                    set(obj.closeButton, 'Position', buttonPos);
                    buttonPos = [3, panelPos(4) - 42, 12, 12];
                    set(obj.actionButton, 'Position', buttonPos);
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
            % TODO: How to undo this?  The uipanel gets deleted...
            
            obj.controller.closePanel(obj);
        end
        
        
        function handleHidePanel(obj, ~, ~)
            obj.controller.hidePanel(obj);
        end
        
        
        function handleShowPanel(obj, ~, ~)
            obj.controller.showPanel(obj);
        end
        
        
        function handleShowActionMenu(obj, ~, ~)
            % Show the contextual menu at
            mousePos = get(obj.controller.figure, 'CurrentPoint');
            set(obj.actionMenu, ...
                'Position', mousePos, ...
                'Visible', 'on');
        end
        
        
        function createControls(obj, panelSize) %#ok<INUSD>
        end
        
        
        function resizeControls(obj, panelSize) %#ok<INUSD>
        end
        
        
        function setHidden(obj, hidden)
            if obj.isHidden ~= hidden
                obj.isHidden = hidden;
                
                if obj.isHidden
                    set(obj.titlePanel, 'Visible', 'off');
                    set(obj.axes, 'Visible', 'off');
                    set(allchild(obj.axes), 'Visible', 'off');
                    set(obj.hiddenTitlePanel, 'Visible', 'on');
                else
                    set(obj.titlePanel, 'Visible', 'on');
                    set(obj.axes, 'Visible', 'on');
                    set(allchild(obj.axes), 'Visible', 'on');
                    set(obj.hiddenTitlePanel, 'Visible', 'off');
                    
                    % Make sure everything is in sync.
                    obj.handleCurrentTimeChanged([], []);
                end
            end
        end
        
        
        function setTitle(obj, title)
            obj.title = title;
            if ~isempty(obj.hiddenTitleText)
                set(obj.hiddenTitleText, 'String', [obj.panelType ': ' obj.title]);
            end
        end
        
        
        function handled = keyWasPressed(obj, event) %#ok<INUSD>
            handled = false;
        end
        
        
        function handled = keyWasReleased(obj, event) %#ok<INUSD>
            handled = false;
        end
        
        
        function handleCurrentTimeChanged(obj, ~, ~)
            if ~obj.isHidden
                obj.currentTimeChanged();
            end
        end
        
        
        function currentTimeChanged(obj) %#ok<MANU>
            % TODO: make abstract?
        end
        
        
        function close(obj)
            % Subclasses can override this if they need to do anything more.
            
            % Delete any listeners.
            cellfun(@(x) delete(x), obj.listeners);
            
            % Remove the uipanel from the figure.
            if ishandle(obj.panel)
                delete(obj.panel);
            end
        end
        
    end
    
end
