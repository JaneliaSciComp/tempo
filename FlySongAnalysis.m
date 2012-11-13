function varargout = FlySongAnalysis(varargin)
    % FLYSONGANALYZER M-file for FlySongAnalysis.fig
    %      FLYSONGANALYSIS, by itself, creates a new ANALYZER or raises the existing
    %      singleton*.
    %
    %      H = FLYSONGANALYSIS returns the handle to a new ANALYZER or the handle to
    %      the existing singleton*.

    % Last Modified by GUIDE v2.5 27-Jul-2012 12:22:14
    
    if verLessThan('matlab', '7.9')
        error 'FlySongAnalysis requires MATLAB 7.9 (2009b) or later.'
    end
    
    % Begin initialization code - DO NOT EDIT
    gui_Singleton = 0;
    gui_State = struct('gui_Name',       mfilename, ...
                       'gui_Singleton',  gui_Singleton, ...
                       'gui_OpeningFcn', @FlySongAnalysis_OpeningFcn, ...
                       'gui_OutputFcn',  @FlySongAnalysis_OutputFcn, ...
                       'gui_LayoutFcn',  [] , ...
                       'gui_Callback',   []);
    if nargin && ischar(varargin{1})
        gui_State.gui_Callback = str2func(varargin{1});
    end

    if nargout
        [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
    else
        gui_mainfcn(gui_State, varargin{:});
    end
    % End initialization code - DO NOT EDIT
end


function FlySongAnalysis_OpeningFcn(hObject, ~, handles, varargin)
    % Choose default command line output for FlySongAnalysis
    handles.output = hObject;
    
    %% Add a right-aligned text field in the toolbar to show the current time and selection.
    toolbarSize = length(get(handles.toolbar, 'Children'));
    jToolbar = get(get(handles.toolbar, 'JavaContainer'), 'ComponentPeer');
    jToolbar.add(javax.swing.Box.createHorizontalGlue());
    label = javax.swing.JLabel('');
    jToolbar.add(label, toolbarSize + 7);
    jToolbar.repaint;
    jToolbar.revalidate;
    handles.timeLabel = handle(label);
    handles.timeLabelFormat = 1;    % default to displaying time in minutes and seconds
   
    %% Insert a splitter at the top level
    set(handles.videoGroup, 'Units', 'normalized');
    set(handles.audioGroup, 'Units', 'normalized');
    videoPos = get(handles.videoGroup, 'Position');
    audioPos = get(handles.audioGroup, 'Position');
    
    warning('off', 'MATLAB:hg:JavaSetHGProperty');
    [handles.leftSplit, handles.rightSplit, handles.mainSplitter] = uisplitpane('DividerLocation', videoPos(3) / (videoPos(3) + audioPos(3)));
    warning('on', 'MATLAB:hg:JavaSetHGProperty');
    set(handles.videoGroup, 'Parent', handles.leftSplit, 'Position', [0 0 1 1]);
    set(handles.audioGroup, 'Parent', handles.rightSplit, 'Position', [0 0 1 1]);
    
    % Hide the video pane by default.
    try
        handles.mainSplitter.JavaComponent.getComponent(0).doClick();
    catch ME
        warning('FlySong:HideVideoPaneFailed', 'Could not hide the video pane. (%s)', ME.message);
    end
    
    %% Populate the list of detectors from the 'Detectors' folder.
    if isdeployed && exist(fullfile(ctfroot, 'Detectors'), 'dir')
        % Look for the detectors in the CTF archive.
        parentDir = ctfroot;
    else
        % Look for the detectors relative to this .m file.
        analysisPath = mfilename('fullpath');
        parentDir = fileparts(analysisPath);
    end
    [handles.detectorClassNames, handles.detectorTypeNames] = findPlugIns(fullfile(parentDir, 'Detectors'));
    [handles.importerClassNames, handles.importerTypeNames] = findPlugIns(fullfile(parentDir, 'Importers'));
    
    addpath(fullfile(parentDir, 'export_fig'));
    if ismac
        setenv('DYLD_LIBRARY_PATH', ['/opt/local/lib:' getenv('DYLD_LIBRARY_PATH')]);
    end
    
    %% Set defaults
    handles.currentTime = 0.0;              % The time currently being "rendered" from the recordings indicated by a red line in the oscillogram.
    handles.displayedTime = 0.0;            % The time on which the displays are centered.
    handles.selectedTime = [0.0 0.0];       % The highlighted range indicated by a light red box in the oscillogram.
    handles.selectingTimeRange = false;     % true when dragging in the oscillogram.
    handles.showCurrentSelection = true;
    handles.maxMediaTime = 0.0;
    handles.zoom = 1.0;
    handles.reporters = {};
    handles.showFeatures = true;
    handles.showSpectrogram = false;
    handles.featureTimes = [];
    
    guidata(hObject, handles);
    
    if verLessThan('matlab', '7.12.0')
        addlistener(handles.timeSlider, 'Action', @timeSlider_Listener);
        addlistener(handles.gainSlider, 'Action', @gainSlider_Listener);
    else
        addlistener(handles.timeSlider, 'ContinuousValueChange', @timeSlider_Listener);
        addlistener(handles.gainSlider, 'ContinuousValueChange', @gainSlider_Listener);
    end
    
    showSpectrogramCallback(0, 0, handles);
    
    if ispref('FlySongAnalysis', 'MainWindowPosition')
        set(handles.figure1, 'Position', getpref('FlySongAnalysis', 'MainWindowPosition'));
    end
    set(handles.figure1, 'WindowButtonDownFcn', @windowButtonDownFcn);
    set(handles.figure1, 'WindowButtonMotionFcn', @windowButtonMotionFcn);
    set(handles.figure1, 'WindowButtonUpFcn', @windowButtonUpFcn);
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


function varargout = FlySongAnalysis_OutputFcn(~, ~, handles) 
    varargout{1} = handles.output;
end


function timeSlider_Listener(hObject, ~)
    handles = guidata(hObject);
    
    newTime = get(hObject, 'Value');
    
    timeRange = displayedTimeRange(handles);
    if handles.currentTime == handles.displayedTime || newTime < timeRange(1) || newTime > timeRange(2)
        % Shift the current time and the displayed time together.
        handles.displayedTime = newTime;
    else
        % Shift the current time slowly back towards the displayed time which will put the red line back at the center of the display.
        if abs(newTime - handles.displayedTime) > abs(handles.currentTime - handles.displayedTime)
            offset = (handles.currentTime - handles.displayedTime) * 0.9;
            if abs(offset) < (timeRange(2) - timeRange(1)) / 1000
                handles.displayedTime = newTime;
            else
                handles.displayedTime = newTime - offset;
            end
        end
    end
    handles.currentTime = newTime;
    
    guidata(hObject, handles);
    syncGUIWithTime(handles)
end


function setZoom(zoom, handles)
    if zoom < 1
        zoom = 1;
    end
    
    handles.displayedTime = handles.currentTime;
    handles.zoom = zoom;
    guidata(handles.figure1, handles);
    
    stepSize = 1 / zoom;
    set(handles.timeSlider, 'SliderStep', [stepSize / 50.0 stepSize]);
    
    if zoom > 1
        set(handles.zoomOutTool, 'Enable', 'on')
    else
        set(handles.zoomOutTool, 'Enable', 'off')
    end
    
    syncGUIWithTime(handles);
end


function zoomSlider_Listener(hObject, ~)
    handles = guidata(hObject);
    
    if isfield(handles, 'audio')
        % Calculate the duration of audio that should be displayed based on the zoom.
        totalDuration = length(handles.audio.data) / handles.audio.sampleRate;
        zoom = 1.0 - get(handles.zoomSlider, 'Value');
        timeRangeSize = 0.1 + (totalDuration - 0.1) * zoom * zoom;
        guidata(handles.figure1, handles);
        
        % Update the step and page sizes of the time slider.
        stepSize = timeRangeSize / totalDuration;
        set(handles.timeSlider, 'SliderStep', [stepSize / 50.0 stepSize]);

        % TODO: set(handles.timeSlider, 'Value') so that it stays in bounds
    end
    
    syncGUIWithTime(handles);
end


function zoomInCallback(~, ~, handles)
    setZoom(handles.zoom * 2, handles);
end


function zoomOutCallback(~, ~, handles)
    setZoom(handles.zoom / 2, handles);
end


function showFeaturesCallback(~, ~, handles)
    state = get(handles.showFeaturesTool, 'State');
    handles.showFeatures = strcmp(state, 'on');
    if handles.showFeatures
        set([handles.features, handles.featuresSlider], 'Visible', 'on');
    else
        set([handles.features, handles.featuresSlider], 'Visible', 'off');
    end
    audioGroup_ResizeFcn(0, 0, handles);
    guidata(handles.figure1, handles);
    syncGUIWithTime(handles);
end


function showSpectrogramCallback(~, ~, handles)
    state = get(handles.showSpectrogramTool, 'State');
    handles.showSpectrogram = strcmp(state, 'on');
    if handles.showSpectrogram
        set(handles.spectrogram, 'Visible', 'on');
    else
        set(handles.spectrogram, 'Visible', 'off');
    end
    audioGroup_ResizeFcn(0, 0, handles);
    guidata(handles.figure1, handles);
    syncGUIWithTime(handles);
end


function playMediaCallback(hObject, ~, handles) %#ok<*DEFNU>
    set(handles.playTool, 'Enable', 'off');
    set(handles.pauseTool, 'Enable', 'on');
    
    handles.tocs = [];
    guidata(hObject, handles);
    
    if handles.selectedTime(1) ~= handles.selectedTime(2)
        % Only play with the selected range.
        if handles.currentTime >= handles.selectedTime(1) && handles.currentTime < handles.selectedTime(2) - 0.1
            playRange = [handles.currentTime handles.selectedTime(2)];
        else
            playRange = [handles.selectedTime(1) handles.selectedTime(2)];
        end
    else
        % Play the whole song, starting at the current time unless it's at the end.
        if handles.currentTime < handles.audio.duration
            playRange = [handles.currentTime handles.audio.duration];
        else
            playRange = [0.0 handles.audio.duration];
        end
    end
    playRange = round(playRange * handles.audio.sampleRate);
    if playRange(1) == 0
        playRange(1) = 1;
    end
    play(handles.audioPlayer, playRange);
    start(handles.playTimer);
end


function pauseMediaCallback(hObject, ~, handles)
    set(handles.playTool, 'Enable', 'on');
    set(handles.pauseTool, 'Enable', 'off');
    
    stop(handles.audioPlayer);
    stop(handles.playTimer);
    
    if isempty(hObject)
        % The audio played to the end without the user clicking the pause button.
        if handles.selectedTime(1) ~= handles.selectedTime(2)
            handles.currentTime = handles.selectedTime(2);
        else
            handles.currentTime = handles.audio.duration;
        end
        handles.displayedTime = handles.currentTime;
    end
    
    syncGUIWithTime(handles);
end


function syncGUIToAudio(timerObj, ~)
    hObject = get(timerObj, 'UserData');
    handles = guidata(hObject);
    
    if isplaying(handles.audioPlayer)
        curSample = get(handles.audioPlayer, 'CurrentSample');
        if curSample > 1
            handles.currentTime = curSample / handles.audio.sampleRate;
            handles.displayedTime = handles.currentTime;

            tic;
            syncGUIWithTime(handles);
            handles.tocs = [handles.tocs toc];

            guidata(hObject, handles);
            
%            disp(num2str(mean(handles.tocs), '%g seconds to render media'));
        end
    else
        pauseMediaCallback([], [], handles);
    end
end


function range = displayedTimeRange(handles)
    timeRangeSize = handles.maxMediaTime / handles.zoom;
    range = [handles.displayedTime - timeRangeSize / 2 handles.displayedTime + timeRangeSize / 2];
    if range(2) - range(1) > handles.maxMediaTime
        range = [0.0 handles.maxMediaTime];
    elseif range(1) < 0.0
        range = [0.0 timeRangeSize];
    elseif range(2) > handles.maxMediaTime
        range = [handles.maxMediaTime - timeRangeSize handles.maxMediaTime];
    end
end


function timeFormatChangedCallback(~, ~, handles)
    handles.timeLabelFormat = mod(handles.timeLabelFormat + 1, 2);
    guidata(handles.figure1, handles);
    syncGUIWithTime(handles);
end


function syncGUIWithTime(handles)
    % This is the main GUI update function.

    % Calculate the range of time currently being displayed.
    timeRange = displayedTimeRange(handles);

    % Calculate the sample range being displayed.
    if isfield(handles, 'audio')
        minSample = ceil(timeRange(1) * handles.audio.sampleRate);
        maxSample = ceil(timeRange(2) * handles.audio.sampleRate);
        if minSample < 1
            minSample = 1;
        end
        if maxSample > length(handles.audio.data)
            maxSample = length(handles.audio.data);
        end
        
        audioWindow = handles.audio.data(minSample:maxSample);
        sampleRate = handles.audio.sampleRate;
    else
        minSample = 0;
        audioWindow = [];
        sampleRate = 0;
    end
    
    handles = updateVideo(handles);
    handles = updateOscillogram(handles, timeRange, audioWindow, minSample, sampleRate);
    handles = updateFeatures(handles, timeRange, audioWindow, minSample, sampleRate);
    handles = updateSpectrogram(handles, timeRange, audioWindow, minSample, sampleRate);
    
    set(handles.timeSlider, 'Value', handles.currentTime);
    
    % Display the current time and selection in the toolbar text field.
    if handles.selectedTime(1) == handles.selectedTime(2)
        timeString = secondstr(handles.currentTime, handles.timeLabelFormat);
        timeToolTip = '';
    else
        timeString = [secondstr(handles.currentTime, handles.timeLabelFormat) ' [' secondstr(handles.selectedTime(1), handles.timeLabelFormat) '-' secondstr(handles.selectedTime(2), handles.timeLabelFormat) ']'];
        timeToolTip = [num2str(handles.selectedTime(2) - handles.selectedTime(1)) ' seconds'];
    end
    handles.timeLabel.setText(timeString);
    handles.timeLabel.setToolTipText(timeToolTip);
    
    guidata(handles.figure1, handles);
end


function newHandles = updateVideo(handles)
    if isfield(handles, 'video')
        % Display the current frame of video.
        frameNum = min([floor(handles.currentTime * handles.video.sampleRate + 1) handles.video.videoReader.NumberOfFrames]);
        if isfield(handles, 'videoBuffer')
            if frameNum >= handles.videoBufferStartFrame && frameNum < handles.videoBufferStartFrame + handles.videoBufferSize
                % TODO: is it worth optimizing the overlap case?
                %['Grabbing ' num2str(handles.videoBufferSize) ' more frames']
                handles.videoBuffer = read(handles.video.videoReader, [frameNum frameNum + handles.videoBufferSize - 1]);
                handles.videoBufferStartFrame = frameNum;
                guidata(get(handles.videoFrame, 'Parent'), handles);    % TODO: necessary with newFeatures?
            end
            frame = handles.videoBuffer(:, :, :, frameNum - handles.videoBufferStartFrame + 1);
        else
            frame = read(handles.video.videoReader, frameNum);
            
            % Window button callbacks can occur during the read call.
            % The callbacks can update the handles so grab a fresh copy.
            handles = guidata(handles.figure1);
        end
        set(handles.videoImage, 'CData', frame);
        set(handles.videoFrame, 'XTick', [], 'YTick', []);
    end
    
    newHandles = handles;
end


function newHandles = updateOscillogram(handles, timeRange, audioWindow, minSample, sampleRate)
    if isfield(handles, 'audio')
        currentSample = floor(handles.currentTime * sampleRate);
    
        timeRangeSize = timeRange(2) - timeRange(1);
        
        windowSampleCount = length(audioWindow);
        
        % Update the waveform.
        if get(handles.autoGainCheckBox, 'Value') == 1.0
            maxAmp = max(abs(audioWindow));
        else
            maxAmp = handles.audioMax / get(handles.gainSlider, 'Value');
        end
        
        if isfield(handles, 'playTimer2')
            tic;
        end
        if isfield(handles, 'oscillogramPlot')
            % Update the existing oscillogram pieces for faster rendering.
            if windowSampleCount ~= timeRangeSize
                % the number of samples changed
                set(handles.oscillogramPlot, 'XData', 1:windowSampleCount, 'YData', audioWindow);
                handles.oscillogramSampleCount = windowSampleCount;
                set(handles.oscillogram, 'XLim', [1 windowSampleCount]);
            elseif minSample ~= timeRange(1)
                % the number of samples is the same but the time point is different
                set(handles.oscillogramPlot, 'YData', audioWindow);
            end
            set(handles.oscillogramTimeLine, 'XData', [currentSample - minSample + 1 currentSample - minSample + 1]);
            if handles.selectedTime(1) ~= handles.selectedTime(2)
                selectionStart = floor(min(handles.selectedTime) * sampleRate);
                selectionEnd = floor(max(handles.selectedTime) * sampleRate);
                set(handles.oscillogramSelection, 'Position', [selectionStart - minSample + 1 -maxAmp selectionEnd - selectionStart maxAmp * 2]);
            end
        else
            % Do a one-time creation of the oscillogram pieces.
            set(handles.figure1, 'CurrentAxes', handles.oscillogram);
            
            handles.oscillogramPlot = plot(audioWindow);
            handles.oscillogramSampleCount = windowSampleCount;
            set(handles.oscillogram, 'XTick', [], 'YTick', []);
            set(handles.oscillogram, 'XLimMode', 'manual');
            set(handles.oscillogram, 'XLim', [1 windowSampleCount]);
            set(handles.oscillogram, 'YLimMode', 'manual');
            set(handles.oscillogram, 'TickLength', [0.01 0.01]);
            
            % Create the current time indicator.
            handles.oscillogramTimeLine = line([currentSample - minSample + 1 currentSample - minSample + 1], [-maxAmp maxAmp], 'Color', [1 0 0]);
            
            % Create the current selection indicator.
            handles.oscillogramSelection = rectangle('Position', [currentSample - minSample + 1 -maxAmp 1 maxAmp * 2], 'EdgeColor', 'none', 'FaceColor', [1 0.9 0.9], 'Visible', 'off');
            uistack(handles.oscillogramSelection, 'bottom');
            
            % Add a button down function to handle clicks on the oscillogram and make sure it always gets called.
            %set(handles.oscillogram, 'ButtonDownFcn', @oscillogram_ButtonDownFcn);
            set(handles.oscillogramPlot, 'HitTest', 'off');
            set(handles.oscillogramTimeLine, 'HitTest', 'off');
            set(handles.oscillogramSelection, 'HitTest', 'off');
            
            handles.timeScaleText = text(10, 0, '', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom');
            
        end
        if isfield(handles, 'playTimer2')
            handles.tocs = [handles.tocs toc];
            disp(mean(handles.tocs));
        end
        
        if handles.showCurrentSelection
            set(handles.oscillogramTimeLine, 'Visible', 'on');
            if handles.selectedTime(1) ~= handles.selectedTime(2)
                set(handles.oscillogramSelection, 'Visible', 'on');
            else
                set(handles.oscillogramSelection, 'Visible', 'off');
            end
        else
            set([handles.oscillogramTimeLine, handles.oscillogramSelection], 'Visible', 'off');
        end
        
        % Update the time ticks and scale label.
        timeScale = fix(log10(timeRangeSize));
        if timeRangeSize < 1
            timeScale = timeScale - 1;
        end
        tickSpacing = 10 ^ timeScale * sampleRate;
        set(handles.oscillogram, 'XTick', tickSpacing-mod(minSample, tickSpacing):tickSpacing:windowSampleCount);
        if timeScale == 0
            string = '1 sec';
        elseif timeScale == 1
            string = '10 sec';
        else
            string = ['10^{' num2str(timeScale) '} sec'];
        end
        set(handles.timeScaleText, 'Position', [windowSampleCount -maxAmp], 'String', string);
        
        curYLim = get(handles.oscillogram, 'YLim');
        if curYLim(1) ~= -maxAmp || curYLim(2) ~= maxAmp
            set(handles.oscillogram, 'YLim', [-maxAmp maxAmp]);
        end
    end
    
    newHandles = handles;
end


function newHandles = updateFeatures(handles, timeRange, ~, ~, ~)
    % Window button callbacks can occur during the axes call.
    % The callbacks can update the handles so store the current copy.
    guidata(handles.figure1, handles)
    
    % TODO: does all of this really need to be done everytime the current time changes?  could update after each detection and then just change xlim...
    % TODO: draw current time and selection indicators on the features as well?
    axes(handles.features);
    
    % Now grab a fresh copy in case the callbacks were triggered.
    handles = guidata(handles.figure1);
    
    cla
    if handles.showFeatures && isfield(handles, 'audio')
        labels = {};
        vertPos = 0;
        timeRangeRects = {};
        if ~isempty(handles.reporters)
            for i = 1:numel(handles.reporters)
                reporter = handles.reporters{i};
                
                featureTypes = reporter.featureTypes;
                
                % Indicate the time spans in which feature detection has occurred for each reporter.
                lastTime = 0.0;
                if isempty(featureTypes)
                    height = 0.5;
                else
                    height = length(featureTypes);
                end
                if isa(reporter, 'FeatureDetector')
                    for j = 1:size(reporter.detectedTimeRanges, 1)
                        detectedTimeRange = reporter.detectedTimeRanges(j, :);

                        if detectedTimeRange(1) > lastTime
                            % Add a gray background before the current range.
                            timeRangeRects{end + 1} = rectangle('Position', [lastTime vertPos + 0.5 detectedTimeRange(1) - lastTime height + 0.5], 'FaceColor', [0.9 0.9 0.9], 'EdgeColor', 'none', 'UIContextMenu', reporter.contextualMenu); %#ok<AGROW>
                        end

                        % Add a white background for this range.
                        timeRangeRects{end + 1} = rectangle('Position', [detectedTimeRange(1) vertPos + 0.5 detectedTimeRange(2) - detectedTimeRange(1) height + 0.5], 'FaceColor', 'white', 'EdgeColor', 'none', 'UIContextMenu', reporter.contextualMenu); %#ok<AGROW>

                        lastTime = detectedTimeRange(2);
                    end
                    if lastTime < handles.maxMediaTime
                        timeRangeRects{end + 1} = rectangle('Position', [lastTime vertPos + 0.5 handles.maxMediaTime - lastTime height + 0.5], 'FaceColor', [0.9 0.9 0.9], 'EdgeColor', 'none', 'UIContextMenu', reporter.contextualMenu); %#ok<AGROW>
                    end
                elseif isa(reporter, 'FeatureImporter')
                    % Importers cover all time spans.
                    timeRangeRects{end + 1} = rectangle('Position', [timeRange(1) vertPos + 0.5 timeRange(2) height + 0.5], 'FaceColor', 'white', 'EdgeColor', 'none', 'UIContextMenu', reporter.contextualMenu); %#ok<AGROW>
                end
                
                % Draw the feature type names.
                for y = 1:length(featureTypes)
                    featureType = featureTypes{y};
                    text(timeRange(1), vertPos + y + 0.25, featureType, 'VerticalAlignment', 'bottom');
                end
                
                % Draw the features that have been reported.
                features = reporter.features();
                if ~isempty(features)
                    labels = horzcat(labels, featureTypes); %#ok<AGROW>
                    for feature = features
                        if feature.sampleRange(1) <= timeRange(2) && feature.sampleRange(2) >= timeRange(1)
                            y = vertPos + find(strcmp(featureTypes, feature.type));
                            if isempty(feature.contextualMenu)
                                if feature.sampleRange(1) == feature.sampleRange(2)
                                    label = [feature.type ' @ ' secondstr(feature.sampleRange(1), handles.timeLabelFormat)];
                                else
                                    label = [feature.type ' @ ' secondstr(feature.sampleRange(1), handles.timeLabelFormat) ' - ' secondstr(feature.sampleRange(2), handles.timeLabelFormat)];
                                end
                                feature.contextualMenu = uicontextmenu();
                                uimenu(feature.contextualMenu, 'Tag', 'reporterNameMenuItem', 'Label', label, 'Enable', 'off');
                                uimenu(feature.contextualMenu, 'Tag', 'showFeaturePropertiesMenuItem', 'Label', 'Show Feature Properties', 'Callback', {@showFeatureProperties, feature}, 'Separator', 'on');
                                uimenu(feature.contextualMenu, 'Tag', 'removeFeatureMenuItem', 'Label', 'Remove Feature...', 'Callback', {@removeFeature, feature, reporter}, 'Separator', 'off');
                            end
                            if feature.sampleRange(1) == feature.sampleRange(2)
                                text(feature.sampleRange(1), y, 'x', 'HorizontalAlignment', 'center', 'UIContextMenu', feature.contextualMenu, 'Color', reporter.featuresColor);
                            else
                                rectangle('Position', [feature.sampleRange(1), y - 0.25, feature.sampleRange(2) - feature.sampleRange(1), 0.5], 'FaceColor', reporter.featuresColor, 'UIContextMenu', feature.contextualMenu);
                            end
                        end
                    end
                end
                vertPos = vertPos + length(featureTypes) + 0.5;
                
                % Add a horizontal line to separate the reporters from each other.
                line([timeRange(1) timeRange(2)], [vertPos + 0.5 vertPos + 0.5], 'Color', 'k');
            end
        else
            vertPos = 1;
        end
        axis(handles.features, [timeRange(1) timeRange(2) 0.5 vertPos + 0.5]);
        
        set(handles.features, 'YTick', 1:numel(labels));
        set(handles.features, 'YTickLabel', labels);
        
        if handles.showCurrentSelection
            % Add the current time indicator.
            line([handles.currentTime handles.currentTime], [0 vertPos + 0.5], 'Color', [1 0 0]);

            % Add the current selection indicator.
            if handles.selectedTime(1) ~= handles.selectedTime(2)
                selectionStart = min(handles.selectedTime);
                selectionEnd = max(handles.selectedTime);
                h = rectangle('Position', [selectionStart 0.5 selectionEnd - selectionStart vertPos], 'EdgeColor', 'none', 'FaceColor', [1 0.9 0.9]);
                uistack(h, 'bottom');
            end
        end
        
        % Make sure all of the time range rectangles are drawmn behind everything else.
        for i = 1:length(timeRangeRects)
            uistack(timeRangeRects{i}, 'bottom');
        end
    end
    
    newHandles = handles;
end
      

function showFeatureProperties(~, ~, feature)
    msg = ['Properties:' char(10) char(10)];
    props = sort(properties(feature));
    ignoreProps = {'type', 'sampleRange', 'contextualMenu'};
    for i = 1:length(props)
        if ~ismember(props{i}, ignoreProps)
            value = feature.(props{i});
            if isnumeric(value)
                value = num2str(value);
            end
            msg = [msg props{i} ' = ' value char(10)]; %#ok<AGROW>
        end
    end
    msgbox(msg, 'Feature Properties', 'modal');
end
      

function removeFeature(hObject, ~, feature, reporter) 
    answer = questdlg('Are you sure you wish to remove this feature?', 'Removing Feature', 'Cancel', 'Remove', 'Cancel');
    if strcmp(answer, 'Remove')
        reporter.removeFeature(feature);
        handles = guidata(hObject);
        handles = updateFeatureTimes(handles);
        timeRange = displayedTimeRange(handles);
        updateFeatures(handles, timeRange);
    end
end


function newHandles = updateSpectrogram(handles, ~, audioWindow, ~, sampleRate)
    set(handles.figure1, 'CurrentAxes', handles.spectrogram);
    cla;
    if handles.showSpectrogram && isfield(handles, 'audio')
        set(gca, 'Units', 'pixels');
        pos = get(gca, 'Position');
        pixelWidth = pos(3);
        pixelHeight = pos(4);
        % TODO: get freq range from prefs
        %freqMin = 0;
        %freqMax = 1000;
        freqRange = handles.spectrogramFreqMax - handles.spectrogramFreqMin;
        freqStep = ceil(freqRange / pixelHeight); % always at least 1
        
        % Base the window size on the number of pixels we want to render.
        window = ceil(length(audioWindow) / pixelWidth) * 2;
        if window < 100
            window = 100;
        end
        noverlap = ceil(window*.25);
        
        [~, ~, ~, P] = spectrogram(audioWindow, window, noverlap, ...
            handles.spectrogramFreqMin:freqStep:handles.spectrogramFreqMax, sampleRate);
        h = image(size(P, 2), size(P, 1), 10 * log10(P));
        set(h,'CDataMapping','scaled'); % (5)
        colormap('jet');
        axis xy;
        set(handles.spectrogram, 'XTick', [], 'YTick', []);
%             if freqRange < 100
%                 set(handles.spectrogram, 'YTick', 1:freqRange:
        
        % "axis xy" or something is doing weird things with the limits of the axes.
        % The lower-left corner is not (0, 0) but the size of P.
        text(size(P, 2) * 2, size(P, 1) * 2 - 1, [num2str(handles.spectrogramFreqMax) ' Hz'], ...
            'HorizontalAlignment', 'right', 'VerticalAlignment', 'top');
        text(size(P, 2) * 2, size(P, 1), [num2str(handles.spectrogramFreqMin) ' Hz'], ...
            'HorizontalAlignment', 'right', 'VerticalAlignment', 'baseline');
        
        % Add a text object to show the time and frequency of where the mouse is currently hovering.
        handles.spectrogramTooltip = text(size(P, 2), size(P, 1), '', 'BackgroundColor', 'w', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', 'Visible', 'off');
    end
    
    newHandles = handles;
end


%% Features contextual menus callbacks


function addContextualMenu(reporter)
    % Create the contextual menu for this detector.
    reporter.contextualMenu = uicontextmenu('Callback', {@enableReporterMenuItems, reporter});
    uimenu(reporter.contextualMenu, 'Tag', 'reporterNameMenuItem', 'Label', reporter.name, 'Enable', 'off');
    uimenu(reporter.contextualMenu, 'Tag', 'showReporterSettingsMenuItem', 'Label', 'Show Reporter Settings', 'Callback', {@showReporterSettings, reporter}, 'Separator', 'on');
    uimenu(reporter.contextualMenu, 'Tag', 'detectFeaturesInSelectionMenuItem', 'Label', 'Detect Features in Selection', 'Callback', {@detectFeaturesInSelection, reporter});
    uimenu(reporter.contextualMenu, 'Tag', 'saveDetectedFeaturesMenuItem', 'Label', 'Save Detected Features...', 'Callback', {@saveDetectedFeatures, reporter});
    uimenu(reporter.contextualMenu, 'Tag', 'setFeaturesColorMenuItem', 'Label', 'Set Features Color...', 'Callback', {@setFeaturesColor, reporter});
    uimenu(reporter.contextualMenu, 'Tag', 'removeReporterMenuItem', 'Label', 'Remove Reporter...', 'Callback', {@removeReporter, reporter}, 'Separator', 'on');
end


function enableReporterMenuItems(hObject, ~, reporter)
    handles = guidata(hObject);
    
    % Enable or disable 'Detect Features in Selection' item in contextual menu based on whether there is a selection.
    menuItem = findobj(reporter.contextualMenu, 'Tag', 'detectFeaturesInSelectionMenuItem');
    if handles.selectedTime(2) == handles.selectedTime(1)
        set(menuItem, 'Enable', 'off');
    else
        set(menuItem, 'Enable', 'on');
    end
end


function showReporterSettings(~, ~, reporter)
    reporter.showSettings();
end


function detectFeaturesInSelection(hObject, ~, detector)
    handles = guidata(hObject);
    
    detector.startProgress();
    try
        n = detector.detectFeatures(handles.selectedTime);
        detector.endProgress();
        
        if n == 0
            waitfor(msgbox('No additional features were detected.', detector.typeName(), 'warn', 'modal'));
        end
        
        handles = updateFeatureTimes(handles);
        
        syncGUIWithTime(handles);
    catch ME
        detector.endProgress();
        rethrow(ME);
    end
end


function setFeaturesColor(hObject, ~, reporter)
    handles = guidata(hObject);
    
    newColor = uisetcolor(reporter.featuresColor);
    if length(newColor) == 3
        reporter.featuresColor = newColor;
        syncGUIWithTime(handles);
    end
end


function removeReporter(hObject, ~, reporter)
    answer = questdlg('Are you sure you wish to remove this reporter?', 'Removing Reporter', 'Cancel', 'Remove', 'Cancel');
    if strcmp(answer, 'Remove')
        handles = guidata(hObject);

        for i = 1:length(handles.reporters)
            if handles.reporters{i} == reporter
                handles.reporters(i) = [];
                break;
            end
        end
        
        handles = updateFeatureTimes(handles);

        guidata(handles.figure1, handles);

        syncGUIWithTime(handles);
    end
end


function saveFeaturesCallback(~, ~, handles)
    % Save the features from all of the detectors.
    saveDetectedFeatures([], [], handles.reporters, handles.audio.name);
end


function saveDetectedFeatures(~, ~, detectors, fileName)
    if nargin < 4
        fileName = 'Fly song';
    end
    
    [fileName, pathName, filterIndex] = uiputfile({'*.mat', 'MATLAB file';'*.txt', 'Text file'}, 'Save features as', [fileName ' features.mat']);
    
    if ~iscell(detectors)
        detectors = {detectors};
    end
    
    if ischar(fileName)
        features = {};
        for i = 1:length(detectors)
            features = horzcat(features, detectors{i}.features()); %#ok<AGROW>
        end
        
        if filterIndex == 1
            % Save as a MATLAB file
            featureTypes = {features.type}; %#ok<NASGU>
            startTimes = arrayfun(@(a) a.sampleRange(1), features); %#ok<NASGU>
            stopTimes = arrayfun(@(a) a.sampleRange(2), features); %#ok<NASGU>
            
            % TODO: also save audio recording path, reporter properties, ???
            save(fullfile(pathName, fileName), 'features', 'featureTypes', 'startTimes', 'stopTimes');
        else
            % Save as an Excel tsv file
            fid = fopen(fullfile(pathName, fileName), 'w');
            
            propNames = {};
            ignoreProps = {'type', 'sampleRange', 'contextualMenu'};
            
            % Find all of the feature properties so we know how many columns there will be.
            for f = 1:length(features)
                feature = features(f);
                props = properties(feature);
                for p = 1:length(props)
                    if ~ismember(props{p}, ignoreProps)
                        propName = [feature.type ':' props{p}];
                        if ~ismember(propName, propNames)
                            propNames{end + 1} = propName; %#ok<AGROW>
                        end
                    end
                end
            end
            propNames = sort(propNames);
            
            % Save a header row.
            fprintf(fid, 'Type\tStart Time\tEnd Time');
            for p = 1:length(propNames)
                fprintf(fid, '\t%s', propNames{p});
            end
            fprintf(fid, '\n');
            
            for i = 1:length(features)
                feature = features(i);
                fprintf(fid, '%s\t%f\t%f', feature.type, feature.sampleRange(1), feature.sampleRange(2));
                
                propValues = cell(1, length(propNames));
                props = sort(properties(feature));
                for j = 1:length(props)
                    if ~ismember(props{j}, ignoreProps)
                        propName = [feature.type ':' props{j}];
                        index = strcmp(propNames, propName);
                        value = feature.(props{j});
                        if isnumeric(value)
                            value = num2str(value);
                        end
                        propValues{index} = value;
                    end
                end
                for p = 1:length(propNames)
                    fprintf(fid, '\t%s', propValues{p});
                end
                fprintf(fid, '\n');
            end

            fclose(fid);
        end
    end
end


%% Media handling


function openRecordingCallback(~, ~, handles)
    [fileNames, pathName] = uigetfile2('Select an audio or video file to analyze');
    
    if ischar(fileNames)
        fileNames = {fileNames};
    end
    
    if iscell(fileNames)
        audioChanged = false;
        
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
            try
                possibleImporters = [];
                audioPaths = {};
                channels = {};
                for j = 1:length(handles.importerClassNames)
                    [canImport, audioPath, channel] = eval([handles.importerClassNames{j} '.canImportFromPath(''' strrep(fullPath, '''', '''''') ''')']);
                    if canImport
                        possibleImporters(end+1) = j; %#ok<AGROW>
                        audioPaths{end + 1} = audioPath; %#ok<AGROW>
                        channels{end + 1} = channel; %#ok<AGROW>
                    end
                end
                
                % If there is no audio file open then only importers that indicate which audio file to open can be used.
                if ~isempty(possibleImporters) && ~isfield(handles, 'audio')
                    inds = ~isempty(audioPaths{:});
                    possibleImporters = possibleImporters(inds);
                    audioPaths = audioPaths(inds);
                    channels = channels(inds);
                    
                    if isempty(possibleImporters)
                        warndlg('You must open an audio file before you can import these features.', 'Fly Song Analysis', 'modal');
                        return
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
                        if ~isfield(handles, 'audio') && ~isempty(audioPaths{index})
                            % Load the audio file indicated by the importer.
                            rec = Recording(audioPaths{index}, channels{index});
                            if rec.isAudio
                                setAudioRecording(rec);
                                audioChanged = true;
                                handles = guidata(handles.figure1);
                            end
                        end
                        
                        constructor = str2func(handles.importerClassNames{index});
                        importer = constructor(handles.audio, fullPath);
                        importer.startProgress();
                        try
                            n = importer.importFeatures();
                            importer.endProgress();
                            
                            if n == 0
                                waitfor(msgbox('No features were imported.', handles.importerTypeNames{index}, 'warn', 'modal'));
                            else
                                handles.reporters{numel(handles.reporters) + 1, 1} = importer;  %TODO: just use handles.audio.reporters() instead?
                                handles.audio.addReporter(importer);
                                handles = updateFeatureTimes(handles);
                                guidata(handles.figure1, handles);
                            end
                        catch ME
                            waitfor(msgbox('An error occurred while importing features.  (See the command window for details.)', handles.importerTypeNames{index}, 'error', 'modal'));
                            importer.endProgress();
                            rethrow(ME);
                        end
                        
                        addContextualMenu(importer);
                    end
                end
            catch ME
                rethrow(ME);
            end
            
            % Next check if it's an audio or video file.
            try
                rec = Recording(fullPath);
                if isempty(rec)
                    % The user cancelled.
                elseif rec.isAudio
                    % TODO: allow the recording to change?  Yes...
                    if isfield(handles, 'handles.audio')
                        error('You have already chosen the audio file.')
                    end
                    setAudioRecording(rec);
                    audioChanged = true;
                elseif rec.isVideo
                    setVideoRecording(rec);
                    handles = guidata(handles.figure1);
                    
                    % Make sure the video pane is showing.
                    try
                        if ~handles.mainSplitter.JavaComponent.getComponent(0).isVisible
                            handles.mainSplitter.JavaComponent.getComponent(1).doClick();
                        end
                    catch ME
                        warning('FlySong:ShowVideoPaneFailed', 'Could not show the video pane. (%s)', ME.message);
                    end
                end
            catch ME
                warndlg(['Error opening media file:\n\n' ME.message]);
                rethrow(ME);
            end
        end
        
        if audioChanged
            handles = guidata(handles.figure1);
            
            set(handles.figure1, 'Name', ['Fly Song Analysis: ' handles.audio.name]);
            
            % Inform all detectors that the audio recording changed.
            for i = 1:length(handles.reporters)
                handles.reporters{i}.setRecording(handles.audio);
            end
            
            % Reset the display.
            handles.currentTime = 0.0;
            handles.displayedTime = 0.0;
            handles.selectedTime = [0.0 0.0];
            handles.selectingTimeRange = false;
            if isfield(handles, 'video')
                handles.maxMediaTime = max([handles.audio.duration handles.video.duration]);
            else
                handles.maxMediaTime = handles.audio.duration;
            end
            handles.zoom = max(1.0,handles.maxMediaTime/60);
            handles.spectrogramFreqMin=0;
            handles.spectrogramFreqMax=floor(rec.sampleRate/2);
            guidata(handles.figure1, handles);
        end
        
        syncGUIWithTime(handles);
    end
end


function setVideoRecording(rec)
    handles = guidata(gcbo);
    
    handles.video = rec;
    
    axes(handles.videoFrame);
    set(handles.videoFrame, 'XTick', [], 'YTick', []);
    handles.videoImage = image(zeros(handles.video.videoReader.Width, handles.video.videoReader.Height));
    
    handles.maxMediaTime = max([handles.maxMediaTime handles.video.duration]);
    
    guidata(gcbo, handles);
    
    set(handles.timeSlider, 'Max', handles.maxMediaTime);
end


function setAudioRecording(rec)
    handles = guidata(gcbo);
    
    handles.audio = rec;
    handles.audioPlayer = audioplayer(handles.audio.data, handles.audio.sampleRate);
    handles.audioPlayer.TimerPeriod = 1.0 / 15.0;
    handles.audioMax = max(abs(handles.audio.data));
    
    handles.maxMediaTime = max([handles.maxMediaTime handles.audio.duration]);
    
    handles.playTimer = timer('ExecutionMode', 'fixedRate', 'TimerFcn', @syncGUIToAudio, 'Period', round(1.0 / 30.0 * 1000) / 1000, 'UserData', handles.oscillogram, 'StartDelay', 0.1);
    
    guidata(gcbo, handles);
    
    % TBD: do all this in opening function?
    axes(handles.oscillogram); %#ok<*MAXES>
    axis off
    
    axes(handles.features);
    axis tight;
    
    axes(handles.spectrogram);
    axis tight;
    view(0, 90);
    
    set(handles.timeSlider, 'Max', handles.maxMediaTime);
end


function autoGainCheckBox_Callback(hObject, ~, handles)
    if get(hObject, 'Value') == 0
        set(handles.gainSlider, 'Enable', 'on');
    else
        set(handles.gainSlider, 'Enable', 'off');
    end
    syncGUIWithTime(handles)
end


function gainSlider_Listener(hObject, ~)
    syncGUIWithTime(guidata(hObject))
end


% --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, ~, handles)
    if isfield(handles, 'playTimer')
        stop(handles.playTimer);
    end
    
    % Remember the window position.
    setpref('FlySongAnalysis', 'MainWindowPosition', get(hObject, 'Position'));
    
    delete(hObject);
end


function updatedHandles = updateFeatureTimes(handles)
    handles.featureTimes = [];
    for i = 1:numel(handles.reporters)
        features = handles.reporters{i}.features();
        for feature = features
            handles.featureTimes(end + 1) = (feature.sampleRange(1) + feature.sampleRange(2)) / 2;
        end
    end
    handles.featureTimes = sort(handles.featureTimes);
    updatedHandles = handles;
end


function detectFeaturesCallback(~, ~, handles)
    if ~isfield(handles, 'audio')
        warndlg('You must open an audio file before you can detect features.', 'Fly Song Analysis', 'modal');
    else
        [index, ok] = listdlg('PromptString', 'Select the detector type:', ...
                    'SelectionMode', 'single', ...
                    'ListSize', [200 120], ...
                    'ListString', handles.detectorTypeNames);
        
        if ok
            className = handles.detectorClassNames{index};
            constructor = str2func(className);
            detector = constructor(handles.audio);
            
            if detector.editSettings()
                addContextualMenu(detector);
                
                detector.startProgress();
                try
                    if handles.selectedTime(2) > handles.selectedTime(1)
                        n = detector.detectFeatures(handles.selectedTime);
                    else
                        n = detector.detectFeatures([0.0 handles.maxMediaTime]);
                    end
                    detector.endProgress();
                    
                    if n == 0
                        waitfor(msgbox('No features were detected.', handles.detectorTypeNames{index}, 'warn', 'modal'));
                    else
                        handles.reporters{numel(handles.reporters) + 1, 1} = detector;  %TODO: just use handles.audio.reporters() instead?
                        handles.audio.addReporter(detector);
                        guidata(handles.figure1, handles);
                    end
                    
                    handles = updateFeatureTimes(handles);
                    
                    syncGUIWithTime(handles);
                catch ME
                    waitfor(msgbox(['An error occurred while detecting features:' char(10) char(10) ME.message char(10) char(10) '(See the command window for details.)'], ...
                                   handles.detectorTypeNames{index}, 'error', 'modal'));
                    detector.endProgress();
                    rethrow(ME);
                end
            end
        end
    end
end


% --- Executes on mouse press over axes background.
function windowButtonDownFcn(hObject, ~)
    handles = guidata(hObject);
    
    clickedObject = get(handles.figure1, 'CurrentObject');
    
    if strcmp(get(gcf, 'SelectionType'), 'alt')
        contextualMenu = get(clickedObject, 'UIContextMenu');
        if ~isempty(contextualMenu)
            set(contextualMenu, 'Position', get(handles.figure1, 'CurrentPoint'), 'Visible', 'On');
            return
        end
    end
    
    if strcmp(get(clickedObject, 'Type'), 'axes')
        clickedAxes = clickedObject;
    else
        clickedAxes = get(clickedObject, 'Parent');
    end
    
    if isfield(handles, 'audio') && (clickedAxes == handles.oscillogram || clickedAxes == handles.features || clickedAxes == handles.spectrogram)
        timeRange = displayedTimeRange(handles);
        
        clickedPoint = get(handles.oscillogram, 'CurrentPoint');
        clickedSample = timeRange(1) * handles.audio.sampleRate - 1 + clickedPoint(1, 1);
        clickedTime = clickedSample / handles.audio.sampleRate;
        if strcmp(get(gcf, 'SelectionType'), 'extend')
            if handles.currentTime == handles.selectedTime(1) || handles.currentTime ~= handles.selectedTime(2)
                handles.selectedTime = sort([handles.selectedTime(1) clickedTime]);
            else
                handles.selectedTime = sort([clickedTime handles.selectedTime(2)]);
            end
        else
            handles.currentTime = clickedTime;
            handles.selectedTime = [clickedTime clickedTime];
            handles.selectingTimeRange = true;
        end
        guidata(hObject, handles);
        syncGUIWithTime(handles);
    end
end


function windowButtonMotionFcn(hObject, ~)
    handles = guidata(hObject);
    
    if handles.selectingTimeRange
        timeRange = displayedTimeRange(handles);
        clickedPoint = get(handles.oscillogram, 'CurrentPoint');
        clickedSample = timeRange(1) * handles.audio.sampleRate - 1 + clickedPoint(1, 1);
        clickedTime = clickedSample / handles.audio.sampleRate;
        if handles.currentTime == handles.selectedTime(1) || handles.currentTime ~= handles.selectedTime(2)
            handles.selectedTime = sort([handles.selectedTime(1) clickedTime]);
        else
            handles.selectedTime = sort([clickedTime handles.selectedTime(2)]);
        end
        guidata(hObject, handles);
        syncGUIWithTime(handles);
    elseif handles.showSpectrogram && isfield(handles, 'spectrogramTooltip')
        freqMin = 0;
        freqMax = 1000;
        
        currentPoint = get(handles.spectrogram, 'CurrentPoint');
        xLim = get(handles.spectrogram, 'XLim');
        yLim = get(handles.spectrogram, 'YLim');
        x = (currentPoint(1, 1) - xLim(1)) / (xLim(2) - xLim(1));
        y = (currentPoint(1, 2) - yLim(1)) / (yLim(2) - yLim(1));
        if x >=0 && x <= 1 && y >= 0 && y <= 1
            timeRange = displayedTimeRange(handles);
            currentTime = timeRange(1) + (timeRange(2) - timeRange(1)) * x;
            frequency = freqMin + (freqMax - freqMin) * y;
            tip = sprintf('Time: %0.2f\nFreq: %.1f', currentTime, frequency);
            set(handles.spectrogramTooltip, 'String', tip, 'Visible', 'on');
        else
            tip = '';
            set(handles.spectrogramTooltip, 'String', tip, 'Visible', 'off');
        end
    end
end


function windowButtonUpFcn(hObject, ~)
    handles = guidata(hObject);
    
    if handles.selectingTimeRange
        timeRange = displayedTimeRange(handles);
        clickedPoint = get(handles.oscillogram, 'CurrentPoint');
        clickedSample = timeRange(1) * handles.audio.sampleRate - 1 + clickedPoint(1, 1);
        clickedTime = clickedSample / handles.audio.sampleRate;
        if handles.currentTime == handles.selectedTime(1) || handles.currentTime ~= handles.selectedTime(2)
            handles.selectedTime = sort([handles.selectedTime(1) clickedTime]);
        else
            handles.selectedTime = sort([clickedTime handles.selectedTime(1)]);
        end
        handles.selectingTimeRange = false;
        guidata(hObject, handles);
        syncGUIWithTime(handles);
    end
end


% --- Executes when audioGroup is resized.
function audioGroup_ResizeFcn(~, ~, handles)
    set(handles.audioGroup, 'Units', 'pixels');
    pos = get(handles.audioGroup,'Position');
    w = ceil(pos(3));
    h = ceil(pos(4));
    set(handles.audioGroup, 'Units', 'normalized');
    
    ss = 16;    % width/height of narrow dimension of scroll bar
    
    showSpectrogram = isfield(handles, 'showSpectrogram') && handles.showSpectrogram;
    showFeatures = isfield(handles, 'showFeatures') && handles.showFeatures;
    
    if showSpectrogram && showFeatures
        h3 = uint16((h - ss) / 3) - 1;
        hr = h - ss - (h3 + 1) * 2 + 1;
        
        set(handles.oscillogram, 'Position',        [1      ss+h3*2+2   w-ss    hr]);
        set(handles.autoGainCheckBox, 'Position',   [w-ss-1 h-16+1      ss+1    ss]);
        set(handles.gainSlider, 'Position',         [w-ss+1 ss+h3*2+2   ss      hr-ss]);
        
        set(handles.features, 'Position',           [1      ss+h3+1     w-ss    h3]);
        set(handles.featuresSlider, 'Position',     [w-ss+1 ss+h3       ss      h3+2]);
        
        set(handles.spectrogram, 'Position',        [1      ss          w-ss    h3]);
        
        set(handles.timeSlider, 'Position',         [1      0           w-ss+1  ss]);
    elseif showFeatures
        h2 = uint16((h - ss) / 2) - 1;
        hr = h - ss - (h2 + 1) + 1;
        
        set(handles.oscillogram, 'Position',        [1      ss+h2+1     w-ss    hr]);
        set(handles.autoGainCheckBox, 'Position',   [w-ss-1 h-16+1      ss+1    ss]);
        set(handles.gainSlider, 'Position',         [w-ss+1 ss+h2+1     ss      hr-ss]);
        
        set(handles.features, 'Position',           [1      ss          w-ss    h2]);
        set(handles.featuresSlider, 'Position',     [w-ss+1 ss          ss      h2+1]);
        
        set(handles.timeSlider, 'Position',         [1      0           w-ss+1  ss]);
    elseif showSpectrogram
        h2 = uint16((h - ss) / 2) - 1;
        hr = h - ss - (h2 + 1) + 1;
        
        set(handles.oscillogram, 'Position',        [1      ss+h2+1     w-ss    hr]);
        set(handles.autoGainCheckBox, 'Position',   [w-ss-1 h-16+1      ss+1    ss]);
        set(handles.gainSlider, 'Position',         [w-ss+1 ss+h2+1     ss      hr-ss]);
        
        set(handles.spectrogram, 'Position',        [1      ss          w-ss    h2]);
        
        set(handles.timeSlider, 'Position',         [1      0           w-ss+1  ss]);
    else % just show the oscillogram
        h1 = uint16((h - ss) / 1) - 1;
        hr = h - ss - (h1 + 1) + 1; %#ok<NASGU>
        
        set(handles.oscillogram, 'Position',        [1      ss          w-ss    h-ss]);
        set(handles.autoGainCheckBox, 'Position',   [w-ss-1 h-16+1      ss+1    ss]);
        set(handles.gainSlider, 'Position',         [w-ss+1 ss          ss      h-ss-15]);
        
        set(handles.timeSlider, 'Position',         [1      0           w-ss+1  ss]);
    end
end


% --- Executes on slider movement.
function featuresSlider_Callback(~, ~, ~)
% hObject    handle to featuresSlider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider
end


function saveScreenShotCallback(~, ~, handles)
    % TODO: determine if Ghostscript is installed and reduce choices if not.
    [defaultPath, defaultName, ~] = fileparts(handles.audio.filePath);
    [fileName, pathName] = uiputfile({'*.pdf','Portable Document Format (*.pdf)'; ...
                                      '*.png','PNG format (*.png)'; ...
                                      '*.jpg','JPEG format (*.jpg)'}, ...
                                     'Select an audio or video file to analyze', ...
                                     fullfile(defaultPath, [defaultName '.pdf']));
    
    if ~isnumeric(fileName)
        % Determine the list of axes to export.
        axes = [handles.oscillogram];
        if handles.showFeatures
            axes(end+1) = handles.features;
        end
        if handles.showSpectrogram
            axes(end+1) = handles.spectrogram;
        end
        
        % Hide the selection for the exported figure.
        handles.showCurrentSelection = false;
        syncGUIWithTime(handles);
        
        export_fig(fullfile(pathName, fileName), '-painters', axes);
        
        % Show the curren selection again.
        handles.showCurrentSelection = true;
        syncGUIWithTime(handles);
    end
end


function figure1_WindowKeyPressFcn(~, keyEvent, handles)
    % Handle keyboard navigation of the timeline.
    % Arrow keys move the display left/right by one tenth of the displayed range.
    % Page up/down moves left/right by a full window's worth.
    % Command+arrow keys moves to the beginning/end of the timeline.
    % Option+left/right arrow key moves to the previous/next feature.
    % Shift plus any of the above extends the selection.
    % Space bar toggles play/pause of media.
    % Up/down arrow keys zoom out/in
    % Command+up arrow zooms all the way out
    if isfield(handles, 'audio')
        timeChange = 0;
        timeRange = displayedTimeRange(handles);
        pageSize = timeRange(2) - timeRange(1);
        stepSize = pageSize / 10;
        shiftDown = any(ismember(keyEvent.Modifier, 'shift'));
        altDown = any(ismember(keyEvent.Modifier, 'alt'));
        cmdDown = any(ismember(keyEvent.Modifier, 'command'));
        ctrlDown = any(ismember(keyEvent.Modifier, 'control'));
        if strcmp(keyEvent.Key, 'leftarrow')
            if cmdDown
                timeChange = -handles.currentTime;
            elseif altDown
                handles = updateFeatureTimes(handles);
                earlierFeatureTimes = handles.featureTimes(handles.featureTimes < handles.currentTime);
                if isempty(earlierFeatureTimes)
                    beep;
                else
                    timeChange = earlierFeatureTimes(end) - handles.currentTime;
                end
            else
                timeChange = -stepSize;
            end
        elseif strcmp(keyEvent.Key, 'rightarrow')
            if cmdDown
                timeChange = handles.maxMediaTime - handles.currentTime;
            elseif altDown
                handles = updateFeatureTimes(handles);
                laterFeatureTimes = handles.featureTimes(handles.featureTimes > handles.currentTime);
                if isempty(laterFeatureTimes)
                    beep;
                else
                    timeChange = laterFeatureTimes(1) - handles.currentTime;
                end
            else
                timeChange = stepSize;
            end
        elseif strcmp(keyEvent.Key, 'pageup')
            timeChange = -pageSize;
        elseif strcmp(keyEvent.Key, 'pagedown')
            timeChange = pageSize;
        elseif strcmp(keyEvent.Key, 'space')
            if isplaying(handles.audioPlayer)
                pauseMediaCallback(handles.figure1, [], handles);
            else
                playMediaCallback(handles.figure1, [], handles);
            end
        elseif strcmp(keyEvent.Key, 'uparrow')
            if cmdDown
                setZoom(1, handles);
            else
                setZoom(handles.zoom / 2, handles);
            end
        elseif strcmp(keyEvent.Key, 'downarrow')
            % TODO: is there a maximum zoom that could be set if command was down?
            setZoom(handles.zoom * 2, handles);
        elseif strcmp(keyEvent.Key, 'j')
            tmp=(handles.spectrogramFreqMax-handles.spectrogramFreqMin)/2;
            handles.spectrogramFreqMin=max(0,handles.spectrogramFreqMin-tmp);
            handles.spectrogramFreqMax=...
                min(floor(handles.audio.sampleRate/2),handles.spectrogramFreqMax+tmp);
        elseif strcmp(keyEvent.Key, 'l')
            tmp=(handles.spectrogramFreqMax-handles.spectrogramFreqMin)/4;
            handles.spectrogramFreqMin=handles.spectrogramFreqMin+tmp;
            handles.spectrogramFreqMax=handles.spectrogramFreqMax-tmp;
        elseif strcmp(keyEvent.Key, 'i')
            tmp=(handles.spectrogramFreqMax-handles.spectrogramFreqMin)/2;
            handles.spectrogramFreqMin=...
                min(floor(handles.audio.sampleRate/2)-1,handles.spectrogramFreqMin+tmp);
            handles.spectrogramFreqMax=...
                min(floor(handles.audio.sampleRate/2),handles.spectrogramFreqMax+tmp);
        elseif strcmp(keyEvent.Key, ',')
            tmp=(handles.spectrogramFreqMax-handles.spectrogramFreqMin)/2;
            handles.spectrogramFreqMin=...
                max(0,handles.spectrogramFreqMin-tmp);
            handles.spectrogramFreqMax=...
                max(1,handles.spectrogramFreqMax-tmp);
        elseif strcmp(keyEvent.Key, 'k')
            handles.spectrogramFreqMin=0;
            handles.spectrogramFreqMax=floor(handles.audio.sampleRate/2);
        end
        
        if timeChange ~= 0
            newTime = max([0 min([handles.maxMediaTime handles.currentTime + timeChange])]);
            if shiftDown
                if handles.currentTime == handles.selectedTime(1)
                    handles.selectedTime = sort([handles.selectedTime(2) newTime]);
                else
                    handles.selectedTime = sort([newTime handles.selectedTime(1)]);
                end
            else
                handles.selectedTime = [newTime newTime];
            end
            handles.currentTime = newTime;
            handles.displayedTime = handles.currentTime;
            guidata(handles.figure1, handles);
        end
        syncGUIWithTime(handles);
    end
end
