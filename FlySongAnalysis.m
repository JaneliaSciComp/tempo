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

    % Last Modified by GUIDE v2.5 28-Apr-2011 15:20:54
    
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
    
%     audioPos(1) = 5;
%     set(handles.audioGroup, 'Position', audioPos);
%     
%     set(handles.videoGroup, 'Units', 'normalized');
%     set(handles.audioGroup, 'Units', 'normalized');
    
    %% Add the "Add detector" tool to the toolbar
    handles.addDetectorTool = uisplittool('parent', handles.toolbar);
    icon = fullfile(matlabroot,'/toolbox/matlab/icons/greencircleicon.gif');
    [cdata,map] = imread(icon);
    map(map(:,1)+map(:,2)+map(:,3)==3) = NaN;
    cdataAdd = ind2rgb(cdata,map);
    set(handles.addDetectorTool, 'cdata',cdataAdd, 'tooltip','Add a feature detector', 'Separator','on');
    
    %% Populate the list of detectors from the 'Detectors' folder.
    analysisPath = mfilename('fullpath');
    parentDir = fileparts(analysisPath);
    detectorsDir = fullfile(parentDir, filesep, 'Detectors');
    detectorDirs = dir(detectorsDir);
    handles.detectorClassNames = cell(length(detectorDirs), 1);
    %handles.detectorTypeNames = cell(length(detectorDirs), 1);
    detectorCount = 0;
    for i = 1:length(detectorDirs)
        if detectorDirs(i).isdir && detectorDirs(i).name(1) ~= '.'
            detectorCount = detectorCount + 1;
            handles.detectorClassNames{detectorCount} = detectorDirs(i).name;
            addpath(fullfile(detectorsDir, filesep, detectorDirs(i).name));
            eval([detectorDirs(i).name '.initialize()'])
        end
    end
    handles.detectorClassNames = handles.detectorClassNames(1:detectorCount);
    %handles.detectorTypeNames = handles.detectorTypeNames(1:detectorCount);
    
    
    %% Set defaults
    handles.currentTime = 0.0;          % The time currently being "rendered" from the recordings indicated by a red line in the oscillogram.
    handles.displayedTime = 0.0;        % The time on which the displays are centered.
    handles.selectedTime = [0.0 0.0];   % The highlighted range indicated by a light red box in the oscillogram.
    handles.maxMediaTime = 0.0;
    handles.zoom = 1.0;
    handles.detectors = {};
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
    
    handles.zoom = zoom;
    guidata(handles.figure1, handles);

    % Update the step and page sizes of the time slider.
    % MATLAB has a weird way of setting the size of the scrollbar thumb.
    if zoom == 1
        % Closest we can get to a thumb that completely fills the slider.
        majorStep = inf;
        minorStep = 1;
    else
        % This formula was determined by manually measuring the scrollbar size with various majorStep settings.
        majorStep = 3 * (1 / zoom) ^ 1.585;
        minorStep = majorStep / 50;
    end
    set(handles.timeSlider, 'SliderStep', [minorStep majorStep]);
    
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


function showSpectrogramCallback(~, ~, handles)
    state = get(handles.showSpectrogramTool, 'State');
    handles.showSpectrogram = strcmp(state, 'on');
    if handles.showSpectrogram
        set(handles.spectrogram, 'Visible', 'on');
    else
        set(handles.spectrogram, 'Visible', 'off');
    end
    audioGroup_ResizeFcn(0, 0, handles);
    syncGUIWithTime(handles);
end


function playMediaCallback(hObject, ~, handles) %#ok<*DEFNU>
    set(handles.playTool, 'Enable', 'off');
    set(handles.pauseTool, 'Enable', 'on');
    
    handles.tocs = [];
    guidata(hObject, handles);
    
    play(handles.audioPlayer, handles.currentTime * handles.audio.sampleRate);
    start(handles.playTimer);
end


function pauseMediaCallback(~, ~, handles)
    set(handles.playTool, 'Enable', 'on');
    set(handles.pauseTool, 'Enable', 'off');
    
    stop(handles.playTimer);
    stop(handles.audioPlayer);
    
    syncGUIWithTime(handles);
end


function syncGUIToAudio(timerObj, ~)
    hObject = get(timerObj, 'UserData');
    handles = guidata(hObject);
    
    curSample = get(handles.audioPlayer, 'CurrentSample');
    
    handles.currentTime = curSample / handles.audio.sampleRate;
    
    tic;
    syncGUIWithTime(handles);
    handles.tocs = [handles.tocs toc];
    
    guidata(hObject, handles);
    
%    set(handles.playButton, 'ToolTipString', num2str(mean(handles.tocs), '%g seconds to render media'));
%    set(handles.stopButton, 'ToolTipString', num2str(mean(handles.tocs), '%g seconds to render media'));
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
    timeRangeSize = timeRange(2) - timeRange(1);
    
    if isfield(handles, 'videoObj')
        % Display the current frame of video.
        frameNum = min([floor(handles.currentTime * handles.video.sampleRate + 1) handles.video.videoReader.NumberOfFrames]);
        if isfield(handles, 'videoBuffer')
            if frameNum >= handles.videoBufferStartFrame && frameNum < handles.videoBufferStartFrame + handles.videoBufferSize
                % TODO: is it worth optimizing the overlap case?
                %['Grabbing ' num2str(handles.videoBufferSize) ' more frames']
                handles.videoBuffer = read(handles.video.videoReader, [frameNum frameNum + handles.videoBufferSize - 1]);
                handles.videoBufferStartFrame = frameNum;
                guidata(get(handles.videoFrame, 'Parent'), handles);
            end
            frame = handles.videoBuffer(:, :, :, frameNum - handles.videoBufferStartFrame + 1);
        else
            frame = read(handles.video.videoReader, frameNum);
        end
        set(handles.videoImage, 'CData', frame);
        set(handles.videoFrame, 'XTick', [], 'YTick', []);
    end
    
    if isfield(handles, 'audio')
        currentSample = floor(handles.currentTime * handles.audio.sampleRate);
        
        % Calculate the sample range being displayed in the oscillogram.
        minSample = ceil(timeRange(1) * handles.audio.sampleRate);
        maxSample = ceil(timeRange(2) * handles.audio.sampleRate);
        if minSample < 1
            minSample = 1;
        end
        if maxSample > length(handles.audio.data)
            maxSample = length(handles.audio.data);
        end
        audioWindow = handles.audio.data(minSample:maxSample);
        windowSampleCount = maxSample - minSample + 1;
        
        %% Update the waveform.
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
                set(handles.oscillogramSelection, 'Position', [selectionStart - minSample + 1 -maxAmp selectionEnd - selectionStart maxAmp * 2], 'Visible', 'on');
            else
                set(handles.oscillogramSelection, 'Visible', 'off');
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
        guidata(get(handles.oscillogram, 'Parent'), handles);
        
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
        
        %% Update the features
        % TODO: does this really need to be done everytime the current time changes?  could update after each detection and then just change xlim...
        % TODO: draw current time and selection indicators on the features as well?
        axes(handles.features);
        cla
        labels = {};
        vertPos = 0;
        if ~isempty(handles.detectors)
            for i = 1:numel(handles.detectors)
                features = handles.detectors{i}.features();
                if ~isempty(features)
                    featureTypes = handles.detectors{i}.featureTypes;
                    for y = 1:length(featureTypes)
                        featureType = featureTypes{y};
                        text(timeRange(1), vertPos + y + 0.25, featureType, 'VerticalAlignment', 'bottom');
                    end
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
    %                 features = features(features.sampleRange(0) >= minSample & features.sampleRange(1) <= maxSample);
    %                 line(features - 0, ones(1, numel(features)) * i, 'LineStyle', 'none', 'Marker', 'o');
                    %plotmatrix(features, ones(1, numel(features)) * i);

                    vertPos = vertPos + numel(featureTypes) + 0.5;
                else
                    % TODO: some visual indication that no features were found?
                    vertPos = vertPos + 1;
                end
                
                % Add a horizontal line to separate the detectors from each other.
                line([timeRange(1) timeRange(2)], [vertPos + 0.5 vertPos + 0.5], 'Color', 'k');
            end
            
            axis(handles.features, [timeRange(1) timeRange(2) 0.5 vertPos + 0.5]);
            
            set(handles.features, 'YTick', 1:numel(labels));
            set(handles.features, 'YTickLabel', labels);
        end
        
        % Add the current time indicator.
        line([handles.currentTime handles.currentTime], [0 vertPos + 1], 'Color', [1 0 0]);

        % Add the current selection indicator.
        if handles.selectedTime(1) ~= handles.selectedTime(2)
            selectionStart = min(handles.selectedTime);
            selectionEnd = max(handles.selectedTime);
            h = rectangle('Position', [selectionStart 0 selectionEnd - selectionStart vertPos + 1], 'EdgeColor', 'none', 'FaceColor', [1 0.9 0.9]);
            uistack(h, 'bottom');
        end
        
        %% Update the spectrogram
        set(handles.figure1, 'CurrentAxes', handles.spectrogram);
        cla;
        if handles.showSpectrogram
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
            window = ceil(windowSampleCount / pixelWidth) * 2;
            if window < 100
                window = 100;
            end
            noverlap = ceil(window*.25);

            [~, ~, ~, P] = spectrogram(audioWindow, window, noverlap, freqMin:freqStep:freqMax, handles.audio.sampleRate);
            h = image(size(P, 2), size(P, 1), 10 * log10(P));
            set(h,'CDataMapping','scaled'); % (5)
            colormap('jet');
            axis xy;
            set(handles.spectrogram, 'XTick', []);
%             if freqRange < 100
%                 set(handles.spectrogram, 'YTick', 1:freqRange:
            
            % "axis xy" or something is doing weird things with the limits of the axes.
            % The lower-left corner is not (0, 0) but the size of P.
            text(size(P, 2) * 2, size(P, 1) * 2 - 1, [num2str(freqMax) ' Hz'], 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top');
            text(size(P, 2) * 2, size(P, 1), [num2str(freqMin) ' Hz'], 'HorizontalAlignment', 'right', 'VerticalAlignment', 'baseline');
        end
    end
    
    set(handles.timeSlider, 'Value', handles.currentTime);
    
    drawnow
end


function openRecordingCallback(~, ~, handles)
    [fileName, pathName] = uigetfile2('Select an audio or video file to analyze');
    
    if fileName ~= 0
        fullPath = fullfile(pathName, fileName);
        try
            rec = Recording(fullPath);
            if rec.isAudio
                % TODO: allow the recording to change?  Yes...
                if isfield(handles, 'handles.audio')
                    error('You have already chosen the audio file.')
                end
                setAudioRecording(rec);
                
                %% Populate the list of detectors from the 'Detectors' folder.
                % TODO: It would be nice to do this at initialization but it crashes there...
                jAddDetector = get(handles.addDetectorTool, 'JavaContainer');
                jMenu = get(jAddDetector, 'MenuComponent');
                jMenu.removeAll;
                warning('off', 'MATLAB:hg:JavaSetHGProperty');
                for i = 1:numel(handles.detectorClassNames)
                    className = handles.detectorClassNames{i};
                    typeName = eval([className '.typeName()']);
                    jActionItem = jMenu.add(['Add ' typeName ' Detector']);
                    set(jActionItem, 'ActionPerformedCallback', {@addDetectorCallback, className, handles.features});
                end
                warning('on', 'MATLAB:hg:JavaSetHGProperty');
                jToolbar = get(get(handles.toolbar,'JavaContainer'),'ComponentPeer');
                jToolbar.revalidate;
            elseif rec.isVideo
                setVideoRecording(rec);
            end
            syncGUIWithTime(handles);
        catch ME
        end
    end
%    handles = guidata(hObject);
end

    
function setVideoRecording(rec)
    handles.video = rec;

    axes(handles.videoFrame);
    set(handles.videoFrame, 'XTick', [], 'YTick', []);
    handles.videoImage = image(zeros(handles.video.videoReader.Width, handles.video.videoReader.Height));

    handles.maxMediaTime = max([handles.maxMediaTime handles.video.duration]);

    guidata(hObject, handles);

    set(handles.timeSlider, 'Max', handles.maxMediaTime);

    syncGUIWithTime(handles)
end


function setAudioRecording(rec)
    handles = guidata(gcbo);
    
    handles.audio = rec;
    handles.audioPlayer = audioplayer(handles.audio.data, handles.audio.sampleRate);
    handles.audioPlayer.TimerPeriod = 1.0 / 15.0;
    handles.audioMax = max(abs(handles.audio.data));

    handles.maxMediaTime = max([handles.maxMediaTime handles.audio.duration]);

    handles.playTimer = timer('ExecutionMode', 'fixedRate', 'TimerFcn', @syncGUIToAudio, 'Period', 1.0 / 30.0, 'UserData', handles.oscillogram, 'StartDelay', 0.1);

    set(handles.timeSlider, 'Max', handles.maxMediaTime);
    
    % TBD: do all this in opening function?
    axes(handles.oscillogram); %#ok<*MAXES>
    axis off

    axes(handles.features);
    axis tight;

    axes(handles.spectrogram);
    axis tight;
    view(0, 90);

    guidata(gcbo, handles);

    set(handles.timeSlider, 'Max', handles.maxMediaTime);

    syncGUIWithTime(handles)
        
% TODO: allow recording to be changed?  UI suggests that...
%     if ~isempty(handles.detectors)
%         for detector = handles.detectors{:}
%             detector.detectFeatures(handles.audioData, handles.audioSampleRate, handles.detectors);
%         end
%     end
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


function addDetectorCallback(~, ~, className, hObject)
    handles = guidata(hObject);
    detector = eval([className '(handles.audio)']);

    if detector.editSettings()
        handles.detectors{numel(handles.detectors) + 1, 1} = detector;  %TODO: just use handles.audio.detectors() instead?
        handles.audio.addDetector(detector);
        guidata(hObject, handles);

        detector.startProgress();
        try
            if handles.selectedTime(2) > handles.selectedTime(1)
                detector.detectFeatures(handles.selectedTime);
            else
                detector.detectFeatures([0.0 handles.maxMediaTime]);
            end
            detector.endProgress();
        catch ME
            detector.endProgress();
            rethrow(ME);
        end

            % Update the features axes.
            % TBD: Use uicontrol instead of tick for each detector?
%             detectors = [handles.detectors{:}];
%             set(handles.features, 'YTick', 1:numel(handles.detectors));
%             set(handles.features, 'YTickLabel', {detectors.name});
%             set(handles.features, 'YLim', [0.5, numel(handles.detectors) + 0.5]);

    end
end


function addDetectorPopUp_CreateFcn(hObject, ~, handles)
    if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
    
    % Get the list of class names from the 'Detectors' folder.
    analysisPath = mfilename('fullpath');
    parentDir = fileparts(analysisPath);
    detectorsDir = fullfile(parentDir, filesep, 'Detectors');
    detectorDirs = dir(detectorsDir);
    handles.detectorClassNames = cell(length(detectorDirs), 1);
    handles.detectorTypeNames = cell(length(detectorDirs), 1);
    detectorCount = 0;
    jUndo = get(handles.addDetectorTool, 'JavaContainer');
    jMenu = get(jUndo, 'MenuComponent');
    jMenu.removeAll;
    for i = 1:length(detectorDirs)
        if detectorDirs(i).isdir && ~strcmp(detectorDirs(i).name, '.') && ~strcmp(detectorDirs(i).name, '..')
            detectorCount = detectorCount + 1;
            handles.detectorClassNames{detectorCount} = detectorDirs(i).name;
            addpath(fullfile(detectorsDir, filesep, detectorDirs(i).name));
            eval([detectorDirs(i).name '.initialize()'])
            handles.detectorTypeNames{detectorCount} = [eval([detectorDirs(i).name '.typeName()']) ' Detector'];
            jActionItem = jMenu.add(handles.detectorTypeNames{detectorCount});
            set(jActionItem, 'ActionPerformedCallback', 'FlySongAnalysis(''addDetectorCallback'', hObject, eventdata, guidata(hObject))');
        end
    end
    handles.detectorClassNames = handles.detectorClassNames(1:detectorCount);
    handles.detectorTypeNames = handles.detectorTypeNames(1:detectorCount);
    handles.detectors = {};
    guidata(hObject, handles);
    
    jToolbar = get(get(handles.toolbar,'JavaContainer'),'ComponentPeer');
    jToolbar.revalidate;
    
    
    % Update the pop-up menu
    % It should start with a single 'Add...' item to which we add a description of each detector type.
    % TODO: Sometimes the list of types gets saved into the .fig along with the 'Add...'.  In that case the additional entries should be stripped.
    string = {get(hObject, 'String')};
    string(2:numel(handles.detectorTypeNames) + 1) = handles.detectorTypeNames;
    set(hObject, 'String', string);
end


% --- Executes on mouse press over axes background.
function windowButtonDownFcn(hObject, ~)
    handles = guidata(hObject);
    
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
        set(handles.figure1, 'WindowButtonMotionFcn', @windowButtonMotionFcn);
        set(handles.figure1, 'WindowButtonUpFcn', @windowButtonUpFcn);
    end
    guidata(hObject, handles);
    syncGUIWithTime(handles);
    
    function windowButtonMotionFcn(hObject, ~)
        handles = guidata(hObject);
        clickedPoint = get(handles.oscillogram, 'CurrentPoint');
        clickedSample = timeRange(1) * handles.audio.sampleRate - 1 + clickedPoint(1, 1);
        handles.selectedTime = [handles.selectedTime(1) clickedSample / handles.audio.sampleRate];
        guidata(hObject, handles);
        syncGUIWithTime(handles);
        drawnow;
    end
    
    function windowButtonUpFcn(hObject, ~)
        handles = guidata(hObject);
        clickedPoint = get(handles.oscillogram, 'CurrentPoint');
        clickedSample = timeRange(1) * handles.audio.sampleRate - 1 + clickedPoint(1, 1);
        handles.selectedTime = sort([handles.selectedTime(1) clickedSample / handles.audio.sampleRate]);
        guidata(hObject, handles);
        syncGUIWithTime(handles);
        set(handles.figure1, 'WindowButtonMotionFcn', []);
        set(handles.figure1, 'WindowButtonUpFcn', []);
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
    
    if isfield(handles, 'showSpectrogram') && handles.showSpectrogram
        h3 = uint16((h - ss) / 3) - 1;
        hr = h - ss - (h3 + 1) * 2 + 1;

        set(handles.oscillogram, 'Position',        [1      ss+h3*2+2   w-ss    hr]);
        set(handles.autoGainCheckBox, 'Position',   [w-ss-1 h-16+1      ss+1    ss]);
        set(handles.gainSlider, 'Position',         [w-ss+1 ss+h3*2+2   ss      hr-ss]);

        set(handles.features, 'Position',           [1      ss+h3+1     w-ss    h3]);
        set(handles.featureSlider, 'Position',      [w-ss+1 ss+h3       ss      h3+2]);

        set(handles.spectrogram, 'Position',        [1      ss          w-ss    h3]);

        set(handles.timeSlider, 'Position',         [1      0           w-ss+1  ss]);
    else
        h2 = uint16((h - ss) / 2) - 1;
        hr = h - ss - (h2 + 1) + 1;

        set(handles.oscillogram, 'Position',        [1      ss+h2+1     w-ss    hr]);
        set(handles.autoGainCheckBox, 'Position',   [w-ss-1 h-16+1      ss+1    ss]);
        set(handles.gainSlider, 'Position',         [w-ss+1 ss+h2+1     ss      hr-ss]);

        set(handles.features, 'Position',           [1      ss          w-ss    h2]);
        set(handles.featureSlider, 'Position',      [w-ss+1 ss          ss      h2+1]);

        set(handles.timeSlider, 'Position',         [1      0           w-ss+1  ss]);
    end
end


% --- Executes on slider movement.
function featureSlider_Callback(hObject, eventdata, handles)
% hObject    handle to featureSlider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider
end
