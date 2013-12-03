classdef WaveformPanel < TimelinePanel

	properties
        audio
        
        plotHandle
        sampleCount
        
        infoMenuItem
        
	    verticalScalingMethod = 1;      % 1 = whole recording, 2 = displayed portion of recording, 3 = manual
        verticalScalingValue = 1.0;
        
        leftGrayRect
        rightGrayRect
	end
	
	methods
	
		function obj = WaveformPanel(controller, recording)
			obj = obj@TimelinePanel(controller);
            
            obj.audio = recording;
            set(obj.infoMenuItem, 'Label', ['Audio file: ' obj.audio.name]);
            % TODO: use Java to show the full path as a tooltip
            
%             addlistener(obj, 'verticalScalingMethod', 'PostSet', @(source, event)handleVerticalScalingChanged(obj, source, event));
%             addlistener(obj, 'verticalScalingValue', 'PostSet', @(source, event)handleVerticalScalingChanged(obj, source, event));
            addlistener(obj.audio, 'timeOffset', 'PostSet', @(source, event)handleTimeOffsetChanged(obj, source, event));
        end
        
        
        function addInfoMenuItems(obj, infoMenu)
            obj.infoMenuItem = uimenu(infoMenu, 'Label', 'Audio file: ', 'Enable', 'off');
            uimenu(infoMenu, ...
                'Label', 'Audio settings...', ...
                'Separator', 'on', ...
                'Callback', @(hObject,eventdata)showAudioSettings(obj, hObject, eventdata));
            uimenu(infoMenu, ...
                'Label', 'Waveform setings...', ...
                'Callback', @(hObject,eventdata)showWaveformSettings(obj, hObject, eventdata));
            
            % Move our first item above the default items.
            menuItems = get(infoMenu, 'Children');
            set(menuItems(end), 'Separator', 'on');
            menuItems = vertcat(menuItems(1:end-3), menuItems(end-1:end), menuItems(end-2));
            set(infoMenu, 'Children', menuItems);
        end
	    
        
	    function createControls(obj, panelSize) %#ok<INUSD>
            set(obj.controller.figure, 'CurrentAxes', obj.axes);
            
            obj.plotHandle = line([0 1000], [0 0], 'HitTest', 'off');
            obj.leftGrayRect = rectangle('Position', [0, -1, 1, 2], 'FaceColor', [0.9 0.9 0.9], 'EdgeColor', 'none', 'HitTest', 'off', 'Visible', 'off');
            obj.rightGrayRect = rectangle('Position', [0, -1, 1, 2], 'FaceColor', [0.9 0.9 0.9], 'EdgeColor', 'none', 'HitTest', 'off', 'Visible', 'off');
        end
	    
        
%         function resizeControls(panelSize)
%             set(obj.autoGainCheckbox, 'Position', [panelSize(1) - obj.scrollSize - 1, panelSize(2) - obj.scrollsize + 1, obj.scrollSize + 1, obj.scrollSize]);
%             set(obj.gainSlider, 'Position', [panelSize(1) - obj.scrollSize + 1 0 obj.scrollSize panelSize(2) - obj.scrollSize]);
%         end
        
        
        function showAudioSettings(obj, ~, ~)
            RecordingSettings(obj.audio);
        end
        
        
        function showWaveformSettings(obj, ~, ~)
            WaveformSettings(obj);
        end
        
        
        function updateAxes(obj, timeRange)
            if isempty(obj.audio)
                return
            end
            
            [audioData, dataOffset] = obj.audio.dataInTimeRange(timeRange(1:2));
            
            if isempty(audioData)
                % TODO: display "zoom in" message
            else
                % The audio may not span the entire time range.
                dataDuration = length(audioData) / obj.audio.sampleRate;

                windowSampleCount = length(audioData);
                axesSize = get(obj.axes, 'Position');
                step = max(1, floor(windowSampleCount/axesSize(3)/100));

                % Update the waveform.
                % TODO: skip if the correct piece of the recording is already displayed
                globalMaxAmplitude = obj.audio.maxAmplitude();  % TODO: check others if "Apply to all"?
                if obj.verticalScalingMethod == 1
                    maxAmp = globalMaxAmplitude;
                elseif obj.verticalScalingMethod == 2
                    maxAmp = max(abs(audioData(1:step:windowSampleCount)));
                elseif obj.verticalScalingMethod == 3
                    maxAmp = globalMaxAmplitude * obj.verticalScalingValue;
                else
                    % error
                end

                % Update the line with the data in this time range.
                xData = (0:step:length(audioData) - 1) / length(audioData) * dataDuration + timeRange(1) + dataOffset;
                set(obj.plotHandle, 'XData', xData, 'YData', audioData(1:step:windowSampleCount));

                % Update the y limits of the axes based on the gain settings.
                curYLim = get(obj.axes, 'YLim');
                if curYLim(1) ~= -maxAmp || curYLim(2) ~= maxAmp
                    set(obj.axes, 'YLim', [-maxAmp maxAmp]);
                end

                % Display a gray rectangle where there isn't audio data available.
                % This should only happen when multiple recordings of different lengths are open or 
                % when a recording has a non-zero starting time offset.
                if dataOffset > 0
                    set(obj.leftGrayRect, 'Position', [timeRange(1), -maxAmp, dataOffset, maxAmp * 2], 'Visible', 'on');
                else
                    set(obj.rightGrayRect, 'Visible', 'off');
                end
                if obj.audio.duration < obj.controller.duration
                    set(obj.rightGrayRect, 'Position', [obj.audio.duration, -maxAmp, obj.controller.duration - obj.audio.duration, maxAmp * 2], 'Visible', 'on');
                else
                    set(obj.rightGrayRect, 'Visible', 'off');
                end
            end
        end
        
        
        function setVerticalScalingMethodAndOrValue(obj, method, value)
            % Pass [] to only change one of them.
            if ~isempty(method)
                obj.verticalScalingMethod = method;
            end
            if ~isempty(value)
                obj.verticalScalingValue = value;
            end
            obj.updateAxes(obj.controller.displayRange);
        end
        
        
        function handleTimeOffsetChanged(obj, ~, ~)
            obj.updateAxes(obj.controller.displayRange);
        end
        
	end
	
end
