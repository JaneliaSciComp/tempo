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
        videoIconAxes
        timelinesPanel
        timelinePanels = {}
        timeIndicatorPanel = []
        timelineIconAxes
        
        iconsPath
        
        panelHandlingKeyPress
        
        videoSlider
        timelineSlider
        
        fileMenu
        editMenu
        viewMenu
        videoMenu
        timelineMenu
        playbackMenu
        windowMenu
        helpMenu
        
        toolbar
        jToolbar
        saveTool
        exportVideoTool
        zoomOutTool
        
        playBackwardsTool
        pauseTool
        playForwardsTool
        
        playSlowerTool
        playbackSpeedTool
        playFasterTool
        
        detectPopUpTool
        annotatePopUpTool
        
        timeLabelFormat = 1     % default to displaying time in minutes and seconds
        
        panelEditingRange
        objectBeingEdited
        originalRangeBeingEdited
        mouseConstraintTime
        mouseConstraintFreq
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
        
        undoManager;
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
                'Position', getpref('Tempo', 'MainWindowPosition', [100 100 1000 500]), ...
                'Color', [0.4 0.4 0.4], ...
                'Renderer', 'opengl', ...
                'ResizeFcn', @(source, event)handleResize(obj, source, event), ...
                'KeyPressFcn', @(source, event)handleKeyPress(obj, source, event), ...
                'KeyReleaseFcn', @(source, event)handleKeyRelease(obj, source, event), ...
                'CloseRequestFcn', @(source, event)handleClose(obj, source, event), ...
                'WindowButtonDownFcn', @(source, event)handleMouseButtonDown(obj, source, event), ...
                'WindowButtonMotionFcn', @(source, event)handleMouseMotion(obj, source, event), ...
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
            
            % Create an undo manager and listen to its changes.
            obj.undoManager = UndoManager();
            addlistener(obj.undoManager, 'UndoStackChanged', @(source, event)handleUndoStackChanged(obj, source, event));
            
            % Create top-level panels to hold the video and timeline panels.
            obj.videosPanel = uipanel(obj.figure, ...
                'BorderType', 'none', ...
                'BorderWidth', 0, ...
                'BackgroundColor', 'black', ...
                'SelectionHighlight', 'off', ...
                'ResizeFcn', @(source, event)arrangeVideoPanels(obj, source, event), ...
                'Visible', onOff(getpref('Tempo', 'ViewShowVideo', true)));
            obj.timelinesPanel = uipanel(obj.figure, ...
                'BorderType', 'none', ...
                'BorderWidth', 0, ...
                'BackgroundColor', 'white', ...
                'SelectionHighlight', 'off', ...
                'ResizeFcn', @(source, event)arrangeTimelinePanels(obj, source, event), ...
                'Visible', onOff(getpref('Tempo', 'ViewShowTimeline', true)));
            
            % Create icons in the middle of the video and timeline panels.
            obj.videoIconAxes = axes(...
                'Parent', obj.videosPanel, ...
                'Color', 'none', ...
                'HitTest', 'off', ...
                'Units', 'pixels', ...
                'Position', [0 100 124 128]);
            image(obj.loadIcon('Video', [0 0 0]), 'HitTest', 'off');
            text(0.5, 0.0, 'Video', ...
                'Units', 'normalized', ...
                'HorizontalAlignment', 'center', ...
                'FontSize', 24, ...
                'FontWeight', 'bold', ...
                'Color', [0.25 0.25 0.25]);
            axis image;
            obj.timelineIconAxes = axes(...
                'Parent', obj.timelinesPanel, ...
                'Color', 'none', ...
                'HitTest', 'off', ...
                'Units', 'pixels', ...
                'Position', [0 100 344 128]);
            image(obj.loadIcon('Timeline', [1 1 1]), 'HitTest', 'off');
            text(0.5, 0.0, 'Timeline', ...
                'Units', 'normalized', ...
                'HorizontalAlignment', 'center', ...
                'FontSize', 24, ...
                'FontWeight', 'bold', ...
                'Color', [0.9 0.9 0.9]);
            axis image;
            
            % Create the time indicator at the bottom of the timelines.
            obj.timeIndicatorPanel = TimeIndicatorPanel(obj);
            
            % Insert a splitter at the top level to separate the video and timeline panels.
            if strcmp(getpref('Tempo', 'VideoPlacement', 'left'), 'left')
                orientation = 'horizontal';
            else
                orientation = 'vertical';
            end
            obj.splitter = UISplitter(obj.figure, obj.videosPanel, obj.timelinesPanel, orientation);
            
            obj.createMenuBar();
            if getpref('Tempo', 'ViewShowToolbar', true)
                obj.createToolbar();
            end
            obj.updateMenuItemsAndToolbar();
            
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
            
            obj.arrangeTimelinePanels();
            
            % Set up a timer to fire 30 times per second during playback.
            % MATLAB can only seem to manage up to 15 FPS but one can hope.
            obj.playTimer = timer('ExecutionMode', 'fixedRate', 'TimerFcn', @(timerObj, event)handlePlayTimer(obj, timerObj, event), 'Period', round(1.0 / 30.0 * 1000) / 1000);
            
            % Display a welcome message the first time the user runs Tempo.
            obj.welcomeUser();
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
                                 'Accelerator', 's', ...
                                 'Tag', 'save');
            uimenu(obj.fileMenu, 'Label', 'Save As...', ...
                                 'Callback', '', ... 
                                 'Accelerator', '', ...
                                 'Enable', 'off', ...
                                 'Tag', 'saveAs');
            uimenu(obj.fileMenu, 'Label', 'Export Video of Selection...', ...
                                 'Callback', @(hObject, eventdata)handleExportSelection(obj, hObject, eventdata), ...
                                 'Separator', 'on', ...
                                 'Tag', 'exportVideo');
            uimenu(obj.fileMenu, 'Label', 'Export All Features...', ...
                                 'Callback', '', ...
                                 'Enable', 'off', ...
                                 'Tag', 'exportFeatures');
            uimenu(obj.fileMenu, 'Label', 'Take Screen Shot...', ...
                                 'Callback', @(hObject, eventdata)handleSaveScreenshot(obj, hObject, eventdata), ... 
                                 'Separator', 'on');
            
            obj.editMenu = uimenu(obj.figure, 'Label', 'Edit');
            uimenu(obj.editMenu, 'Label', 'Undo', ...
                                 'Callback', @(hObject, eventdata)handleUndo(obj, hObject, eventdata), ...
                                 'Accelerator', 'z', ...
                                 'Tag', 'undo');
            uimenu(obj.editMenu, 'Label', 'Redo', ...
                                 'Callback', @(hObject, eventdata)handleRedo(obj, hObject, eventdata), ...
                                 'Accelerator', 'y', ...
                                 'Tag', 'redo');
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
                uimenu(detectorMenu, 'Label', [obj.detectorTypeNames{detectorIdx} '...'], ...
                                     'Callback', @(hObject, eventdata)handleDetectFeatures(obj, hObject, eventdata), ...
                                     'UserData', detectorIdx);
            end
            
            obj.viewMenu = uimenu(obj.figure, 'Label', 'View');
            uimenu(obj.viewMenu, 'Label', 'Show Toolbar', ...
                                 'Callback', @(hObject, eventdata)handleShowToolbar(obj, hObject, eventdata), ...
                                 'Accelerator', '', ...
                                 'Tag', 'showToolbar');
            uimenu(obj.viewMenu, 'Label', 'Show Only Video', ...
                                 'Callback', @(hObject, eventdata)handleShowVideoAndOrTimeline(obj, hObject, eventdata, true, false), ...
                                 'Accelerator', '', ...
                                 'Separator', 'on', ...
                                 'Tag', 'showVideo');
            uimenu(obj.viewMenu, 'Label', 'Show Only Timeline', ...
                                 'Callback', @(hObject, eventdata)handleShowVideoAndOrTimeline(obj, hObject, eventdata, false, true), ...
                                 'Accelerator', '', ...
                                 'Tag', 'showTimeline');
            uimenu(obj.viewMenu, 'Label', 'Show Video and Timeline', ...
                                 'Callback', @(hObject, eventdata)handleShowVideoAndOrTimeline(obj, hObject, eventdata, true, true), ...
                                 'Accelerator', '', ...
                                 'Tag', 'showVideoAndTimeline');
            uimenu(obj.viewMenu, 'Label', 'Place Videos Left of the Timeline', ...
                                 'Callback', @(hObject, eventdata)handlePlaceVideoToTheLeft(obj, hObject, eventdata), ...
                                 'Separator', 'on', ...
                                 'Tag', 'placeVideoToTheLeft');
            uimenu(obj.viewMenu, 'Label', 'Place Videos Above the Timeline', ...
                                 'Callback', @(hObject, eventdata)handlePlaceVideoAbove(obj, hObject, eventdata), ...
                                 'Tag', 'placeVideoAbove');
            obj.updateViewMenuItems();
            
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
                                  'Separator', 'on', ...
                                  'Enable', 'off');
            uimenu(obj.videoMenu, 'Label', 'Arrange Videos Top to Bottom', ...
                                  'Callback', '', ...
                                  'Checked', 'on', ...
                                  'Enable', 'off');
            uimenu(obj.videoMenu, 'Label', 'Show Current Frame Number', ...
                                  'Callback', @(hObject, eventdata)handleShowFrameNumber(obj, hObject, eventdata), ...
                                  'Accelerator', '', ... 
                                  'Separator', 'on', ...
                                  'Tag', 'showFrameNumber');
            
            obj.timelineMenu = uimenu(obj.figure, 'Label', 'Timeline');
            uimenu(obj.timelineMenu, 'Label', 'Zoom In', ...
                                     'Callback', @(hObject, eventdata)handleZoomIn(obj, hObject, eventdata), ...
                                     'Accelerator', '', ...
                                     'Tag', 'zoomIn');
            uimenu(obj.timelineMenu, 'Label', 'Zoom Out', ...
                                     'Callback', @(hObject, eventdata)handleZoomOut(obj, hObject, eventdata), ...
                                     'Accelerator', '', ...
                                     'Tag', 'zoomOut');
            uimenu(obj.timelineMenu, 'Label', 'Zoom to Selection', ...
                                     'Callback', @(hObject, eventdata)handleZoomToSelection(obj, hObject, eventdata), ...
                                     'Accelerator', '', ...
                                     'Tag', 'zoomToSelection');
            uimenu(obj.timelineMenu, 'Label', 'Annotate Features...', ...
                                     'Callback', @(hObject, eventdata)handleAnnotateFeatures(obj, hObject, eventdata, true, false), ...
                                     'Separator', 'on', ...
                                     'Tag', 'addManualAnnotations');
            uimenu(obj.timelineMenu, 'Label', 'Open Waveform for New Recordings', ...
                                     'Callback', @(hObject, eventdata)handleShowWaveformAndOrSpectrogramOnOpen(obj, hObject, eventdata, true, false), ...
                                     'Separator', 'on', ...
                                     'Tag', 'showWaveformOnOpen');
            uimenu(obj.timelineMenu, 'Label', 'Open Spectrogram for New Recordings', ...
                                     'Callback', @(hObject, eventdata)handleShowWaveformAndOrSpectrogramOnOpen(obj, hObject, eventdata, false, true), ...
                                     'Tag', 'showSpectrogramOnOpen');
            uimenu(obj.timelineMenu, 'Label', 'Open Both for New Recordings', ...
                                     'Callback', @(hObject, eventdata)handleShowWaveformAndOrSpectrogramOnOpen(obj, hObject, eventdata, true, true), ...
                                     'Tag', 'showBothOnOpen');
            
            obj.playbackMenu = uimenu(obj.figure, 'Label', 'Playback');
            uimenu(obj.playbackMenu, 'Label', 'Play', ...
                                     'Callback', @(hObject, eventdata)handlePlay(obj, hObject, eventdata, 'forwards'), ...
                                     'Accelerator', '', ...
                                     'Tag', 'play');
            uimenu(obj.playbackMenu, 'Label', 'Play Backwards', ...
                                     'Callback', @(hObject, eventdata)handlePlay(obj, hObject, eventdata, 'backwards'), ...
                                     'Accelerator', '', ...
                                     'Tag', 'playBackwards');
            uimenu(obj.playbackMenu, 'Label', 'Pause', ...
                                     'Callback', @(hObject, eventdata)handlePause(obj, hObject, eventdata), ...
                                     'Accelerator', '', ...
                                     'Tag', 'pause');
            uimenu(obj.playbackMenu, 'Label', 'Play at Regular Speed', ...
                                     'Callback', @(hObject, eventdata)handlePlay(obj, hObject, eventdata, '1x'), ...
                                     'Accelerator', '1', ...
                                     'Separator', 'on', ...
                                     'Tag', 'regularSpeed');
            uimenu(obj.playbackMenu, 'Label', 'Play at Double Speed', ...
                                     'Callback', @(hObject, eventdata)handlePlay(obj, hObject, eventdata, '2x'), ...
                                     'Accelerator', '', ...
                                     'Tag', 'doubleSpeed');
            uimenu(obj.playbackMenu, 'Label', 'Play at Half Speed', ...
                                     'Callback', @(hObject, eventdata)handlePlay(obj, hObject, eventdata, '1/2x'), ...
                                     'Accelerator', '2', ...
                                     'Tag', 'halfSpeed');
            uimenu(obj.playbackMenu, 'Label', 'Increase Speed', ...
                                     'Callback', @(hObject, eventdata)handlePlay(obj, hObject, eventdata, 'faster'), ...
                                     'Accelerator', '', ...
                                     'Separator', 'on', ...
                                     'Tag', 'increaseSpeed');
            uimenu(obj.playbackMenu, 'Label', 'Decrease Speed', ...
                                     'Callback', @(hObject, eventdata)handlePlay(obj, hObject, eventdata, 'slower'), ...
                                     'Accelerator', '', ...
                                     'Tag', 'decreaseSpeed');
            
            obj.windowMenu = uimenu(obj.figure, 'Label', 'Window');
            uimenu(obj.windowMenu, 'Label', 'Arrange Windows Top to Bottom', ...
                                   'Callback', '', ...
                                   'Accelerator', '', ...
                                   'Enable', 'off');
            uimenu(obj.windowMenu, 'Label', 'Arrange Windows Left to Right', ...
                                   'Callback', '', ...
                                   'Accelerator', '', ...
                                   'Enable', 'off');
            % TODO: add/manage the list of open windows
            
            obj.helpMenu = uimenu(obj.figure, 'Label', 'Help');
            uimenu(obj.helpMenu, 'Label', 'Tempo Help', ...
                                 'Callback', @(hObject, eventdata)handleShowHelp(obj, hObject, eventdata));
            uimenu(obj.helpMenu, 'Label', 'Getting Your Data Into Tempo', ...
                                 'Callback', @(hObject, eventdata)handleShowHelp(obj, hObject, eventdata, 'Getting Your Data Into Tempo'), ...
                                 'Separator', 'on');
            uimenu(obj.helpMenu, 'Label', 'Browsing', ...
                                 'Callback', @(hObject, eventdata)handleShowHelp(obj, hObject, eventdata, 'Browsing'));
            uimenu(obj.helpMenu, 'Label', 'Analyzing', ...
                                 'Callback', @(hObject, eventdata)handleShowHelp(obj, hObject, eventdata, 'Analyzing'));
            uimenu(obj.helpMenu, 'Label', 'Annotating', ...
                                 'Callback', @(hObject, eventdata)handleShowHelp(obj, hObject, eventdata, 'Annotating'));
            uimenu(obj.helpMenu, 'Label', 'Customizing Tempo', ...
                                 'Callback', @(hObject, eventdata)handleShowHelp(obj, hObject, eventdata, 'Customizing'), ...
                                 'Separator', 'on');
            uimenu(obj.helpMenu, 'Label', 'Visit the Tempo Web Site', ...
                                 'Callback', @(hObject, eventdata)handleVisitWebSite(obj, hObject, eventdata), ...
                                 'Separator', 'on');
        end
        
        
        function createToolbar(obj)
            obj.toolbar = uitoolbar(obj.figure);
            
            defaultBackground = get(0, 'defaultUicontrolBackgroundColor');
            
            % Open and save
            uipushtool(obj.toolbar, ...
                'Tag', 'open', ...
                'CData', obj.loadIcon('file_open'), ...
                'TooltipString', 'Open a saved workspace, open audio/video files or import features',... 
                'Separator', 'on', ...
                'ClickedCallback', @(hObject, eventdata)handleOpenFile(obj, hObject, eventdata));
            uipushtool(obj.toolbar, ...
                'Tag', 'save', ...
                'CData', obj.loadIcon('file_save'), ...
                'TooltipString', 'Save the workspace',...
                'ClickedCallback', @(hObject, eventdata)handleSaveWorkspace(obj, hObject, eventdata));
            
            % Export and screenshot
            obj.exportVideoTool = uipushtool(obj.toolbar, ...
                'Tag', 'exportVideo', ...
                'CData', obj.loadIcon('ExportToMovie'), ...
                'TooltipString', 'Export the selected time window to a movie',...
                'Separator', 'on', ...
                'ClickedCallback', @(hObject, eventdata)handleExportSelection(obj, hObject, eventdata));
            uipushtool(obj.toolbar, ...
                'Tag', 'saveScreenshot', ...
                'CData', obj.loadIcon('screenshot'), ...
                'TooltipString', 'Save a screenshot',...
                'ClickedCallback', @(hObject, eventdata)handleSaveScreenshot(obj, hObject, eventdata));
            
            % Annotate and detect features
            obj.annotatePopUpTool = uipushtool('Parent', obj.toolbar, ...
                'Tag', 'annotate', ...
                'CData', obj.loadIcon('Annotate'), ...
                'TooltipString', 'Annotate features',... 
                'Separator', 'on', ...
                'ClickedCallback', @(hObject, eventdata)handleAnnotateFeatures(obj, hObject, eventdata));
            obj.detectPopUpTool = uisplittool('Parent', obj.toolbar, ...
                'Tag', 'detectFeatures', ...
                'CData', obj.loadIcon('detect'), ...
                'TooltipString', 'Detect features',... 
                'Separator', 'on', ...
                'ClickedCallback', @(hObject, eventdata)handleDetectFeatures(obj, hObject, eventdata));
            
            % Playback
            obj.playBackwardsTool = uipushtool(obj.toolbar, ...
                'CData', obj.loadIcon('PlayBackwards'), ...
                'TooltipString', 'Play backwards',... 
                'Separator', 'on', ...
                'ClickedCallback', @(hObject, eventdata)handlePlay(obj, hObject, eventdata, 'backwards'));
            obj.pauseTool = uipushtool(obj.toolbar, ...
                'CData', obj.loadIcon('pause'), ...
                'TooltipString', 'Pause playback',... 
                'ClickedCallback', @(hObject, eventdata)handlePause(obj, hObject, eventdata), ...
                'Enable', 'off');
            obj.playForwardsTool = uipushtool(obj.toolbar, ...
                'CData', obj.loadIcon('PlayForwards'), ...
                'TooltipString', 'Play forwards',... 
                'ClickedCallback', @(hObject, eventdata)handlePlay(obj, hObject, eventdata, 'forwards'));
            
            % Playback speed
            obj.playSlowerTool = uipushtool(obj.toolbar, ...
                'CData', obj.loadIcon('PlaySlower'), ...
                'Separator', 'on', ...
                'TooltipString', 'Decrease the speed of playback',... 
                'ClickedCallback', @(hObject, eventdata)handlePlay(obj, hObject, eventdata, 'slower'));
            obj.playbackSpeedTool = uipushtool(obj.toolbar, ...
                'CData', zeros(16, 16, 3), ...
                'TooltipString', 'Choose the speed of playback',... 
                'ClickedCallback', @(hObject, eventdata)handleChoosePlaybackSpeed(obj, hObject, eventdata));
            obj.playFasterTool = uipushtool(obj.toolbar, ...
                'CData', obj.loadIcon('PlayFaster'), ...
                'TooltipString', 'Increase the speed of playback',... 
                'ClickedCallback', @(hObject, eventdata)handlePlay(obj, hObject, eventdata, 'faster'));
            
            % Zooming
            uipushtool(obj.toolbar, ...
                'Tag', 'zoomIn', ...
                'CData', obj.loadIcon('tool_zoom_in'), ...
                'TooltipString', 'Zoom in',... 
                'Separator', 'on', ...
                'ClickedCallback', @(hObject, eventdata)handleZoomIn(obj, hObject, eventdata));
            uipushtool(obj.toolbar, ...
                'Tag', 'zoomOut', ...
                'CData', obj.loadIcon('tool_zoom_out'), ...
                'TooltipString', 'Zoom out',... 
                'ClickedCallback', @(hObject, eventdata)handleZoomOut(obj, hObject, eventdata));
            
            % Make sure the Java components we need have been created.
            drawnow;
            
            obj.jToolbar = get(get(obj.toolbar, 'JavaContainer'), 'ComponentPeer');
            if ~isempty(obj.jToolbar)
                oldWarn = warning('off', 'MATLAB:hg:JavaSetHGProperty');
                oldWarn2 = warning('off', 'MATLAB:hg:PossibleDeprecatedJavaSetHGProperty');
                
                % Add the detector options to the pop-up menu.
                jDetect = get(obj.detectPopUpTool,'JavaContainer');
                jMenu = get(jDetect,'MenuComponent');
                jMenu.removeAll;
                jMenu.add('Detect Features:').setEnabled(false);
                for actionIdx = 1:length(obj.detectorTypeNames)
                    jActionItem = jMenu.add([obj.detectorTypeNames{actionIdx} '...']);
                    set(jActionItem, 'ActionPerformedCallback', @(hObject, eventdata)handleDetectFeatures(obj, hObject, eventdata), ...
                        'UserData', actionIdx);
                end
                
                % Try to replace the 'choose playback speed' tool with a Java button that can display the play rate.
                obj.replaceToolbarTool(18, 'playbackSpeedTool');
                if isjava(obj.playbackSpeedTool)
                    obj.playbackSpeedTool.setBorderPainted(false);
                    obj.playbackSpeedTool.setText('1x');
                end

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
        
        
        function updateMenuItemsAndToolbar(obj)
            obj.updateFileMenuItems();
            obj.updateEditMenuItems();
            obj.updateViewMenuItems();
            obj.updateVideoMenuItems();
            obj.updateTimelineMenuItems();
            obj.updatePlaybackMenuItems();
        end
        
        
        function iconData = loadIcon(obj, iconName, backgroundColor)
            if isempty(obj.iconsPath)
                [tempoRoot, ~, ~] = fileparts(mfilename('fullpath'));
                obj.iconsPath = fullfile(tempoRoot, 'Icons');
            end
            
            if nargin < 3
                backgroundColor = get(0, 'defaultUicontrolBackgroundColor');
            end
            
            % First look in our icons folder.
            iconPath = fullfile(obj.iconsPath, [iconName '.png']);
            iconMax = 256;
            if ~exist(iconPath, 'file')
                % Not one of ours, get the icon from the standard MATLAB icons.
                iconPath = fullfile(matlabroot, 'toolbox', 'matlab', 'icons', [iconName '.png']);
                iconMax = 65536;
            end
            
            iconData = double(imread(iconPath, 'BackgroundColor', backgroundColor)) / iconMax;
        end
        
        
        function welcomeUser(obj) %#ok<MANU>
            if ~getpref('Tempo', 'UserWasWelcomed', false)
                uiwait(msgbox(['Welcome to Tempo!' char(10) char(10) ...
                               'To get started open a video, audio or annotation file.'], 'Tempo', 'modal'));
                
                setpref('Tempo', 'UserWasWelcomed', true);
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
            if shownPanelHeight < 32
                warning('Tempo:WindowTooSmall', 'The window is too small to display all of the panels');
            else
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
        end
        
        
        function arrangeVideoPanels(obj, ~, ~)
            % Get the size of the top-level panel.
            set(obj.videosPanel, 'Units', 'pixels');
            videosPos = get(obj.videosPanel, 'Position');
            set(obj.videosPanel, 'Units', 'normalized');
            
            obj.arrangePanels(obj.videoPanels, videosPos(3:4), [0 3 16 4]);
            
            iconAxesPos = [videosPos(3) / 2 - 62, videosPos(4) / 2 - 64, 124, 128];
            set(obj.videoIconAxes, 'Visible', onOff(isempty(obj.videoPanels)), ...
                                   'Position', iconAxesPos);
            
            set(obj.videoSlider, 'Position', [1, 0, videosPos(3), 16]);
        end
        
        
        function showVideoPanels(obj, doShow)
            if nargin < 2
                doShow = true;
            end
            set(obj.videosPanel, 'Visible', onOff(doShow));
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
            
            % Position the time indicator panel at the bottom.
            timeIndicatorHeight = 13;
            obj.timeIndicatorPanel.setHidden(false);
            set(obj.timeIndicatorPanel.panel, 'Position', [2, 18, timelinesPos(3), timeIndicatorHeight + 1]);
            obj.timeIndicatorPanel.updateAxes(obj.displayRange(1:2));
            
            obj.arrangePanels(obj.timelinePanels, timelinesPos(3:4), [0, 0, timeIndicatorHeight + 2 + 16, 2]);
            
            iconAxesPos = [timelinesPos(3) / 2 - 172, timelinesPos(4) / 2 - 64, 344, 128];
            set(obj.timelineIconAxes, 'Visible', onOff(isempty(obj.timelinePanels)), ...
                                      'Position', iconAxesPos);
            axis(obj.timelineIconAxes, 'off');
            
            % Position the timeline slider at the bottom.
            set(obj.timelineSlider, 'Position', [1, 0, timelinesPos(3) + 2, 16]);
        end
        
        
        function showTimelinePanels(obj, doShow)
            if nargin < 2
                doShow = true;
            end
            set(obj.timelinesPanel, 'Visible', onOff(doShow));
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
            % Let the panel do what it needs to before closing.
            panel.close();
            
            % Remove the panel.
            if isa(panel, 'VideoPanel')
                obj.videoPanels(cellfun(@(x) x == panel, obj.videoPanels)) = [];
                obj.arrangeVideoPanels();
            else
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
                    % Open a Tempo workspace.
                    
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
                                features = importer.importFeatures();
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
                                
                                if isempty(features)
                                    waitfor(msgbox('No features were imported.', obj.importerTypeNames{index}, 'warn', 'modal'));
                                else
                                    importer.addFeatures(features);
                                    
                                    obj.reporters{end + 1} = importer;
                                    obj.timelinePanels{end + 1} = FeaturesPanel(importer);
                                    
                                    somethingOpened = true;
                                    obj.needsSave = true;
                                end
                            catch ME
                                importer.endProgress();
                                obj.importing = false;
                                obj.recordingsToAdd = {};
                                waitfor(msgbox('An error occurred while importing features.  (See the command window for details.)', obj.importerTypeNames{index}, 'error', 'modal'));
                                rethrow(ME);
                            end
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
                
                obj.arrangeVideoPanels();
                obj.arrangeTimelinePanels();
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
        
        
        function updateFileMenuItems(obj)
            set([obj.menuItem(obj.fileMenu, 'save'), obj.saveTool], ...
                'Enable', onOff(obj.needsSave));
            set([obj.menuItem(obj.fileMenu, 'exportVideo'), obj.exportVideoTool], ...
                'Enable', onOff(obj.selectedRange(2) > obj.selectedRange(1)));
            set(obj.menuItem(obj.fileMenu, 'exportFeatures'), ...
                'Enable', onOff(~isempty(obj.reporters)));
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
                % Create a new detector.
                detectorClassName = obj.detectorClassNames{index};
                constructor = str2func(detectorClassName);
                detector = constructor(obj);
                
                % Let the user tweak its settings.
                if detector.editSettings()
                    % If there is a selection then only detect features within it, otherwise check everywhere.
                    if obj.selectedRange(2) > obj.selectedRange(1)
                        timeRange = obj.selectedRange;
                    else
                        timeRange = [0.0 obj.duration];
                    end
                    
                    % Have the detector look for features in the time range.
                    if ~isa(detector, 'ManualDetector') && isempty(obj.detectFeatures(detector, timeRange))
                        waitfor(msgbox('No features were detected.', detector.typeName, 'warn', 'modal'));
                    end
                    
                    % Create a panel to show the features that were found.
                    panel = obj.addReporter(detector);
                    
                    obj.addUndoableAction(['Detect ' detector.typeName], ...
                                          @() obj.closePanel(panel), ...
                                          @() obj.addReporter(detector, panel), ...
                                          panel);
                end
            end
        end
        
        
        function features = detectFeatures(obj, detector, timeRange) %#ok<INUSL>
            % Detect features using the given detector in the given time range.
            % TODO: don't add duplicate features if selection overlaps already detected region?
            %       or reduce selection to not overlap before detection?
            
            % TODO: startProgress() should be a controller method.
            
            % Have the detector look for features and report its progress.
            detector.startProgress();
            try
                features = detector.detectFeatures(timeRange);
                detector.endProgress();
            catch ME
                detector.endProgress();
                waitfor(msgbox(['An error occurred while detecting features:' char(10) char(10) ME.message char(10) char(10) '(See the command window for details.)'], ...
                               detector.typeName, 'error', 'modal'));
                rethrow(ME);
            end
            
            % Add the found features to the detector's list of features.
            detector.addFeaturesInTimeRange(features, timeRange);
        end
        
        
        function updateEditMenuItems(obj)
            undoAction = obj.undoManager.nextUndoAction();
            if ~isempty(undoAction)
                set(obj.menuItem(obj.editMenu, 'undo'), 'Label', ['Undo ' undoAction], 'Enable', 'on');
            else
                set(obj.menuItem(obj.editMenu, 'undo'), 'Label', 'Undo', 'Enable', 'off');
            end
            
            redoAction = obj.undoManager.nextRedoAction();
            if ~isempty(redoAction)
                set(obj.menuItem(obj.editMenu, 'redo'), 'Label', ['Redo ' redoAction], 'Enable', 'on');
            else
                set(obj.menuItem(obj.editMenu, 'redo'), 'Label', 'Redo', 'Enable', 'off');
            end
        end
        
        
        %% View menu callbacks
        
        
        function handleShowToolbar(obj, ~, ~)
            % Toggle the display of the toolbar.
            menuItem = findobj(obj.viewMenu, 'Tag', 'showToolbar');
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
            
            % Remember the user's preference.
            setpref('Tempo', 'ViewShowToolbar', strcmp(curState, 'off'));
        end
        
        
        function handleShowVideoAndOrTimeline(obj, ~, ~, showVideo, showTimeline)
            % Show and/or hide the videos and timelines.
            
            % Update the panels.
            set(obj.videosPanel, 'Visible', onOff(showVideo));
            set(obj.timelinesPanel, 'Visible', onOff(showTimeline));
            
            % Remember the user's preference.
            setpref('Tempo', 'ViewShowVideo', showVideo);
            setpref('Tempo', 'ViewShowTimeline', showTimeline);
            
            obj.updateViewMenuItems();
            obj.updateVideoMenuItems();
            obj.updateTimelineMenuItems();
        end
        
        
        function handlePlaceVideoToTheLeft(obj, ~, ~)
            % Update the menu items.
            obj.splitter.orientation = 'horizontal';
            
            % Remember the user's preference.
            setpref('Tempo', 'VideoPlacement', 'left');
            
            obj.updateViewMenuItems();
        end
        
        
        function handlePlaceVideoAbove(obj, ~, ~)
            obj.splitter.orientation = 'vertical';
            
            % Remember the user's preference.
            setpref('Tempo', 'VideoPlacement', 'above');
            
            obj.updateViewMenuItems();
        end
        
        
        function updateViewMenuItems(obj)
            % Update the show toolbar item based on the user's preference.
            set(findobj(obj.viewMenu, 'Tag', 'showToolbar'), 'Checked', onOff(getpref('Tempo', 'ViewShowToolbar', true)));
            
            % Update the show video and/or timeine items based on the visibility of the video and timeline panels.
            showVideo = onOff(get(obj.videosPanel, 'Visible'));
            showTimeline = onOff(get(obj.timelinesPanel, 'Visible'));
            set(findobj(obj.viewMenu, 'Tag', 'showVideo'), 'Checked', onOff(showVideo && ~showTimeline));
            set(findobj(obj.viewMenu, 'Tag', 'showTimeline'), 'Checked', onOff(~showVideo && showTimeline));
            set(findobj(obj.viewMenu, 'Tag', 'showVideoAndTimeline'), 'Checked', onOff(showVideo && showTimeline));
            
            set(findobj(obj.viewMenu, 'Tag', 'placeVideoToTheLeft'), ...
                'Enable', onOff(showVideo), ...
                'Checked', onOff(strcmp(obj.splitter.orientation, 'horizontal')));
            set(findobj(obj.viewMenu, 'Tag', 'placeVideoAbove'), ...
                'Enable', onOff(showVideo), ...
                'Checked', onOff(strcmp(obj.splitter.orientation, 'vertical')));
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
            
            % Remember the user's preference.
            setpref('Tempo', 'VideoShowFrameNumber', showNumbers);
            
            obj.updateVideoMenuItems();
        end
        
        
        function updateVideoMenuItems(obj)
            showVideo = onOff(get(obj.videosPanel, 'Visible'));
            
            if isempty(obj.videoPanels)
                showFrameNumbers = getpref('Tempo', 'VideoShowFrameNumber', true);
            else
                showFrameNumbers = obj.videoPanels{1}.showFrameNum;
            end
            
            % Update the menu items.
            set(findobj(obj.videoMenu, 'Tag', 'showFrameNumber'), ...
                'Enable', onOff(showVideo), ...
                'Checked', onOff(showFrameNumbers));
        end
        
        
        %% Timeline menu callbacks
        
        
        function handleZoomIn(obj, ~, ~)
            obj.setZoom(obj.zoom * 2);
        end
        
        
        function handleZoomOut(obj, ~, ~)
            obj.setZoom(obj.zoom / 2);
            
            obj.updateTimelineMenuItems();
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
        
        
        function handleAnnotateFeatures(obj, ~, ~)
            % Create a new feature annotator.
            annotator = FeaturesAnnotator(obj);

            % Let the user tweak its settings.
            if annotator.editSettings()
                % Create a panel to show the annotator.
                panel = obj.addReporter(annotator);

                obj.addUndoableAction('Annotate Features', ...
                                      @() obj.closePanel(panel), ...
                                      @() obj.addReporter(annotator, panel), ...
                                      panel);
            end
        end
        
        
        function handleShowWaveformAndOrSpectrogramOnOpen(obj, ~, ~, showWaveform, showSpectrogram)
            % Remember the user's choice.
            setpref('Tempo', 'ShowWaveforms', showWaveform);
            setpref('Tempo', 'ShowSpectrograms', showSpectrogram);
            
            obj.updateTimelineMenuItems();
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
                waveform.handleDisplayRangeChanged([], []);
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
                spectrogram.handleDisplayRangeChanged([], []);
                obj.timelinePanels = {obj.timelinePanels{1:position}, spectrogram, obj.timelinePanels{position + 1:end}};
            end
            
            obj.arrangeTimelinePanels();
        end
        
        
        function updateTimelineMenuItems(obj)
            showTimeline = onOff(get(obj.timelinesPanel, 'Visible'));
            
            % Update the menu items.
            set(findobj(obj.timelineMenu, 'Tag', 'zoomIn'), ...
                'Enable', onOff(showTimeline));
            set(findobj(obj.timelineMenu, 'Tag', 'zoomOut'), ...
                'Enable', onOff(showTimeline && obj.zoom > 1));
            set(findobj(obj.timelineMenu, 'Tag', 'zoomToSelection'), ...
                'Enable', onOff(showTimeline));
            set(findobj(obj.timelineMenu, 'Tag', 'showWaveformOnOpen'), ...
                'Enable', onOff(showTimeline), ...
                'Checked', onOff(getpref('Tempo', 'ShowWaveforms', true) && ~getpref('Tempo', 'ShowSpectrograms', true)));
            set(findobj(obj.timelineMenu, 'Tag', 'showSpectrogramOnOpen'), ...
                'Enable', onOff(showTimeline), ...
                'Checked', onOff(~getpref('Tempo', 'ShowWaveforms', true) && getpref('Tempo', 'ShowSpectrograms', true)));
            set(findobj(obj.timelineMenu, 'Tag', 'showBothOnOpen'), ...
                'Enable', onOff(showTimeline), ...
                'Checked', onOff(getpref('Tempo', 'ShowWaveforms', true) && getpref('Tempo', 'ShowSpectrograms', true)));
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
            elseif strcmp(playRate, '16x')
                newRate = 16.0;
            elseif strcmp(playRate, '8x')
                newRate = 8.0;
            elseif strcmp(playRate, '4x')
                newRate = 4.0;
            elseif strcmp(playRate, '2x')
                newRate = 2.0;
            elseif strcmp(playRate, '1x')
                newRate = 1.0;
            elseif strcmp(playRate, '1/2x')
                newRate = 1.0 / 2;
            elseif strcmp(playRate, '1/4x')
                newRate = 1.0 / 4;
            elseif strcmp(playRate, '1/8x')
                newRate = 1.0 / 8;
            elseif strcmp(playRate, '1/16x')
                newRate = 1.0 / 16;
            elseif strcmp(playRate, 'faster')
                newRate = obj.playRate * 2.0;
            elseif strcmp(playRate, 'slower')
                newRate = obj.playRate / 2.0;
            else
                warning('Tempo:UnknownPlayMode', 'Don''t know how to play ''%s''.', num2str(playRate));
            end
            obj.playRate = newRate;
            
            if startPlaying && (~obj.isPlaying || newRate ~= obj.playRate)
                % TODO: if already playing then things need to be done differently...
                
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
            
            obj.updatePlaybackMenuItems();
        end
        
        
        function handleChoosePlaybackSpeed(obj, ~, ~)
            % Create a pop-up menu with speeds from 16x through 1/16x.
            chooseSpeedMenu = uicontextmenu();
            uimenu(chooseSpeedMenu, 'Label', 'Playback speed', 'Enable', 'off');
            speeds = {'16x', '8x', '4x', '2x', '1x', '1/2x', '1/4x', '1/8x', '1/16x'};
            for speed = speeds
                uimenu(chooseSpeedMenu, 'Label', speed{1}, ...
                                  'Tag', speed{1}, ...
                                  'Separator', onOff(strcmp(speed{1}, '16x')), ...
                                  'Callback', @(hObject, eventdata)handlePlay(obj, hObject, eventdata, speed{1}));
            end
            
            % Show the menu at the current mouse point.
            mousePos = get(0, 'PointerLocation');
            figurePos = get(obj.figure, 'Position');
            set(chooseSpeedMenu, ...
                'Position', [mousePos(1) - figurePos(1), mousePos(2) - figurePos(2)], ...
                'Visible', 'on');
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
                
% Debug code:
%                 elapsedTime = (now - obj.playStartTime) * (24*60*60);
%                 fprintf('FPS: %g\n', obj.fpsFrameCount / elapsedTime);  % should be divided by number of videos playing
                
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
                
                obj.updatePlaybackMenuItems();
            end
        end
        
        
        function updatePlaybackMenuItems(obj)
            set(findobj(obj.playbackMenu, 'Tag', 'play'), ...
                'Enable', onOff(~obj.isPlaying));
            set(findobj(obj.playbackMenu, 'Tag', 'playBackwards'), ...
                'Enable', onOff(~obj.isPlaying));
            set(findobj(obj.playbackMenu, 'Tag', 'pause'), ...
                'Enable', onOff(obj.isPlaying));
            set(findobj(obj.playbackMenu, 'Tag', 'regularSpeed'), ...
                'Enable', onOff(~obj.isPlaying), ...
                'Checked', onOff(obj.playRate == 1.0));
            set(findobj(obj.playbackMenu, 'Tag', 'doubleSpeed'), ...
                'Enable', onOff(~obj.isPlaying), ...
                'Checked', onOff(obj.playRate == 2.0));
            set(findobj(obj.playbackMenu, 'Tag', 'halfSpeed'), ...
                'Enable', onOff(~obj.isPlaying), ...
                'Checked', onOff(obj.playRate == 0.5));
            set(findobj(obj.playbackMenu, 'Tag', 'increaseSpeed'), ...
                'Enable', onOff(~obj.isPlaying));
            set(findobj(obj.playbackMenu, 'Tag', 'decreaseSpeed'), ...
                'Enable', onOff(~obj.isPlaying));
            
            set(obj.playForwardsTool, 'Enable', onOff(~obj.isPlaying));
            set(obj.pauseTool, 'Enable', onOff(obj.isPlaying));
            set(obj.playBackwardsTool, 'Enable', onOff(~obj.isPlaying));
            set(obj.playSlowerTool, 'Enable', onOff(~obj.isPlaying));
            if isjava(obj.playbackSpeedTool)
                obj.playbackSpeedTool.setEnabled(~obj.isPlaying);
            else
                set(obj.playbackSpeedTool, 'Enable', onOff(~obj.isPlaying));
            end
            set(obj.playFasterTool, 'Enable', onOff(~obj.isPlaying));
            
            % Show the play rate in the toolbar icon
            if isjava(obj.playbackSpeedTool)
                if obj.playRate < 1
                    obj.playbackSpeedTool.setText(sprintf('1/%dx', 1.0 / obj.playRate));
                else
                    obj.playbackSpeedTool.setText(sprintf('%dx', obj.playRate));
                end
            end
        end
        
        
        %% Window menu callbacks
        
        
        %% Help menu callbacks
        
        
        function handleShowHelp(obj, ~, ~, varargin)  %#ok<INUSL>
            TempoHelp().openPage(varargin{:});
        end
        
        
        function handleVisitWebSite(obj, ~, ~) %#ok<INUSD>
            web('http://github.com/JaneliaSciComp/tempo', '-browser');
        end
        
        
        %% Toolbar callbacks
        
        
        function panel = addReporter(obj, reporter, panel)
            obj.reporters{end + 1} = reporter;
            
            % Open a new features panel for the reporter unless one was provided.
            if nargin < 3
                panel = FeaturesPanel(reporter);
            else
                panel.createUI();
                panel.handleCurrentTimeChanged([], []);
            end
            obj.timelinePanels{end + 1} = panel;
            obj.arrangeTimelinePanels();
            obj.showTimelinePanels(true);
        end
        
        
        function removeReporter(obj, reporter)
            % Remove the reporter's panel if it has one.
            for featurePanel = obj.panelsOfClass('FeaturesPanel')
                if featurePanel{1}.reporter == reporter
                    obj.timelinePanels(cellfun(@(x) x == featurePanel{1}, obj.timelinePanels)) = [];
                    featurePanel{1}.close();
                    delete(featurePanel{1});
                    obj.arrangeTimelinePanels();
                    break
                end
            end
            
            % Remove the reporter.
            obj.reporters(cellfun(@(x) x == reporter, obj.reporters)) = [];
            
            for j = 1:length(obj.timelinePanels)
                panel = obj.timelinePanels{j};
                if isa(panel, 'SpectrogramPanel')
                    panel.deleteAllReporters();
                end
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
            
            % Move the selection into view if necessary
            if obj.selectedRange(1) > obj.displayRange(2) || obj.selectedRange(2) < obj.displayRange(1)
                obj.centerDisplayAtTime(mean(obj.selectedRange(1:2)));
            end
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
            obj.splitter.resize();
            
            % The panels' ResizeFcn's should take care of this but they aren't for some reason.
            obj.arrangeVideoPanels();
            obj.arrangeTimelinePanels();
        end
        
        
        function pointer = resizePointer(obj, xConstraint, yConstraint)
            % Cursor names:
            %  topl  top   topr
            %  left fleur  right
            %  botl bottom botr
            if obj.panelEditingRange.showsFrequencyRange && strcmp(yConstraint, 'min')
                pointer = 'bot';
            elseif obj.panelEditingRange.showsFrequencyRange && strcmp(yConstraint, 'max')
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
            
            % Figure out what was clicked on.
            clickedType = get(clickedObject, 'Type');
            if strcmp(clickedType, 'axes')
                clickedAxes = clickedObject;
            else
                if isempty(get(clickedObject, 'ButtonDownFcn'))
                    clickedAxes = get(clickedObject, 'Parent');
                else
                    clickedAxes = [];
                end
            end
            clickedPanel = [];
            for i = 1:length(obj.timelinePanels)
                if clickedAxes == obj.timelinePanels{i}.axes
                    clickedPanel = obj.timelinePanels{i};
                    break;
                end
            end
            
            if ~isempty(clickedPanel)
                % Figure out the time and frequency of the clicked point.
                clickedPoint = get(clickedAxes, 'CurrentPoint');
                clickedTime = clickedPoint(1, 1);
                if clickedPanel.showsFrequencyRange
                    % Get the frequency from the clicked point.
                    % TODO: this doesn't work if the spectrogram is hidden when zoomed out.  Probably just need to have YLim set.
                    clickedFreq = clickedPoint(1, 2);
                else
                % Pick a frequency at the middle of the selected range.
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
                    if clickedPanel.showsFrequencyRange && ~isinf(obj.selectedRange(3)) && ~isinf(obj.selectedRange(4))
                        if clickedFreq < obj.selectedRange(3)
                            obj.selectedRange(3) = clickedFreq;
                        else
                            obj.selectedRange(4) = clickedFreq;
                        end
                    else
                        obj.selectedRange(3:4) = [-inf inf];
                    end
                else
                    obj.panelEditingRange = clickedPanel;
                    obj.objectBeingEdited = clickedObject;
                    
                    if clickedObject == clickedAxes
                        % Potentially edit the global selected range.
                        rangeBeingEdited = obj.selectedRange;
                            
                        if clickedPanel.showsFrequencyRange && isinf(rangeBeingEdited(3))
                            % The selection is infinite but if the user clicks on the displayed edges then
                            % use the displayed range as the starting point of the new selection.
                            rangeBeingEdited(3:4) = obj.displayRange(3:4);
                        end
                    elseif isa(clickedPanel, 'FeaturesPanel')
                        % Potentially edit the range of the panel's selected object.
                        rangeBeingEdited = clickedPanel.selectedFeature.range;
                    end
                    obj.originalRangeBeingEdited = rangeBeingEdited;
                    if clickedTime > rangeBeingEdited(1) && clickedTime < rangeBeingEdited(2) && ...
                       clickedFreq > rangeBeingEdited(3) && clickedFreq < rangeBeingEdited(4)
                        % The user clicked inside of the existing selection, figure out which part was clicked on.
                        % TODO: only allow mid/mid if box is too small?
                            
                        % Clicking within 10 pixels of an edge will resize that edge (constraint = min/max), 
                        % otherwise drag the whole selection (constraint = mid).
                        axesPos = get(clickedAxes, 'Position');
                            timeMargin = 10 * (obj.displayRange(2) - obj.displayRange(1)) / (axesPos(3) - axesPos(1));
                            freqMargin = 10 * (obj.displayRange(4) - obj.displayRange(3)) / (axesPos(4) - axesPos(2));
                        if clickedTime < rangeBeingEdited(1) + timeMargin && clickedTime < rangeBeingEdited(2) - timeMargin
                                obj.mouseConstraintTime = 'min';
                        elseif clickedTime > rangeBeingEdited(2) - timeMargin && clickedTime > rangeBeingEdited(1) + timeMargin
                                obj.mouseConstraintTime = 'max';
                        else
                            obj.mouseConstraintTime = 'mid';
                        end
                        if clickedFreq < rangeBeingEdited(3) + freqMargin && clickedFreq < rangeBeingEdited(4) - freqMargin
                                obj.mouseConstraintFreq = 'min';
                        elseif clickedFreq > rangeBeingEdited(4) - freqMargin && clickedFreq > rangeBeingEdited(3) + freqMargin
                                obj.mouseConstraintFreq = 'max';
                        else
                            obj.mouseConstraintFreq = 'mid';
                        end
                    else
                        % The user clicked outside of the existing selection, make a new one.
                        if clickedPanel.showsFrequencyRange
                            rangeBeingEdited = [clickedTime clickedTime clickedFreq clickedFreq];
                        else
                            rangeBeingEdited = [clickedTime clickedTime -inf inf];    %obj.displayRange(3:4)];
                        end
                        obj.originalRangeBeingEdited = rangeBeingEdited;
                            obj.mouseConstraintTime = 'max';
                            obj.mouseConstraintFreq = 'max';
                            obj.currentTime = clickedTime;
                    end
                    obj.mouseOffset = [clickedTime - rangeBeingEdited(1), clickedFreq - rangeBeingEdited(3)];
                end
            end
        end
        
        
        function updateEditedRange(obj, endOfUpdate)
            clickedPoint = get(obj.panelEditingRange.axes, 'CurrentPoint');
            clickedTime = clickedPoint(1, 1);
            clickedFreq = clickedPoint(1, 2);
            newRange = obj.originalRangeBeingEdited;
            
            xConstraint = obj.mouseConstraintTime;
            if strcmp(obj.mouseConstraintTime, 'min')
                newRange(1) = clickedTime;
            elseif strcmp(obj.mouseConstraintTime, 'mid') && strcmp(obj.mouseConstraintFreq, 'mid')
                width = obj.originalRangeBeingEdited(2) - obj.originalRangeBeingEdited(1);
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
            if obj.panelEditingRange.showsFrequencyRange
                if strcmp(obj.mouseConstraintFreq, 'min')
                    newRange(3) = clickedFreq;
                elseif strcmp(obj.mouseConstraintFreq, 'mid') && strcmp(obj.mouseConstraintTime, 'mid')
                    if ~isinf(newRange(3)) && ~isinf(newRange(3))
                        height = obj.originalRangeBeingEdited(4) - obj.originalRangeBeingEdited(3);
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
            
            obj.panelEditingRange.setEditedRange(obj.objectBeingEdited, newRange, endOfUpdate);
        end
        
        
        function handleMouseMotion(obj, varargin)
            if ~isempty(obj.panelEditingRange)
                obj.updateEditedRange(false);
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
            if ~isempty(obj.panelEditingRange)
                obj.updateEditedRange(true);
                if obj.selectedRange(3) == obj.selectedRange(4)
                    obj.selectedRange(3:4) = [-inf inf];
                end
                obj.panelEditingRange = [];
                obj.objectBeingEdited = [];
                set(gcf, 'Pointer', 'arrow');
            end
        end
        
        
        function handleKeyPress(obj, ~, keyEvent)
            if ~strcmp(keyEvent.Key, 'space') && isempty(obj.panelHandlingKeyPress)
                % Let one of the panels handle the event.
                % If any video panels are open they get first dibs.
                panels = horzcat(obj.videoPanels, obj.timelinePanels);
                for i = 1:length(panels)
                    if ~panels{i}.isHidden
                        handled = panels{i}.keyWasPressed(keyEvent);
                        if handled
                            obj.panelHandlingKeyPress = panels{i};
                            break
                        end
                    end
                end
                
                if isempty(keyEvent.Modifier) && ~isempty(keyEvent.Character) && isempty(obj.panelHandlingKeyPress)
                    % The key wasn't handle by anyone.
                    beep
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
                obj.panelHandlingKeyPress = [];
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
        
        
        function set.currentTime(obj, time)
            if obj.currentTime ~= time
                obj.currentTime = time;
                
                set(obj.videoSlider, 'Value', obj.currentTime);
            end
        end
        
        
        function set.displayRange(obj, range)
            if ~all(obj.displayRange == range)
                obj.displayRange = range;
                
                % Adjust the step and page sizes of the time slider.
                stepSize = 1 / obj.zoom;
                curMax = get(obj.timelineSlider, 'Max');
                newValue = mean(obj.displayRange(1:2));
                set(obj.timelineSlider, 'SliderStep', [stepSize / 50.0 stepSize], ...
                                        'Value', newValue, ...
                                        'Max', max(curMax, newValue));
            end
        end
        
        
        function set.selectedRange(obj, range)
            if ~all(obj.selectedRange== range)
                obj.selectedRange = range;
                
                obj.updateMenuItemsAndToolbar();
            end
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
                
                obj.showTimelinePanels();
                obj.arrangeTimelinePanels();
                
                addlistener(recording, 'timeOffset', 'PostSet', @(source, event)handleRecordingDurationChanged(obj, source, event));
                
                obj.needsSave = true;
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
                
                obj.showVideoPanels();
                obj.arrangeVideoPanels();
                
                addlistener(recording, 'timeOffset', 'PostSet', @(source, event)handleRecordingDurationChanged(obj, source, event));
                
                obj.needsSave = true;
            end
        end
        
        
        function updateOverallDuration(obj)
            obj.duration = max([cellfun(@(r) r.duration, obj.recordings) cellfun(@(r) r.duration, obj.reporters)]);
            
            set(obj.videoSlider, 'Max', obj.duration);
            if ~isempty(obj.videoPanels)
                meanFrameRate = mean(cellfun(@(v) v.video.sampleRate, obj.videoPanels));
                set(obj.videoSlider, 'SliderStep', [1.0 / meanFrameRate / obj.duration, 5.0 / obj.duration]);
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
            s.version = 1.0;
            
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
            
            % Save the state of the splitter.
            s.showVideo = onOff(get(obj.videosPanel, 'Visible'));
            s.showTimeline = onOff(get(obj.timelinesPanel, 'Visible'));
            s.mainSplitter.orientation = obj.splitter.orientation;
            s.mainSplitter.position = obj.splitter.position;
            
            save(filePath, '-struct', 's');
        end
        
        
        function openWorkspace(obj, filePath)
            % TODO: Allow "importing" a workspace to add it to the current one?
            
            set(obj.figure, 'Pointer', 'watch');
            drawnow
            
            obj.savePath = filePath;
            [~, fileName, ~] = fileparts(filePath);
            set(obj.figure, 'Name', ['Tempo: ' fileName]);
            
            s = load(filePath, '-mat');
            
            % TODO: check if the window still fits on screen?
            set(obj.figure, 'Position', s.windowPosition);
            
            % Restore the state of the splitter.
            if isfield(s, 'showVideo') && isfield(s, 'showTimeline')
                % Load newest style settings.
                obj.splitter.orientation = s.mainSplitter.orientation;
                obj.splitter.position = s.mainSplitter.position;
                obj.showVideoPanels(s.showVideo);
                obj.showTimelinePanels(s.showTimeline);
            elseif isfield(s, 'mainSplitter')
                % Load settings from an older file.
                if isfield(s.mainSplitter', 'orientation')
                    obj.splitter.orientation = s.mainSplitter.orientation;
                end
                
                if s.mainSplitter.location < 0.01
                    obj.showVideoPanels(false);
                    obj.showTimelinePanels(true);
                elseif s.mainSplitter.location > 0.99
                    obj.showVideoPanels(true);
                    obj.showTimelinePanels(false);
                else
                    obj.showVideoPanels(true);
                    obj.showTimelinePanels(true);
                end
                obj.splitter.position = s.mainSplitter.location;
            end
            
            havePanels = isfield(s, 'videoPanels');
            
            % Load the recordings.
            obj.recordings = s.recordings;
            for i = 1:length(obj.recordings)
                recording = obj.recordings{i};
                recording.controller = obj;
                try
                    recording.loadData();
                catch ME
                    % TODO: prompt the user to locate a moved file?
                    uiwait(errordlg(['One of the recordings could not be opened.' char(10) char(10) ME.message], 'Tempo', 'modal'));
                    recording = [];
                end
                if ~isempty(recording) && ~havePanels
                    if isa(recording, 'AudioRecording')
                        % TODO: check prefs?
                        obj.openWaveform(recording);
                        obj.openSpectrogram(recording);
                        obj.showTimelinePanels();
                    elseif isa(recording, 'VideoRecording')
                        panel = VideoPanel(obj, recording);
                        obj.videoPanels{end + 1} = panel;
                        obj.showVideoPanels();
                    end
                end
            end
            
            % Load the detectors and importers.
            % TODO: do Feature's reporters need to be set?
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
            
            obj.updateViewMenuItems();
            obj.updateVideoMenuItems();
            obj.updateTimelineMenuItems();
            
            set(obj.figure, 'Pointer', 'arrow');
            drawnow
        end
        
        
        %% Undo management
        
        
        function addUndoableAction(obj, actionName, undoAction, redoAction, context)
            % Remember the display range, selection and current time so they can be restored on undo/redo.
            userData.displayRange = obj.displayRange;
            userData.selectedRange = obj.selectedRange;
            userData.currentTime = obj.currentTime;
            
            % Mark the workspace as dirty.
            % TODO: can this be determined by the state of the undo stack?
            obj.needsSave = true;
            
            obj.undoManager.addAction(actionName, undoAction, redoAction, context, userData);
        end
        
        
        function handleUndo(obj, ~, ~)
            userData = obj.undoManager.undo();
            
            % Reset the display, selection and current time to where they were when the action was performed.
            obj.displayRange = userData.displayRange;
            obj.selectedRange = userData.selectedRange;
            obj.currentTime = userData.currentTime;
        end
        
        
        function handleRedo(obj, ~, ~)
            userData = obj.undoManager.redo();
            
            % Reset the display, selection and current time to where it was when the action was performed.
            obj.displayRange = userData.displayRange;
            obj.selectedRange = userData.selectedRange;
            obj.currentTime = userData.currentTime;
        end
        
        
        function handleUndoStackChanged(obj, ~, ~)
            obj.updateEditMenuItems();
        end
        
        
        %% Miscellaneous functions
        
        
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
            if isjava(obj.playbackSpeedTool)
                set(obj.playbackSpeedTool, 'ActionPerformedCallback', []);
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
