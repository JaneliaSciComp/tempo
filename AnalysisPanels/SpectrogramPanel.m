classdef SpectrogramPanel < TimelinePanel

	properties
        audio
        
        imageHandle
        
        freqMaxLabel
        freqMinLabel
        otherLabel
        
        noDisplayLabel

        reporter
        bounding_boxes
	end
	
	methods
	
		function obj = SpectrogramPanel(controller, recording)
			obj = obj@TimelinePanel(controller);
            
            obj.audio = recording;
            
            obj.controller.windowSize = 0.001;
            obj.controller.freqMin = 0;
            obj.controller.freqMax = floor(recording.sampleRate / 2);
            
            obj.listeners{end + 1} = addlistener(obj.controller, 'windowSize', 'PostSet', ...
                @(source, event)handleSpectrogramParametersChanged(obj, source, event));
            obj.listeners{end + 1} = addlistener(obj.controller, 'freqMin', 'PostSet', ...
                @(source, event)handleSpectrogramParametersChanged(obj, source, event));
            obj.listeners{end + 1} = addlistener(obj.controller, 'freqMax', 'PostSet', ...
                @(source, event)handleSpectrogramParametersChanged(obj, source, event));
        end
        
        function handleSpectrogramParametersChanged(obj, ~, ~)
            obj.updateAxes(obj.controller.displayedTimeRange());
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
        
        
        function updateAxes(obj, timeRange)
            if isempty(obj.audio)
                return
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
                audioData = obj.audio.dataInTimeRange(timeRange);
                set(obj.noDisplayLabel, 'Visible', 'off');

                if ~isempty(audioData)
                    set(obj.axes, 'CLimMode', 'auto')
                    % Get the raw spectrogram data.
                    % TODO: any way to cache this to allow viewing at larger scales?
                    [~, f, ~, P] = spectrogram(double(audioData), window, [], [], obj.audio.sampleRate);
                    
                    % Restrict to the frequencies of interest.
                    idx = (f > obj.controller.freqMin) & (f < obj.controller.freqMax);
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
            
%            set(obj.axes, 'YLim', [1 size(P, 1)]);
            set(obj.axes, 'YLim', freqRange);
            
%            set(obj.imageHandle, 'CData', P, 'XData', timeRange, 'YData', [1 size(P, 1)]);
            set(obj.imageHandle, 'CData', P, 'XData', timeRange, 'YData', freqRange);
            
            set(obj.freqMaxLabel, 'String', [num2str(round(obj.controller.freqMax)) ' Hz']);
            set(obj.freqMinLabel, 'String', [num2str(round(obj.controller.freqMin)) ' Hz']);
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
                    tmp=(obj.controller.freqMax - obj.controller.freqMin) / 2;
                    obj.controller.freqMin = min(floor(obj.audio.sampleRate / 2) - 1, obj.controller.freqMin + tmp);
                    obj.controller.freqMax = min(floor(obj.audio.sampleRate / 2), obj.controller.freqMax + tmp);
                elseif ctrlDown
                    % Halve the window size.
                    obj.controller.windowSize = max(64 / obj.audio.sampleRate, obj.controller.windowSize / 2);
                else
                    % Double the range of frequencies shown.
                    tmp = (obj.controller.freqMax - obj.controller.freqMin) / 2;
                    obj.controller.freqMin = max(0,obj.controller.freqMin - tmp);
                    obj.controller.freqMax = min(floor(obj.audio.sampleRate / 2), obj.controller.freqMax + tmp);
                end
                %obj.updateAxes(obj.controller.displayedTimeRange());
                handled = true;
            elseif strcmp(keyEvent.Key, 'rightbracket')
                if shiftDown
                    % Scroll down to lower frequencies.
                    tmp= (obj.controller.freqMax - obj.controller.freqMin) / 2;
                    obj.controller.freqMin = max(0, obj.controller.freqMin - tmp);
                    obj.controller.freqMax = max(1, obj.controller.freqMax - tmp);
                elseif ctrlDown
                    % Double the window size.
                    obj.controller.windowSize = min(1, obj.controller.windowSize * 2);
                else
                    % Halve the range of frequencies shown.
                    tmp = (obj.controller.freqMax - obj.controller.freqMin) / 4;
                    obj.controller.freqMin = obj.controller.freqMin + tmp;
                    obj.controller.freqMax = obj.controller.freqMax - tmp;
                end
                %obj.updateAxes(obj.controller.displayedTimeRange());
                handled = true;
            elseif keyEvent.Character == '|'
                % Reset to the defaults.
                obj.controller.windowSize = 0.001;
                obj.controller.freqMin = 0;
                obj.controller.freqMax = floor(obj.audio.sampleRate / 2);
                %obj.updateAxes(obj.controller.displayedTimeRange());
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
          set(obj.bounding_boxes{i},'Color',reporter.featuresColor);
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
%          if isempty(obj.contextualMenu)
%              obj.contextualMenu = uicontextmenu('Callback', @(source, event)enableReporterMenuItems(obj, source, event));
%              uimenu(obj.contextualMenu, 'Label', obj.reporter.name, 'Enable', 'off');
%              obj.showReporterSettingsMenuItem = uimenu(obj.contextualMenu, 'Label', 'Show Reporter Settings', 'Callback', @(source, event)showReporterSettings(obj, source, event), 'Separator', 'on');
%              obj.detectFeaturesInSelectionMenuItem = uimenu(obj.contextualMenu, 'Label', 'Detect Features in Selection', 'Callback', @(source, event)detectFeaturesInSelection(obj, source, event));
%              uimenu(obj.contextualMenu, 'Label', 'Save Detected Features...', 'Callback', @(source, event)saveFeatures(obj, source, event));
%              uimenu(obj.contextualMenu, 'Label', 'Set Features Color...', 'Callback', @(source, event)setFeaturesColor(obj, source, event));
%              uimenu(obj.contextualMenu, 'Label', 'Draw Bounding Boxes', 'Callback', @(source, event)drawBoundingBoxes(obj, source, event), 'Separator', 'off');
%              uimenu(obj.contextualMenu, 'Label', 'Remove Reporter...', 'Callback', @(source, event)removeReporter(obj, source, event), 'Separator', 'on');
%              set(obj.axes, 'UIContextMenu', obj.contextualMenu);
%          end
          
          bounding_boxes=[];
          axes(obj.axes);
%          cla;
          
%          obj.featureTypeLabels= {};
%          obj.featureTypeShadows = {};
          
          featureTypes = reporter.featureTypes();
          
          spacing = 1 / length(featureTypes);
          axesPos = get(obj.axes, 'Position');
          
          % Indicate the time spans in which feature detection has occurred for each reporter.
%          lastTime = 0.0;
%          if isa(obj.reporter, 'FeatureDetector')
%              for j = 1:size(obj.reporter.detectedTimeRanges, 1)
%                  detectedTimeRange = obj.reporter.detectedTimeRanges(j, :);
%                  
%                  if detectedTimeRange(1) > lastTime
%                      % Add a gray background before the current range.
%                      rectangle('Position', [lastTime 0 detectedTimeRange(1) - lastTime 1], 'FaceColor', [0.9 0.9 0.9], 'EdgeColor', 'none', 'HitTest', 'off');
%                  end
%                  
%                  lastTime = detectedTimeRange(2);
%              end
%              if lastTime < obj.controller.duration
%                  rectangle('Position', [lastTime 0 obj.controller.duration - lastTime 1], 'FaceColor', [0.9 0.9 0.9], 'EdgeColor', 'none', 'HitTest', 'off');
%              end
%          end
          
          % Draw the features that have been reported.
          features = reporter.features();
          for feature = features
              y = find(strcmp(featureTypes, feature.type));
%              if isempty(feature.contextualMenu)
%                  if feature.sampleRange(1) == feature.sampleRange(2)
%                      label = [feature.type ' @ ' secondstr(feature.sampleRange(1), obj.controller.timeLabelFormat)];
%                  else
%                      label = [feature.type ' @ ' secondstr(feature.sampleRange(1), obj.controller.timeLabelFormat) ' - ' secondstr(feature.sampleRange(2), obj.controller.timeLabelFormat)];
%                  end
%                  feature.contextualMenu = uicontextmenu();
%                  uimenu(feature.contextualMenu, 'Tag', 'reporterNameMenuItem', 'Label', label, 'Enable', 'off');
%                  uimenu(feature.contextualMenu, 'Tag', 'showFeaturePropertiesMenuItem', 'Label', 'Show Feature Properties', 'Callback', @(source, event)showFeatureProperties(obj, source, event), 'Separator', 'on');
%                  uimenu(feature.contextualMenu, 'Tag', 'removeFeatureMenuItem', 'Label', 'Remove Feature...', 'Callback', @(source, event)removeFeature(obj, source, event), 'Separator', 'off');
%              end
%              yCen = (length(featureTypes) - y + 0.5) * spacing;
%              if feature.sampleRange(1) == feature.sampleRange(2)
%                  text(feature.sampleRange(1), yCen, 'x', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'UIContextMenu', feature.contextualMenu, 'Color', obj.reporter.featuresColor, 'UserData', feature);
%              else
%                  fillColor = obj.reporter.featuresColor;
%                  fillColor = fillColor + ([1 1 1] - fillColor) * 0.5;
                  %rectangle('Position', [feature.sampleRange(1), yCen - spacing * 0.45, feature.sampleRange(2) - feature.sampleRange(1), spacing * 0.9], 'FaceColor', fillColor, 'EdgeColor', obj.reporter.featuresColor, 'UIContextMenu', feature.contextualMenu, 'UserData', feature);
                  x0=feature.sampleRange(1);
                  y0=feature.FreqRange(1);
                  x1=feature.sampleRange(2);
                  y1=feature.FreqRange(2);
%                  h=patch([x0 x1 x1 x0 x0],[y0 y0 y1 y1 y0],fillColor);
                  h=line([x0 x1 x1 x0 x0],[y0 y0 y1 y1 y0]);
                  bounding_boxes(end+1)=h;
                  set(h, 'Color', reporter.featuresColor);
%                  set(h, 'EdgeColor', obj.reporter.featuresColor, 'UIContextMenu', feature.contextualMenu, 'UserData', feature);
%              end
          end
          
%          % Draw the feature type names.
%          for y = 1:length(featureTypes)
%              featureType = featureTypes{y};
%              obj.featureTypeShadows{end + 1} = text(6, (length(featureTypes) - y + 0.75) * spacing * axesPos(4) - 1, featureType, 'VerticalAlignment', 'middle', 'Units', 'pixels', 'HitTest', 'off', 'Color', [0.75 0.75 0.75]);
%              obj.featureTypeLabels{end + 1} = text(5, (length(featureTypes) - y + 0.75) * spacing * axesPos(4), featureType, 'VerticalAlignment', 'middle', 'Units', 'pixels', 'HitTest', 'off', 'Color', [0.25 0.25 0.25]);
%          end
      end
	
	end
	
end
