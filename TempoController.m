classdef TempoController < handle
    
    properties
        figure
        
        recordings = {}
        reporters = {}
        
        duration = 300
        zoom = 1
        
        splitterPanel
        splitter
        videosPanel
        videoPanels = {}
        timelinesPanel
        timelinePanels = {}
        timeIndicatorPanel = []
        
        panelHandlingKeyPress
        
        videoSlider
        timelineSlider
        
        fileMenu
        editMenu
        videoMenu
        timelineMenu
        playbackMenu
        windowMenu
        
        toolbar
        jToolbar
        zoomOutTool
        
        playSlowerTool
        playBackwardsTool
        pauseTool
        playForwardsTool
        playFasterTool
        
        detectPopUpTool
        
        timeLabelFormat = 1     % default to displaying time in minutes and seconds
        
        panelSelectingTime
        mouseConstraintTime
        mouseConstraintFreq
        originalSelectedRange
        mouseOffset
        
        isPlaying = false
        playRate = 1.0          % positive plays forward, negative plays backwards
        playTimer
        playRange
        playStartTime
        fpsFrameCount
        
        recordingClassNames
        recordingTypeNames
        detectorClassNames
        detectorTypeNames
        importerClassNames
        importerTypeNames
        
        importing = false
        recordingsToAdd = {}
        
        showWaveforms
        showSpectrograms
        showFeatures
        
        needsSave = false
        savePath
    end
    
    
    properties (SetObservable)
        % The Tempo panels will listen for changes to these properties.
        displayRange = [0 300 0 100000]      % The window in time and frequency which all timeline panels should display (in seconds/Hz, [minTime maxTime minFreq maxFreq]).
        currentTime = 0         % The time point currently being played (in seconds).
        selectedRange = [0 0 -inf inf]    % The range of time and frequency currently selected (in seconds/Hz).  The first two values will be equal if there is a point selection.
        windowSize = 0.01
    end
    
    
    methods
        
        function obj = TempoController()
            obj.showWaveforms = getpref('Tempo', 'ShowWaveforms', true);
            obj.showSpectrograms = getpref('Tempo', 'ShowSpectrograms', true);
            obj.showFeatures = getpref('Tempo', 'ShowFeatures', true);
            
            obj.figure = figure('Name', 'Tempo', ...
                'NumberTitle', 'off', ...
                'Toolbar', 'none', ...
                'MenuBar', 'none', ...
                'Position', getpref('Tempo', 'MainWindowPosition', [100 100 400 200]), ...
                'Color', [0.4 0.4 0.4], ...
                'Renderer', 'opengl', ...
                'ResizeFcn', @(source, event)handleResize(obj, source, event), ...
                'KeyPressFcn', @(source, event)handleKeyPress(obj, source, event), ...
                'KeyReleaseFcn', @(source, event)handleKeyRelease(obj, source, event), ...
                'CloseRequestFcn', @(source, event)handleClose(obj, source, event), ...
                'WindowButtonDownFcn', @(source, event)handleMouseButtonDown(obj, source, event), ...
                'WindowButtonUpFcn', @(source, event)handleMouseButtonUp(obj, source, event)); %#ok<CPROP>
            
            if isdeployed && exist(fullfile(ctfroot, 'Detectors'), 'dir')
                % Look for the detectors in the CTF archive.
                parentDir = ctfroot;
            else
                % Look for the detectors relative to this .m file.
                tempoPath = mfilename('fullpath');
                parentDir = fileparts(tempoPath);
            end
            
            addpath(fullfile(parentDir, 'Panels'));
            addpath(fullfile(parentDir, 'Recordings'));
            addpath(fullfile(parentDir, 'Utility'));
            
            [obj.recordingClassNames, obj.recordingTypeNames] = obj.findPlugIns(fullfile(parentDir, 'Recordings'));
            [obj.detectorClassNames, obj.detectorTypeNames] = obj.findPlugIns(fullfile(parentDir, 'Detectors'));
            [obj.importerClassNames, obj.importerTypeNames] = obj.findPlugIns(fullfile(parentDir, 'Importers'));
            
            % Add the paths to the third-party code.
            addpath(fullfile(parentDir, 'ThirdParty', 'export_fig'));
            addpath(fullfile(parentDir, 'ThirdParty', 'dbutils'));
            addpath(fullfile(parentDir, 'ThirdParty', 'ffmpeg'));
            addpath(fullfile(parentDir, 'ThirdParty', 'uisplitpane'));
            
            % Insert a splitter at the top level to separate the video and timeline panels.
            % TODO: Allow the splitter to split the screen vertically with the video panels on top.
            %       This will require removing and re-adding the uisplitpane since that property cannot be modified.
            set(obj.figure, 'WindowButtonMotionFcn', @()handleMouseMotion(obj));
            figurePos = get(obj.figure, 'Position');
            obj.splitterPanel = uipanel(obj.figure, ...
                'BorderType', 'none', ...
                'BorderWidth', 0, ...
                'BackgroundColor', [0.25 0.25 0.25], ...
                'SelectionHighlight', 'off', ...
                'Units', 'pixels', ...
                'Position', [0 0 figurePos(3) figurePos(4)]);
            [obj.videosPanel, obj.timelinesPanel, obj.splitter] = uisplitpane(obj.splitterPanel, ...
                'DividerLocation', 0.25, ...
                'DividerWidth', 5);
            set(obj.videosPanel, ...
                'BackgroundColor', 'black', ...
                'ResizeFcn', @(source, event)arrangeVideoPanels(obj, source, event));
            set(obj.timelinesPanel, ...
                'BackgroundColor', 'white', ...
                'ResizeFcn', @(source, event)arrangeTimelinePanels(obj, source, event));
            
            obj.timeIndicatorPanel = TimeIndicatorPanel(obj);
            
            obj.createMenuBar();
            if getpref('Tempo', 'WindowShowToolbar', true)
                obj.createToolbar();
            end
            
            % Create the scroll bars that let the user scrub through time.
            videosPos = get(obj.videosPanel, 'Position');
            obj.videoSlider = uicontrol(...
                'Parent', obj.videosPanel, ...
                'Style', 'slider',... 
                'Min', 0, ...
                'Max', obj.duration, ...
                'Value', 0, ...
                'Position', [1 1 videosPos(3) 16]);
            addlistener(obj.videoSlider, 'ContinuousValueChange', @(source, event)handleVideoSliderChanged(obj, source, event));
            timelinesPos = get(obj.timelinesPanel, 'Position');
            obj.timelineSlider = uicontrol(...
                'Parent', obj.timelinesPanel, ...
                'Style', 'slider',... 
                'Min', 0, ...
                'Max', obj.duration, ...
                'Value', 0, ...
                'Position', [1 1 timelinesPos(3) 16]);
            addlistener(obj.timelineSlider, 'ContinuousValueChange', @(source, event)handleTimelineSliderChanged(obj, source, event));
            
            % Listen for changes to the displayRange property.
            addlistener(obj, 'currentTime', 'PostSet', @(source, event)handleCurrentTimeChanged(obj, source, event));
            addlistener(obj, 'displayRange', 'PostSet', @(source, event)handleTimeWindowChanged(obj, source, event));
            
            obj.arrangeTimelinePanels();
            
            % Set up a timer to fire 30 times per second during playback.
            obj.playTimer = timer('ExecutionMode', 'fixedRate', 'TimerFcn', @(timerObj, event)handlePlayTimer(obj, timerObj, event), 'Period', round(1.0 / 30.0 * 1000) / 1000);
        end
        
        
        function createMenuBar(obj)
            obj.fileMenu = uimenu(obj.figure, 'Label', 'File');
            uimenu(obj.fileMenu, 'Label', 'New', ...
                                 'Callback', @(hObject, eventdata)handleNewWorkspace(obj, hObject, eventdata), ...
                                 'Accelerator', 'n');
            uimenu(obj.fileMenu, 'Label', 'Open...', ...
                                 'Callback', @(hObject, eventdata)handleOpenFile(obj, hObject, eventdata), ...
                                 'Accelerator', 'o');
            uimenu(obj.fileMenu, 'Label', 'Close', ...
                                 'Callback', @(hObject, eventdata)handleClose(obj, hObject, eventdata), ...
                                 'Accelerator', 'w', ...
                                 'Separator', 'on');
            uimenu(obj.fileMenu, 'Label', 'Close All', ...
                                 'Callback', '', ...
                                 'Enable', 'off');
            uimenu(obj.fileMenu, 'Label', 'Save...', ...
                                 'Callback', @(hObject, eventdata)handleSaveWorkspace(obj, hObject, eventdata), ... 
                                 'Accelerator', 's');
            uimenu(obj.fileMenu, 'Label', 'Save As...', ...
                                 'Callback', '', ... 
                                 'Accelerator', '', ...
                                 'Enable', 'off');
            uimenu(obj.fileMenu, 'Label', 'Export Video of Selection...', ...
                                 'Callback', @(hObject, eventdata)handleExportSelection(obj, hObject, eventdata), ...
                                 'Separator', 'on');
            uimenu(obj.fileMenu, 'Label', 'Export All Features...', ...
                                 'Callback', '', ...
                                 'Enable', 'off');
            uimenu(obj.fileMenu, 'Label', 'Take Screen Shot...', ...
                                 'Callback', @(hObject, eventdata)handleSaveScreenshot(obj, hObject, eventdata), ... 
                                 'Separator', 'on');
            
            obj.editMenu = uimenu(obj.figure, 'Label', 'Edit');
            uimenu(obj.editMenu, 'Label', 'Undo', ...
                                 'Callback', '', ...
                                 'Accelerator', 'z', ...
                                 'Enable', 'off');
            uimenu(obj.editMenu, 'Label', 'Redo...', ...
                                 'Callback', '', ...
                                 'Accelerator', 'Z', ...
                                 'Enable', 'off');
            uimenu(obj.editMenu, 'Label', 'Cut', ...
                                 'Callback', '', ...
                                 'Accelerator', 'x', ...
                                 'Separator', 'on', ...
                                 'Enable', 'off');
            uimenu(obj.editMenu, 'Label', 'Copy', ...
                                 'Callback', '', ...
                                 'Accelerator', 'c', ...
                                 'Enable', 'off');
            uimenu(obj.editMenu, 'Label', 'Paste', ...
                                 'Callback', '', ... 
                                 'Accelerator', 'v', ...
                                 'Enable', 'off');
            uimenu(obj.editMenu, 'Label', 'Select All', ...
                                 'Callback', @(hObject, eventdata)handleSelectAll(obj, hObject, eventdata), ...
                                 'Accelerator', 'a', ...
                                 'Separator', 'on');
            uimenu(obj.editMenu, 'Label', 'Select None', ...
                                 'Callback', @(hObject, eventdata)handleSelectNone(obj, hObject, eventdata), ...
                                 'Accelerator', '');
            detectorMenu = uimenu(obj.editMenu, 'Label', 'Detect Features', ...
                                                'Callback', '', ... 
                                                'Separator', 'on');
            for detectorIdx = 1:length(obj.detectorTypeNames)
                uimenu(detectorMenu, 'Label', obj.detectorTypeNames{detectorIdx}, ...
                                     'Callback', @(hObject, eventdata)handleDetectFeatures(obj, hObject, eventdata), ...
                                     'UserData', detectorIdx);
            end
            
            obj.videoMenu = uimenu(obj.figure, 'Label', 'Video');
            uimenu(obj.videoMenu, 'Label', 'View at Actual Size', ...
                                  'Callback', '', ...
                                  'Accelerator', '', ...
                                  'Enable', 'off');
            uimenu(obj.videoMenu, 'Label', 'View at Double Size', ...
                                  'Callback', '', ...
                                  'Accelerator', '', ...
                                  'Enable', 'off');
            uimenu(obj.videoMenu, 'Label', 'View at Half Size', ...
                                  'Callback', '', ...
                                  'Accelerator', '', ...
                                  'Enable', 'off');
            uimenu(obj.videoMenu, 'Label', 'View at Maximum Size', ...
                                  'Callback', '', ...
                                  'Accelerator', '', ...
                                  'Checked', 'on', ...
                                  'Enable', 'off');
            uimenu(obj.videoMenu, 'Label', 'Arrange Videos Left to Right', ...
                                  'Callback', '', ...
                                  'Accelerator', '', ... 
                                  'Separator', 'on', ...
                                  'Enable', 'off');
            uimenu(obj.videoMenu, 'Label', 'Arrange Videos Top to Bottom', ...
                                  'Callback', '', ...
                                  'Accelerator', '', ...
                                  'Checked', 'on', ...
                                  'Enable', 'off');
            uimenu(obj.videoMenu, 'Label', 'Place Videos Left of the Timeline', ...
                                  'Callback', '', ...
                                  'Accelerator', '', ... 
                                  'Separator', 'on', ...
                                  'Checked', 'on', ...
                                  'Enable', 'off');
            uimenu(obj.videoMenu, 'Label', 'Place Videos Above the Timeline', ...
                                  'Callback', '', ...
                                  'Accelerator', '', ...
                                  'Enable', 'off');
            uimenu(obj.videoMenu, 'Label', 'Show Current Frame Number', ...
                                  'Callback', @(hObject, eventdata)handleShowFrameNumber(obj, hObject, eventdata), ...
                                  'Accelerator', '', ... 
                                  'Separator', 'on', ...
                                  'Checked', onOff(getpref('Tempo', 'VideoShowFrameNumber', true)), ...
                                  'Tag', 'showFrameNumber');
            
            obj.timelineMenu = uimenu(obj.figure, 'Label', 'Timeline');
            uimenu(obj.timelineMenu, 'Label', 'Zoom In', ...
                                     'Callback', @(hObject, eventdata)handleZoomIn(obj, hObject, eventdata), ...
                                     'Accelerator', '');
            uimenu(obj.timelineMenu, 'Label', 'Zoom Out', ...
                                     'Callback', @(hObject, eventdata)handleZoomOut(obj, hObject, eventdata), ...
                                     'Accelerator', '');
            uimenu(obj.timelineMenu, 'Label', 'Zoom to Selection', ...
                                     'Callback', @(hObject, eventdata)handleZoomToSelection(obj, hObject, eventdata), ...
                                     'Accelerator', '');
            uimenu(obj.timelineMenu, 'Label', 'Open Waveform for New Recordings', ...
                                     'Callback', @(hObject, eventdata)handleShowWaveformOnOpen(obj, hObject, eventdata), ...
                                     'Separator', 'on', ...
                                     'Checked', onOff(getpref('Tempo', 'ShowWaveforms', true) && ~getpref('Tempo', 'ShowSpectrograms', true)), ...
                                     'Tag', 'showWaveformOnOpen');
            uimenu(obj.timelineMenu, 'Label', 'Open Spectrogram for New Recordings', ...
                                     'Callback', @(hObject, eventdata)handleShowSpectrogramOnOpen(obj, hObject, eventdata), ...
                                     'Checked', onOff(~getpref('Tempo', 'ShowWaveforms', true) && getpref('Tempo', 'ShowSpectrograms', true)), ...
                                     'Tag', 'showSpectrogramOnOpen');
            uimenu(obj.timelineMenu, 'Label', 'Open Both for New Recordings', ...
                                     'Callback', @(hObject, eventdata)handleShowBothOnOpen(obj, hObject, eventdata), ...
                                     'Checked', onOff(getpref('Tempo', 'ShowWaveforms', true) && getpref('Tempo', 'ShowSpectrograms', true)), ...
                                     'Tag', 'showBothOnOpen');
            
            obj.playbackMenu = uimenu(obj.figure, 'Label', 'Playback');
            uimenu(obj.playbackMenu, 'Label', 'Play', ...
                                     'Callback', @(hObject, eventdata)handlePlay(obj, hObject, eventdata, 'forwards'), ...
                                     'Accelerator', '');
            uimenu(obj.playbackMenu, 'Label', 'Play Backwards', ...
                                     'Callback', @(hObject, eventdata)handlePlay(obj, hObject, eventdata, 'backwards'), ...
                                     'Accelerator', '');
            uimenu(obj.playbackMenu, 'Label', 'Pause', ...
                                     'Callback', @(hObject, eventdata)handlePause(obj, hObject, eventdata), ...
                                     'Accelerator', '');
            uimenu(obj.playbackMenu, 'Label', 'Play at Regular Speed', ...
                                     'Callback', @(hObject, eventdata)handlePlay(obj, hObject, eventdata, '1x'), ...
                                     'Accelerator', '1', ...
                                     'Separator', 'on', ...
                                     'Checked', 'on', ...
                                     'Tag', 'regularSpeed');
            uimenu(obj.playbackMenu, 'Label', 'Play at Double Speed', ...
                                     'Callback', @(hObject, eventdata)handlePlay(obj, hObject, eventdata, '2x'), ...
                                     'Accelerator', '2', ...
                                     'Tag', 'doubleSpeed');
            uimenu(obj.playbackMenu, 'Label', 'Play at Half Speed', ...
                                     'Callback', @(hObject, eventdata)handlePlay(obj, hObject, eventdata, '1/2x'), ...
                                     'Accelerator', '', ...
                                     'Tag', 'halfSpeed');
            uimenu(obj.playbackMenu, 'Label', 'Increase Speed', ...
                                     'Callback', @(hObject, eventdata)handlePlay(obj, hObject, eventdata, 'faster'), ...
                                     'Accelerator', '', ...
                                     'Separator', 'on');
            uimenu(obj.playbackMenu, 'Label', 'Decrease Speed', ...
                                     'Callback', @(hObject, eventdata)handlePlay(obj, hObject, eventdata, 'slower'), ...
                                     'Accelerator', '');
            
            obj.windowMenu = uimenu(obj.figure, 'Label', 'Window');
            uimenu(obj.windowMenu, 'Label', 'Show Toolbar', ...
                                   'Callback', @(hObject, eventdata)handleShowToolbar(obj, hObject, eventdata), ...
                                   'Accelerator', '', ...
                                   'Checked', onOff(getpref('Tempo', 'WindowShowToolbar', true)), ...
                                   'Tag', 'showToolbar');
            uimenu(obj.windowMenu, 'Label', 'Arrange Windows Top to Bottom', ...
                                   'Callback', '', ...
                                   'Accelerator', '', ...
                                   'Separator', 'on', ...
                                   'Enable', 'off');
            uimenu(obj.windowMenu, 'Label', 'Arrange Windows Left to Right', ...
                                   'Callback', '', ...
                                   'Accelerator', '', ...
                                   'Enable', 'off');
            % TODO: add/manage the list of open windows
            
            % TODO: Help menu
        end
        
        
        function createToolbar(obj)
            % Open | Zoom in Zoom out | Play Pause | Find features | Save features Save screenshot | Show/hide waveforms Show/hide features Toggle time format
            obj.toolbar = uitoolbar(obj.figure);
            
            [tempoRoot, ~, ~] = fileparts(mfilename('fullpath'));
            iconRoot = fullfile(tempoRoot, 'Icons');
            defaultBackground = get(0, 'defaultUicontrolBackgroundColor');
            
            % Open, save, export
            
            iconData = double(imread(fullfile(matlabroot, 'toolbox', 'matlab', 'icons', 'file_open.png'), 'BackgroundColor', defaultBackground)) / 65535;
            uipushtool(obj.toolbar, ...
                'Tag', 'openFile', ...
                'CData', iconData, ...
                'TooltipString', 'Open a saved workspace, open audio/video files or import features',... 
                'Separator', 'on', ...
                'ClickedCallback', @(hObject, eventdata)handleOpenFile(obj, hObject, eventdata));
            iconData = double(imread(fullfile(matlabroot, 'toolbox', 'matlab', 'icons', 'file_save.png'),'BackgroundColor', defaultBackground)) / 65535;
            uipushtool(obj.toolbar, ...
                'Tag', 'saveWorkspace', ...
                'CData', iconData, ...
                'TooltipString', 'Save the workspace',...
                'ClickedCallback', @(hObject, eventdata)handleSaveWorkspace(obj, hObject, eventdata));
            
            iconData = double(imread(fullfile(matlabroot, 'toolbox', 'matlab', 'icons', 'tool_shape_rectangle.png'),'BackgroundColor', defaultBackground)) / 65535;
            uipushtool(obj.toolbar, ...
                'Tag', 'exportSelection', ...
                'CData', iconData, ...
                'TooltipString', 'Export the selected time window to a movie',...
                'ClickedCallback', @(hObject, eventdata)handleExportSelection(obj, hObject, eventdata));
            
            iconData = double(imread(fullfile(iconRoot, 'screenshot.png'), 'BackgroundColor', defaultBackground)) / 255;
            uipushtool(obj.toolbar, ...
                'Tag', 'saveScreenshot', ...
                'CData', iconData, ...
                'TooltipString', 'Save a screenshot',...
                'ClickedCallback', @(hObject, eventdata)handleSaveScreenshot(obj, hObject, eventdata));
            
            iconData = double(imread(fullfile(iconRoot, 'detect.png'), 'BackgroundColor', defaultBackground)) / 255;
            obj.detectPopUpTool = uisplittool('Parent', obj.toolbar, ...
                'Tag', 'detectFeatures', ...
                'CData', iconData, ...
                'TooltipString', 'Detect features',... 
                'Separator', 'on', ...
                'ClickedCallback', @(hObject, eventdata)handleDetectFeatures(obj, hObject, eventdata));
            
            % Playback
            
            forwardIcon = double(imread(fullfile(iconRoot, 'play.png'), 'BackgroundColor', defaultBackground)) / 255;
            pauseIcon = double(imread(fullfile(iconRoot, 'pause.png'), 'BackgroundColor', defaultBackground)) / 255;
            backwardsIcon = flipdim(forwardIcon, 2);
            obj.playSlowerTool = uipushtool(obj.toolbar, ...
                'CData', backwardsIcon, ...
                'Separator', 'on', ...
                'TooltipString', 'Decrease the speed of playback',... 
                'ClickedCallback', @(hObject, eventdata)handlePlay(obj, hObject, eventdata, 'slower'));
            obj.playBackwardsTool = uipushtool(obj.toolbar, ...
                'CData', backwardsIcon, ...
                'TooltipString', 'Play backwards',... 
                'ClickedCallback', @(hObject, eventdata)handlePlay(obj, hObject, eventdata, 'backwards'));
            obj.pauseTool = uipushtool(obj.toolbar, ...
                'CData', pauseIcon, ...
                'TooltipString', 'Pause playback',... 
                'ClickedCallback', @(hObject, eventdata)handlePause(obj, hObject, eventdata), ...
                'Enable', 'off');
            obj.playForwardsTool = uipushtool(obj.toolbar, ...
                'CData', forwardIcon, ...
                'TooltipString', 'Play forwards',... 
                'ClickedCallback', @(hObject, eventdata)handlePlay(obj, hObject, eventdata, 'forwards'));
            obj.playFasterTool = uipushtool(obj.toolbar, ...
                'CData', forwardIcon, ...
                'TooltipString', 'Increase the speed of playback',... 
                'ClickedCallback', @(hObject, eventdata)handlePlay(obj, hObject, eventdata, 'faster'));
            
            % Zooming
            
            iconData = double(imread(fullfile(matlabroot, 'toolbox', 'matlab', 'icons', 'tool_zoom_in.png'), 'BackgroundColor', defaultBackground)) / 65535;
            uipushtool(obj.toolbar, ...
                'Tag', 'zoomIn', ...
                'CData', iconData, ...
                'TooltipString', 'Zoom in',... 
                'Separator', 'on', ...
                'ClickedCallback', @(hObject, eventdata)handleZoomIn(obj, hObject, eventdata));
            iconData = double(imread(fullfile(matlabroot, 'toolbox', 'matlab', 'icons', 'tool_zoom_out.png'), 'BackgroundColor', defaultBackground)) / 65535;
            uipushtool(obj.toolbar, ...
                'Tag', 'zoomOut', ...
                'CData', iconData, ...
                'TooltipString', 'Zoom out',... 
                'ClickedCallback', @(hObject, eventdata)handleZoomOut(obj, hObject, eventdata));
            
            drawnow;
            
            obj.jToolbar = get(get(obj.toolbar, 'JavaContainer'), 'ComponentPeer');
            if ~isempty(obj.jToolbar)
                oldWarn = warning('off', 'MATLAB:hg:JavaSetHGProperty');
                oldWarn2 = warning('off', 'MATLAB:hg:PossibleDeprecatedJavaSetHGProperty');
                
                % Add the detector options to the pop-up menu.
                jDetect = get(obj.detectPopUpTool,'JavaContainer');
                jMenu = get(jDetect,'MenuComponent');
                jMenu.removeAll;
                for actionIdx = 1:length(obj.detectorTypeNames)
                    jActionItem = jMenu.add(obj.detectorTypeNames(actionIdx));
                    set(jActionItem, 'ActionPerformedCallback', @(hObject, eventdata)handleDetectFeatures(obj, hObject, eventdata), ...
                        'UserData', actionIdx);
                end
                
                % Try to replace the playback tools with Java buttons that can display the play rate, etc.
                obj.replaceToolbarTool(8, 'playSlowerTool', 'PlaySlower');
                obj.replaceToolbarTool(9, 'playBackwardsTool', 'PlayBackwards');
                obj.replaceToolbarTool(10, 'pauseTool');
                if isjava(obj.pauseTool)
                    obj.pauseTool.setText('1x');
                end
                obj.replaceToolbarTool(11, 'playForwardsTool', 'PlayForwards');
                obj.replaceToolbarTool(12, 'playFasterTool', 'PlayFaster');

                try
                    obj.jToolbar(1).repaint;
                    obj.jToolbar(1).revalidate;
                catch
                end
                
                warning(oldWarn);
                warning(oldWarn2);
            end
        end
        
        
        function replaceToolbarTool(obj, position, toolName, iconName)
            % Try to replace the tool with a Java button.
            try
                if nargin < 4
                    jButton = javax.swing.JButton('');
                    jButton.setMargin(java.awt.Insets(1, 2, 1, 2));
                else
                    jButton = javax.swing.JButton(javax.swing.ImageIcon(fullfile('icons', [iconName '.png'])));
                end
                callback = get(obj.(toolName), 'ClickedCallback');
                tooltip = get(obj.(toolName), 'TooltipString');
                set(jButton, 'ActionPerformedCallback', callback, ...
                             'ToolTipText', tooltip);
                delete(obj.(toolName));
                obj.jToolbar(1).add(jButton, position);
                obj.(toolName) = jButton;
            catch ME
                rethrow(ME);
                % Oh well, leave it alone.
            end
        end
        
        
        %% Panel management
        
        
        function panels = panelsOfClass(obj, panelClass)
            % Return a cell array of panel instances of the given class.
            % A cell array is needed in case a base panel class is specified, e.g. TimelinePanel.
            
            panels = {};
            for i = 1:length(obj.videoPanels)
                panel = obj.videoPanels{i};
                if isa(panel, panelClass)
                    panels{end + 1} = panel; %#ok<AGROW>
                end
            end
            for i = 1:length(obj.timelinePanels)
                panel = obj.timelinePanels{i};
                if isa(panel, panelClass)
                    panels{end + 1} = panel; %#ok<AGROW>
                end
            end
        end
        
        
        function arrangePanels(obj, panels, parentSize, margin)  %#ok<INUSL>
            % Arrange a set of panels within the given parent size (W, H) and margins (T, R, B, L).
            
            % Figure out how many panels are hidden.
            numPanels = length(panels);
            numHidden = 0;
            for i = 1:numPanels
                if panels{i}.isHidden
                    numHidden = numHidden + 1;
                end
            end
            numShown = numPanels - numHidden;
            
            % Arrange the panels.
            % Open panels share the full height of the area minus room for hidden panels and top and bottom margins.
            % TODO: allow left to right
            % TODO: allow panels to specify a fixed height/width.
            titleBarHeight = 16;
            shownPanelsHeight = parentSize(2) - margin(1) - numPanels * (titleBarHeight + 1) - margin(3);
            shownPanelHeight = floor(shownPanelsHeight / numShown);
            curY = parentSize(2) - margin(1) + 2;
            for i = 1:numPanels
                if panels{i}.isHidden
                    % Just need room for the title bar.
                    panelHeight = titleBarHeight;
                    curY = curY - panelHeight - 1;
                elseif i < numPanels
                    % Open panels get an even fraction of the available space.
                    % Leave a one pixel gap between panels so there's a visible line between them.
                    panelHeight = shownPanelHeight + 1 + titleBarHeight;
                    curY = curY - panelHeight - 1;
                else
                    % The last open panel gets whatever is left.
                    panelHeight = curY - (2 + margin(3)) - 1;
                    curY = 2 + margin(3);
                end
                set(panels{i}.panel, 'Position', [margin(4), curY, parentSize(1) - margin(2), panelHeight]);
                panels{i}.handleResize([], []);
            end
        end
        
        
        function arrangeVideoPanels(obj, ~, ~)
            % Get the size of the top-level panel.
            set(obj.videosPanel, 'Units', 'pixels');
            videosPos = get(obj.videosPanel, 'Position');
            set(obj.videosPanel, 'Units', 'normalized');
            
            if videosPos(3) < 5
                % The splitter has been collapsed, don't show the video panels.
                set(obj.videosPanel, 'Visible', 'off');
            else
                % The splitter is open, show the panels.
                set(obj.videosPanel, 'Visible', 'on');
                
                obj.arrangePanels(obj.videoPanels, videosPos(3:4), [0 3 16 4]);
                
                set(obj.videoSlider, 'Position', [1, 0, videosPos(3) + 1, 16]);
            end
        end
        
        
        function showVideoPanels(obj, doShow)
            if nargin < 2
                doShow = true;
            end
            isShowing = (get(obj.splitter, 'DividerLocation') > 0.01);
            if isShowing ~= doShow
                try
                    obj.splitter.JavaComponent.getComponent(0).doClick();
                catch
                    % oh well?
                end
            end
        end
        
        
        function to = timelinesAreOpen(obj)
            % Get the size of the top-level panel.
            set(obj.timelinesPanel, 'Units', 'pixels');
            timelinesPos = get(obj.timelinesPanel, 'Position');
            set(obj.timelinesPanel, 'Units', 'normalized');
            
            to = timelinesPos(3) > 15;
        end
        
        
        function arrangeTimelinePanels(obj, ~, ~)
            % Get the size of the top-level panel.
            set(obj.timelinesPanel, 'Units', 'pixels');
            timelinesPos = get(obj.timelinesPanel, 'Position');
            set(obj.timelinesPanel, 'Units', 'normalized');
            
            if timelinesPos(3) > 15
                % The splitter is open, show the panels.
                set(obj.timelinesPanel, 'Visible', 'on');
                
                % Position the time indicator panel at the bottom.
                timeIndicatorHeight = 13;
                obj.timeIndicatorPanel.setHidden(false);
                set(obj.timeIndicatorPanel.panel, 'Position', [2, 18, timelinesPos(3), timeIndicatorHeight + 1]);
                obj.timeIndicatorPanel.updateAxes(obj.displayRange(1:2));
                
                obj.arrangePanels(obj.timelinePanels, timelinesPos(3:4), [0, 0, timeIndicatorHeight + 2 + 16, 2]);
                
                % Position the timeline slider at the bottom.
                set(obj.timelineSlider, 'Position', [1, 0, timelinesPos(3) + 1, 16]);
            else
                % The splitter has been collapsed, don't show the timeline panels.
                set(obj.timelinesPanel, 'Visible', 'off');
            end
        end
        
        
        function showTimelinePanels(obj, doShow)
            if nargin < 2
                doShow = true;
            end
            isShowing = (get(obj.splitter, 'DividerLocation') < 0.99);
            if isShowing ~= doShow
                try
                    obj.splitter.JavaComponent.getComponent(1).doClick();
                catch
                    % oh well?
                end
            end
        end
        
        
        function hidePanel(obj, panel)
            panel.setHidden(true);
            if isa(panel, 'VideoPanel')
                obj.arrangeVideoPanels();
            else
                obj.arrangeTimelinePanels();
            end
        end
        
        
        function showPanel(obj, panel)
            panel.setHidden(false);
            if isa(panel, 'VideoPanel')
                obj.arrangeVideoPanels();
            else
                obj.arrangeTimelinePanels();
            end
        end
        
        
        function closePanel(obj, panel)
            if isa(panel, 'VideoPanel')
                % Let the panel do what it needs to before closing.
                panel.close();
                
                % Remove the panel.
                obj.videoPanels(cellfun(@(x) x == panel, obj.videoPanels)) = [];
                obj.arrangeVideoPanels();
            else
                % Let the panel do what it needs to before closing.
                panel.close();
                
                % Remove the panel.
                obj.timelinePanels(cellfun(@(x) x == panel, obj.timelinePanels)) = [];
                obj.arrangeTimelinePanels();
            end
        end
        
        
        %% File menu callbacks
        
        
        function handleNewWorkspace(obj, ~, ~) %#ok<INUSD>
            % Open a new window with a new controller object.
            % TODO: stagger the window so it doesn't land exactly on top of the existing one.
            TempoController();
        end
        
        
        function handleOpenFile(obj, ~, ~)
            [fileNames, pathName] = uigetfile('*.*', 'Select an audio or video file to open', 'MultiSelect', 'on');
            
            if ischar(fileNames)
                fileNames = {fileNames};
            elseif isnumeric(fileNames)
                fileNames = {};
            end
            
            nothingWasOpen = isempty(obj.recordings);
            somethingOpened = false;

            for i = 1:length(fileNames)
                fileName = fileNames{i};
                fullPath = fullfile(pathName, fileName);

                % Handle special characters in the file name.
                NFD = javaMethod('valueOf', 'java.text.Normalizer$Form','NFD');
                UTF8=java.nio.charset.Charset.forName('UTF-8');
                s = java.lang.String(fullPath);
                sc = java.text.Normalizer.normalize(s,NFD);
                bs = single(sc.getBytes(UTF8)');
                bs(bs < 0) = 256 + (bs(bs < 0));
                fullPath = char(bs);
                
                [~, ~, ext] = fileparts(fileName);
                if strcmp(ext, '.tempo')
                    if isempty(obj.recordings) && isempty(obj.reporters)
                        % Nothing has been done in this controller so load the workspace here.
                        target = obj;
                    else
                        % Open the workspace in a new controller.
                        target = TempoController();
                    end
                    target.openWorkspace(fullPath);
                    somethingOpened = true;
                    continue
                end
                
                % First check if the file can be imported by one of the feature importers.
                try
                    possibleImporters = [];
                    for j = 1:length(obj.importerClassNames)
                        if eval([obj.importerClassNames{j} '.canImportFromPath(''' strrep(fullPath, '''', '''''') ''')'])
                            possibleImporters(end+1) = j; %#ok<AGROW>
                        end
                    end
                    
                    if ~isempty(possibleImporters)
                        index = [];
                        if length(possibleImporters) == 1
                            index = possibleImporters(1);
                        else
                            choice = listdlg('PromptString', 'Choose which importer to use:', ...
                                             'SelectionMode', 'Single', ...
                                             'ListString', handles.importerTypeNames(possibleImporters));
                            if ~isempty(choice)
                                index = choice(1);
                            end
                        end
                        if ~isempty(index)
                            obj.importing = true;
                            constructor = str2func(obj.importerClassNames{index});
                            importer = constructor(obj, fullPath);
                            importer.startProgress();
                            try
                                n = importer.importFeatures();
                                importer.endProgress();
                                obj.importing = false;
                                
                                % Open any recordings that the importer queued up.
                                for recording = obj.recordingsToAdd
                                    if isa(recording, 'AudioRecording')
                                        obj.addAudioRecording(recording);
                                    elseif isa(recording, 'VideoRecording')
                                        obj.addVideoRecording(recording);
                                    end
                                end
                                obj.recordingsToAdd = {};
                                
                                if n == 0
                                    waitfor(msgbox('No features were imported.', obj.importerTypeNames{index}, 'warn', 'modal'));
                                else
                                    obj.reporters{end + 1} = importer;
                                    obj.timelinePanels{end + 1} = FeaturesPanel(importer);
                                    
                                    obj.arrangeTimelinePanels();
                                    
                                    somethingOpened = true;
                                end
                            catch ME
                                importer.endProgress();
                                obj.importing = false;
                                obj.recordingsToAdd = {};
                                waitfor(msgbox('An error occurred while importing features.  (See the command window for details.)', obj.importerTypeNames{index}, 'error', 'modal'));
                                rethrow(ME);
                            end

% TODO                            addContextualMenu(importer);
                        end
                    end
                catch ME
                    rethrow(ME);
                end

                % Next check if it's an audio or video file.
                try
                    for j = 1:length(obj.recordingClassNames)
                        if eval([obj.recordingClassNames{j} '.canLoadFromPath(''' strrep(fullPath, '''', '''''') ''')'])
                            set(obj.figure, 'Pointer', 'watch'); drawnow
                            constructor = str2func(obj.recordingClassNames{j});
                            recording = constructor(obj, fullPath);
                            if isa(recording, 'AudioRecording')
                                obj.addAudioRecording(recording);
                                somethingOpened = true;
                            elseif isa(recording, 'VideoRecording')
                                obj.addVideoRecording(recording);
                                somethingOpened = true;
                            end
                            set(obj.figure, 'Pointer', 'arrow'); drawnow
                            break
                        end
                    end
                catch ME
                    set(obj.figure, 'Pointer', 'arrow'); drawnow
                    if ~strcmp(ME.identifier, 'Tempo:UserCancelled')
                        warndlg(sprintf('Error opening recording:\n\n%s', ME.message));
                        rethrow(ME);
                    end
                end
            end
            
            if somethingOpened
                obj.updateOverallDuration();
                
                if nothingWasOpen
                    if isempty(obj.videoPanels)
                        % Hide the video half of the splitter.
                        obj.showVideoPanels(false);
                    elseif isempty(obj.timelinePanels)
                        % Hide the video half of the splitter.
                        obj.showTimelinePanels(false);
                    end
                end
                
                obj.needsSave = true;
            elseif ~isempty(fileNames)
                warndlg('Tempo does not know how to open that kind of file.');
            end
        end
        
        
        function saved = handleSaveWorkspace(obj, ~, ~)
            saved = false;
            
            if isempty(obj.savePath)
                % Figure out a default save location and name.
                if isempty(obj.recordings)
                    filePath = '';
                    fileName = 'Workspace';
                else
                    [filePath, fileName, ~] = fileparts(obj.recordings{1}.filePath);
                end
                [fileName, filePath] = uiputfile({'*.tempo', 'Tempo Workspace'}, 'Save Tempo Workspace', fullfile(filePath, fileName));
                if ~eq(fileName, 0)
                    obj.savePath = fullfile(filePath, fileName);
                    [~, fileName, ~] = fileparts(fileName); % strip off the extension
                    set(obj.figure, 'Name', ['Tempo: ' fileName]);
                end
            end
            
            if ~isempty(obj.savePath)
                try
                    obj.saveWorkspace(obj.savePath);
                    obj.needsSave = false;
                    saved = true;
                catch ME
                    waitfor(warndlg(['Could not save the workspace. (' ME.message ')'], 'Tempo', 'modal'));
                end
            end
        end
        
        
        function saved = handleExportSelection(obj, ~, ~)
           saved = false;
            
            % Figure out a default save location and name.
            if isempty(obj.recordings)
                filePath = '';
                fileName = 'Workspace';
            else
                [filePath, fileName, ~] = fileparts(obj.recordings{1}.filePath);
            end
            [fileName, filePath] = uiputfile('*.mp4', 'Export Selection', fullfile(filePath, fileName));
            if ~eq(fileName, 0)
                exportPath = fullfile(filePath, fileName);
                [~, fileName, ~] = fileparts(fileName); % strip off the extension
                set(obj.figure, 'Name', ['Tempo: ' fileName]);
            end
            
            if ~isempty(exportPath)
                try
                    h=waitbar(0,'');
                    c=fileparts(mfilename('fullpath'));
                    if ismac
                      c=fullfile(c, 'ThirdParty', 'ffmpeg', 'ffmpeg_mac ');
                    elseif ispc
                      c=fullfile(c, 'ThirdParty', 'ffmpeg', 'ffmpeg_win.exe ');
                    elseif isunix
                      c=fullfile(c, 'ThirdParty', 'ffmpeg', 'ffmpeg_linux ');
                    end
                    f=cell(1,length(obj.recordings));
                    for i=1:length(obj.recordings)
                        h=waitbar(i/(length(obj.recordings)+1),h,['Processing ' obj.recordings{i}.name]);
                        set(findall(h,'type','text'),'Interpreter','none');
                        f{i}=obj.recordings{i}.saveData;
                        c=[c '-i ' f{i} ' ']; %#ok<AGROW>
                    end
                    c=[c '-acodec copy -vcodec copy ''' exportPath ''''];
                    waitbar(length(obj.recordings)/(length(obj.recordings)+1),h,['Processing '  exportPath]);
                    [s,~]=system(c);
                    if s
                      close(h);
                      ME=MException('problem with system(''ffmpeg'')');
                      throw(ME);
                    end
                    waitbar(1,h,'Deleting temporary files');
                    for i=1:length(obj.recordings)
                      delete(f{i});
                    end
                    close(h);
                catch ME
                    waitfor(warndlg(['Could not export the selection. (' ME.message ')'], 'Tempo', 'modal'));
                end
            end
        end
        
        
        function handleSaveScreenshot(obj, ~, ~)
            % TODO: determine if Ghostscript is installed and reduce choices if not.
            if isempty(obj.recordings)
                defaultPath = '';
                defaultName = 'Screenshot';
            else
                [defaultPath, defaultName, ~] = fileparts(obj.recordings{1}.filePath);
            end
            [fileName, pathName] = uiputfile({'*.pdf','Portable Document Format (*.pdf)'; ...
                                              '*.eps','Encapsulated Level 2 Color PostScript (*.eps)'; ...
                                              '*.png','PNG format (*.png)'; ...
                                              '*.jpg','JPEG format (*.jpg)'}, ...
                                             'Save a screen shot', ...
                                             fullfile(defaultPath, [defaultName '.pdf']));

            if ~isnumeric(fileName)
                if ismac
                    % Make sure export_fig can find Ghostscript if it was installed via MacPorts.
                    prevEnv = getenv('DYLD_LIBRARY_PATH');
                    setenv('DYLD_LIBRARY_PATH', ['/opt/local/lib:' prevEnv]);
                end
                
                % Determine the list of axes to export.
                axesToSave = [obj.timeIndicatorPanel.axes];
                for i = 1:length(obj.videoPanels)
                    if ~obj.videoPanels{i}.isHidden
                        axesToSave(end + 1) = obj.videoPanels{i}.axes; %#ok<AGROW>
                    end
                end
                for i = 1:length(obj.timelinePanels)
                    if ~obj.timelinePanels{i}.isHidden
                        axesToSave(end + 1) = obj.timelinePanels{i}.axes; %#ok<AGROW>
%                        visibleTimelinePanels{i}.showSelection(false);
                    end
                end
                
                [~,~,e]=fileparts(fileName);
                switch e
                  case '.pdf'
                    print(obj.figure, '-dpdf', '-painters', fullfile(pathName, fileName));
                  case '.eps'
                    print(obj.figure, '-depsc2', '-painters', fullfile(pathName, fileName));
                  case '.png'
                    print(obj.figure, '-dpng', fullfile(pathName, fileName));
                  case '.jpg'
                    print(obj.figure, '-djpeg', fullfile(pathName, fileName));
                end
%                export_fig(fullfile(pathName, fileName), '-opengl', '-a1');  %, axesToSave);

                % Show the current selection again.
                for i = 1:length(obj.timelinePanels)
                    if ~obj.timelinePanels{i}.isHidden
                        obj.timelinePanels{i}.showSelection(true);
                    end
                end
                
                if ismac
                    setenv('DYLD_LIBRARY_PATH', prevEnv);
                end
            end
        end
        
        
        %% Edit menu callbacks
        
        
        function handleSelectAll(obj, ~, ~)
            % Select the full duration of all recordings.
            obj.selectedRange = [0 obj.duration -inf inf];
        end
        
        
        function handleSelectNone(obj, ~, ~)
            % Reduce the selection to just the current time.
            obj.selectedRange = [obj.currentTime obj.currentTime -inf inf];
        end
        
        
        function handleDetectFeatures(obj, hObject, ~)
            index = get(hObject, 'UserData');
            
            if isempty(index)
                % The user clicked the icon instead of the little pop-up arrow.
                % We want the pop-up menu to appear in this case as well.
                jDetect = get(obj.detectPopUpTool,'JavaContainer');
                if ~isempty(jDetect)
                    jDetect.showMenu();
                else
                    waitfor(warndlg({'Could not automatically pop up the detectors toolbar menu.', '', 'Please click the small arrow next to the icon instead.'}, 'Tempo', 'modal'));
                end
            else
                detectorClassName = obj.detectorClassNames{index};
                
                constructor = str2func(detectorClassName);
                detector = constructor(obj);
                
                if detector.editSettings()
% TODO:               addContextualMenu(detector);
                    
                    detector.startProgress();
                    try
                        if obj.selectedRange(2) > obj.selectedRange(1)
                            n = detector.detectFeatures(obj.selectedRange);
                        else
                            n = detector.detectFeatures([0.0 obj.duration]);
                        end
                        detector.endProgress();
                        
                        if n == 0
                            waitfor(msgbox('No features were detected.', detectorClassName, 'warn', 'modal'));
                        else
                            obj.reporters{end + 1} = detector;
                            obj.timelinePanels{end + 1} = FeaturesPanel(detector);
                            
                            obj.arrangeTimelinePanels();
                            
                            obj.showTimelinePanels(true);
                            
                            obj.needsSave = true;
                        end
                        
% TODO:                   handles = updateFeatureTimes(handles);
                    catch ME
                        waitfor(msgbox(['An error occurred while detecting features:' char(10) char(10) ME.message char(10) char(10) '(See the command window for details.)'], ...
                                       detectorClassName, 'error', 'modal'));
                        detector.endProgress();
                        rethrow(ME);
                    end
                end
            end
        end
        
        
        %% Video menu callbacks
        
        
        function handleShowFrameNumber(obj, ~, ~)
            % Toggle the display of the frame count in video panels.
            menuItem = findobj(obj.videoMenu, 'Tag', 'showFrameNumber');
            curState = get(menuItem, 'Checked');
            showNumbers = strcmp(curState, 'off');
            
            for videoPanel = obj.videoPanels
                videoPanel{1}.showFrameNumber(showNumbers);
            end
            
            if showNumbers
                set(menuItem, 'Checked', 'on');
            else
                set(menuItem, 'Checked', 'off');
            end
            
            setpref('Tempo', 'VideoShowFrameNumber', showNumbers);
        end
        
        
        %% Timeline menu callbacks
        
        
        function handleZoomIn(obj, ~, ~)
            obj.setZoom(obj.zoom * 2);
        end
        
        
        function handleZoomOut(obj, ~, ~)
            obj.setZoom(obj.zoom / 2);
        end
        
        
        function handleZoomToSelection(obj, ~, ~)
            selectionLength = abs(obj.selectedRange(2) - obj.selectedRange(1));
            if selectionLength > 0
                % Zoom the timelines so the selection exactly fits in the panels.
                obj.setZoom(obj.duration / selectionLength);
            else
                % Keep the current zoom but center the selection line.
                obj.centerDisplayAtTime(mean(obj.selectedRange(1:2)));
            end
        end
        
        
        function handleShowWaveformOnOpen(obj, ~, ~)
            % Update the menu items.
            set(findobj(obj.timelineMenu, 'Tag', 'showWaveformOnOpen'), 'Checked', 'on');
            set(findobj(obj.timelineMenu, 'Tag', 'showSpectrogramOnOpen'), 'Checked', 'off');
            set(findobj(obj.timelineMenu, 'Tag', 'showBothOnOpen'), 'Checked', 'off');
            
            % Remember the user's choice.
            setpref('Tempo', 'ShowWaveforms', true);
            setpref('Tempo', 'ShowSpectrograms', false);
        end
        
        
        function handleShowSpectrogramOnOpen(obj, ~, ~)
            % Update the menu items.
            set(findobj(obj.timelineMenu, 'Tag', 'showWaveformOnOpen'), 'Checked', 'off');
            set(findobj(obj.timelineMenu, 'Tag', 'showSpectrogramOnOpen'), 'Checked', 'on');
            set(findobj(obj.timelineMenu, 'Tag', 'showBothOnOpen'), 'Checked', 'off');
            
            % Remember the user's choice.
            setpref('Tempo', 'ShowWaveforms', false);
            setpref('Tempo', 'ShowSpectrograms', true);
        end
        
        
        function handleShowBothOnOpen(obj, ~, ~)
            % Update the menu items.
            set(findobj(obj.timelineMenu, 'Tag', 'showWaveformOnOpen'), 'Checked', 'off');
            set(findobj(obj.timelineMenu, 'Tag', 'showSpectrogramOnOpen'), 'Checked', 'off');
            set(findobj(obj.timelineMenu, 'Tag', 'showBothOnOpen'), 'Checked', 'on');
            
            % Remember the user's choice.
            setpref('Tempo', 'ShowWaveforms', true);
            setpref('Tempo', 'ShowSpectrograms', true);
        end
        
        
        function openWaveform(obj, recording)
            % Open or show the waveform for the given recording.
            
            % If it exists then make sure it's showing.
            waveform = [];
            for panel = obj.panelsOfClass('WaveformPanel')
                if panel{1}.audio == recording
                    panel{1}.setHidden(false);
                    waveform = panel;
                    break
                end
            end
            
            if isempty(waveform)
                % Otherwise add a waveform panel right below the spectrorgam panel of the same recording.
                position = length(obj.timelinePanels);
                for i = 1:length(obj.timelinePanels)
                    panel = obj.timelinePanels{i};
                    if isa(panel, 'SpectrogramPanel') && panel.audio == recording
                        position = i;
                        break
                    end
                end

                waveform = WaveformPanel(obj, recording);
                waveform.handleTimeWindowChanged();
                obj.timelinePanels = {obj.timelinePanels{1:position}, waveform, obj.timelinePanels{position + 1:end}};
            end
            
            obj.arrangeTimelinePanels();
        end
        
        
        function openSpectrogram(obj, recording)
            % Open or show the spectrogram for the given recording.
            
            % If it exists then make sure it's showing.
            spectrogram = [];
            for panel = obj.panelsOfClass('SpectrogramPanel')
                if panel{1}.audio == recording
                    panel{1}.setHidden(false);
                    spectrogram = panel;
                    break
                end
            end
            
            if isempty(spectrogram)
                % Otherwise add a spectrogram panel right below the waveform panel of the same recording.
                position = length(obj.timelinePanels);
                for i = 1:length(obj.timelinePanels)
                    panel = obj.timelinePanels{i};
                    if isa(panel, 'WaveformPanel') && panel.audio == recording
                        position = i;
                        break
                    end
                end

                spectrogram = SpectrogramPanel(obj, recording);
                spectrogram.handleTimeWindowChanged();
                obj.timelinePanels = {obj.timelinePanels{1:position}, spectrogram, obj.timelinePanels{position + 1:end}};
            end
            
            obj.arrangeTimelinePanels();
        end
        
        
        %% Playback menu callbacks
        
        
        function handlePlay(obj, ~, ~, playRate)
            % Start playing the recordings or change the speed of playback.
            
            startPlaying = false;
            if strcmp(playRate, 'forwards')
                newRate = abs(obj.playRate);
                startPlaying = true;
            elseif strcmp(playRate, 'backwards')
                newRate = -abs(obj.playRate);
                startPlaying = true;
            elseif strcmp(playRate, '1x')
                newRate = 1.0;
            elseif strcmp(playRate, '2x')
                newRate = 2.0;
            elseif strcmp(playRate, '1/2x')
                newRate = 0.5;
            elseif strcmp(playRate, 'faster')
                newRate = obj.playRate * 2.0;
            elseif strcmp(playRate, 'slower')
                newRate = obj.playRate / 2.0;
            else
                warning('Tempo:UnknownPlayMode', 'Don''t know how to play ''%s''.', num2str(playRate));
            end
            obj.playRate = newRate;
            
            % Update the checked status of the play rate menu items.
            set(obj.menuItem(obj.playbackMenu, 'regularSpeed'), 'Checked', onOff(abs(obj.playRate) == 1.0));
            set(obj.menuItem(obj.playbackMenu, 'doubleSpeed'), 'Checked', onOff(abs(obj.playRate) == 2.0));
            set(obj.menuItem(obj.playbackMenu, 'halfSpeed'), 'Checked', onOff(abs(obj.playRate) == 0.5));
            
            % Show the play rate in the toolbar icon
            if isjava(obj.pauseTool)
                if obj.playRate < 1
                    obj.pauseTool.setText(sprintf('1/%dx', 1.0 / obj.playRate));
                else
                    obj.pauseTool.setText(sprintf('%dx', obj.playRate));
                end
            end
            
            if startPlaying && (~obj.isPlaying || newRate ~= obj.playRate)
                % TODO: if already playing then things need to be done differently...
                
                oldWarn = warning('off', 'MATLAB:hg:JavaSetHGPropertyParamValue');
                set(obj.playBackwardsTool, 'Enable', onOff(obj.playRate > 0));
                set(obj.pauseTool, 'Enable', 'on');
                set(obj.playForwardsTool, 'Enable', onOff(obj.playRate < 0));
                warning(oldWarn);
                
                % Determine what range of time to play.
                if obj.selectedRange(1) ~= obj.selectedRange(2)
                    % Only play within the selected range.
                    if obj.currentTime >= obj.selectedRange(1) && obj.currentTime < obj.selectedRange(2) - 0.1
                        idealRange = [obj.currentTime obj.selectedRange(2)];
                    else
                        idealRange = [obj.selectedRange(1) obj.selectedRange(2)];
                    end
                else
                    % Play starting at the current time unless it's at the end/beginning.
                    idealRange = [0.0 obj.duration];
                    if obj.playRate > 0 && obj.currentTime < obj.duration
                        idealRange(1) = obj.currentTime;
                    elseif obj.playRate < 0 && obj.currentTime > 0
                        idealRange(2) = obj.currentTime;
                    end
                end
                
                obj.isPlaying = true;
                
                if obj.playRate > 0
                    % Start all of the audio players if we're playing forward.
                    % TODO: Alter their sample rate when obj.playRate isn't 1.0.
                    % TODO: Would there ever be any value to hearing the audio backwards?
                    for i = 1:length(obj.recordings)
                        recording = obj.recordings{i};
                        if isa(recording, 'AudioRecording') && ~recording.muted
                            audioRange = round((idealRange + recording.timeOffset) * recording.sampleRate);
                            if audioRange(1) == 0
                                audioRange(1) = 1;
                            end
                            if audioRange(2) > recording.duration * recording.sampleRate
                                audioRange(2) = floor(recording.duration * recording.sampleRate);
                            end
                            player = recording.player();
                            if ~isempty(player)
                                play(player, audioRange);
                            end
                        end
                    end
                end
                
                obj.fpsFrameCount = 0;
                obj.playRange = idealRange;
                obj.playStartTime = now;
                start(obj.playTimer);
            end
        end
        
        
        function handlePlayTimer(obj, ~, ~)
            % Determine how much time has passed since playback started.
            offset = (now - obj.playStartTime) * 24 * 60 * 60;
            
            % Now determine what the new time should be based on the play rate.
            if obj.playRate >= 0
                newTime = obj.playRange(1) + offset * obj.playRate;
            else
                newTime = obj.playRange(2) + offset * obj.playRate;
            end
            
            if (obj.playRate >= 0 && newTime >= obj.playRange(2)) || ...
               (obj.playRate <= 0 && newTime <= obj.playRange(1))
                % Don't go beyond the intended range.
                obj.handlePause([], []);
            else
                obj.currentTime = newTime;
                obj.centerDisplayAtTime(newTime);
            end
        end
        
        
        function handlePause(obj, hObject, ~)
            if obj.isPlaying
                oldWarn = warning('off', 'MATLAB:hg:JavaSetHGPropertyParamValue');
                set(obj.playForwardsTool, 'Enable', 'on');
                set(obj.pauseTool, 'Enable', 'off');
                set(obj.playBackwardsTool, 'Enable', 'on');
                warning(oldWarn);
                
                % Stop all of the audio players.
                for i = 1:length(obj.recordings)
                    recording = obj.recordings{i};
                    if isa(recording, 'AudioRecording') && ~recording.muted
                        player = recording.player();
                        if ~isempty(player)
                            stop(player);
                        end
                    end
                end
                stop(obj.playTimer);

                obj.isPlaying = false;
                
                elapsedTime = (now - obj.playStartTime) * (24*60*60);
                fprintf('FPS: %g (%d/%g)\n', obj.fpsFrameCount / elapsedTime, obj.fpsFrameCount, elapsedTime);
                
                if isempty(hObject)
                    % The recordings played to the end without the user clicking the pause button.
                    if obj.selectedRange(1) ~= obj.selectedRange(2)
                        obj.currentTime = obj.selectedRange(2);
                    else
                        obj.currentTime = obj.duration;
                    end
                    obj.centerDisplayAtTime(obj.currentTime);
                else
                    obj.currentTime = obj.currentTime;
                    obj.centerDisplayAtTime(mean(obj.displayRange(1:2))); % trigger a refresh of timeline-based panels
                end
            end
        end
        
        
        %% Window menu callbacks
        
        
        function handleShowToolbar(obj, ~, ~)
            % Toggle the display of the toolbar.
            menuItem = findobj(obj.windowMenu, 'Tag', 'showToolbar');
            curState = get(menuItem, 'Checked');
            if strcmp(curState, 'on')
                set(obj.toolbar, 'Visible', 'off');
                set(menuItem, 'Checked', 'off');
            else
                if isempty(obj.toolbar)
                    obj.createToolbar();
                end
                set(obj.toolbar, 'Visible', 'on');
                set(menuItem, 'Checked', 'on');
            end
            
            setpref('Tempo', 'WindowShowToolbar', strcmp(curState, 'off'));
        end
        
        
        %% Toolbar callbacks
        
        
        function removeFeaturePanel(obj, featurePanel)
            answer = questdlg('Are you sure you wish to remove this reporter?', 'Removing Reporter', 'Cancel', 'Remove', 'Cancel');
            if strcmp(answer, 'Remove')
                reporter = featurePanel.reporter;
                
                % Remove the panel.
                obj.closePanel(featurePanel);
                
                % Remove the panel's reporter.
                obj.reporters(cellfun(@(x) x == reporter, obj.reporters)) = [];
                delete(reporter);
                
% TODO:                handles = updateFeatureTimes(handles);

                for j = 1:length(obj.timelinePanels)
                    panel = obj.timelinePanels{j};
                    if isa(panel, 'SpectrogramPanel')
                        panel.deleteAllReporters();
                    end
                end
                
                obj.needsSave = true;
            end
        end
        
        
        %% Other callbacks
        
        
        function centerDisplayAtTime(obj, timeCenter)
            if isempty(obj.displayRange) && ~isempty(obj.recordings)
                newRange = [0 obj.recordings{1}.duration 0 floor(obj.recordings{1}.sampleRate / 2)];
            else
                newRange = obj.displayRange;
            end

            timeWindowRadius = obj.duration / obj.zoom / 2;
            if timeCenter - timeWindowRadius < 0
                newRange(1:2) = [0, timeWindowRadius * 2];
            elseif timeCenter + timeWindowRadius > obj.duration
                newRange(1:2) = [obj.duration - timeWindowRadius * 2, obj.duration];
            else
                newRange(1:2) = [timeCenter - timeWindowRadius, timeCenter + timeWindowRadius];
            end

            obj.displayRange = newRange;
        end
        
        
        function selectRange(obj, range)
            obj.selectedRange = range;
            
            obj.currentTime = range(1);
            
            % TODO: Move the selection into view if necessary
%             newRange = ...
%             obj.displayRange = newRange;
        end
        
        
        function setZoom(obj, zoom)
            if zoom < 1
                obj.zoom = 1;
            else
                obj.zoom = zoom;
            end
            
            % Center all of the timeline-based panels on the selection.
            obj.centerDisplayAtTime(mean(obj.selectedRange(1:2)));
            
            if obj.zoom > 1
                set(obj.zoomOutTool, 'Enable', 'on')
            else
                set(obj.zoomOutTool, 'Enable', 'off')
            end
        end
        
        
        function handleResize(obj, ~, ~)
            pos = get(obj.figure, 'Position');
            
            set(obj.splitterPanel, 'Position', [1, 1, pos(3), pos(4)]);
            
            obj.needsSave = true;
        end
        
        
        function pointer = resizePointer(obj, xConstraint, yConstraint)
            % Cursor names:
            %  topl  top   topr
            %  left fleur  right
            %  botl bottom botr
            if obj.panelSelectingTime.showsFrequencyRange && strcmp(yConstraint, 'min')
                pointer = 'bot';
            elseif obj.panelSelectingTime.showsFrequencyRange && strcmp(yConstraint, 'max')
                pointer = 'top';
            else
                pointer = '';
            end
            if strcmp(xConstraint, 'min')
                if isempty(pointer)
                    pointer = 'left';
                else
                    pointer = [pointer 'l'];
                end
            elseif strcmp(xConstraint, 'max')
                if isempty(pointer)
                    pointer = 'right';
                else
                    pointer = [pointer 'r'];
                end
            else
                if isempty(pointer)
                    pointer = 'fleur';
                elseif strcmp(pointer, 'bot')
                    pointer = [pointer 'tom'];
                end
            end
        end
        
        
        function handleMouseButtonDown(obj, ~, ~)
            if strcmp(get(gcf, 'SelectionType'), 'alt')
                return  % Don't change the current time or selection when control/right clicking.
            end
            
            clickedObject = get(obj.figure, 'CurrentObject');
            
            % TODO: allow panels to handle clicks on their objects?
            %
            %     handled = panel{i}.handleMouseDown(...);
            %     if ~handled
            %         ...
            
            for i = 1:length(obj.timelinePanels)
                timelinePanel = obj.timelinePanels{i};
                if clickedObject == timelinePanel.axes
                    clickedPoint = get(clickedObject, 'CurrentPoint');
                    clickedTime = clickedPoint(1, 1);
                    if timelinePanel.showsFrequencyRange
                        % Get the frequency from the clicked point.
                        % TODO: this doesn't work if the spectrogram is hidden when zoomed out.  Probably just need to have YLim set.
                        clickedFreq = clickedPoint(1, 2);
                    else
                        % Pick a dummy frequency at the middle of the selected range.
                        if isinf(obj.selectedRange(3)) && isinf(obj.selectedRange(4))
                            clickedFreq = 0;
                        else
                            clickedFreq = mean(obj.selectedRange(3:4));
                        end
                    end
                    if strcmp(get(gcf, 'SelectionType'), 'extend')
                        % Extend the time range.
                        if obj.currentTime == obj.selectedRange(1) || obj.currentTime ~= obj.selectedRange(2)
                            obj.selectedRange(1:2) = sort([obj.selectedRange(1) clickedTime]);
                        else
                            obj.selectedRange(1:2) = sort([clickedTime obj.selectedRange(2)]);
                        end
                        
                        % Extend the frequency range if appropriate.
                        if timelinePanel.showsFrequencyRange && ~isinf(obj.selectedRange(3)) && ~isinf(obj.selectedRange(4))
                            if clickedFreq < obj.selectedRange(3)
                                obj.selectedRange(3) = clickedFreq;
                            else
                                obj.selectedRange(4) = clickedFreq;
                            end
                        else
                            obj.selectedRange(3:4) = [-inf inf];
                        end
                    else
                        obj.panelSelectingTime = timelinePanel;
                        obj.originalSelectedRange = obj.selectedRange;
                        if clickedTime > obj.selectedRange(1) && clickedTime < obj.selectedRange(2) && ...
                           clickedFreq > obj.selectedRange(3) && clickedFreq < obj.selectedRange(4)
                            % The user clicked inside of the existing selection, figure out which part was clicked on.
                            % TODO: only allow mid/mid if box is too small?
                            
                            if timelinePanel.showsFrequencyRange && isinf(obj.selectedRange(3))
                                obj.selectedRange(3:4) = obj.displayRange(3:4);
                            end
                            
                            axesPos = get(timelinePanel.axes, 'Position');
                            timeMargin = 10 * (obj.displayRange(2) - obj.displayRange(1)) / (axesPos(3) - axesPos(1));
                            freqMargin = 10 * (obj.displayRange(4) - obj.displayRange(3)) / (axesPos(4) - axesPos(2));
                            if clickedTime < obj.selectedRange(1) + timeMargin && clickedTime < obj.selectedRange(2) - timeMargin
                                obj.mouseConstraintTime = 'min';
                            elseif clickedTime > obj.selectedRange(2) - timeMargin && clickedTime > obj.selectedRange(1) + timeMargin
                                obj.mouseConstraintTime = 'max';
                            else
                                obj.mouseConstraintTime = 'mid';
                            end
                            if clickedFreq < obj.selectedRange(3) + freqMargin && clickedFreq < obj.selectedRange(4) - freqMargin
                                obj.mouseConstraintFreq = 'min';
                            elseif clickedFreq > obj.selectedRange(4) - freqMargin && clickedFreq > obj.selectedRange(3) + freqMargin
                                obj.mouseConstraintFreq = 'max';
                            else
                                obj.mouseConstraintFreq = 'mid';
                            end
                        else
                            % The user clicked outside of the existing selection.
                            if timelinePanel.showsFrequencyRange
                                obj.selectedRange = [clickedTime clickedTime clickedFreq clickedFreq];
                            else
                                obj.selectedRange = [clickedTime clickedTime -inf inf];    %obj.displayRange(3:4)];
                            end
                            obj.originalSelectedRange = obj.selectedRange;
                            obj.mouseConstraintTime = 'max';
                            obj.mouseConstraintFreq = 'max';
                            obj.currentTime = clickedTime;
                        end
                        obj.mouseOffset = [clickedTime - obj.selectedRange(1), clickedFreq - obj.selectedRange(3)];
                    end
                    
                    break
                end
            end
        end
        
        
        function updateSelectedRange(obj)
            clickedPoint = get(obj.panelSelectingTime.axes, 'CurrentPoint');
            clickedTime = clickedPoint(1, 1);
            clickedFreq = clickedPoint(1, 2);
            newRange = obj.originalSelectedRange;
            
            xConstraint = obj.mouseConstraintTime;
            if strcmp(obj.mouseConstraintTime, 'min')
                newRange(1) = clickedTime;
            elseif strcmp(obj.mouseConstraintTime, 'mid') && strcmp(obj.mouseConstraintFreq, 'mid')
                width = obj.originalSelectedRange(2) - obj.originalSelectedRange(1);
                newRange(1) = clickedTime - obj.mouseOffset(1);
                newRange(2) = newRange(1) + width;
            elseif strcmp(obj.mouseConstraintTime, 'max')
                newRange(2) = clickedTime;
            end
            
            % Check if the drag has flipped over the y axis.
            if newRange(2) < newRange(1)
                newRange(1:2) = [newRange(2) newRange(1)];
                if strcmp(obj.mouseConstraintTime, 'min')
                    xConstraint = 'max';
                else
                    xConstraint = 'min';
                end
            end
            
            yConstraint = obj.mouseConstraintFreq;
            if obj.panelSelectingTime.showsFrequencyRange
                if strcmp(obj.mouseConstraintFreq, 'min')
                    newRange(3) = clickedFreq;
                elseif strcmp(obj.mouseConstraintFreq, 'mid') && strcmp(obj.mouseConstraintTime, 'mid')
                    if ~isinf(newRange(3)) && ~isinf(newRange(3))
                        height = obj.originalSelectedRange(4) - obj.originalSelectedRange(3);
                        newRange(3) = clickedFreq - obj.mouseOffset(2);
                        newRange(4) = newRange(3) + height;
                    end
                elseif strcmp(obj.mouseConstraintFreq, 'max')
                    newRange(4) = clickedFreq;
                end
                
                % Check if the drag has flipped over the x axis.
                if newRange(4) < newRange(3)
                    newRange(3:4) = [newRange(4) newRange(3)];
                    if strcmp(obj.mouseConstraintFreq, 'min')
                        yConstraint = 'max';
                    else
                        yConstraint = 'min';
                    end
                end
            end
            
            set(gcf, 'Pointer', obj.resizePointer(xConstraint, yConstraint));
            
            % If the current time was at the beginning or end of the selection then keep it there.
            if obj.currentTime == obj.selectedRange(1)
                obj.currentTime = newRange(1);
            elseif obj.currentTime == obj.selectedRange(2)
                obj.currentTime = newRange(2);
            end
            
            obj.selectedRange = newRange;
        end
        
        
        function handleMouseMotion(obj, varargin)
            if ~isempty(obj.panelSelectingTime)
                obj.updateSelectedRange();
            elseif false    %handles.showSpectrogram && isfield(handles, 'spectrogramTooltip')
% TODO:
%                 currentPoint = get(handles.spectrogram, 'CurrentPoint');
%                 xLim = get(handles.spectrogram, 'XLim');
%                 yLim = get(handles.spectrogram, 'YLim');
%                 x = (currentPoint(1, 1) - xLim(1)) / (xLim(2) - xLim(1));
%                 y = (currentPoint(1, 2) - yLim(1)) / (yLim(2) - yLim(1));
%                 if x >=0 && x <= 1 && y >= 0 && y <= 1
%                     timeRange = displayedTimeRange(handles);
%                     currentTime = timeRange(1) + (timeRange(2) - timeRange(1)) * x;
%                     frequency = handles.spectrogramFreqMin + ...
%                         (handles.spectrogramFreqMax - handles.spectrogramFreqMin) * y;
%                     tip = sprintf('%0.2f sec\n%.1f Hz', currentTime, frequency);
%                     set(handles.spectrogramTooltip, 'String', tip, 'Visible', 'on');
%                 else
%                     tip = '';
%                     set(handles.spectrogramTooltip, 'String', tip, 'Visible', 'off');
%                 end
            end
        end


        function handleMouseButtonUp(obj, ~, ~)
            if ~isempty(obj.panelSelectingTime)
                obj.updateSelectedRange();
                if obj.selectedRange(3) == obj.selectedRange(4)
                    obj.selectedRange(3:4) = [-inf inf];
                end
                obj.panelSelectingTime = [];
                set(gcf, 'Pointer', 'arrow');
            end
        end
        
        
        function handleKeyPress(obj, ~, keyEvent)
            if ~strcmp(keyEvent.Key, 'space')
                % Let one of the panels handle the event.
                % If the video panels are open they get first dibs.
                panels = horzcat(obj.videoPanels, obj.timelinePanels);
                obj.panelHandlingKeyPress = [];
                for i = 1:length(panels)
                    if ~panels{i}.isHidden && panels{i}.keyWasPressed(keyEvent)
                        obj.panelHandlingKeyPress = panels{i};
                        break
                    end
                end
            end
        end
        
        
        function handleKeyRelease(obj, source, keyEvent)
            if strcmp(keyEvent.Key, 'space')
                % The space bar toggles play/pause of the recordings at the current play rate.
                % If the shift key is down then playback is backwards.
                
                if obj.isPlaying
                    obj.handlePause(source, keyEvent);
                else
                    shiftDown = any(ismember(keyEvent.Modifier, 'shift'));
                    if shiftDown
                        obj.handlePlay(source, keyEvent, 'backwards');
                    else
                        obj.handlePlay(source, keyEvent, 'forwards');
                    end
                end
            elseif ~isempty(obj.panelHandlingKeyPress)
                % Let the panel that handled the key press handle this key release as well.
                obj.panelHandlingKeyPress.keyWasReleased(keyEvent);
            end
        end
        
        
        function handleVideoSliderChanged(obj, ~, ~)
            % The video slider controls the current time.
            obj.currentTime = get(obj.videoSlider, 'Value');
        end
        
        
        function handleTimelineSliderChanged(obj, ~, ~)
            % The timeline slider controls the window of time being displayed in the timelines.
            if get(obj.timelineSlider, 'Value') ~= obj.displayRange(1)
                obj.centerDisplayAtTime(get(obj.timelineSlider, 'Value'));
            end
        end
        
        
        function handleCurrentTimeChanged(obj, ~, ~)
            set(obj.videoSlider, 'Value', obj.currentTime);
        end
        
        
        function handleTimeWindowChanged(obj, ~, ~)
            % Adjust the step and page sizes of the time slider.
            stepSize = 1 / obj.zoom;
            curMax = get(obj.timelineSlider, 'Max');
            newValue = mean(obj.displayRange(1:2));
            set(obj.timelineSlider, 'SliderStep', [stepSize / 50.0 stepSize], ...
                                    'Value', newValue, ...
                                    'Max', max(curMax, newValue));
        end
        
        
        function addAudioRecording(obj, recording)
            if obj.importing
                % There seems to be a bug in MATLAB where you can't create new axes while a waitbar is open.
                % Queue the recording to be added after the waitbar has gone away.
                obj.recordingsToAdd{end + 1} = recording;
            else
                if isempty(obj.recordings) && isempty(obj.savePath)
                    set(obj.figure, 'Name', ['Tempo: ' recording.name]);
                end
                
                obj.recordings{end + 1} = recording;
                
                if getpref('Tempo', 'ShowWaveforms')
                    obj.openWaveform(recording);
                end
                
                if getpref('Tempo', 'ShowSpectrograms')
                    obj.openSpectrogram(recording);
                end
                
                obj.arrangeTimelinePanels();
                
                addlistener(recording, 'timeOffset', 'PostSet', @(source, event)handleRecordingDurationChanged(obj, source, event));
            end
        end
        
        
        function addVideoRecording(obj, recording)
            if obj.importing
                % There seems to be a bug in MATLAB where you can't create new axes while a waitbar is open.
                % Queue the recording to be added after the waitbar has gone away.
                obj.recordingsToAdd{end + 1} = recording;
            else
                if isempty(obj.recordings)
                    set(obj.figure, 'Name', ['Tempo: ' recording.name]);
                end
                
                obj.recordings{end + 1} = recording;
                
                panel = VideoPanel(obj, recording);
                panel.showFrameNumber(getpref('Tempo', 'VideoShowFrameNumber', true));
                obj.videoPanels{end + 1} = panel;
                
                obj.arrangeVideoPanels();
                
                addlistener(recording, 'timeOffset', 'PostSet', @(source, event)handleRecordingDurationChanged(obj, source, event));
            end
        end
        
        
        function updateOverallDuration(obj)
            obj.duration = max([cellfun(@(r) r.duration, obj.recordings) cellfun(@(r) r.duration, obj.reporters)]);
            
            if ~isempty(obj.videoPanels)
                meanFrameRate = mean(cellfun(@(v) v.video.sampleRate, obj.videoPanels));
                set(obj.videoSlider, 'Max', obj.duration, ...
                                     'SliderStep', [1.0 / meanFrameRate / obj.duration, 5.0 / obj.duration]);
            end
            set(obj.timelineSlider, 'Max', obj.duration);
            
            % Alter the zoom so that the same window of time is visible.
            if isempty(obj.displayRange)
                obj.setZoom(1);
            else
                obj.setZoom(obj.duration / (obj.displayRange(2) - obj.displayRange(1)));
            end
            
            obj.centerDisplayAtTime(mean(obj.displayRange(1:2))); % trigger a refresh of timeline-based panels
        end
        
        
        function handleRecordingDurationChanged(obj, ~, ~)
            obj.updateOverallDuration();
        end
        
        
        function saveWorkspace(obj, filePath)
            s.displayRange = obj.displayRange;
            s.selectedRange = obj.selectedRange;
            s.currentTime = obj.currentTime;
            s.windowSize = obj.windowSize;
            
            s.recordings = obj.recordings;
            
            s.reporters = obj.reporters;
            
            % Remember which panels are open and their settings.
            s.videoPanels = obj.videoPanels;
            s.timelinePanels = obj.timelinePanels;
            
            s.windowPosition = get(obj.figure, 'Position');
            s.mainSplitter.orientation = get(obj.splitter, 'Orientation');
            s.mainSplitter.location = get(obj.splitter, 'DividerLocation');
            
            save(filePath, '-struct', 's');
        end
        
        
        function openWorkspace(obj, filePath)
            % TODO: Create a new controller if the current one has recordings open?
            %       Allow "importing" a workspace to add it to the current one?
            
            set(obj.figure, 'Pointer', 'watch');
            drawnow
            
            obj.savePath = filePath;
            [~, fileName, ~] = fileparts(filePath);
            set(obj.figure, 'Name', ['Tempo: ' fileName]);
            
            s = load(filePath, '-mat');
            
            % TODO: check if the window still fits on screen?
            set(obj.figure, 'Position', s.windowPosition);
            
            if isfield(s, 'mainSplitter')
                % TODO: set vertical orientation once supported
                if s.mainSplitter.location < 0.01
                    obj.showVideoPanels(false);
                elseif s.mainSplitter.location > 0.99
                    obj.showTimelinePanels(false);
                else
                    obj.showVideoPanels(true);
                    obj.showTimelinePanels(true);
                    set(obj.splitter, 'DividerLocation', s.mainSplitter.location);
                end
            end
            
            havePanels = isfield(s, 'videoPanels');
            
            % Load the recordings.
            obj.recordings = s.recordings;
            for i = 1:length(obj.recordings)
                recording = obj.recordings{i};
                recording.controller = obj;
                recording.loadData();
                if ~havePanels
                    if isa(recording, 'AudioRecording')
                        % TODO: check prefs?
                        obj.openWaveform(recording);
                        obj.openSpectrogram(recording);
                    elseif isa(recording, 'VideoRecording')
                        panel = VideoPanel(obj, recording);
                        obj.videoPanels{end + 1} = panel;
                    end
                end
            end
            
            % Load the detectors and importers.
            if isfield(s, 'reporters')
                obj.reporters = s.reporters;
                for i = 1:length(obj.reporters)
                    reporter = obj.reporters{i};
                    reporter.controller = obj;
                    
                    if ~havePanels
                        obj.timelinePanels{end + 1} = FeaturesPanel(reporter);
                        obj.timelinePanels{end}.setHidden(~obj.showFeatures);
                    end
                end
            end
            
            % Load the panels if they're in the file.  (Older versions didn't store them.)
            if havePanels
                obj.videoPanels = s.videoPanels;
                obj.timelinePanels = s.timelinePanels;
                
                for panel = {obj.videoPanels{:}, obj.timelinePanels{:}}
                    panel{1}.controller = obj;
                    panel{1}.createUI();
                end
            end
            
            obj.windowSize = s.windowSize;
            obj.displayRange = s.displayRange;
            obj.selectedRange = s.selectedRange;
            obj.currentTime = s.currentTime;
            
            obj.duration = max([cellfun(@(r) r.duration, obj.recordings) cellfun(@(r) r.duration, obj.reporters)]);
                
            set(obj.videoSlider, 'Max', obj.duration);
            set(obj.timelineSlider, 'Max', obj.duration);
                
            % Alter the zoom so that the same window of time is visible.
            if isempty(obj.displayRange)
                obj.setZoom(1);
            else
                obj.setZoom(obj.duration / (obj.displayRange(2) - obj.displayRange(1)));
            end
                
            obj.centerDisplayAtTime(mean(obj.displayRange(1:2))); % trigger a refresh of timeline-based panels
            
            obj.arrangeVideoPanels();
            obj.arrangeTimelinePanels();
            
            set(obj.figure, 'Pointer', 'arrow');
            drawnow
        end
        
        
        function handleClose(obj, ~, ~)
            obj.handlePause([]);
            
            if obj.needsSave
                button = questdlg('Do you want to save the changes to the Tempo workspace?', 'Tempo', 'Don''t Save', 'Cancel', 'Save', 'Save');
                if strcmp(button, 'Save')
                    if ~obj.handleSaveWorkspace()
                        return
                    end
                elseif strcmp(button, 'Cancel')
                    return;
                else
                    % TODO: obj.needsSave = false?
                end
            end
            
            delete(obj.playTimer);
            
            % Remember the window position.
            setpref('Tempo', 'MainWindowPosition', get(obj.figure, 'Position'));
            
% TODO:
%             if (handles.close_matlabpool)
%               matlabpool close
%             end
            
            % TODO: Send a "will close" message to all of the panels?
            
            % Fix a Java memory leak that prevents this object from ever being deleted.
            % TODO: there's probably a better way to do this...
            oldWarn = warning('off', 'MATLAB:hg:JavaSetHGProperty');
            oldWarn2 = warning('off', 'MATLAB:hg:PossibleDeprecatedJavaSetHGProperty');
            jDetect = get(obj.detectPopUpTool, 'JavaContainer');
            jMenu = get(jDetect, 'MenuComponent');
            if ~isempty(jMenu)
                jMenuItems = jMenu.getSubElements();
                for i = 1:length(jMenuItems)
                    set(jMenuItems(i), 'ActionPerformedCallback', []);
                end
            end
            if isjava(obj.playSlowerTool)
                set(obj.playSlowerTool, 'ActionPerformedCallback', []);
            end
            if isjava(obj.playBackwardsTool)
                set(obj.playBackwardsTool, 'ActionPerformedCallback', []);
            end
            if isjava(obj.pauseTool)
                set(obj.pauseTool, 'ActionPerformedCallback', []);
            end
            if isjava(obj.playForwardsTool)
                set(obj.playForwardsTool, 'ActionPerformedCallback', []);
            end
            if isjava(obj.playFasterTool)
                set(obj.playFasterTool, 'ActionPerformedCallback', []);
            end
            warning(oldWarn);
            warning(oldWarn2);
            
            delete(obj.figure);
        end
        
    end
    
    
    methods (Static)
        
        function [classNames, typeNames] = findPlugIns(pluginsDir)
            pluginDirs = dir(pluginsDir);
            classNames = cell(length(pluginDirs), 1);
            typeNames = cell(length(pluginDirs), 1);
            pluginCount = 0;
            for i = 1:length(pluginDirs)
                if pluginDirs(i).isdir && pluginDirs(i).name(1) ~= '.'
                    % Directory plug-in
                    className = pluginDirs(i).name;
                    try
                        addpath(fullfile(pluginsDir, filesep, className));
                        eval([className '.initialize()'])
                        pluginCount = pluginCount + 1;
                        classNames{pluginCount} = className;
                        typeNames{pluginCount} = eval([className '.typeName()']);
                    catch ME
                        waitfor(warndlg(['Could not load ' pluginDirs(i).name ': ' ME.message]));
                        rmpath(fullfile(pluginsDir, filesep, pluginDirs(i).name));
                    end
                elseif ~pluginDirs(i).isdir && strcmp(pluginDirs(i).name(end-1:end), '.m')
                    % Single file plug-in
                    className = pluginDirs(i).name(1:end-2);
                    try
                        eval([className '.initialize()'])
                        pluginCount = pluginCount + 1;
                        classNames{pluginCount} = className;
                        typeNames{pluginCount} = className;
                    catch
                        % It's a .m file but not a plug-in.
                    end
                end
            end
            classNames = classNames(1:pluginCount);
            typeNames = typeNames(1:pluginCount);
        end
        
        
        function item = menuItem(menu, tag)
            % Look up a menu item from its tag.
            item = findobj(menu, 'Tag', tag);
        end
        
    end
    
end
