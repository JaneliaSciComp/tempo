classdef WaveformPanel < TimelinePanel

	properties
        audio
        
        plotHandle
        sampleCount
        
	    autoGainCheckbox
	    gainSlider
        
        grayRect
	end
	
	methods
	
		function obj = WaveformPanel(controller, recording)
			obj = obj@TimelinePanel(controller);
            
            obj.audio = recording;
        end
	    
        
	    function createControls(obj, panelSize)
            set(obj.controller.figure, 'CurrentAxes', obj.axes);
            
            obj.plotHandle = line([0 1000], [0 0], 'HitTest', 'off');
%            obj.oscillogramSampleCount = windowSampleCount;

%            handles.timeScaleText = text(10, 0, '', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom');
            
% 	        obj.autoGainCheckbox = uicontrol('Parent', obj.panel);
% 	        obj.gainSlider = uicontrol('Parent', obj.panel);
            
            obj.grayRect = rectangle('Position', [0, -1, 1, 2], 'FaceColor', [0.9 0.9 0.9], 'EdgeColor', 'none', 'HitTest', 'off', 'Visible', 'off');
            
            % TODO: mute button?
        end
	    
        
%         function resizeControls(panelSize)
%             set(obj.autoGainCheckbox, 'Position', [panelSize(1) - obj.scrollSize - 1, panelSize(2) - obj.scrollsize + 1, obj.scrollSize + 1, obj.scrollSize]);
%             set(obj.gainSlider, 'Position', [panelSize(1) - obj.scrollSize + 1 0 obj.scrollSize panelSize(2) - obj.scrollSize]);
%         end
        
        
        function updateAxes(obj, timeRange)
            if isempty(obj.audio)
                return
            end
            
            audioData = obj.audio.dataInTimeRange(timeRange(1:2));
            
            % The audio may not span the entire time range.
            dataDuration = length(audioData) / obj.audio.sampleRate;

            windowSampleCount = length(audioData);
            axesSize = get(obj.axes, 'Position');
            step = max(1, floor(windowSampleCount/axesSize(3)/100));

            % Update the waveform.
            if false    % TODO: get(handles.autoGainCheckBox, 'Value') == 1.0
                maxAmp = max(abs(audioData(1:step:windowSampleCount)));
            else
                maxAmp = obj.audio.maxAmplitude() / 1.0;    % TODO: get(handles.gainSlider, 'Value');
            end
            
            % Update the line with the data in this time range.
            xData = (0:step:length(audioData) - 1) / length(audioData) * dataDuration + timeRange(1);
            set(obj.plotHandle, 'XData', xData, 'YData', audioData(1:step:windowSampleCount));
            
            % Update the y limits of the axes based on the gain settings.
            curYLim = get(obj.axes, 'YLim');
            if curYLim(1) ~= -maxAmp || curYLim(2) ~= maxAmp
                set(obj.axes, 'YLim', [-maxAmp maxAmp]);
            end
            
            % Display a gray rectangle where there isn't audio data available.
            if obj.audio.duration < obj.controller.duration
                set(obj.grayRect, 'Position', [obj.audio.duration, -maxAmp, obj.controller.duration - obj.audio.duration, maxAmp * 2], 'Visible', 'on');
            else
                set(obj.grayRect, 'Visible', 'off');
            end
        end
        
	end
	
end
