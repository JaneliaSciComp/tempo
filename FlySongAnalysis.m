function varargout = FlySongAnalysis(varargin)
    % FLYSONGANALYZER M-file for FlySongAnalysis.fig
    %      FLYSONGANALYSIS, by itself, creates a new ANALYZER or raises the existing
    %      singleton*.
    %
    %      H = FLYSONGANALYSIS returns the handle to a new ANALYZER or the handle to
    %      the existing singleton*.
    %
    %      FLYSONGANALYSIS('CALLBACK',hObject,eventData,handles,...) calls the local
    %      function named CALLBACK in ANALYZER.M with the given input arguments.
    %
    %      FLYSONGANALYSIS('Property','Value',...) creates a new ANALYZER or raises the
    %      existing singleton*.  Starting from the left, property value pairs are
    %      applied to the GUI before FlySongAnalysis_OpeningFcn gets called.  An
    %      unrecognized property name or invalid value makes property application
    %      stop.  All inputs are passed to FlySongAnalysis_OpeningFcn via varargin.
    %
    %      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
    %      instance to run (singleton)".
    %
    % See also: GUIDE, GUIDATA, GUIHANDLES

    % Edit the above text to modify the response to help FlySongAnalysis

    % Last Modified by GUIDE v2.5 11-Nov-2011 16:48:49
    
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
    
    %% Populate the list of detectors from the 'Detectors' folder.
    if isdeployed && exist(fullfile(ctfroot, 'Detectors'), 'dir')
        % Look for the detectors in the CTF archive.
        parentDir = ctfroot;
    else
        % Look for the detectors relative to this .m file.
        analysisPath = mfilename('fullpath');
        parentDir = fileparts(analysisPath);
    end
    detectorsDir = fullfile(parentDir, 'Detectors');
    detectorDirs = dir(detectorsDir);
    handles.detectorClassNames = cell(length(detectorDirs), 1);
    handles.detectorTypeNames = cell(length(detectorDirs), 1);
    detectorCount = 0;
    for i = 1:length(detectorDirs)
        if detectorDirs(i).isdir && detectorDirs(i).name(1) ~= '.'
            className = detectorDirs(i).name;
            try
                addpath(fullfile(detectorsDir, filesep, className));
                eval([className '.initialize()'])
                detectorCount = detectorCount + 1;
                handles.detectorClassNames{detectorCount} = className;
                handles.detectorTypeNames{detectorCount} = eval([className '.typeName()']);
            catch ME
                waitfor(warndlg(['Could not load detector ' detectorDirs(i).name ': ' ME.message]));
                rmpath(fullfile(detectorsDir, filesep, detectorDirs(i).name));
            end
        end
    end
    handles.detectorClassNames = handles.detectorClassNames(1:detectorCount);
    handles.detectorTypeNames = handles.detectorTypeNames(1:detectorCount);
    
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
    handles.detectors = {};
    handles.showFeatures = true;
    handles.showSpectrogram = false;
    
    guidata(hObject, handles);
    
    if verLessThan('matlab', '7.12.0')
        addlistener(handles.timeSlider, 'Action', @timeSlider_Listener);
        addlistener(handles.gainSlider, 'Action', @gainSlider_Listener);
    else
        addlistener(handles.timeSlider, 'ContinuousValueChange', @timeSlider_Listener);
        addlistener(handles.gainSlider, 'ContinuousValueChange', @gainSlider_Listener);
    end
    
    showSpectrogramCallback(0, 0, handles);
    
    set(handles.figure1, 'WindowButtonDownFcn', @windowButtonDownFcn);
    set(handles.figure1, 'WindowButtonMotionFcn', @windowButtonMotionFcn);
    set(handles.figure1, 'WindowButtonUpFcn', @windowButtonUpFcn);
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
        if handles.currentTime >= handles.selectedTime(1) && handles.currentTime < handles.selectedTime(2)
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
    else
        minSample = 0;
        audioWindow = [];
    end
    
    handles = updateVideo(handles);
    handles = updateOscillogram(handles, timeRange, audioWindow, minSample);
    handles = updateFeatures(handles, timeRange, audioWindow, minSample);
    handles = updateSpectrogram(handles, timeRange, audioWindow, minSample);
    
    set(handles.timeSlider, 'Value', handles.currentTime);
    
    guidata(handles.figure1, handles);
    
    drawnow
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


function newHandles = updateOscillogram(handles, timeRange, audioWindow, minSample)
    if isfield(handles, 'audio')
        currentSample = floor(handles.currentTime * handles.audio.sampleRate);
    
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
                selectionStart = floor(min(handles.selectedTime) * handles.audio.sampleRate);
                selectionEnd = floor(max(handles.selectedTime) * handles.audio.sampleRate);
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
        tickSpacing = 10 ^ timeScale * handles.audio.sampleRate;
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


function newHandles = updateFeatures(handles, timeRange, ~, ~)
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
        if ~isempty(handles.detectors)
            for i = 1:numel(handles.detectors)
                detector = handles.detectors{i};
                
                featureTypes = detector.featureTypes;
                
                % First gray out areas that haven't been detected.
                lastTime = 0.0;
                if isempty(featureTypes)
                    height = 0.5;
                else
                    height = length(featureTypes);
                end
                for j = 1:size(detector.detectedTimeRanges, 1)
                    detectedTimeRange = detector.detectedTimeRanges(j, :);
                    
                    if detectedTimeRange(1) > lastTime
                        % Add a gray background before the current range.
                        timeRangeRects{end + 1} = rectangle('Position', [lastTime vertPos + 0.5 detectedTimeRange(1) - lastTime height + 0.5], 'FaceColor', [0.9 0.9 0.9], 'EdgeColor', 'none', 'UIContextMenu', detector.contextualMenu); %#ok<AGROW>
                    end
                    
                    % Add a white background for this range.
                    timeRangeRects{end + 1} = rectangle('Position', [detectedTimeRange(1) vertPos + 0.5 detectedTimeRange(2) - detectedTimeRange(1) height + 0.5], 'FaceColor', 'white', 'EdgeColor', 'none', 'UIContextMenu', detector.contextualMenu); %#ok<AGROW>
                    
                    lastTime = detectedTimeRange(2);
                end
                if lastTime < handles.maxMediaTime
                    timeRangeRects{end + 1} = rectangle('Position', [lastTime vertPos + 0.5 handles.maxMediaTime - lastTime height + 0.5], 'FaceColor', [0.9 0.9 0.9], 'EdgeColor', 'none', 'UIContextMenu', detector.contextualMenu); %#ok<AGROW>
                end
                
                % Draw the feature type names.
                for y = 1:length(featureTypes)
                    featureType = featureTypes{y};
                    text(timeRange(1), vertPos + y + 0.25, featureType, 'VerticalAlignment', 'bottom');
                end
                
                % Draw the features that have been detected.
                features = detector.features();
                if ~isempty(features)
                    labels = horzcat(labels, featureTypes); %#ok<AGROW>
                    for feature = features
                        if feature.sampleRange(1) <= timeRange(2) && feature.sampleRange(2) >= timeRange(1)
                            y = vertPos + find(strcmp(featureTypes, feature.type));
                            if feature.sampleRange(1) == feature.sampleRange(2)
                                text(feature.sampleRange(1), y, 'x', 'HorizontalAlignment', 'center');
                            else
                                rectangle('Position', [feature.sampleRange(1), y - 0.25, feature.sampleRange(2) - feature.sampleRange(1), 0.5], 'FaceColor', 'b');
                            end
                        end
                    end
                end
                vertPos = vertPos + length(featureTypes) + 0.5;
                
                % Add a horizontal line to separate the detectors from each other.
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


function newHandles = updateSpectrogram(handles, ~, audioWindow, ~)
    set(handles.figure1, 'CurrentAxes', handles.spectrogram);
    cla;
    if handles.showSpectrogram && isfield(handles, 'audio')
        set(gca, 'Units', 'pixels');
        pos = get(gca, 'Position');
        pixelWidth = pos(3);
        pixelHeight = pos(4);
        % TODO: get freq range from prefs
        freqMin = 0;
        freqMax = 1000;
        freqRange = freqMax - freqMin;
        freqStep = ceil(freqRange / pixelHeight); % always at least 1
        
        % Base the window size on the number of pixels we want to render.
        window = ceil(length(audioWindow) / pixelWidth) * 2;
        if window < 100
            window = 100;
        end
        noverlap = ceil(window*.25);
        
        [~, ~, ~, P] = spectrogram(audioWindow, window, noverlap, freqMin:freqStep:freqMax, handles.audio.sampleRate);
        h = image(size(P, 2), size(P, 1), 10 * log10(P));
        set(h,'CDataMapping','scaled'); % (5)
        colormap('jet');
        axis xy;
        set(handles.spectrogram, 'XTick', [], 'YTick', []);
%             if freqRange < 100
%                 set(handles.spectrogram, 'YTick', 1:freqRange:
        
        % "axis xy" or something is doing weird things with the limits of the axes.
        % The lower-left corner is not (0, 0) but the size of P.
        text(size(P, 2) * 2, size(P, 1) * 2 - 1, [num2str(freqMax) ' Hz'], 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top');
        text(size(P, 2) * 2, size(P, 1), [num2str(freqMin) ' Hz'], 'HorizontalAlignment', 'right', 'VerticalAlignment', 'baseline');
        
        % Add a text object to show the time and frequency of where the mouse is currently hovering.
        handles.spectrogramTooltip = text(size(P, 2), size(P, 1), '', 'BackgroundColor', 'w', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', 'Visible', 'off');
    end
    
    newHandles = handles;
end


%% Features contextual menus callbacks

function enableDetectorMenuItems(hObject, ~, detector)
    handles = guidata(hObject);
    
    % Enable or disable 'Detect Features in Selection' item in contextual menu based on whether there is a selection.
    menuItem = findobj(detector.contextualMenu, 'Tag', 'detectFeaturesInSelectionMenuItem');
    if handles.selectedTime(2) == handles.selectedTime(1)
        set(menuItem, 'Enable', 'off');
    else
        set(menuItem, 'Enable', 'on');
    end
end


function showDetectorSettings(~, ~, detector)
    detector.showSettings();
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
        
        syncGUIWithTime(handles);
    catch ME
        detector.endProgress();
        rethrow(ME);
    end
end


function removeDetector(hObject, ~, detector)
    answer = questdlg('Are you sure you wish to remove this detector?', 'Removing Detector', 'Cancel', 'Remove', 'Cancel');
    if strcmp(answer, 'Remove')
        handles = guidata(hObject);

        for i = 1:length(handles.detectors)
            if handles.detectors{i} == detector
                handles.detectors(i) = [];
            end
        end

        guidata(handles.figure1, handles);

        syncGUIWithTime(handles);
    end
end


function saveDetectedFeatures(~, ~, detector)
    [fileName, pathName, filterIndex] = uiputfile({'*.mat', 'MATLAB file';'*.txt', 'Text file'} ,'Save features as');
    
    if ischar(fileName)
        features = detector.features();
        if filterIndex == 1
            % Save as a MATLAB file
            featureTypes = {features.type}; %#ok<NASGU>
            startTimes = arrayfun(@(a) a.sampleRange(1), features); %#ok<NASGU>
            stopTimes = arrayfun(@(a) a.sampleRange(2), features); %#ok<NASGU>
            save(fullfile(pathName, fileName), 'features', 'featureTypes', 'startTimes', 'stopTimes');
        else
            % Save as an Excel tsv file
            fid = fopen(fullfile(pathName, fileName), 'w');
            
            for i = 1:length(features)
                feature = features(i);
                fprintf(fid, '%s\t%f\t%f\n', feature.type, feature.sampleRange(1), feature.sampleRange(2));
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
                end
            catch ME
                warndlg(['Error opening media file:\n\n' getReport(ME)]);
            end
        end
        
        if audioChanged
            handles = guidata(handles.figure1);
            
            % Inform all detectors that the audio recording changed.
            for i = 1:length(handles.detectors)
                handles.detectors{i}.setRecording(handles.audio);
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
            handles.zoom = 1.0;
            guidata(handles.figure1, handles);
            syncGUIWithTime(handles);
        end
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
    delete(hObject);
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
                % Create the contextual menu for this detector.
                detector.contextualMenu = uicontextmenu('Callback', {@enableDetectorMenuItems, detector});
                uimenu(detector.contextualMenu, 'Tag', 'detectorNameMenuItem', 'Label', detector.name, 'Enable', 'off');
                uimenu(detector.contextualMenu, 'Tag', 'showDetectorSettingsMenuItem', 'Label', 'Show Detector Settings', 'Callback', {@showDetectorSettings, detector}, 'Separator', 'on');
                uimenu(detector.contextualMenu, 'Tag', 'detectFeaturesInSelectionMenuItem', 'Label', 'Detect Features in Selection', 'Callback', {@detectFeaturesInSelection, detector});
                uimenu(detector.contextualMenu, 'Tag', 'saveDetectedFeaturesMenuItem', 'Label', 'Save Detected Features...', 'Callback', {@saveDetectedFeatures, detector});
                uimenu(detector.contextualMenu, 'Tag', 'removeDetectorMenuItem', 'Label', 'Remove Detector...', 'Callback', {@removeDetector, detector}, 'Separator', 'on');
                
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
                        handles.detectors{numel(handles.detectors) + 1, 1} = detector;  %TODO: just use handles.audio.detectors() instead?
                        handles.audio.addDetector(detector);
                        guidata(handles.figure1, handles);
                    end
                    
                    syncGUIWithTime(handles);
                catch ME
                    waitfor(msgbox('An error occurred while detecting features.  (See the command window for details.)', handles.detectorTypeNames{index}, 'error', 'modal'));
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
            if clickedTime >= handles.selectedTime(1)
                handles.selectedTime = [handles.selectedTime(1) clickedTime];
            else
                handles.selectedTime = [clickedTime handles.selectedTime(2)];
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
        handles.selectedTime = [handles.selectedTime(1) clickedSample / handles.audio.sampleRate];
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
        handles.selectedTime = sort([handles.selectedTime(1) clickedSample / handles.audio.sampleRate]);
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
        hr = h - ss - (h1 + 1) + 1;
        
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
    [fileName, pathName] = uiputfile({'*.pdf','Portable Document Format (*.pdf)'; ...
                                      '*.png','PNG format (*.png)'; ...
                                      '*.jpg','JPEG format (*.jpg)'}, ...
                                     'Select an audio or video file to analyze');
    
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
