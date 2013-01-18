function FlySongAnalysis()
    if verLessThan('matlab', '7.9')
        error 'FlySongAnalysis requires MATLAB 7.9 (2009b) or later.'
    end
    
    % TODO: implement app-level features like window menu, etc.
    
    AnalysisController();
    return
end


% All code past here is historical.  Anything left needs to find a home in the new code architecture.


function FlySongAnalysis_OpeningFcn(hObject, ~, handles, varargin)
    handles.output = hObject;

    handles.close_matlabpool=0;
    if((exist('matlabpool')==2) && (matlabpool('size')==0))
      try
        matlabpool open
        handles.close_matlabpool=1;
      catch
        disp('WARNING: could not open matlab pool.  proceeding with a single thread.');
      end
    end
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


function newHandles = updateVideo(handles)
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
    end
end


function setAudioRecording(rec)
    handles.audio = rec;
    handles.audioPlayer = audioplayer(handles.audio.data, handles.audio.sampleRate);
    handles.audioPlayer.TimerPeriod = 1.0 / 15.0;
    handles.audioMax = max(abs(handles.audio.data));
    
    handles.maxMediaTime = max([handles.maxMediaTime handles.audio.duration]);
    
    handles.playTimer = timer('ExecutionMode', 'fixedRate', 'TimerFcn', @syncGUIToAudio, 'Period', round(1.0 / 30.0 * 1000) / 1000, 'UserData', handles.oscillogram, 'StartDelay', 0.1);
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
