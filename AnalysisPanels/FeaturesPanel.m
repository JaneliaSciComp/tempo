classdef FeaturesPanel < TimelinePanel

	properties
        reporter
        featureTypeLabels
        featureTypeShadows
	end
	
	methods
	
		function obj = FeaturesPanel(reporter)
			obj = obj@TimelinePanel(reporter.controller);
            
            obj.reporter = reporter;
            
            obj.populateFeatures();
            
            % Listen for whenever the reporter changes its features.
            addlistener(obj.reporter, 'FeaturesDidChange', @(source, event)handleFeaturesDidChange(obj, source, event));
        end
        
        
        function handleFeaturesDidChange(obj, ~, ~)
            % TODO: how to avoid repetitive calls during detection?
            obj.populateFeatures();
        end
        
        
        function populateFeatures(obj)
            axes(obj.axes);
            cla;
            obj.featureTypeLabels= {};
            obj.featureTypeShadows = {};
            
            featureTypes = obj.reporter.featureTypes();
            
            spacing = 1 / length(featureTypes);
            axesPos = get(obj.axes, 'Position');
            
            % Indicate the time spans in which feature detection has occurred for each reporter.
            lastTime = 0.0;
            timeRangeRects = {};
            if isa(obj.reporter, 'FeatureDetector')
% TODO:
%                 for j = 1:size(obj.reporter.detectedTimeRanges, 1)
%                     detectedTimeRange = obj.reporter.detectedTimeRanges(j, :);
% 
%                     if detectedTimeRange(1) > lastTime
%                         % Add a gray background before the current range.
%                         timeRangeRects{end + 1} = rectangle('Position', [lastTime 0 detectedTimeRange(1) - lastTime 1], 'FaceColor', [0.9 0.9 0.9], 'EdgeColor', 'none', 'UIContextMenu', obj.reporter.contextualMenu); %#ok<AGROW>
%                     end
% 
%                     % Add a white background for this range.
%                     timeRangeRects{end + 1} = rectangle('Position', [detectedTimeRange(1) 0 detectedTimeRange(2) - detectedTimeRange(1) 1], 'FaceColor', 'white', 'EdgeColor', 'none', 'UIContextMenu', obj.reporter.contextualMenu); %#ok<AGROW>
% 
%                     lastTime = detectedTimeRange(2);
%                 end
%                 if lastTime < obj.controller.duration
%                     timeRangeRects{end + 1} = rectangle('Position', [lastTime 0 obj.controller.duration - lastTime 1], 'FaceColor', [0.9 0.9 0.9], 'EdgeColor', 'none', 'UIContextMenu', obj.reporter.contextualMenu);
%                 end
            elseif isa(obj.reporter, 'FeatureImporter')
                % Importers cover all time spans.
                timeRangeRects{end + 1} = rectangle('Position', [0 0 obj.controller.duration 1], 'FaceColor', 'white', 'EdgeColor', 'none', 'UIContextMenu', obj.reporter.contextualMenu, 'HitTest', 'off');
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
                    text(feature.sampleRange(1), yCen, 'x', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'UIContextMenu', feature.contextualMenu, 'Color', obj.reporter.featuresColor, 'UserData', feature);
                else
                    fillColor = obj.reporter.featuresColor;
                    fillColor = fillColor + ([1 1 1] - fillColor) * 0.5;
                    rectangle('Position', [feature.sampleRange(1), yCen - spacing * 0.45, feature.sampleRange(2) - feature.sampleRange(1), spacing * 0.9], 'FaceColor', fillColor, 'EdgeColor', obj.reporter.featuresColor, 'UIContextMenu', feature.contextualMenu, 'UserData', feature);
                end
            end
            
            % Draw the feature type names.
            for y = 1:length(featureTypes)
                featureType = featureTypes{y};
                obj.featureTypeShadows{end + 1} = text(6, (length(featureTypes) - y + 0.75) * spacing * axesPos(4) - 1, featureType, 'VerticalAlignment', 'middle', 'Units', 'pixels', 'HitTest', 'off', 'Color', [0.75 0.75 0.75]);
                obj.featureTypeLabels{end + 1} = text(5, (length(featureTypes) - y + 0.75) * spacing * axesPos(4), featureType, 'VerticalAlignment', 'middle', 'Units', 'pixels', 'HitTest', 'off', 'Color', [0.25 0.25 0.25]);
            end
            
            % Make sure all of the time range rectangles are drawmn behind everything else.
            % TODO: is this necessary anymore?
            for i = 1:length(timeRangeRects)
                uistack(timeRangeRects{i}, 'bottom');
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
                obj.controller.displayedTime = newTime;
                
                handled = true;
            else
                handled = keyWasPressed@TimelinePanel(obj, keyEvent);
            end
        end
        
        
        function showFeatureProperties(obj, ~, ~) %#ok<MANU>
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
