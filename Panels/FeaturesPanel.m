classdef FeaturesPanel < TimelinePanel

	properties
        reporter
    end
    
    properties (Transient)
        featureTypeLabels
        featureTypeShadows
        featureHandles
        
        timeRangeRectangles
        
        detectFeaturesInSelectionMenuItem
        showReporterSettingsMenuItem
        
        selectedFeature
        selectedFeatureHandle
        selectedFeatureListener
        selectedFeatureOriginalRange
        
        featureTypesListener
        featuresListener
        timeRangesListener
    end
    
	
	methods
	
		function obj = FeaturesPanel(reporter)
			obj = obj@TimelinePanel(reporter.controller, reporter);
            
            obj.panelType = 'Features';
            
            obj.reporter = reporter;
            obj.setTitle(reporter.name);
        end
        
        
	    function createControls(obj, ~, varargin)
            % For new panels the reporter comes in varargin.
            % For panels loaded from a workspace varargin will be empty but the reporter is already set.
            if isempty(obj.reporter)
                obj.reporter = varargin{1};
            end
            
            obj.updateFeatureTypes();
            obj.updateTimeRanges();
            obj.updateFeatures('add', obj.reporter.features());
            
            % Listen for whenever the reporter changes its features or types.
            obj.featureTypesListener = addlistener(obj.reporter, 'FeatureTypesDidChange', @(source, event)handleFeatureTypesDidChange(obj, source, event));
            obj.featuresListener = addlistener(obj.reporter, 'FeaturesDidChange', @(source, event)handleFeaturesDidChange(obj, source, event));
            if isa(obj.reporter, 'FeaturesDetector')
                obj.timeRangesListener = addlistener(obj.reporter, 'DetectedTimeRangesDidChange', @(source, event)handleTimeRangesDidChange(obj, source, event));
            end
        end
        
        
        function addActionMenuItems(obj, actionMenu)
            if isa(obj.reporter, 'FeaturesDetector') || isa(obj.reporter, 'FeaturesAnnotator')
                uimenu(actionMenu, ...
                    'Label', ['Show ' obj.reporter.typeName() ' Settings...'], ...
                    'Callback', @(source, event)handleShowReporterSettings(obj, source, event));
            end
            if isa(obj.reporter, 'FeaturesDetector')
                uimenu(actionMenu, ...
                    'Label', 'Detect Additional Features in Selection', ...
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
            if ~isa(obj.reporter, 'FeaturesAnnotator')
                uimenu(actionMenu, ...
                        'Label', 'Add New Feature with Selection...', ...
                        'Callback', @(source, event)handleAddNewFeature(obj, source, event), ...
                        'Tag', 'setFeaturesColor');
            end
            uimenu(actionMenu, ...
                    'Label', 'Draw/Clear Bounding Boxes', ...
                    'Callback', @(source, event)handleBoundingBoxes(obj, source, event), ...
                    'Separator', 'off');
            uimenu(actionMenu, ...
                    'Label', 'Show Feature Properties...', ...
                    'Callback', @(source, event)handleShowFeatureProperties(obj, source, event), ...
                    'Tag', 'showFeatureProperties');
        end
        
        
        function updateActionMenu(obj, ~)
            selectionIsEmpty = obj.controller.selectedRange(2) == obj.controller.selectedRange(1);
            if isa(obj.reporter, 'FeaturesDetector')
                set(obj.actionMenuItem('detectFeaturesInSelection'), 'Enable', onOff(~selectionIsEmpty));
            end
            set(obj.actionMenuItem('showFeatureProperties'), 'Enable', onOff(~isempty(obj.selectedFeature)));
        end
        
        
        function handleFeatureTypesDidChange(obj, ~, ~)
            obj.updateFeatureTypes();
        end
        
        
        function handleFeaturesDidChange(obj, ~, eventData)
            obj.updateFeatures(eventData.type, eventData.features);
        end
        
        
        function updateFeatureTypes(obj)
            if ~isempty(obj.reporter)
                axes(obj.axes);
                
                % Get rid of the previous elements.
                delete(obj.featureTypeLabels);
                delete(obj.featureTypeShadows);
                
                featureTypes = obj.reporter.featureTypes();
                typeCount = length(featureTypes);
                spacing = 1 / length(featureTypes);
                obj.featureTypeLabels = [];
                obj.featureTypeShadows = [];
                
                % Draw the feature type names with a shadow.
                axesPos = get(obj.axes, 'Position');
                for i = 1:typeCount
                    featureType = featureTypes{i};
                    obj.featureTypeShadows(i) = text(6, (typeCount - i + 0.75) * spacing * axesPos(4) - 1, ...
                                                     featureType, ...
                                                     'VerticalAlignment', 'middle', ...
                                                     'Units', 'pixels', ...
                                                     'HitTest', 'off', ...
                                                     'Color', [0.75 0.75 0.75]);
                    obj.featureTypeLabels(i) = text(5, (typeCount - i + 0.75) * spacing * axesPos(4), ...
                                                    featureType, ...
                                                    'VerticalAlignment', 'middle', ...
                                                    'Units', 'pixels', ...
                                                    'HitTest', 'off', ...
                                                    'Color', [0.25 0.25 0.25]);
                end
            end
        end
        
        
        function handleTimeRangesDidChange(obj, ~, ~)
            obj.updateTimeRanges();
        end
        
        
        function updateTimeRanges(obj)
            % Indicate the time spans in which feature detection has occurred.
            
            % Features importers and annotators don't have time ranges.
            % TODO: Would it help to do this for annotation to keep track of what's been looked at?
            %       How would you know what's been looked at?
            if ~isempty(obj.reporter) && isa(obj.reporter, 'FeaturesDetector')
                set(obj.controller.figure, 'CurrentAxes', obj.axes);
                
                % Clear any existing rectangles.
                delete(obj.timeRangeRectangles);
                obj.timeRangeRectangles = [];
                
                lastTime = 0.0;
                
                for j = 1:size(obj.reporter.detectedTimeRanges, 1)
                    detectedTimeRange = obj.reporter.detectedTimeRanges(j, :);
                    
                    if detectedTimeRange(1) > lastTime
                        % Add a gray background before the current range.
                        obj.timeRangeRectangles(end + 1) = rectangle('Position', [lastTime 0 detectedTimeRange(1) - lastTime 1], 'FaceColor', [0.9 0.9 0.9], 'EdgeColor', 'none', 'HitTest', 'off');
                    end
                    
                    lastTime = detectedTimeRange(2);
                end
                if lastTime < obj.controller.duration
                    obj.timeRangeRectangles(end + 1) = rectangle('Position', [lastTime 0 obj.controller.duration - lastTime 1], 'FaceColor', [0.9 0.9 0.9], 'EdgeColor', 'none', 'HitTest', 'off');
                end
            end
        end
        
        
        function updateFeatures(obj, updateType, features)
            % Add or remove the features from the display.
            % updateType will be 'add', 'update' or 'remove'.
            % Features is a cell array as there may be sub-classes.
            
            if ~isempty(obj.reporter)
                featureTypes = obj.reporter.featureTypes();
                
                if strcmp(updateType, 'add') || strcmp(updateType, 'update')
                    % Get the range of frequencies for the whole reporter so features can be positioned in that space.
                    featuresRange = obj.reporter.featuresRange();
                    minFreq = featuresRange(3);
                    maxFreq = featuresRange(4);
                    
                    spacing = 1 / length(featureTypes);
                    
                    % Add or update a text or patch for each feature.
                    for i = 1:length(features)
                        feature = features{i};
                        featureIsPoint = (feature.startTime == feature.endTime);
                        
                        if strcmp(updateType, 'add')
                            uiElement = [];
                        else
                            uiElement = findobj(obj.featureHandles, 'UserData', feature);
                            
                            if ~isempty(uiElement)
                                % If the feature changed from a range to a point or vice-versa then the UI element needs to be recreated.
                                uiElementType = get(uiElement, 'Type');
                                if (featureIsPoint && ~strcmp(uiElementType, 'text')) || ...
                                   (~featureIsPoint && ~strcmp(uiElementType, 'patch'))
                                    obj.featureHandles(obj.featureHandles == uiElement) = [];
                                    if obj.selectedFeature == feature
                                        obj.selectedFeatureHandle = [];
                                    end
                                    delete(uiElement);
                                    uiElement = [];
                                end
                            end
                        end
                        
                        y = find(strcmp(featureTypes, feature.type));
                        yCen = (length(featureTypes) - y + 0.5) * spacing;
                        if featureIsPoint
                            % Add or update a point feature.
                            
                            if isempty(uiElement)
                                % Create a new text for the feature.
                                set(obj.controller.figure, 'CurrentAxes', obj.axes);
                                obj.featureHandles(end + 1) = text(feature.startTime, yCen, 'x', ...
                                    'Parent', obj.axes, ...
                                    'HorizontalAlignment', 'center', ...
                                    'VerticalAlignment', 'middle', ...
                                    'Color', feature.color(), ...
                                    'Clipping', 'on', ...
                                    'ButtonDownFcn', @(source, event)handleSelectFeature(obj, source, event), ...
                                    'UserData', feature);
                                if obj.selectedFeature == feature
                                    obj.selectedFeatureHandle = obj.featureHandles(end);
                                end
                            else
                                % Update the existing text.
                                set(uiElement, 'Position', [feature.startTime, yCen], ...
                                               'Color', feature.color());
                            end
                        else
                            % Add or update a range feature.
                            
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
                            
                            fillColor = feature.color();
                            edgeColor = fillColor * 0.5;
                            
                            if isempty(uiElement)
                                % Create a new patch for the feature.
                                set(obj.controller.figure, 'CurrentAxes', obj.axes);
                                obj.featureHandles(end + 1) = patch([x0 x1 x1 x0 x0], [y0 y0 y1 y1 y0], fillColor, ...
                                    'Parent', obj.axes, ...
                                    'EdgeColor', edgeColor, ...
                                    'ButtonDownFcn', @(source, event)handleSelectFeature(obj, source, event), ...
                                    'UserData', feature);
                                if obj.selectedFeature == feature
                                    obj.selectedFeatureHandle = obj.featureHandles(end);
                                end
                            else
                                % Update the existing patch.
                                set(uiElement, 'XData', [x0 x1 x1 x0 x0], ...
                                               'YData', [y0 y0 y1 y1 y0], ...
                                               'CData', fillColor, ...
                                               'EdgeColor', edgeColor);
                            end
                        end
                    end
                elseif strcmp(updateType, 'remove')
                    % Remove the texts/patches for the features.
                    for i = 1:length(features)
                        if features{i} == obj.selectedFeature
                            obj.selectFeature([]);
                        end
                        
                        uiElement = findobj(obj.featureHandles, 'UserData', features{i});
                        obj.featureHandles(obj.featureHandles == uiElement) = [];
                        delete(uiElement);
                    end
                else
                    error('Tempo:Panel:Features:UnknownUpdateType', 'Unknown feature update type: %s', updateType);
                end
            end
        end
        
        
        function resizeControls(obj, panelSize)
            % Update the position of the feature type names.
            spacing = 1 / length(obj.featureTypeLabels);
            for i = 1:length(obj.featureTypeLabels)
                set(obj.featureTypeShadows(i), 'Position', [6, (length(obj.featureTypeLabels) - i + 0.65) * spacing * panelSize(2) - 1]);
                set(obj.featureTypeLabels(i), 'Position', [5, (length(obj.featureTypeLabels) - i + 0.65) * spacing * panelSize(2)]);
            end
        end
        
        
        function handled = keyWasPressed(obj, keyEvent)
            handled = false;
            altDown = any(ismember(keyEvent.Modifier, 'alt'));
            if altDown && strcmp(keyEvent.Key, 'leftarrow')
                % Move the selection to the previous feature.
                features = obj.reporter.features();
                earlierFeatures = features(cellfun(@(f) f.endTime < obj.controller.selectedRange(1), features));
                if isempty(earlierFeatures)
                    beep
                else
                    [~, ind] = max(cellfun(@(f) f.endTime, earlierFeatures));
                    obj.selectFeature(earlierFeatures{ind});
                end
                handled = true;
            elseif altDown && strcmp(keyEvent.Key, 'rightarrow')
                % Move the selection to the next feature.
                features = obj.reporter.features();
                laterFeatures = features(cellfun(@(f) f.startTime > obj.controller.selectedRange(2), features));
                if isempty(laterFeatures)
                    beep
                else
                    [~, ind] = min(cellfun(@(f) f.startTime, laterFeatures));
                    obj.selectFeature(laterFeatures{ind});
                end
                handled = true;
            elseif strcmp(keyEvent.Key, 'backspace')
                % Delete the selected feature.
                if ~isempty(obj.selectedFeature)
                    obj.removeFeature(obj.selectedFeature);
                    handled = true;
                end
            end
            
            % Let the reporter respond to the key.
            if ~handled
                handled = obj.reporter.keyWasPressedInPanel(keyEvent, obj);
            end
            
            % Otherwise pass it up the chain.
            if ~handled
                handled = keyWasPressed@TimelinePanel(obj, keyEvent);
            end
        end
        
        
        function handled = keyWasReleased(obj, keyEvent)
            if isa(obj.reporter, 'FeaturesAnnotator')
                % Let the reporter respond to the key.
                handled = obj.reporter.keyWasReleasedInPanel(keyEvent, obj);
            else
                handled = false;
            end
            
            % Otherwise pass it up the chain.
            if ~handled
                handled = keyWasReleased@TimelinePanel(obj, keyEvent);
            end
        end
        
        
        function handleShowReporterSettings(obj, ~, ~)
            if isa(obj.reporter, 'FeaturesDetector')    
                obj.reporter.showSettings();
            else % it's an annotator
                obj.reporter.editSettings();
            end
        end
        
        
        function handleDetectFeaturesInSelection(obj, ~, ~)
            timeRange = obj.controller.selectedRange;
            features = obj.controller.detectFeatures(obj.reporter, timeRange);
            if isempty(features)
                waitfor(msgbox('No additional features were detected.', obj.reporter.typeName, 'warn', 'modal'));
            else
                % Create a new reference to the reporter object so it doesn't get destroyed when this panel does.
                reporterHandle = obj.reporter;
                
                obj.controller.addUndoableAction(['Detect ' obj.reporter.typeName], ...
                                                  @() reporterHandle.removeFeaturesInTimeRange(features, timeRange), ...
                                                  @() reporterHandle.addFeaturesInTimeRange(features, timeRange), ...
                                                  obj);
            end
        end
        
        
        function handleSetFeaturesName(obj, ~, ~)
            newName = inputdlg('Enter a new name for the features:', 'Tempo', 1, {obj.reporter.name});
            if ~isempty(newName)
                oldName = obj.setFeaturesName(newName{1});
                
                obj.controller.addUndoableAction('Set Features Name', ...
                                                  @() obj.setFeaturesName(oldName), ...
                                                  @() obj.setFeaturesName(newName{1}), ...
                                                  obj);
            end
        end
        
        
        function oldName = setFeaturesName(obj, newName)
            oldName = obj.reporter.name;
            obj.reporter.name = newName;
            obj.setTitle(obj.reporter.name);
        end
        
        
        function handleSetFeaturesColor(obj, ~, ~)
            newColor = uisetcolor(obj.reporter.featuresColor);
            if length(newColor) == 3
                oldColor = obj.setFeaturesColor(newColor);
                
                obj.controller.addUndoableAction('Set Features Color', ...
                                                  @() obj.setFeaturesColor(oldColor), ...
                                                  @() obj.setFeaturesColor(newColor), ...
                                                  obj);
            end
        end
        
        
        function oldColor = setFeaturesColor(obj, newColor)
            oldColor = obj.reporter.featuresColor;
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
        
        
        function handleRemoveReporter(obj, ~, ~)
            answer = questdlg('Are you sure you wish to remove this reporter?', 'Removing Reporter', 'Cancel', 'Remove', 'Cancel');
            if strcmp(answer, 'Remove')
                % Create new references to the controller and reporter objects so they don't get destroyed when this panel does.
                controllerHandle = obj.controller;
                reporterHandle = obj.reporter;
                
                obj.controller.addUndoableAction(['Remove ' obj.reporter.typeName], ...
                                                  @() controllerHandle.addReporter(reporterHandle), ...
                                                  @() controllerHandle.removeReporter(reporterHandle), ...
                                                  obj);
                
                obj.controller.removeReporter(obj.reporter);
            end
        
        end
        
        
        function handleAddNewFeature(obj, ~, ~)
            % Add a new feature using the current selection.
            
            % Figure out which type of feature it should be.
            featureTypes = obj.reporter.featureTypes();
            if length(featureTypes) == 1
                featureType = featureTypes{1};
            else
                choice = listdlg('PromptString', 'Choose which type of feature to add:', ...
                                 'SelectionMode', 'Single', ...
                                 'ListString', featureTypes, ...
                                 'ListSize', [200 100]);
                if isempty(choice)
                    featureType = [];
                else
                    featureType = featureTypes{choice(1)};
                end
            end
            
            % Add the feature
            if ~isempty(featureType)
                features = {Feature(featureType, obj.controller.selectedRange)};
                obj.reporter.addFeatures(features);
                
                % Create a new reference to the reporter object so it doesn't get destroyed when this panel does.
                reporterHandle = obj.reporter;
                obj.controller.addUndoableAction('Add Feature', ...
                                                  @() reporterHandle.removeFeatures(features), ...
                                                  @() reporterHandle.addFeatures(features), ...
                                                  obj);
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
        
        
        function handleShowFeatureProperties(obj, ~, ~)
            feature = obj.selectedFeature;
            
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
            ignoreProps = {'type', 'range', 'startTime', 'endTime', 'duration', 'highFreq', 'lowFreq', 'color', 'reporter'};
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
            
            obj.removeFeature(feature);
        end
        
        
        function removeFeature(obj, feature)
            answer = questdlg('Are you sure you wish to remove this feature?', 'Removing Feature', 'Cancel', 'Remove', 'Cancel');
            if strcmp(answer, 'Remove')
                if obj.selectedFeature == feature
                    obj.selectFeature([]);
                end
                
                obj.reporter.removeFeatures({feature});
                
                % Create a new reference to the reporter object so it doesn't get destroyed when this panel does.
                reporterHandle = obj.reporter;
                obj.controller.addUndoableAction('Add Feature', ...
                                                  @() reporterHandle.addFeatures({feature}), ...
                                                  @() reporterHandle.removeFeatures({feature}), ...
                                                  obj);
            end
        end
        
        
        function handleSelectFeature(obj, ~, ~)
            % Get the feature instance from the clicked rectangle's UserData.
            obj.selectFeature(get(gco, 'UserData'));
        end
        
        
        function selectFeature(obj, feature)
            if isempty(obj.selectedFeature) || isempty(feature) || obj.selectedFeature ~= feature
                delete(obj.selectedFeatureListener);
                obj.selectedFeatureListener = [];
                
                if ~isempty(obj.selectedFeature)
                    % Restore the button down callback for feature selection.
                    set(obj.selectedFeatureHandle, 'ButtonDownFcn', @(source, event)handleSelectFeature(obj, source, event));
                    obj.selectedFeatureHandle = [];
                end
                
                % Remember that the user chose this feature.  If the selection gets changed then it won't be considered selected any more.
                obj.selectedFeature = feature;
                
                if ~isempty(obj.selectedFeature)
                    obj.selectedFeatureListener = addlistener(obj.selectedFeature, 'RangeChanged', @(source, event)handleFeatureDidChange(obj, source, event));
                    
                    % Temporarily clear the button down function so the user can edit the bounds of the feature.
                    obj.selectedFeatureHandle = findobj(obj.featureHandles, 'UserData', obj.selectedFeature);
                    set(obj.selectedFeatureHandle, 'ButtonDownFcn', []);
                    
                    % Also set the timeline's selection.
                    obj.controller.selectRange(obj.selectedFeature.range);
                    
                    % TODO: add cursor rects to show the resize cursors
                end
            end
        end
        
        
        function handleSelectedRangeChanged(obj, ~, ~)
            % De-select our current feature if the selection changes.
            if ~isempty(obj.selectedFeature) && ~all(obj.controller.selectedRange == obj.selectedFeature.range)
                obj.selectFeature([]);
            end
            
            handleSelectedRangeChanged@TimelinePanel(obj);
        end
        
        
        function setFeatureRange(obj, feature, range)
            obj.selectFeature(feature);
            feature.range = range;
        end
        
        
        function setEditedRange(obj, editedObject, range, endOfUpdate)
            if editedObject == obj.selectedFeatureHandle
                if isempty(obj.selectedFeatureOriginalRange)
                    obj.selectedFeatureOriginalRange = obj.selectedFeature.range;
                end
                
                obj.selectedFeature.range = range;
                
                if endOfUpdate
                    feature = obj.selectedFeature;
                    prevRange = obj.selectedFeatureOriginalRange;
                    obj.controller.addUndoableAction(['Edit ' obj.selectedFeature.type], ...
                                                      @() obj.setFeatureRange(feature, prevRange), ...
                                                      @() obj.setFeatureRange(feature, range), ...
                                                      obj);
                    obj.selectedFeatureOriginalRange = [];
                end
            else
                setEditedRange@TimelinePanel(obj, editedObject, range);
            end
        end
        
        
        function currentTimeChanged(obj)
            if ~isempty(obj.selectedFeature) && isa(obj.reporter, 'FeaturesAnnotator')
                % Let the annotator respond to the current time change.
                obj.reporter.currentTimeChangedInPanel(obj);
            end
            
            currentTimeChanged@TimelinePanel(obj);
        end
        
        
        function handleFeatureDidChange(obj, feature, ~)
            obj.updateFeatures('update', {feature});
            
            if obj.selectedFeature == feature
                % Update the timeline's selection.
                obj.controller.selectRange(obj.selectedFeature.range);
            end
        end
        
        
        function close = shouldClose(obj)
            close = strcmp(questdlg('Are you sure you wish to close these features?', 'Tempo', 'Close', 'Cancel', 'Close'), 'Close');
            
            if close
                delete(obj.selectedFeatureListener);
                obj.selectedFeatureListener = [];
            end
        end
        
        
        function close(obj)
            delete(obj.featureTypesListener);
            obj.featureTypesListener = [];
            delete(obj.featuresListener);
            obj.featuresListener = [];
            delete(obj.timeRangesListener);
            obj.timeRangesListener = [];
            
            delete(obj.featureTypeLabels);
            obj.featureTypeLabels = [];
            delete(obj.featureTypeShadows);
            obj.featureTypeShadows = [];
            delete(obj.timeRangeRectangles);
            obj.timeRangeRectangles = [];
            
            obj.controller.removeReporter(obj.reporter, false);
            
            close@TimelinePanel(obj);
        end
        
        
        function delete(obj)
            delete(obj.featureTypesListener);
            obj.featureTypesListener = [];
            delete(obj.featuresListener);
            obj.featuresListener = [];
            delete(obj.timeRangesListener);
            obj.timeRangesListener = [];
        end
        
    end
	
end
