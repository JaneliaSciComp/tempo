classdef FeaturesPanel < TimelinePanel

	properties
        reporter
        
        featureTypeLabels
        featureTypeShadows
        featureHandles
        
        contextualMenu
        detectFeaturesInSelectionMenuItem
        showReporterSettingsMenuItem
        
        featureChangeListener
	end
	
	methods
	
		function obj = FeaturesPanel(reporter)
			obj = obj@TimelinePanel(reporter.controller);
            
            obj.reporter = reporter;
            
            obj.featureHandles=obj.populateFeatures();
            
            % Listen for whenever the reporter changes its features.
            obj.featureChangeListener = addlistener(obj.reporter, 'FeaturesDidChange', @(source, event)handleFeaturesDidChange(obj, source, event));
            obj.listeners{end + 1} = obj.featureChangeListener;
        end
        
        
        function createControls(obj, ~) %#ok<INUSD>
        end
        
        
        function handleFeaturesDidChange(obj, ~, ~)
            obj.featureHandles=obj.populateFeatures();
        end
        
        
        function hh=populateFeatures(obj)
            hh=[];
            if isempty(obj.contextualMenu)
                obj.contextualMenu = uicontextmenu('Callback', @(source, event)enableReporterMenuItems(obj, source, event));
                uimenu(obj.contextualMenu, 'Label', obj.reporter.name, 'Enable', 'off');
                obj.showReporterSettingsMenuItem = uimenu(obj.contextualMenu, 'Label', 'Show Reporter Settings', 'Callback', @(source, event)showReporterSettings(obj, source, event), 'Separator', 'on');
                obj.detectFeaturesInSelectionMenuItem = uimenu(obj.contextualMenu, 'Label', 'Detect Features in Selection', 'Callback', @(source, event)detectFeaturesInSelection(obj, source, event));
                uimenu(obj.contextualMenu, 'Label', 'Save Detected Features...', 'Callback', @(source, event)saveFeatures(obj, source, event));
                uimenu(obj.contextualMenu, 'Label', 'Set Features Color...', 'Callback', @(source, event)setFeaturesColor(obj, source, event));
                uimenu(obj.contextualMenu, 'Label', 'Draw/Clear Bounding Boxes', 'Callback', @(source, event)handleBoundingBoxes(obj, source, event), 'Separator', 'off');
                uimenu(obj.contextualMenu, 'Label', 'Remove Reporter...', 'Callback', @(source, event)removeReporter(obj, source, event), 'Separator', 'on');
                set(obj.axes, 'UIContextMenu', obj.contextualMenu);
            end
            
            axes(obj.axes);
            cla;
            
            obj.featureTypeLabels= {};
            obj.featureTypeShadows = {};
            
            featureTypes = obj.reporter.featureTypes();
            
            spacing = 1 / length(featureTypes);
            axesPos = get(obj.axes, 'Position');
            
            % Indicate the time spans in which feature detection has occurred for each reporter.
            lastTime = 0.0;
            if isa(obj.reporter, 'FeatureDetector')
                for j = 1:size(obj.reporter.detectedTimeRanges, 1)
                    detectedTimeRange = obj.reporter.detectedTimeRanges(j, :);
                    
                    if detectedTimeRange(1) > lastTime
                        % Add a gray background before the current range.
                        rectangle('Position', [lastTime 0 detectedTimeRange(1) - lastTime 1], 'FaceColor', [0.9 0.9 0.9], 'EdgeColor', 'none', 'HitTest', 'off');
                    end
                    
                    lastTime = detectedTimeRange(2);
                end
                if lastTime < obj.controller.duration
                    rectangle('Position', [lastTime 0 obj.controller.duration - lastTime 1], 'FaceColor', [0.9 0.9 0.9], 'EdgeColor', 'none', 'HitTest', 'off');
                end
            end
            
            % Draw the features that have been reported.
            features = obj.reporter.features();
            for feature = features
                y = find(strcmp(featureTypes, feature.type));
                if isempty(feature.contextualMenu)
                    if feature.sampleRange(1) == feature.sampleRange(2)
                        label = [feature.type ' @ ' secondstr(feature.sampleRange(1), obj.controller.timeLabelFormat)];
                    else
                        label = [feature.type ' @ ' secondstr(feature.sampleRange(1), obj.controller.timeLabelFormat) ' - ' secondstr(feature.sampleRange(2), obj.controller.timeLabelFormat)];
                    end
                    feature.contextualMenu = uicontextmenu();
                    uimenu(feature.contextualMenu, 'Tag', 'reporterNameMenuItem', 'Label', label, 'Enable', 'off');
                    uimenu(feature.contextualMenu, 'Tag', 'showFeaturePropertiesMenuItem', 'Label', 'Show Feature Properties', 'Callback', @(source, event)showFeatureProperties(obj, source, event), 'Separator', 'on');
                    uimenu(feature.contextualMenu, 'Tag', 'removeFeatureMenuItem', 'Label', 'Remove Feature...', 'Callback', @(source, event)removeFeature(obj, source, event), 'Separator', 'off');
                end
                yCen = (length(featureTypes) - y + 0.5) * spacing;
                if feature.sampleRange(1) == feature.sampleRange(2)
                    h=text(feature.sampleRange(1), yCen, 'x', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'UIContextMenu', feature.contextualMenu, 'Color', obj.reporter.featuresColor, 'UserData', feature);
                    hh=[hh h];
                else
                    fillColor = obj.reporter.featuresColor;
                    fillColor = fillColor + ([1 1 1] - fillColor) * 0.5;
                    %rectangle('Position', [feature.sampleRange(1), yCen - spacing * 0.45, feature.sampleRange(2) - feature.sampleRange(1), spacing * 0.9], 'FaceColor', fillColor, 'EdgeColor', obj.reporter.featuresColor, 'UIContextMenu', feature.contextualMenu, 'UserData', feature);
                    x0=feature.sampleRange(1);
                    y0=yCen - spacing * 0.45;
                    x1=x0+feature.sampleRange(2) - feature.sampleRange(1);
                    y1=y0+spacing * 0.9;
                    h=patch([x0 x1 x1 x0 x0],[y0 y0 y1 y1 y0],fillColor);
                    set(h, 'EdgeColor', obj.reporter.featuresColor, 'UIContextMenu', feature.contextualMenu, 'UserData', feature);
                    hh=[hh h];
                end
            end
            
            % Draw the feature type names.
            for y = 1:length(featureTypes)
                featureType = featureTypes{y};
                obj.featureTypeShadows{end + 1} = text(6, (length(featureTypes) - y + 0.75) * spacing * axesPos(4) - 1, featureType, 'VerticalAlignment', 'middle', 'Units', 'pixels', 'HitTest', 'off', 'Color', [0.75 0.75 0.75]);
                obj.featureTypeLabels{end + 1} = text(5, (length(featureTypes) - y + 0.75) * spacing * axesPos(4), featureType, 'VerticalAlignment', 'middle', 'Units', 'pixels', 'HitTest', 'off', 'Color', [0.25 0.25 0.25]);
            end
        end
        
        
        function resizeControls(obj, panelSize)
            % Update the position of the feature type names.
            spacing = 1 / length(obj.featureTypeLabels);
            for i = 1:length(obj.featureTypeLabels)
                set(obj.featureTypeShadows{i}, 'Position', [6, (length(obj.featureTypeLabels) - i + 0.65) * spacing * panelSize(2) - 1]);
                set(obj.featureTypeLabels{i}, 'Position', [5, (length(obj.featureTypeLabels) - i + 0.65) * spacing * panelSize(2)]);
            end
        end
        
        
        function handled = keyWasPressed(obj, keyEvent)
            % Handle option/alt arrow keys to jump from feature to feature.
            % TODO: how will this work with multiple panels?
            
            timeChange = 0;
            shiftDown = any(ismember(keyEvent.Modifier, 'shift'));
            if any(ismember(keyEvent.Modifier, 'alt'));
                if strcmp(keyEvent.Key, 'leftarrow')
                    handles = updateFeatureTimes(handles);
                    earlierFeatureTimes = handles.featureTimes(handles.featureTimes < handles.currentTime);
                    if isempty(earlierFeatureTimes)
                        beep;
                    else
                        timeChange = earlierFeatureTimes(end) - handles.currentTime;
                    end
                elseif strcmp(keyEvent.Key, 'rightarrow')
                    handles = updateFeatureTimes(handles);
                    laterFeatureTimes = handles.featureTimes(handles.featureTimes > handles.currentTime);
                    if isempty(laterFeatureTimes)
                        beep;
                    else
                        timeChange = laterFeatureTimes(1) - handles.currentTime;
                    end
                end
            end
            
            if timeChange ~= 0
                newTime = max([0 min([obj.controller.maxMediaTime obj.controller.currentTime + timeChange])]);
                if shiftDown
                    if obj.controller.currentTime == obj.controller.selectedTime(1)
                        obj.controller.selectedTime = sort([obj.controller.selectedTime(2) newTime]);
                    else
                        obj.controller.selectedTime = sort([newTime obj.controller.selectedTime(1)]);
                    end
                else
                    obj.controller.selectedTime = [newTime newTime];
                end
                obj.controller.currentTime = newTime;
                obj.controller.centerDisplayAtTime(newTime);
                
                handled = true;
            else
                handled = obj.reporter.keyWasPressed(keyEvent);
                
                if ~handled
                    handled = keyWasPressed@TimelinePanel(obj, keyEvent);
                end
            end
        end
        
        
        function enableReporterMenuItems(obj, ~, ~)
            if isa(obj.reporter, 'FeatureDetector') && (obj.controller.selectedTime(2) ~= obj.controller.selectedTime(1))
                set(obj.detectFeaturesInSelectionMenuItem, 'Enable', 'on');
            else
                set(obj.detectFeaturesInSelectionMenuItem, 'Enable', 'off');
            end
            if isa(obj.reporter, 'FeatureDetector')
                set(obj.showReporterSettingsMenuItem, 'Enable', 'on');
            else
                set(obj.showReporterSettingsMenuItem, 'Enable', 'off');
            end
        end
        
        
        function showReporterSettings(obj, ~, ~)
            obj.reporter.showSettings();
        end
        
        
        function detectFeaturesInSelection(obj, ~, ~)
            % Detect features in the current selection using an existing detector.
            % TODO: don't add duplicate features if selection overlaps already detected region?
            %       or reduce selection to not overlap before detection?
            
            obj.reporter.startProgress();
            obj.featureChangeListener.Enabled = false;
            try
                n = obj.reporter.detectFeatures(obj.controller.selectedTime);
                obj.featureChangeListener.Enabled = true;
                obj.reporter.endProgress();
                
                if n == 0
                    waitfor(msgbox('No additional features were detected.', obj.reporter.typeName(), 'warn', 'modal'));
                else
                    obj.featureHandles=obj.populateFeatures();
                end
                
% TODO:                handles = updateFeatureTimes(handles);
            catch ME
                obj.featureChangeListener.Enabled = true;
                obj.reporter.endProgress();
                rethrow(ME);
            end
        end
        
        
        function setFeaturesColor(obj, ~, ~)
            newColor = uisetcolor(obj.reporter.featuresColor);
            if length(newColor) == 3
                obj.reporter.featuresColor = newColor;
%                 syncGUIWithTime(handles);
                fillColor = obj.reporter.featuresColor;
                fillColor = fillColor + ([1 1 1] - fillColor) * 0.5;
                set(obj.featureHandles,'FaceColor',fillColor,'EdgeColor',obj.reporter.featuresColor);
                for j = 1:length(obj.controller.otherPanels)
                    panel = obj.controller.otherPanels{j};
                    if isa(panel, 'SpectrogramPanel')
                        panel.changeBoundingBoxColor(obj.reporter);
                    end
                end
            end
        end
        
        
        function removeReporter(obj, ~, ~)
            obj.controller.removeFeaturePanel(obj);
        end
        
        
        function saveFeatures(obj, ~, ~)
            % TODO: default name to recording used by detector
            obj.controller.saveFeatures({obj.reporter});
        end
        
        
        function handleBoundingBoxes(obj, ~, ~) %#ok<INUSD>
%TODO:  make this work for drosophila
          for i = 1:length(obj.controller.otherPanels)
              panel = obj.controller.otherPanels{i};
              if isa(panel, 'SpectrogramPanel')
                  panel.addReporter(obj.reporter);
              end
          end
        end
        
        
        function showFeatureProperties(obj, ~, ~) %#ok<INUSD>
            feature = get(gco, 'UserData'); % Get the feature instance from the clicked rectangle's UserData
            
            msg = '';
            props = sort(properties(feature));
            ignoreProps = {'type', 'sampleRange', 'contextualMenu'};
            for i = 1:length(props)
                if ~ismember(props{i}, ignoreProps)
                    value = feature.(props{i});
                    if isnumeric(value)
                        value = num2str(value);
                    end
                    msg = [msg props{i} ' = ' value char(10)]; %#ok<AGROW>
                end
            end
            if isempty(msg)
                msg = 'This feature has no properties.';
            end
            msg = ['Properties:' char(10) char(10) msg];
            msgbox(msg, 'Feature Properties', 'modal');
        end
        
        
        function removeFeature(obj, ~, ~)
            feature = get(gco, 'UserData'); % Get the feature instance from the clicked rectangle's UserData
            
            answer = questdlg('Are you sure you wish to remove this feature?', 'Removing Feature', 'Cancel', 'Remove', 'Cancel');
            if strcmp(answer, 'Remove')
                obj.reporter.removeFeature(feature);
            end
        end
        
	end
	
end
