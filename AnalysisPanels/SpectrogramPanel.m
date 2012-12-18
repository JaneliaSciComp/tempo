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
        zoomInLabel
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
            
            obj.freqMaxLabel = text(panelSize(1) - 1, panelSize(2), '', 'Units', 'pixels', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'BackgroundColor', 'white');
            obj.freqMinLabel = text(panelSize(1) - 1, 4, '', 'Units', 'pixels', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', 'BackgroundColor', 'white');
            obj.otherLabel = text(5, panelSize(2), '', 'Units', 'pixels', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', 'BackgroundColor', 'white');
            obj.zoomInLabel = text(panelSize(1) / 2, panelSize(2) / 2, 'Zoom in to see the spectrogram', 'Units', 'pixels', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Visible', 'off');
        end
        
        
        function resizeControls(obj, panelSize)
            panelSize(1) = panelSize(1) - obj.axesBorder(3);
            
            % Update the positions of the labels.
            set(obj.freqMaxLabel, 'Position', [panelSize(1) - 1, panelSize(2)]);
            set(obj.freqMinLabel, 'Position', [panelSize(1) - 1, 4]);
            set(obj.otherLabel, 'Position', [5, panelSize(2)]);
            set(obj.zoomInLabel, 'Position', [panelSize(1) / 2, panelSize(2) / 2]);
        end
        
        
        function updateAxes(obj, timeRange)
            if isempty(obj.audio)
                return
            end
            
            fullLength = floor((timeRange(2) - timeRange(1)) * obj.audio.sampleRate);
            window = 2 ^ nextpow2(obj.windowSize * obj.audio.sampleRate);
            
            if fullLength > 100000
                % It will take too long to compute the spectrogram for this much data.
                P = zeros(100, 100);
                set(obj.axes, 'CLim', [-1 9]);
                set(obj.zoomInLabel, 'Visible', 'on');
            else
                audioData = obj.audio.dataInTimeRange(timeRange);
                set(obj.axes, 'CLimMode', 'auto')
                set(obj.zoomInLabel, 'Visible', 'off');

                if isempty(audioData)
                    P = zeros(100, 100);
                    set(obj.axes, 'CLim', [-1 9]);
                else
                    % Get the raw spectrogram data.
                    % TODO: any way to cache this to allow viewing at larger scales?
                    [~, f, ~, P] = spectrogram(double(audioData), window, [], [], obj.audio.sampleRate);
                    
                    % Restrict to the frequencies of interest.
                    idx = (f > obj.freqMin) & (f < obj.freqMax);
                    P = log10(abs(P(idx, :)));
                    
                    % Reduce the dimensions of P so that there are no more than 2x2 data points per pixel.
                    axesSize = get(obj.axes, 'Position');
                    xScale = floor(size(P, 2) / axesSize(3));
                    yScale = floor(size(P, 1) / axesSize(4));
                    if xScale > 2 && yScale > 2
                        P = P(1:yScale:end, 1:xScale:end);
                    elseif xScale > 2
                        P = P(:, 1:xScale:end);
                    elseif yScale > 2
                        P = P(1:yScale:end, :);
                    end
                    
                    % Remove the bottom and top 1% of values.
                    tmp = reshape(P, 1, numel(P));
                    tmp = prctile(tmp, [1 99]);
                    P(P < tmp(1)) = tmp(1);
                    P(P > tmp(2)) = tmp(2);
                    
                    if length(audioData) < fullLength
                        % Pad the image with [0.9 0.9 0.9] so it fills the entire time range.
                        scale = (fullLength / length(audioData)) - 1;
                        maxP = max(P(:));
                        minP = min(P(:));
                        P = horzcat(P, ones(size(P, 1), floor(size(P, 2) * scale)) * (maxP - minP) * 0.1 + minP);
                    end
                end
            end
            
            set(obj.axes, 'YLim', [1 size(P, 1)]);
            
            set(obj.imageHandle, 'CData', P, 'XData', timeRange, 'YData', [1 size(P, 1)]);
            
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
                    % Scroll up to higher frequencies.
                    tmp=(obj.freqMax - obj.freqMin) / 2;
                    obj.freqMin = min(floor(obj.audio.sampleRate / 2) - 1, obj.freqMin + tmp);
                    obj.freqMax = min(floor(obj.audio.sampleRate / 2), obj.freqMax + tmp);
                elseif ctrlDown
                    % Halve the window size.
                    obj.windowSize = max(64 / obj.audio.sampleRate, obj.windowSize / 2);
                else
                    % Double the range of frequencies shown.
                    tmp = (obj.freqMax - obj.freqMin) / 2;
                    obj.freqMin = max(0,obj.freqMin - tmp);
                    obj.freqMax = min(floor(obj.audio.sampleRate / 2), obj.freqMax + tmp);
                end
                obj.updateAxes(obj.controller.displayedTimeRange());
                handled = true;
            elseif strcmp(keyEvent.Key, 'rightbracket')
                if shiftDown
                    % Scroll down to lower frequencies.
                    tmp= (obj.freqMax - obj.freqMin) / 2;
                    obj.freqMin = max(0, obj.freqMin - tmp);
                    obj.freqMax = max(1, obj.freqMax - tmp);
                elseif ctrlDown
                    % Double the window size.
                    obj.windowSize = min(1, obj.windowSize * 2);
                else
                    % Halve the range of frequencies shown.
                    tmp = (obj.freqMax - obj.freqMin) / 4;
                    obj.freqMin = obj.freqMin + tmp;
                    obj.freqMax = obj.freqMax - tmp;
                end
                obj.updateAxes(obj.controller.displayedTimeRange());
                handled = true;
            elseif keyEvent.Character == '|'
                % Reset to the defaults.
                obj.windowSize = 0.001;
                obj.freqMin = 0;
                obj.freqMax = floor(obj.audio.sampleRate / 2);
                obj.updateAxes(obj.controller.displayedTimeRange());
                handled = true;
            else
                handled = keyWasPressed@TimelinePanel(obj, keyEvent);
            end
        end
	
	end
	
end
