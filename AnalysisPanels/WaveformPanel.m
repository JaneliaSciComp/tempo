classdef WaveformPanel < MediaPanel

	properties
        plotHandle
        sampleCount
        
	    autoGainCheckbox
	    gainSlider
	end
	
	methods
	
		function obj = WaveformPanel(controller, recording)
			obj = obj@MediaPanel(controller, recording);
		end
	    
	    function createControls(obj, panelSize)
            set(obj.controller.figure, 'CurrentAxes', obj.axes);
            
            obj.plotHandle = line([0 1000], [0 0], 'HitTest', 'off');
%            obj.oscillogramSampleCount = windowSampleCount;

%            handles.timeScaleText = text(10, 0, '', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom');
            
% 	        obj.autoGainCheckbox = uicontrol('Parent', obj.panel);
% 	        obj.gainSlider = uicontrol('Parent', obj.panel);
            
            % TODO: mute button?
        end
	    
        
%         function resizeControls(panelSize)
%             set(obj.autoGainCheckbox, 'Position', [panelSize(1) - obj.scrollSize - 1, panelSize(2) - obj.scrollsize + 1, obj.scrollSize + 1, obj.scrollSize]);
%             set(obj.gainSlider, 'Position', [panelSize(1) - obj.scrollSize + 1 0 obj.scrollSize panelSize(2) - obj.scrollSize]);
%         end
        
        
        function updateAxes(obj, timeRange)
            if isempty(obj.recording)
                return
            end
            
            audioData = obj.recording.dataInTimeRange(timeRange);

%             windowSampleCount = length(audioWindow);
% 
%             step = max(1, floor(windowSampleCount/panelSize(2)/100));

            % Update the waveform.
            if false    % TODO: get(handles.autoGainCheckBox, 'Value') == 1.0
%                 maxAmp = max(abs(audioWindow(1:step:windowSampleCount)));
            else
                maxAmp = obj.recording.maxAmplitude() / 1.0;    % TODO: get(handles.gainSlider, 'Value');
            end

            % Update the existing oscillogram pieces for faster rendering.
% TODO:
%             if windowSampleCount ~= timeRangeSize
%                 % the number of samples changed
%                 set(handles.oscillogramPlot, 'XData', 1:step:windowSampleCount, 'YData', audioWindow(1:step:windowSampleCount));
%                 handles.oscillogramSampleCount = windowSampleCount;
%                 set(handles.oscillogram, 'XLim', [1 windowSampleCount]);
%             elseif minSample ~= timeRange(1)
%                 % the number of samples is the same but the time point is different
%                 set(handles.oscillogramPlot, 'YData', audioWindow(1:step:windowSampleCount));
%             end
            
            xData = (0:length(audioData) - 1) / length(audioData) * (timeRange(2) - timeRange(1)) + timeRange(1);
            set(obj.plotHandle, 'XData', xData, 'YData', audioData);
%            stepSize = (timeRange(2) - timeRange(1)) / length(audioData);
%            set(obj.plotHandle, 'XData', timeRange(1):stepSize:timeRange(2) - stepSize, 'YData', audioData);
            
            curYLim = get(obj.axes, 'YLim');
            if curYLim(1) ~= -maxAmp || curYLim(2) ~= maxAmp
                set(obj.axes, 'YLim', [-maxAmp maxAmp]);
            end
        end
        
	end
	
end
