classdef AnalysisController < handle
    
    properties
        figure
        recordings = Recording.empty()
        
        duration = 300
        zoom = 1
        
        videoPanels = {}
        otherPanels = {}
        
        timeSlider
        
        toolbar
        zoomOutTool
        
        timeLabel
        timeLabelFormat
        
        panelSelectingTime
        
        playTimer
        
        detectorClassNames
        detectorTypeNames
        importerClassNames
        importerTypeNames
        
        showWaveforms
        showSpectrograms
        showFeatures
    end
    
    properties (SetObservable)
        % The analysis panels will listen for changes to these properties.
        displayedTime = 0       % The time that all of the non-video panels should center their display on (in seconds).
        timeWindow = 5          % The width of the time window the non-video panels should display (in seconds).
        currentTime = 0         % The time point currently being played (in seconds).
        selectedTime = [0 0]    % The range of time currently selected (in seconds).  The two values will be equal if there is a point selection.
    end
    
    %                   On change update:                           Can be changed by:
    % displayedTime     other panels, time slider                   time slider, key press, player
    % timeWindow        other panels                                toolbar icons, key press
    % currentTime       other panels, video panels, time label      axes click, key press, player
    % selectedTime      other panels, time label                    axes click, key press
    
    methods
        
        function obj = AnalysisController()
            obj.showWaveforms = getpref('SongAnalysis', 'ShowWaveforms', true);
            obj.showSpectrograms = getpref('SongAnalysis', 'ShowSpectrograms', true);
            obj.showFeatures = getpref('SongAnalysis', 'ShowFeatures', true);
            
            obj.figure = figure('Name', 'Song Analysis', ...
                'NumberTitle', 'off', ...
                'Toolbar', 'none', ...
                'Position', getpref('SongAnalysis', 'MainWindowPosition', [100 100 400 200]), ...
                'Color', 'black', ...
                'ResizeFcn', @(source, event)handleResize(obj, source, event), ...
                'KeyPressFcn', @(source, event)handleKeyPress(obj, source, event), ...
                'CloseRequestFcn', @(source, event)handleClose(obj, source, event), ...
                'WindowButtonDownFcn', @(source, event)handleMouseButtonDown(obj, source, event), ...
                'WindowButtonUpFcn', @(source, event)handleMouseButtonUp(obj, source, event)); %#ok<CPROP>
            
            obj.createToolbar();
            
            % Create the scroll bar that lets the user scrub through time.
            obj.timeSlider = uicontrol('Style', 'slider',...
                'Min', 0, ...
                'Max', obj.duration, ...
                'Value', 0, ...
                'Position', [1 1 400 16], ...
                'Callback', @(source, event)handleTimeSliderChanged(obj, source, event));
            if verLessThan('matlab', '7.12.0')
                addlistener(obj.timeSlider, 'Action', @(source, event)handleTimeSliderChanged(obj, source, event));
            else
                addlistener(obj.timeSlider, 'ContinuousValueChange', @(source, event)handleTimeSliderChanged(obj, source, event));
            end
            
            if isdeployed && exist(fullfile(ctfroot, 'Detectors'), 'dir')
                % Look for the detectors in the CTF archive.
                parentDir = ctfroot;
            else
                % Look for the detectors relative to this .m file.
                analysisPath = mfilename('fullpath');
                parentDir = fileparts(analysisPath);
            end
            
            [obj.detectorClassNames, obj.detectorTypeNames] = findPlugIns(fullfile(parentDir, 'Detectors'));
            [obj.importerClassNames, obj.importerTypeNames] = findPlugIns(fullfile(parentDir, 'Importers'));
            
            addpath(fullfile(parentDir, 'AnalysisPanels'));
            
            addpath(fullfile(parentDir, 'export_fig'));
            if ismac
                % Make sure the export_fig can find Ghostscript if it was installed via MacPorts.
                setenv('DYLD_LIBRARY_PATH', ['/opt/local/lib:' getenv('DYLD_LIBRARY_PATH')]);
            end
            
            obj.arrangePanels();
        end
        
        
        function createToolbar(obj)
            % Open | Zoom in Zoom out | Play Pause | Find features | Save features Save screenshot | Show/hide waveforms Show/hide features Toggle time format
            obj.toolbar = uitoolbar(obj.figure);
            
            iconRoot = 'Icons';
            defaultBackground = get(0, 'defaultUicontrolBackgroundColor');
            
            iconData = double(imread(fullfile(matlabroot, 'toolbox', 'matlab', 'icons', 'file_open.png'), 'BackgroundColor', defaultBackground)) / 65535;
            uipushtool(obj.toolbar, ...
                'Tag', 'openFile', ...
                'CData', iconData, ...
                'TooltipString', 'Open audio/video files or import features',... 
                'Separator', 'on', ...
                'ClickedCallback', @(hObject, eventdata)handleOpenFile(obj, hObject, eventdata));
            
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
            
            iconData = double(imread(fullfile(iconRoot, 'play.png'), 'BackgroundColor', defaultBackground)) / 255;
            uipushtool(obj.toolbar, ...
                'Tag', 'playMedia', ...
                'CData', iconData, ...
                'TooltipString', 'Play audio/video recordings',... 
                'Separator', 'on', ...
                'ClickedCallback', @(hObject, eventdata)handlePlay(obj, hObject, eventdata));
            iconData = double(imread(fullfile(iconRoot, 'pause.png'), 'BackgroundColor', defaultBackground)) / 255;
            uipushtool(obj.toolbar, ...
                'Tag', 'pauseMedia', ...
                'CData', iconData, ...
                'TooltipString', 'Pause audio/video recordings',... 
                'ClickedCallback', @(hObject, eventdata)handlePause(obj, hObject, eventdata));
            
            iconData = double(imread(fullfile(iconRoot, 'detect.png'), 'BackgroundColor', defaultBackground)) / 255;
            uipushtool(obj.toolbar, ...
                'Tag', 'detectFeatures', ...
                'CData', iconData, ...
                'TooltipString', 'Detect features',... 
                'Separator', 'on', ...
                'ClickedCallback', @(hObject, eventdata)handleDetectFeatures(obj, hObject, eventdata));
            
            iconData = double(imread(fullfile(matlabroot, 'toolbox', 'matlab', 'icons', 'file_save.png'),'BackgroundColor', defaultBackground)) / 65535;
            uipushtool(obj.toolbar, ...
                'Tag', 'saveFeatures', ...
                'CData', iconData, ...
                'TooltipString', 'Save all features',...
                'Separator', 'on', ...
                'ClickedCallback', @(hObject, eventdata)handleSaveAllFeatures(obj, hObject, eventdata));
            iconData = double(imread(fullfile(iconRoot, 'screenshot.png'), 'BackgroundColor', defaultBackground)) / 255;
            uipushtool(obj.toolbar, ...
                'Tag', 'saveScreenshot', ...
                'CData', iconData, ...
                'TooltipString', 'Save a screenshot',...
                'ClickedCallback', @(hObject, eventdata)handleSaveScreenshot(obj, hObject, eventdata));
            
            states = {'off', 'on'};
            iconData = double(imread(fullfile(iconRoot, 'waveform.png'), 'BackgroundColor', defaultBackground)) / 255;
            uitoggletool(obj.toolbar, ...
                'Tag', 'showHideWaveforms', ...
                'CData', iconData, ...
                'State', states{obj.showWaveforms + 1}, ...
                'TooltipString', 'Show/hide the waveform(s)',... 
                'Separator', 'on', ...
                'OnCallback', @(hObject, eventdata)handleToggleWaveforms(obj, hObject, eventdata), ...
                'OffCallback', @(hObject, eventdata)handleToggleWaveforms(obj, hObject, eventdata));
            iconData = double(imread(fullfile(iconRoot, 'spectrogram.png'), 'BackgroundColor', defaultBackground)) / 255;
            uitoggletool(obj.toolbar, ...
                'Tag', 'showHideSpectrograms', ...
                'CData', iconData, ...
                'State', states{obj.showSpectrograms + 1}, ...
                'TooltipString', 'Show/hide the spectrogram(s)',... 
                'OnCallback', @(hObject, eventdata)handleToggleSpectrograms(obj, hObject, eventdata), ...
                'OffCallback', @(hObject, eventdata)handleToggleSpectrograms(obj, hObject, eventdata));
            iconData = double(imread(fullfile(iconRoot, 'features.png'), 'BackgroundColor', defaultBackground)) / 255;
            uitoggletool(obj.toolbar, ...
                'Tag', 'showHideFeatures', ...
                'CData', iconData, ...
                'State', states{obj.showFeatures + 1}, ...
                'TooltipString', 'Show/hide the features',... 
                'OnCallback', @(hObject, eventdata)handleToggleFeatures(obj, hObject, eventdata), ...
                'OffCallback', @(hObject, eventdata)handleToggleFeatures(obj, hObject, eventdata));
            
            drawnow;
            
            % Add a right-aligned text field to show the current time and selection.
            % TODO: move this somewhere that will be included in screen shots
            toolbarSize = length(get(obj.toolbar, 'Children'));
            jToolbar = get(get(obj.toolbar, 'JavaContainer'), 'ComponentPeer');
            jToolbar.add(javax.swing.Box.createHorizontalGlue());
            label = javax.swing.JLabel('');
            jToolbar.add(label, toolbarSize + 5);
            jToolbar.repaint;
            jToolbar.revalidate;
            obj.timeLabel = handle(label);
            obj.timeLabelFormat = 1;    % default to displaying time in minutes and seconds
        end
        
        
        function arrangePanels(obj)
            pos = get(obj.figure, 'Position');
            
            if ~isempty(obj.videoPanels)
                % TODO: Arrange the video panels
            end
            
            visibleOtherPanels = {};
            for i = 1:length(obj.otherPanels)
                panel = obj.otherPanels{i};
                if (panel.visible)
                    visibleOtherPanels{end + 1} = panel; %#ok<AGROW>
                end
            end
            
            if ~isempty(visibleOtherPanels)
                % Arrange the other panels
                panelsHeight = pos(4) - 16;
                numPanels = length(visibleOtherPanels);
                panelHeight = floor(panelsHeight / numPanels);
                for i = 1:numPanels - 1
                    set(visibleOtherPanels{i}.panel, 'Position', [1, pos(4) - i * panelHeight, pos(3), panelHeight + 1]);
                end
                lastPanelHeight = panelsHeight - panelHeight * (numPanels - 1);
                set(visibleOtherPanels{end}.panel, 'Position', [1, 16, pos(3), lastPanelHeight]);
            end
            
            % TODO: time slider should be under other panels if there are any, otherwise under the video panels.
            set(obj.timeSlider, 'Position', [1 0 pos(3) 16]);
        end
        
        
        function handleToggleWaveforms(obj, ~, ~)
            obj.showWaveforms = ~obj.showWaveforms;
            for i = 1:length(obj.otherPanels)
                panel = obj.otherPanels{i};
                if isa(panel, 'WaveformPanel')
                    panel.setVisible(obj.showWaveforms);
                end
            end
            
            obj.arrangePanels();
            
            setpref('SongAnalysis', 'ShowWaveforms', obj.showWaveforms);
        end
        
        
        function handleToggleSpectrograms(obj, ~, ~)
            obj.showSpectrograms = ~obj.showSpectrograms;
            for i = 1:length(obj.otherPanels)
                panel = obj.otherPanels{i};
                if isa(panel, 'SpectrogramPanel')
                    panel.setVisible(obj.showSpectrograms);
                end
            end
            
            obj.arrangePanels();
            
            setpref('SongAnalysis', 'ShowSpectrograms', obj.showSpectrograms);
        end
        
        
        function handleToggleFeatures(obj, ~, ~)
            obj.showFeatures = ~obj.showFeatures;
            for i = 1:length(obj.otherPanels)
                panel = obj.otherPanels{i};
                if isa(panel, 'FeaturesPanel')
                    panel.setVisible(obj.showFeatures);
                end
            end
            
            obj.arrangePanels();
            
            setpref('SongAnalysis', 'ShowFeatures', obj.showFeatures);
        end
        
        
        function setZoom(obj, zoom)
            if zoom < 1
                obj.zoom = 1;
            else
                obj.zoom = zoom;
            end
            
            % Center the display on the current time.
            obj.displayedTime = obj.currentTime;
            obj.timeWindow = obj.duration / obj.zoom;
            
            stepSize = 1 / obj.zoom;
            set(obj.timeSlider, 'SliderStep', [stepSize / 50.0 stepSize]);
            
            if obj.zoom > 1
                set(obj.zoomOutTool, 'Enable', 'on')
            else
                set(obj.zoomOutTool, 'Enable', 'off')
            end
        end
        
        
        function handleZoomIn(obj, ~, ~)
            obj.setZoom(obj.zoom * 2);
        end
        
        
        function handleZoomOut(obj, ~, ~)
            obj.setZoom(obj.zoom / 2);
        end
        
        
        function handleResize(obj, ~, ~)
            obj.arrangePanels();
        end
        
        
        function handleMouseButtonDown(obj, ~, ~)
% TODO: make control-click work again
%             if strcmp(get(gcf, 'SelectionType'), 'alt')
%                 contextualMenu = get(clickedObject, 'UIContextMenu');
%                 if ~isempty(contextualMenu)
%                     set(contextualMenu, 'Position', get(handles.figure1, 'CurrentPoint'), 'Visible', 'On');
%                     return
%                 end
%             end
            
            clickedObject = get(obj.figure, 'CurrentObject');
            for i = 1:length(obj.otherPanels)
                if clickedObject == obj.otherPanels{i}.axes
                    clickedPoint = get(clickedObject, 'CurrentPoint');
                    clickedTime = clickedPoint(1);
                    if strcmp(get(gcf, 'SelectionType'), 'extend')
                        if obj.currentTime == obj.selectedTime(1) || obj.currentTime ~= obj.selectedTime(2)
                            obj.selectedTime = sort([obj.selectedTime(1) clickedTime]);
                        else
                            obj.selectedTime = sort([clickedTime obj.selectedTime(2)]);
                        end
                    else
                        obj.currentTime = clickedTime;
                        obj.selectedTime = [clickedTime clickedTime];
                        obj.panelSelectingTime = obj.otherPanels{i};
                    end
                    
                    obj.updateTimeLabel();
                    
                    break
                end
            end
        end


        function handleMouseButtonMotion(obj, ~, ~)
            if ~isempty(obj.panelSelectingTime)
                clickedPoint = get(obj.panelSelectingTime.axes, 'CurrentPoint');
                clickedTime = clickedPoint(1);
                if obj.currentTime == obj.selectedTime(1) || obj.currentTime ~= obj.selectedTime(2)
                    obj.selectedTime = sort([obj.selectedTime(1) clickedTime]);
                else
                    obj.selectedTime = sort([clickedTime obj.selectedTime(2)]);
                end
                
                obj.updateTimeLabel();
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
                clickedPoint = get(obj.panelSelectingTime.axes, 'CurrentPoint');
                clickedTime = clickedPoint(1);
                if obj.currentTime == obj.selectedTime(1) || obj.currentTime ~= obj.selectedTime(2)
                    obj.selectedTime = sort([obj.selectedTime(1) clickedTime]);
                else
                    obj.selectedTime = sort([clickedTime obj.selectedTime(2)]);
                end
                obj.panelSelectingTime = [];
                
                obj.updateTimeLabel();
            end
        end
        
        
        function handleKeyPress(obj, ~, ~)
            % TODO
        end
        
        
        function handleTimeSliderChanged(obj, ~, ~)
            obj.displayedTime = get(obj.timeSlider, 'Value');
        end
        
        
        function handleOpenFile(obj, ~, ~)
            [fileNames, pathName] = uigetfile2('Select an audio or video file to analyze');
            
            if ischar(fileNames)
                fileNames = {fileNames};
            elseif isnumeric(fileNames)
                fileNames = {};
            end

            audioChanged = false;
            videoChanged = false;

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

                % First check if the file can be imported by one of the feature importers.
%                 try
%                     possibleImporters = [];
%                     audioPaths = {};
%                     channels = {};
%                     for j = 1:length(handles.importerClassNames)
%                         [canImport, audioPath, channel] = eval([handles.importerClassNames{j} '.canImportFromPath(''' strrep(fullPath, '''', '''''') ''')']);
%                         if canImport
%                             possibleImporters(end+1) = j; %#ok<AGROW>
%                             audioPaths{end + 1} = audioPath; %#ok<AGROW>
%                             channels{end + 1} = channel; %#ok<AGROW>
%                         end
%                     end
% 
%                     % If there is no audio file open then only importers that indicate which audio file to open can be used.
%                     if ~isempty(possibleImporters) && ~isfield(handles, 'audio')
%                         inds = ~isempty(audioPaths{:});
%                         possibleImporters = possibleImporters(inds);
%                         audioPaths = audioPaths(inds);
%                         channels = channels(inds);
% 
%                         if isempty(possibleImporters)
%                             warndlg('You must open an audio file before you can import these features.', 'Fly Song Analysis', 'modal');
%                             return
%                         end
%                     end
% 
%                     if ~isempty(possibleImporters)
%                         index = [];
%                         if length(possibleImporters) == 1
%                             index = possibleImporters(1);
%                         else
%                             choice = listdlg('PromptString', 'Choose which importer to use:', ...
%                                              'SelectionMode', 'Single', ...
%                                              'ListString', handles.importerTypeNames(possibleImporters));
%                             if ~isempty(choice)
%                                 index = choice(1);
%                             end
%                         end
%                         if ~isempty(index)
%                             if ~isfield(handles, 'audio') && ~isempty(audioPaths{index})
%                                 % Load the audio file indicated by the importer.
%                                 rec = Recording(audioPaths{index}, channels{index});
%                                 if rec.isAudio
%                                     setAudioRecording(rec);
%                                     audioChanged = true;
%                                     handles = guidata(handles.figure1);
%                                 end
%                             end
% 
%                             constructor = str2func(handles.importerClassNames{index});
%                             importer = constructor(handles.audio, fullPath);
%                             importer.startProgress();
%                             try
%                                 n = importer.importFeatures();
%                                 importer.endProgress();
% 
%                                 if n == 0
%                                     waitfor(msgbox('No features were imported.', handles.importerTypeNames{index}, 'warn', 'modal'));
%                                 else
%                                     handles.reporters{numel(handles.reporters) + 1, 1} = importer;  %TODO: just use handles.audio.reporters() instead?
%                                     handles.audio.addReporter(importer);
%                                     handles = updateFeatureTimes(handles);
%                                     guidata(handles.figure1, handles);
%                                 end
%                             catch ME
%                                 waitfor(msgbox('An error occurred while importing features.  (See the command window for details.)', handles.importerTypeNames{index}, 'error', 'modal'));
%                                 importer.endProgress();
%                                 rethrow(ME);
%                             end
% 
%                             addContextualMenu(importer);
%                         end
%                     end
%                 catch ME
%                     rethrow(ME);
%                 end

                % Next check if it's an audio or video file.
                try
                    recs = Recording(fullPath);
                    
                    for j = 1:length(recs)
                        rec = recs(j);
                        if rec.isAudio
                            obj.addAudioRecording(rec);
                            audioChanged = true;
                        elseif rec.isVideo
                            obj.addVideoRecording(rec);
                            handles = guidata(handles.figure1);
                            videoChanged = true;
                        end
                    end
                catch ME
                    warndlg(['Error opening media file:\n\n' ME.message]);
                    rethrow(ME);
                end
            end

            if audioChanged || videoChanged
                obj.duration = max([obj.recordings.duration]);
                obj.zoom = max(1.0, obj.duration / 60);
                set(obj.timeSlider, 'Max', obj.duration);
                
                obj.displayedTime = obj.displayedTime;
            end
        end
        
        
        function addAudioRecording(obj, recording)
            if isempty(obj.recordings)
                set(obj.figure, 'Name', ['Song Analysis: ' recording.name]);
            end
            
            obj.recordings(end + 1) = recording;
            
            panel = WaveformPanel(obj, recording);
            obj.otherPanels{end + 1} = panel;
            panel.setVisible(obj.showWaveforms);
            
            panel = SpectrogramPanel(obj, recording);
            obj.otherPanels{end + 1} = panel;
            panel.setVisible(obj.showSpectrograms);
            
            obj.arrangePanels();
        end
        
        
        function addVideoRecording(obj, recording)
            if isempty(obj.recordings)
                set(obj.figure, 'Name', ['Song Analysis: ' recording.name]);
            end
            
            obj.recordings(end + 1) = recording;
            
            panel = VideoPanel(obj, recording);
            obj.videoPanels{end + 1} = panel;
            
            obj.arrangePanels();
        end
        
        
        function updateTimeLabel(obj)
            % Display the current time and selection in the toolbar text field.
            if obj.selectedTime(1) == obj.selectedTime(2)
                timeString = secondstr(obj.currentTime, obj.timeLabelFormat);
                timeToolTip = '';
            else
                timeString = [secondstr(obj.currentTime, obj.timeLabelFormat) ' [' secondstr(obj.selectedTime(1), obj.timeLabelFormat) '-' secondstr(obj.selectedTime(2), obj.timeLabelFormat) ']'];
                timeToolTip = [num2str(obj.selectedTime(2) - obj.selectedTime(1)) ' seconds'];
            end
            obj.timeLabel.setText(timeString);
            obj.timeLabel.setToolTipText(timeToolTip);
        end
        
        
        function updateTimeTicks(obj)
            % Update the time ticks and scale label.
% TODO:            
%             timeScale = fix(log10(obj.timeWindow));
%             if obj.timeWindow < 1
%                 timeScale = timeScale - 1;
%             end
%             tickSpacing = 10 ^ timeScale * sampleRate;
%             set(handles.oscillogram, 'XTick', tickSpacing-mod(minSample, tickSpacing):tickSpacing:windowSampleCount);
%             if timeScale == 0
%                 string = '1 sec';
%             elseif timeScale == 1
%                 string = '10 sec';
%             else
%                 string = ['10^{' num2str(timeScale) '} sec'];
%             end
%             set(obj.timeScaleText, 'Position', [windowSampleCount -maxAmp], 'String', string);
        end
        
        
        function handleClose(obj, ~, ~)
            if ~isempty(obj.playTimer)
                stop(obj.playTimer);
            end

            % Remember the window position.
            setpref('SongAnalysis', 'MainWindowPosition', get(obj.figure, 'Position'));

% TODO:
%             if (handles.close_matlabpool)
%               matlabpool close
%             end
            
            % TODO: Close all of the panels?
            
            delete(obj.figure);
        end
        
    end
    
end


function [classNames, typeNames] = findPlugIns(pluginsDir)
    pluginDirs = dir(pluginsDir);
    classNames = cell(length(pluginDirs), 1);
    typeNames = cell(length(pluginDirs), 1);
    pluginCount = 0;
    for i = 1:length(pluginDirs)
        if pluginDirs(i).isdir && pluginDirs(i).name(1) ~= '.'
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
        end
    end
    classNames = classNames(1:pluginCount);
    typeNames = typeNames(1:pluginCount);
end
