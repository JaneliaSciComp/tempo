classdef SpectrogramPanel < TimelinePanel

	properties
        audio
        
        infoMenuItem
        
        imageHandle
        
        freqMaxLabel
        freqMinLabel
        otherLabel
        
        noDisplayLabel

        reporter
        bounding_boxes
        
        % The frequency range is shared by all panels and is stored in the second half of obj.controller.displayRange.
        % The FFT window shared by all panels and is stored in obj.controller.windowSize.
        saturation = [0.01 0.99]
	end
	
	methods
	
		function obj = SpectrogramPanel(controller, recording)
			obj = obj@TimelinePanel(controller);
            
            obj.showsFrequencyRange = true;
            
            obj.audio = recording;
            set(obj.infoMenuItem, 'Label', ['Audio file: ' obj.audio.name]);
            
            obj.listeners{end + 1} = addlistener(obj.controller, 'windowSize', 'PostSet', ...
                @(source, event)handleSpectrogramParametersChanged(obj, source, event));
            obj.listeners{end + 1} = addlistener(obj.controller, 'displayRange', 'PostSet', ...
                @(source, event)handleSpectrogramParametersChanged(obj, source, event));
        end
        
        
        function handleSpectrogramParametersChanged(obj, ~, ~)
            if ~isempty(obj.controller.displayRange) && obj.visible
                obj.updateAxes(obj.controller.displayRange);
            end
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
            obj.noDisplayLabel = text(panelSize(1) / 2, panelSize(2) / 2, 'Zoom in to see the spectrogram', 'Units', 'pixels', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Visible', 'off');
        end
        
        
        function resizeControls(obj, panelSize)
            panelSize(1) = panelSize(1) - obj.axesBorder(3);
            
            % Update the positions of the labels.
            set(obj.freqMaxLabel, 'Position', [panelSize(1) - 1, panelSize(2)]);
            set(obj.freqMinLabel, 'Position', [panelSize(1) - 1, 4]);
            set(obj.otherLabel, 'Position', [5, panelSize(2)]);
            set(obj.noDisplayLabel, 'Position', [panelSize(1) / 2, panelSize(2) / 2]);
        end
        
        
        function addInfoMenuItems(obj, infoMenu)
            % Add recording name, "Audio Settings..." and "Spectrogram Settings..." menu items
            obj.infoMenuItem = uimenu(infoMenu, 'Label', 'Audio file: ', 'Enable', 'off');
            uimenu(infoMenu, ...
                'Label', 'Audio settings...', ...
                'Separator', 'on', ...
                'Callback', @(hObject,eventdata)showAudioSettings(obj, hObject, eventdata));
            uimenu(infoMenu, ...
                'Label', 'Spectrogram setings...', ...
                'Callback', @(hObject,eventdata)showSpectrogramSettings(obj, hObject, eventdata));
            
            % Move the recording's name item above the default items.
            menuItems = get(infoMenu, 'Children');
            set(menuItems(end), 'Separator', 'on');
            menuItems = vertcat(menuItems(1:end-3), menuItems(end-1:end), menuItems(end-2));
            set(infoMenu, 'Children', menuItems);
        end
        
        
        function showAudioSettings(obj, ~, ~)
            % TODO: obj.controller.showAudioSettings(obj.audio);
            beep;
        end
        
        
        function showSpectrogramSettings(obj, ~, ~)
            SpectrogramSettings(obj);
        end
        
        
        function updateAxes(obj, timeRange)
            if isempty(obj.audio)
                return
            end
            
            if isempty(timeRange)
                timeRange = get(obj.axes, 'XLim');
            end
            
            fullLength = floor((timeRange(2) - timeRange(1)) * obj.audio.sampleRate);
            window = 2 ^ nextpow2(obj.controller.windowSize * obj.audio.sampleRate);
            
            P = zeros(100, 100);
            freqRange=[1 100];
            set(obj.axes, 'CLim', [-1 9]);
            if obj.controller.isPlayingMedia
                set(obj.noDisplayLabel, 'Visible', 'on', 'String', 'No spectrogram while media is playing');
            elseif fullLength > 1000000
                % It will take too long to compute the spectrogram for this much data.
                set(obj.noDisplayLabel, 'Visible', 'on', 'String', 'Zoom in to see the spectrogram');
            else
                [audioData, dataOffset] = obj.audio.dataInTimeRange(timeRange(1:2));
                set(obj.noDisplayLabel, 'Visible', 'off');

                if ~isempty(audioData)
                    set(obj.axes, 'CLimMode', 'auto')
                    % Get the raw spectrogram data.
                    % TODO: any way to cache this to allow viewing at larger scales?
                    [~, f, ~, P] = spectrogram(double(audioData), window, [], [], obj.audio.sampleRate);
                    
                    % Restrict to the frequencies of interest.
                    idx = (f > obj.controller.displayRange(3)) & (f < obj.controller.displayRange(4));
                    P = log10(abs(P(idx, :)));
                    freqRange=[min(f(idx)) max(f(idx))];
                    
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
                    
                    % Saturate out the bottom and top values to alter the constrast.
                    tmp = reshape(P, 1, numel(P));
                    tmp = prctile(tmp, obj.saturation * 100);
                    P(P < tmp(1)) = tmp(1);
                    P(P > tmp(2)) = tmp(2);
                    
                    if length(audioData) < fullLength
                        % Pad the image with [0.9 0.9 0.9] so it fills the entire time range.
                        % This can happen when multiple recordings are open and they don't have the same duration 
                        % or when one or more recordings have non-zero start times.
                        maxP = max(P(:));
                        minP = min(P(:));
                        gray = (maxP - minP) * 0.1 + minP;
                        dataFraction = length(audioData) / fullLength;
                        preFraction = dataOffset / (timeRange(2) - timeRange(1));
                        postFraction = 1.0 - dataFraction - preFraction;
                        prePixels = floor(preFraction * size(P, 2) / dataFraction);
                        postPixels = floor(postFraction * size(P, 2) / dataFraction);
                        P = horzcat(ones(size(P, 1), prePixels) * gray, P, ones(size(P, 1), postPixels) * gray);
                    end
                end
            end
            
%            set(obj.axes, 'YLim', [1 size(P, 1)]);
            set(obj.axes, 'YLim', freqRange);
            
%            set(obj.imageHandle, 'CData', P, 'XData', timeRange, 'YData', [1 size(P, 1)]);
            set(obj.imageHandle, 'CData', P, 'XData', timeRange(1:2), 'YData', freqRange);
            
            set(obj.freqMaxLabel, 'String', [num2str(round(obj.controller.displayRange(4))) ' Hz']);
            set(obj.freqMinLabel, 'String', [num2str(round(obj.controller.displayRange(3))) ' Hz']);
            set(obj.otherLabel, 'String', sprintf('%.3g msec\n%.3g Hz', window / obj.audio.sampleRate / 2 * 1000, obj.audio.sampleRate / window / 2));
            
% TODO
%             % Add a text object to show the time and frequency of where the mouse is currently hovering.
%             obj.spectrogramTooltip = text(size(P, 2), size(P, 1), '', 'BackgroundColor', 'w', ...
%                 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', 'Visible', 'off');
        end
        
        
        function handled = keyWasPressed(obj, keyEvent)
            shiftDown = any(ismember(keyEvent.Modifier, 'shift'));
            ctrlDown = any(ismember(keyEvent.Modifier, 'control'));
            freqRange = (obj.controller.displayRange(4) - obj.controller.displayRange(3)) / 2;
            if strcmp(keyEvent.Key, 'leftbracket')
                if shiftDown
                    % Scroll up to higher frequencies.
                    obj.controller.displayRange = [obj.controller.displayRange(1:2) ...
                                                   min(floor(obj.audio.sampleRate / 2) - 1, obj.controller.displayRange(3) + freqRange) ...
                                                   min(floor(obj.audio.sampleRate / 2), obj.controller.displayRange(4) + freqRange)];
                elseif ctrlDown
                    % Halve the window size.
                    obj.controller.windowSize = max(64 / obj.audio.sampleRate, obj.controller.windowSize / 2);
                else
                    % Double the range of frequencies shown.
                    obj.controller.displayRange = [obj.controller.displayRange(1:2) ...
                                                   max(0,obj.controller.displayRange(3) - freqRange / 2) ...
                                                   min(floor(obj.audio.sampleRate / 2), obj.controller.displayRange(4) + freqRange / 2)];
                end
                %obj.updateAxes(obj.controller.displayRange);
                handled = true;
            elseif strcmp(keyEvent.Key, 'rightbracket')
                if shiftDown
                    % Scroll down to lower frequencies.
                    obj.controller.displayRange = [obj.controller.displayRange(1:2) ...
                                                   max(0, obj.controller.displayRange(3) - freqRange) ...
                                                   max(1, obj.controller.displayRange(4) - freqRange)];
                elseif ctrlDown
                    % Double the window size.
                    obj.controller.windowSize = min(1, obj.controller.windowSize * 2);
                else
                    % Halve the range of frequencies shown.
                    obj.controller.displayRange = [obj.controller.displayRange(1:2) ...
                                                   obj.controller.displayRange(3) + freqRange / 2 ...
                                                   obj.controller.displayRange(4) - freqRange / 2];
                end
                %obj.updateAxes(obj.controller.displayRange);
                handled = true;
            elseif keyEvent.Character == '|'
                % Reset to the defaults.
                obj.controller.windowSize = 0.001;
                obj.controller.displayRange = [obj.controller.displayRange(1:2) 0 floor(obj.audio.sampleRate / 2)];
                %obj.updateAxes(obj.controller.displayRange);
                handled = true;
            else
                handled = keyWasPressed@TimelinePanel(obj, keyEvent);
            end
        end
        
        
        function changeBoundingBoxColor(obj,reporter)
            i=1;
            while i<=length(obj.reporter) && (obj.reporter{i}~=reporter)
                i=i+1;
            end
            if i<=length(obj.reporter) && (obj.reporter{i}==reporter)
              for j=1:length(obj.bounding_boxes{i})
                switch(get(obj.bounding_boxes{i}(j),'type'))
                  case 'line'
                    set(obj.bounding_boxes{i}(j),'Color',reporter.featuresColor);
                  case 'patch'
                    set(obj.bounding_boxes{i}(j),'FaceColor',reporter.featuresColor);
                end
              end
            end
        end
        
        
        function deleteAllReporters(obj)
            for i=1:length(obj.reporter)
                j=1;
                while j<=length(obj.listeners) && (obj.listeners{j}.Source{1}~=obj.reporter{i})
                   j=j+1;
                end
                delete(obj.listeners{j});
                obj.listeners(j)=[];
                obj.reporter(i)=[];
                delete(obj.bounding_boxes{i});
                obj.bounding_boxes(i)=[];
            end
        end
        
        function addReporter(obj, reporter)
            i=1;
            while i<=length(obj.reporter) && (obj.reporter{i}~=reporter)
                i=i+1;
            end
            if(i==(length(obj.reporter)+1))
                obj.reporter{i}=reporter;
                obj.bounding_boxes{i}=obj.populateFeatures(obj.reporter{i});
                %obj.listeners{end+1} = addlistener(obj.reporter{i}, 'FeaturesDidChange', @(source, event)handleFeaturesDidChange(obj, source, event));
                obj.listeners{i} = addlistener(obj.reporter{i}, 'FeaturesDidChange', @(src,evt,dat)handleFeaturesDidChange(obj,src,evt,i));
            else
                obj.reporter(i)=[];
                delete(obj.bounding_boxes{i});
                obj.bounding_boxes(i)=[];
                i=1;
                while i<=length(obj.listeners) && (obj.listeners{i}.Source{1}~=reporter)
                    i=i+1;
                end
                delete(obj.listeners{i});
                obj.listeners(i)=[];
            end
        end
        
        
        function handleFeaturesDidChange(obj, ~, ~, idx)
           delete(obj.bounding_boxes{idx});
           obj.bounding_boxes{idx}=obj.populateFeatures(obj.reporter{idx});
        end
        
        
        function bounding_boxes=populateFeatures(obj,reporter)
          
            bounding_boxes=[];
            axes(obj.axes);
            
            featureTypes = reporter.featureTypes();
            
            spacing = 1 / length(featureTypes);
            axesPos = get(obj.axes, 'Position');
            
            % Draw the features that have been reported.
            features = reporter.features();
            for feature = features
                x0=feature.range(1);
                y0=feature.range(3);
                x1=feature.range(2);
                y1=feature.range(4);
                h=line([x0 x1 x1 x0 x0],[y0 y0 y1 y1 y0]);
                bounding_boxes(end+1)=h;
                set(h, 'Color', reporter.featuresColor);
                if isprop(feature,'HotPixels')
                    chan=find(cellfun(@(x) strcmp(x,obj.audio.filePath),...
                        cellfun(@(y) y.filePath, reporter.recording, 'uniformoutput', false)));
                    for i=1:length(feature.HotPixels)
                      idx=find(feature.HotPixels{i}{1}(:,3)==chan);
                      t=repmat(feature.HotPixels{i}{1}(idx,1)',5,1)+...
                        repmat(feature.HotPixels{i}{2}*[-0.5; +0.5; +0.5; -0.5; -0.5],1,length(idx));
                      f=repmat(feature.HotPixels{i}{1}(idx,2)',5,1)+...
                        repmat(feature.HotPixels{i}{3}*[-0.5; -0.5; +0.5; +0.5; -0.5],1,length(idx));
                      h=patch(t+reporter.detectedTimeRanges(1),f,reporter.featuresColor);
                      set(h,'edgecolor','none');
                      bounding_boxes=[bounding_boxes h'];
                    end
                end
            end
        end
	
      
        function set.saturation(obj, saturation)
            if any(obj.saturation ~= saturation)
                obj.saturation = saturation;
        
                obj.updateAxes(obj.controller.displayRange);
            end
        end
      
	end
	
end
