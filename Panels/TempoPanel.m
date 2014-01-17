classdef TempoPanel < handle
    
    properties
        panelType = ''
        title = ''
        titleColor = [0.75 0.75 0.75]
        isHidden = false
    end
    
    properties (Transient)
        controller
        panel
        
        titlePanel
        closeButton
        showHideButton
        showIcon
        hideIcon
        actionButton
        actionMenu
        titleText
        helpButton
        
        axes
        
        listeners = {}
    end
    
    
    methods
        
        function obj = TempoPanel(controller, varargin)
            obj.controller = controller;
            
            obj.createUI(varargin{:});
            
            obj.handleCurrentTimeChanged([], []);
        end
        
        
        function createUI(obj, varargin)
            if isa(obj, 'VideoPanel')
                parentPanel = obj.controller.videosPanel;
            else
                parentPanel = obj.controller.timelinesPanel;
            end
            
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
                'BackgroundColor', obj.titleColor, ...
                'SelectionHighlight', 'off', ...
                'Units', 'pixels', ...
                'Position', [0 0 100 16]);
            
            if obj.hasTitleBarControls()
                [tempoRoot, ~, ~] = fileparts(mfilename('fullpath'));
                [tempoRoot, ~, ~] = fileparts(tempoRoot);
                iconRoot = fullfile(tempoRoot, 'Icons');
                
                obj.closeButton = uicontrol(...
                    'Parent', obj.titlePanel, ...
                    'Style', 'pushbutton', ...
                    'CData', double(imread(fullfile(iconRoot, 'PanelClose.png'))) / 255.0, ...
                    'Units', 'pixels', ...
                    'Position', [4 2 12 12], ...
                    'Callback', @(hObject,eventdata)handleClosePanel(obj, hObject, eventdata), ...
                    'Tag', 'closeButton');
                
                obj.showIcon = double(imread(fullfile(iconRoot, 'PanelShow.png'))) / 255.0;
                obj.hideIcon = double(imread(fullfile(iconRoot, 'PanelHide.png'))) / 255.0;
                if obj.isHidden
                    icon = obj.showIcon;
                    callback = @(hObject,eventdata)handleShowPanel(obj, hObject, eventdata);
                    textColor = obj.titleColor * 0.5;
                else
                    icon = obj.hideIcon;
                    callback = @(hObject,eventdata)handleHidePanel(obj, hObject, eventdata);
                    textColor = obj.titleColor * 0.25;
                end
                obj.showHideButton = uicontrol(...
                    'Parent', obj.titlePanel, ...
                    'Style', 'pushbutton', ...
                    'CData', icon, ...
                    'Units', 'pixels', ...
                    'Position', [20 2 12 12], ...
                    'Callback', callback, ...
                    'Tag', 'hideButton');
                
                obj.actionMenu = uicontextmenu;
                obj.actionButton = uicontrol(...
                    'Parent', obj.titlePanel, ...
                    'Style', 'pushbutton', ...
                    'CData', double(imread(fullfile(iconRoot, 'PanelAction.png'))) / 255.0, ...
                    'Units', 'pixels', ...
                    'Position', [36 2 12 12], ...
                    'Callback', @(hObject,eventdata)handleShowActionMenu(obj, hObject, eventdata), ...
                    'UIContextMenu', obj.actionMenu, ...
                    'Tag', 'actionButton');
                
                obj.titleText = uicontrol(...
                    'Parent', obj.titlePanel, ...
                    'Style', 'text', ...
                    'String', [obj.panelType ': ' obj.title], ...
                    'Units', 'pixels', ...
                    'Position', [52 0 100 16], ...
                    'HorizontalAlignment', 'left', ...
                    'ForegroundColor', textColor, ...
                    'BackgroundColor', obj.titleColor, ...
                    'HitTest', 'off', ...
                    'Tag', 'titleText');
                
                obj.helpButton = uicontrol(...
                    'Parent', obj.titlePanel, ...
                    'Style', 'pushbutton', ...
                    'CData', double(imread(fullfile(iconRoot, 'PanelHelp.png'))) / 255.0, ...
                    'Units', 'pixels', ...
                    'Position', [152 2 12 12], ...
                    'Callback', @(hObject,eventdata)handleShowHelp(obj, hObject, eventdata), ...
                    'Tag', 'helpButton');
            end
            
            obj.axes = axes('Parent', obj.panel, ...
                'Units', 'pixels', ...
                'Position', [0 0 100 - 16 100], ...
                'XLim', [0 1], ...
                'XTick', [], ...
                'YLim', [0 1], ...
                'YTick', []); %#ok<CPROP>
            
            % Make calls that sub-classes can override, making sure to pass along varargin to createControls.
            obj.createControls([100, 100], varargin{:});
            if obj.hasTitleBarControls()
                obj.addActionMenuItems(obj.actionMenu);
            end
            
            % Add listeners so we know when the current time and selection change.
            obj.listeners{end + 1} = addlistener(obj.controller, 'currentTime', 'PostSet', @(source, event)handleCurrentTimeChanged(obj, source, event));
        end
        
        
        function h = hasTitleBarControls(obj) %#ok<MANU>
            h = true;
        end
        
        
        function addActionMenuItems(obj, actionMenu) %#ok<INUSD>
            % Sub-classes can override to add additional items to the action menu.
        end
        
        
        function updateActionMenu(obj, actionMenu) %#ok<INUSD>
            % Sub-classes can override to enable/disable/check/etc. their menu items.
        end
        
        
        function menuItem = actionMenuItem(obj, tag)
            % Look up an item by its tag.
            menuItem = findobj(obj.actionMenu, 'Tag', tag);
        end
        
        
        function handleResize(obj, ~, ~)
            % Get the pixel size of the whole panel.
            prevUnits = get(obj.panel, 'Units');
            set(obj.panel, 'Units', 'pixels');
            panelPos = get(obj.panel, 'Position');
            set(obj.panel, 'Units', prevUnits);
            
            if ~isempty(panelPos)
                panelPos(4) = panelPos(4) + 1;
                
                if obj.hasTitleBarControls()
                    % Position the title panel.
                    titlePos = [0, panelPos(4) - 16, panelPos(3) + 1, 16];
                    set(obj.titlePanel, 'Position', titlePos);
                    
                    % Resize the text box.
                    set(obj.titleText, 'Position', [52, 1, titlePos(3) - 1 - 12 - 5 - 52,  14]);
                    
                    % Resize the help button.
                    set(obj.helpButton, 'Position', [titlePos(3) - 1 - 12, 2, 12,  12]);
                    
                    % Don't let the axes overlap the title bar.
                    axesPos = [0, 0, panelPos(3), panelPos(4) - 16];
                else
                    axesPos = [0, 0, panelPos(3), panelPos(4)];
                end
                
                % Position the axes within the panel.
                set(obj.axes, 'Position', axesPos, 'Units', 'pixels');
                
                % Let subclasses reposition their controls.
                obj.resizeControls(axesPos(3:4));
            end
        end
        
        
        function close = shouldClose(obj) %#ok<MANU>
            close = true;
        end
        
        
        function handleClosePanel(obj, ~, ~)
            % TODO: How to undo this?  The uipanel gets deleted...
            
            if obj.shouldClose()
                obj.controller.closePanel(obj);
                
                % Remove any undoable actions that had been added for this panel.
                obj.controller.undoManager.clearContext(obj);
            end
        end
        
        
        function handleHidePanel(obj, ~, ~)
            obj.controller.hidePanel(obj);
        end
        
        
        function handleShowPanel(obj, ~, ~)
            obj.controller.showPanel(obj);
        end
        
        
        function handleShowActionMenu(obj, ~, ~)
            % Make sure the menu items are in the correct state.
            obj.updateActionMenu(obj.actionMenu);
            
            % Show the contextual menu at the current mouse point.
            mousePos = get(obj.controller.figure, 'CurrentPoint');
            set(obj.actionMenu, ...
                'Position', mousePos, ...
                'Visible', 'on');
        end
        
        
        function handleShowHelp(obj, ~, ~)
            TempoHelp().openPage('UserInterface', class(obj));
        end
        
        
        function createControls(obj, panelSize) %#ok<INUSD>
        end
        
        
        function resizeControls(obj, panelSize) %#ok<INUSD>
        end
        
        
        function setHidden(obj, hidden)
            if obj.isHidden ~= hidden
                obj.isHidden = hidden;
                
                if obj.isHidden
                    set(obj.showHideButton, 'CData', obj.showIcon, 'Callback', @(hObject,eventdata)handleShowPanel(obj, hObject, eventdata));
                    set(obj.titleText, 'ForegroundColor', obj.titleColor * 0.5);
                    
                    % Hide the axes and all of its children.
                    set(obj.axes, 'Visible', 'off');
                    set(allchild(obj.axes), 'Visible', 'off');
                else
                    set(obj.showHideButton, 'CData', obj.hideIcon, 'Callback', @(hObject,eventdata)handleHidePanel(obj, hObject, eventdata));
                    set(obj.titleText, 'ForegroundColor', obj.titleColor * 0.25);
                    
                    % Show the axes and all of its children.
                    set(obj.axes, 'Visible', 'on');
                    set(allchild(obj.axes), 'Visible', 'on');
                    
                    % Make sure everything is in sync.
                    obj.handleCurrentTimeChanged([], []);
                end
            end
        end
        
        
        function setTitle(obj, title)
            obj.title = title;
            if ~isempty(obj.titleText)
                set(obj.titleText, 'String', [obj.panelType ': ' obj.title]);
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
            obj.listeners = {};
            
            % Remove the uipanel from the figure.
            if ishandle(obj.panel)
                delete(obj.panel);
            end
        end
        
    end
    
end
