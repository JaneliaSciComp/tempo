classdef SpectrogramPanel < TimelinePanel

	properties
        audio
        
        windowSize
        freqMin
        freqMax
        
        imageHandle
        
        freqMaxLabel
        freqMinLabel
        otherLabel
	end
	
	methods
	
		function obj = SpectrogramPanel(controller, recording)
			obj = obj@TimelinePanel(controller);
            
            obj.audio = recording;
            
            obj.windowSize = 0.001;
            obj.freqMin = 0;
            obj.freqMax = floor(recording.sampleRate / 2);
        end
        
        
        function createControls(obj, panelSize)
            panelSize(1) = panelSize(1) - obj.axesBorder(3);
            
            obj.imageHandle = image(panelSize(1), panelSize(2), zeros(panelSize), ...
                'CDataMapping', 'scaled', ...
                'HitTest', 'off');
            colormap(flipud(gray));
            axis xy;
            set(obj.axes, 'XTick', [], 'YTick', [], 'Box', 'off');
            
            obj.freqMaxLabel = text(panelSize(1)  - 1, panelSize(2), '', 'Units', 'pixels', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'BackgroundColor', 'white');
            obj.freqMinLabel = text(panelSize(1) - 1, 4, '', 'Units', 'pixels', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', 'BackgroundColor', 'white');
            obj.otherLabel = text(5, panelSize(2), '', 'Units', 'pixels', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', 'BackgroundColor', 'white');
        end
        
        
        function resizeControls(obj, panelSize)
            panelSize(1) = panelSize(1) - obj.axesBorder(3);
            
            % Update the positions of the labels.
            set(obj.freqMaxLabel, 'Position', [panelSize(1)  - 1, panelSize(2)]);
            set(obj.freqMinLabel, 'Position', [panelSize(1) - 1, 4]);
            set(obj.otherLabel, 'Position', [5, panelSize(2)]);
        end
        
        
        function updateAxes(obj, timeRange)
            if isempty(obj.audio)
                return
            end
            
            audioData = obj.audio.dataInTimeRange(timeRange);
            
            window = 2^nextpow2(obj.windowSize * obj.audio.sampleRate);
            
%             axesSize = get(obj.axes, 'Position');
            [~, f, ~, P] = spectrogram(double(audioData), window, [], [], obj.audio.sampleRate);
            idx = (f > obj.freqMin) & (f < obj.freqMax);
            P = log10(abs(P(idx, :)));
%             floor(size(P, 1) / axesSize(3));  if (ans>2) P=P(1:ans:end,:);  end
%             floor(size(P, 2) / axesSize(4));   if (ans>2) P=P(:,1:ans:end);  end
            tmp = reshape(P, 1, numel(P));
            tmp = prctile(tmp, [1 99]);
            P(P < tmp(1)) = tmp(1);
            P(P > tmp(2)) = tmp(2);
            
            set(obj.imageHandle, 'CData', P, 'XData', timeRange);

            set(obj.freqMaxLabel, 'String', [num2str(round(obj.freqMax)) ' Hz']);
            set(obj.freqMinLabel, 'String', [num2str(round(obj.freqMin)) ' Hz']);
            set(obj.otherLabel, 'String', sprintf('%.3g msec\n%.3g Hz', window / obj.audio.sampleRate / 2 * 1000, obj.audio.sampleRate / window / 2));
            
% TODO
%             % Add a text object to show the time and frequency of where the mouse is currently hovering.
%             obj.spectrogramTooltip = text(size(P, 2), size(P, 1), '', 'BackgroundColor', 'w', ...
%                 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', 'Visible', 'off');
        end
        
        
        function handled = keyWasPressed(obj, keyEvent)
            shiftDown = any(ismember(keyEvent.Modifier, 'shift'));
            ctrlDown = any(ismember(keyEvent.Modifier, 'control'));
            if strcmp(keyEvent.Key, 'leftbracket')
                if shiftDown
                    tmp=(obj.freqMax - obj.freqMin) / 2;
                    obj.freqMin = min(floor(obj.audio.sampleRate / 2) - 1, obj.freqMin + tmp);
                    obj.freqMax = min(floor(obj.audio.sampleRate / 2), obj.freqMax + tmp);
                elseif ctrlDown
                    obj.windowSize = max(64 / obj.audio.sampleRate, obj.windowSize / 2);
                else
                    tmp = (obj.freqMax - obj.freqMin) / 2;
                    obj.freqMin = max(0,obj.freqMin - tmp);
                    obj.freqMax = min(floor(obj.audio.sampleRate / 2), obj.freqMax + tmp);
                end
                obj.updateAxes(obj.controller.displayedTimeRange());
                handled = true;
            elseif strcmp(keyEvent.Key, 'rightbracket')
                if shiftDown
                    tmp= (obj.freqMax - obj.freqMin) / 2;
                    obj.freqMin = max(0, obj.freqMin - tmp);
                    obj.freqMax = max(1, obj.freqMax - tmp);
                elseif ctrlDown
                    obj.windowSize = min(1, obj.windowSize * 2);
                else
                    tmp = (obj.freqMax - obj.freqMin) / 4;
                    obj.freqMin = obj.freqMin + tmp;
                    obj.freqMax = obj.freqMax - tmp;
                end
                obj.updateAxes(obj.controller.displayedTimeRange());
                handled = true;
            else
                handled = keyWasPressed@TimelinePanel(obj, keyEvent);
            end
        end
	
	end
	
end
