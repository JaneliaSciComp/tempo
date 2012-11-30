classdef SpectrogramPanel < MediaPanel

	properties
        windowSize
        freqMin
        freqMax
        
        imageHandle
	end
	
	methods
	
		function obj = SpectrogramPanel(controller, recording)
			obj = obj@MediaPanel(controller, recording);
            
            obj.windowSize = 0.001;
            obj.freqMin = 0;
            obj.freqMax = floor(recording.sampleRate / 2);
        end
        
        
        function createControls(obj, panelSize)
            obj.imageHandle = image(panelSize(1), panelSize(2), zeros(panelSize), ...
                'CDataMapping', 'scaled', ...
                'HitTest', 'off');
            set(obj.axes, 'XTick', [], 'YTick', []);
            colormap(flipud(gray));
            axis xy;
        end
        
        
        function updateAxes(obj, timeRange)
            if isempty(obj.recording)
                return
            end
            
            audioData = obj.recording.dataInTimeRange(timeRange);
            
            window = 2^nextpow2(obj.windowSize * obj.recording.sampleRate);
            
            axesSize = get(obj.axes, 'Position');
            [~, f, ~, P] = spectrogram(double(audioData), window, [], [], obj.recording.sampleRate);
            idx = (f > obj.freqMin) & (f < obj.freqMax);
            P = log10(abs(P(idx, :)));
%             floor(size(P, 1) / axesSize(3));  if (ans>2) P=P(1:ans:end,:);  end
%             floor(size(P, 2) / axesSize(4));   if (ans>2) P=P(:,1:ans:end);  end
            tmp = reshape(P, 1, prod(size(P)));
            tmp = prctile(tmp, [1 99]);
            P(P < tmp(1)) = tmp(1);
            P(P > tmp(2)) = tmp(2);
            
            set(obj.imageHandle, 'CData', P, ...
                'XData', timeRange);

%             % "axis xy" or something is doing weird things with the limits of the axes.
%             % The lower-left corner is not (0, 0) but the size of P.
%             text(size(P, 2) * 2, size(P, 1) * 2 - 1, [num2str(round(handles.spectrogramFreqMax)) ' Hz'], ...
%                 'BackgroundColor', 'w', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top');
%             text(size(P, 2) * 2, size(P, 1), [num2str(round(handles.spectrogramFreqMin)) ' Hz'], ...
%                 'BackgroundColor', 'w', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'baseline');
%             text(size(P, 2), size(P, 1) * 2 - 1, ...
%                  sprintf('%.3g msec\n%.3g Hz',[window/sampleRate/2*1000 sampleRate/window/2]), ...
%                 'BackgroundColor', 'w', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top');
% 
%             % Add a text object to show the time and frequency of where the mouse is currently hovering.
%             handles.spectrogramTooltip = text(size(P, 2), size(P, 1), '', 'BackgroundColor', 'w', ...
%                 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', 'Visible', 'off');
        end
	
	end
	
end
