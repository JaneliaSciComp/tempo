classdef FeaturesPanel < TimelinePanel

	properties
        reporter
    end
    
    properties (Transient)
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
			obj = obj@TimelinePanel(reporter.controller, reporter);
            
            obj.panelType = 'Features';
            
            obj.reporter = reporter;
            obj.setTitle(reporter.name);
            
            obj.featureHandles = obj.populateFeatures();
        end
        
        
	    function createControls(obj, ~, varargin)
            % For new panels the reporter comes in varargin.
            % For panels loaded from a workspace varargin will be empty but the reporter is already set.
            if isempty(obj.reporter)
                obj.reporter = varargin{1};
            end
            
            obj.featureHandles = obj.populateFeatures(obj.reporter);
            
            % Listen for whenever the reporter changes its features.
            obj.featureChangeListener = addlistener(obj.reporter, 'FeaturesDidChange', @(source, event)handleFeaturesDidChange(obj, source, event));
            obj.listeners{end + 1} = obj.featureChangeListener;
        end
        
        
        function addActionMenuItems(obj, actionMenu)
            if isa(obj.reporter, 'FeatureDetector')
                uimenu(actionMenu, ...
                    'Label', 'Show Reporter Settings', ...
                    'Callback', @(source, event)handleShowReporterSettings(obj, source, event));
                uimenu(actionMenu, ...
                    'Label', 'Detect Features in Selection', ...
                    'Callback', @(source, event)handleDetectFeaturesInSelection(obj, source, event), ...
                    'Tag', 'detectFeaturesInSelection');
            end
            uimenu(actionMenu, ...
                    'Label', 'Export Features...', ...
                    'Callback', @(source, event)exportFeatures(obj.reporter), ...
                    'Tag', 'exportFeatures');
            uimenu(actionMenu, ...
                    'Label', 'Set Features Name...', ...
                    'Callback', @(source, event)handleSetFeaturesName(obj, source, event), ...
                    'Tag', 'setFeaturesName');
            uimenu(actionMenu, ...
                    'Label', 'Set Features Color...', ...
                    'Callback', @(source, event)handleSetFeaturesColor(obj, source, event), ...
                    'Tag', 'setFeaturesColor');
            uimenu(actionMenu, ...
                    'Label', 'Add New Feature with Selection...', ...
                    'Callback', @(source, event)handleAddNewFeature(obj, source, event), ...
                    'Tag', 'setFeaturesColor');
            uimenu(actionMenu, ...
                    'Label', 'Draw/Clear Bounding Boxes', ...
                    'Callback', @(source, event)handleBoundingBoxes(obj, source, event), ...
                    'Separator', 'off');
        end
        
        
        function updateActionMenu(obj, ~)
            selectionIsEmpty = obj.controller.selectedRange(2) == obj.controller.selectedRange(1);
            if isa(obj.reporter, 'FeatureDetector')
                set(obj.actionMenuItem('detectFeaturesInSelection'), 'Enable', onOff(~selectionIsEmpty));
            end
        end
        
        
        function handleFeaturesDidChange(obj, ~, ~)
            obj.featureHandles=obj.populateFeatures();
        end
        
        
        function hh=populateFeatures(obj, reporter)
            if nargin < 2
                reporter = obj.reporter;
            end
            
            hh=[];
            
            if isempty(reporter)
                return;
            end
            
            axes(obj.axes);
            cla;
            
            obj.featureTypeLabels= {};
            obj.featureTypeShadows = {};
            
            featureTypes = reporter.featureTypes();
            
            spacing = 1 / length(featureTypes);
            axesPos = get(obj.axes, 'Position');
            
            % Indicate the time spans in which feature detection has occurred for each reporter.
            lastTime = 0.0;
            if isa(reporter, 'FeatureDetector')
                for j = 1:size(reporter.detectedTimeRanges, 1)
                    detectedTimeRange = reporter.detectedTimeRanges(j, :);
                    
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
            features = reporter.features();
            if isempty(features)
                lowFreqs = [];
                highFreqs = [];
            else
                lowFreqs = [features.lowFreq];
                highFreqs = [features.highFreq];
            end
            minFreq = min(lowFreqs(lowFreqs > -Inf));
            if isempty(minFreq)
                minFreq = -Inf;
            end
            maxFreq = max(highFreqs(highFreqs < Inf));
            if isempty(maxFreq)
                maxFreq = Inf;
            end
            for feature = features
                y = find(strcmp(featureTypes, feature.type));
                if isempty(feature.contextualMenu)
                    if feature.startTime == feature.endTime
                        label = [feature.type ' @ ' secondstr(feature.startTime, obj.controller.timeLabelFormat)];
                    else
                        label = [feature.type ' @ ' secondstr(feature.startTime, obj.controller.timeLabelFormat) ' - ' secondstr(feature.endTime, obj.controller.timeLabelFormat)];
                    end
                    feature.contextualMenu = uicontextmenu();
                    uimenu(feature.contextualMenu, 'Tag', 'reporterNameMenuItem', 'Label', label, 'Enable', 'off');
                    uimenu(feature.contextualMenu, 'Tag', 'showFeaturePropertiesMenuItem', 'Label', 'Show Feature Properties', 'Callback', @(source, event)handleShowFeatureProperties(obj, source, event), 'Separator', 'on');
                    uimenu(feature.contextualMenu, 'Tag', 'removeFeatureMenuItem', 'Label', 'Remove Feature...', 'Callback', @(source, event)handleRemoveFeature(obj, source, event), 'Separator', 'off');
                end
                yCen = (length(featureTypes) - y + 0.5) * spacing;
                if feature.startTime == feature.endTime
                    h=text(feature.startTime, yCen, 'x', ...
                           'HorizontalAlignment', 'center', ...
                           'VerticalAlignment', 'middle', ...
                           'UIContextMenu', feature.contextualMenu, ...
                           'Color', reporter.featuresColor, ...
                           'Clipping', 'on', ...
                           'ButtonDownFcn', @(source, event)handleSelectFeature(obj, source, event), ...
                           'UserData', feature);
                    hh=[hh h];
                else
                    x0 = feature.startTime;
                    x1 = feature.endTime;
                    
                    minY = yCen - spacing * 0.45;
                    maxY = minY + spacing * 0.9;
                    if feature.lowFreq > -Inf && feature.highFreq < Inf
                        % Scale the upper and lower edges of the patch to the feature's frequency range.
                        y0 = (feature.lowFreq - minFreq) / (maxFreq - minFreq) * (maxY - minY) + minY;
                        y1 = (feature.highFreq - minFreq) / (maxFreq - minFreq) * (maxY - minY) + minY;
                    else
                        % Have the patch cover the full vertical space for this feature type.
                        y0 = minY;
                        y1 = maxY;
                    end
                    
                    fillColor = reporter.featuresColor;
                    fillColor = fillColor + ([1 1 1] - fillColor) * 0.5;
                    
                    h=patch([x0 x1 x1 x0 x0], [y0 y0 y1 y1 y0], fillColor, ...
                            'EdgeColor', reporter.featuresColor, ...
                            'UIContextMenu', feature.contextualMenu, ...
                            'ButtonDownFcn', @(source, event)handleSelectFeature(obj, source, event), ...
                            'UserData', feature);
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
                newTime = max([0 min([obj.controller.duration obj.controller.currentTime + timeChange])]);
                if shiftDown
                    if obj.controller.currentTime == obj.controller.selectedRange(1)
                        obj.controller.selectedRange = [sort([obj.controller.selectedRange(2) newTime]) obj.selectedRange(3:4)];
                    else
                        obj.controller.selectedRange = [sort([newTime obj.controller.selectedRange(1)]) obj.selectedRange(3:4)];
                    end
                else
                    obj.controller.selectedRange = [newTime newTime obj.selectedRange(3:4)];
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
        
        
        function handleShowReporterSettings(obj, ~, ~)
            obj.reporter.showSettings();
        end
        
        
        function handleDetectFeaturesInSelection(obj, ~, ~)
            % Detect features in the current selection using an existing detector.
            % TODO: don't add duplicate features if selection overlaps already detected region?
            %       or reduce selection to not overlap before detection?
            
            obj.reporter.startProgress();
            obj.featureChangeListener.Enabled = false;
            try
                n = obj.reporter.detectFeatures(obj.controller.selectedRange);
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
        
        
        function handleSetFeaturesName(obj, ~, ~)
            newName = inputdlg('Enter a new name for the features:', 'Tempo', 1, {obj.reporter.name});
            if ~isempty(newName)
                obj.reporter.name = newName{1};
                obj.setTitle(obj.reporter.name);
            end
        end
        
        
        function handleSetFeaturesColor(obj, ~, ~)
            newColor = uisetcolor(obj.reporter.featuresColor);
            if length(newColor) == 3
                obj.reporter.featuresColor = newColor;
                fillColor = obj.reporter.featuresColor;
                fillColor = fillColor + ([1 1 1] - fillColor) * 0.5;
                set(obj.featureHandles(strcmp(get(obj.featureHandles, 'Type'), 'patch')), 'FaceColor', fillColor, 'EdgeColor', obj.reporter.featuresColor);
                set(obj.featureHandles(strcmp(get(obj.featureHandles, 'Type'), 'text')), 'Color', obj.reporter.featuresColor);
                for j = 1:length(obj.controller.timelinePanels)
                    panel = obj.controller.timelinePanels{j};
                    if isa(panel, 'SpectrogramPanel')
                        panel.changeBoundingBoxColor(obj.reporter);
                    end
                end
            end
        end
        
        
        function handleAddNewFeature(obj, ~, ~)
            % Add a new feature using the current selection.
            
            % Figure out which type of feature it should be.
            featureTypes = obj.reporter.featureTypes();
            if length(featureTypes) == 1
                featureType = featureTypes{1};
            else
                choice = listdlg('PromptString', 'Choose which importer to use:', ...
                                 'SelectionMode', 'Single', ...
                                 'ListString', featureTypes);
                if isempty(choice)
                    featureType = [];
                else
                    featureType = featureTypes{choice(1)};
                end
            end
            
            % Add the feature
            if ~isempty(featureType)
                feature = Feature(featureType, obj.controller.selectedRange);
                obj.reporter.addFeature(feature);
            end
        end
        
        
        function handleBoundingBoxes(obj, ~, ~)
%TODO:  make this work for drosophila
          for i = 1:length(obj.controller.timelinePanels)
              panel = obj.controller.timelinePanels{i};
              if isa(panel, 'SpectrogramPanel')
                  panel.addReporter(obj.reporter);
              end
          end
        end
        
        
        function handleShowFeatureProperties(obj, ~, ~) %#ok<INUSD>
            feature = get(gco, 'UserData'); % Get the feature instance from the clicked rectangle's UserData
            
            msg = ['Type: ' feature.type char(10) char(10)];
            if feature.startTime == feature.endTime
                msg = [msg 'Time: ' secondstr(feature.startTime, 1) char(10)];
            else
                msg = [msg 'Time: ' secondstr(feature.startTime, 1) ' - ' secondstr(feature.endTime, 1) '  (' secondstr(feature.duration, 0) ')' char(10)];
            end
            if ~isinf(feature.lowFreq) && ~isinf(feature.highFreq)
                msg = sprintf('%sFrequency: %.0f - %.0f Hz\n', msg, feature.lowFreq, feature.highFreq);
            end
            props = sort(properties(feature));
            ignoreProps = {'type', 'range', 'startTime', 'endTime', 'duration', 'highFreq', 'lowFreq', 'contextualMenu'};
            addedSeparator = false;
            for i = 1:length(props)
                if ~ismember(props{i}, ignoreProps)
                    value = feature.(props{i});
                    if ~iscell(value)
                        if ~addedSeparator
                            msg = [msg char(10) 'Other Properties:' char(10)]; %#ok<AGROW>
                            addedSeparator = true;
                        end
                        if isnumeric(value)
                            value = num2str(value);
                        end
                        msg = [msg props{i} ' = ' value char(10)]; %#ok<AGROW>
                    end
                end
            end
            if isempty(msg)
                msg = 'This feature has no properties.';
            end
            msgbox(msg, 'Feature Properties', 'modal');
        end
        
        
        function handleRemoveFeature(obj, ~, ~)
            feature = get(gco, 'UserData'); % Get the feature instance from the clicked rectangle's UserData
            
            answer = questdlg('Are you sure you wish to remove this feature?', 'Removing Feature', 'Cancel', 'Remove', 'Cancel');
            if strcmp(answer, 'Remove')
                obj.reporter.removeFeature(feature);
            end
        end
        
        
        function handleSelectFeature(obj, ~, ~)
            feature = get(gco, 'UserData'); % Get the feature instance from the clicked rectangle's UserData
            
            obj.controller.selectRange(feature.range);
        end
        
        
        function close = shouldClose(obj)
            close = strcmp(questdlg('Are you sure you wish to close these features?', 'Tempo', 'Close', 'Cancel', 'Close'), 'Close');
        end
        
    end
	
end
