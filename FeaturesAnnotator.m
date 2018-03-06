classdef FeaturesAnnotator < FeaturesReporter
    
    properties
        featureSet
    end
    
    properties (Transient)
        rangeFeatureBeingAdded
        
        settingsEdited
        settingsTable
        selectedSet
        
        featureSetsPopup
        lastChosenFeatureSetName
        reporterName
    end
    
    
    methods(Static)
        
        function n = typeName()
            n = 'Annotations';
        end
        
        function ft = possibleFeatureTypes()
            % TODO: can't do this statically
            ft = {};
        end
        
    end
    
    
    methods
        
        function obj = FeaturesAnnotator(controller)
            obj = obj@FeaturesReporter(controller);
            
            if ispref('Tempo', 'AnnotationFeatureSets');
                savedSets = getpref('Tempo', 'AnnotationFeatureSets');
            else
                savedSets = struct('name', {}, 'features', {});
            end
            if ispref('Tempo', 'AnnotationLastChosenFeatureSet');
                lastChosenSet = getpref('Tempo', 'AnnotationLastChosenFeatureSet');
            else
                lastChosenSet = '';
            end
            if isempty(savedSets)
                obj.featureSet(1).name = '';
                obj.featureSet(1).key = '';
                obj.featureSet(1).color = [1 0 0];
                obj.featureSet(1).isRange = true;
            else
                for i = 1:length(savedSets)
                    if strcmp(savedSets(i).name, lastChosenSet)
                        obj.featureSet = savedSets(i).features;
                        obj.lastChosenFeatureSetName = savedSets(i).name;
                        obj.reporterName = savedSets(i).name;
                        break;
                    end
                end
                if isempty(obj.featureSet)
                    obj.featureSet = savedSets(1).features;
                    obj.lastChosenFeatureSetName = savedSets(1).name;
                    obj.reporterName = savedSets(1).name;
                end
            end
        end
        
        
        function types = featureTypes(obj)
            % Override the base class so we show all types and preserve the order.
            types = {obj.featureSet.name};
        end
        
        
        function edited = editSettings(obj)
            windowSize = [400 250];
            
            window = dialog(...
                'Units', 'points', ...
                'Name', 'Annotation Features', ...
                'Position', [100, 100, windowSize(1:2)], ...
                'Visible', 'off', ...
                'WindowKeyPressFcn', @(source, event)handleEditSettingsKeyPress(obj, source, event));
            
            uicontrol(...
                'Parent', window, ...
                'Units', 'points', ...
                'Position', [10 windowSize(2) - 16, windowSize(1) - 20, 12], ...
                'HorizontalAlignment', 'left', ...
                'Style', 'text', ...
                'String', 'Add the types of features to annotate:');
            obj.settingsTable = uitable(window, ...
                'ColumnName',     {'Name', 'Key',  'Color', 'Type'}, ...
                'ColumnFormat',   {'char', 'char', 'char',  {'Range', 'Point'}}, ...
                'ColumnEditable', [ true,   true,   false,   true], ...
                'ColumnWidth',    {windowSize(1) - 40 - 60 - 70 - 24, 40, 60, 70}, ...
                'RowName', [], ...
                'Data', {}, ...
                'Units', 'pixels', ...
                'Position', [10, 10 + 20 + 10 + 20, windowSize(1) - 10 - 10, windowSize(2) - 10 - 20 - 10 - 20 - 12 - 10], ...
                'CellEditCallback', @(source, event)handleSettingWasEdited(obj, source, event), ...
                'CellSelectionCallback', @(source, event)handleFeatureSetWasSelected(obj, source, event));
            uicontrol(...
                'Parent', window,...
                'Units', 'points', ...
                'Callback', @(source, event)handleAddFeatureType(obj, source, event), ...
                'Position', [10 - 1, 10 + 20 + 10 + 1, 20, 20], ...
                'String', '+', ...
                'Tag', 'addButton');
            uicontrol(...
                'Parent', window,...
                'Units', 'points', ...
                'Callback', @(source, event)handleRemoveFeatureType(obj, source, event), ...
                'Position', [10 + 20 - 2, 10 + 20 + 10 + 1, 20, 20], ...
                'String', '-', ...
                'Tag', 'removeButton');
            obj.featureSetsPopup = uicontrol(...
                'Parent', window, ...
                'Units', 'points', ...
                'Position', [10 + 20 + 20 - 7, 10 + 20 + 10, windowSize(1) - 10 - 20 - 20 + 2, 20], ...
                'Callback', @(source, event)handleFeatureSetsPopupChanged(obj, source, event), ...
                'String', {'Save As...'}, ...
                'Style', 'popupmenu', ...
                'Value', 1, ...
                'Tag', 'featureSetsPopup');
            
            handles.cancelButton = uicontrol(...
                'Parent', window,...
                'Units', 'points', ...
                'Callback', @(source, event)handleCancelEditSettings(obj, source, event), ...
                'Position', [windowSize(1) - 56 - 10 - 56 - 10, 10, 56, 20], ...
                'String', 'Cancel', ...
                'Tag', 'cancelButton');
            handles.saveButton = uicontrol(...
                'Parent', window,...
                'Units', 'points', ...
                'Callback', @(source, event)handleSaveEditSettings(obj, source, event), ...
                'Position', [windowSize(1) - 10 - 56, 10, 56, 20], ...
                'String', 'Save', ...
                'Tag', 'saveButton');
            
            obj.updateSettingsData();
            obj.updateFeatureSetsPopup();
            
            movegui(window, 'center');
            set(window, 'Visible', 'on');
            
            uiwait;
            
            edited = obj.settingsEdited;
            
            close(window);
        end
        
        
        function handleEditSettingsKeyPress(obj, ~, event)
            if strcmp(event.Key, 'return')
                obj.handleSaveEditSettings(obj);
            elseif strcmp(event.Key, 'escape')
                obj.handleCancelEditSettings(obj);
            end
        end
        
        
        function updateSettingsData(obj)
            data = cell(length(obj.featureSet), 4);
            for i = 1:length(obj.featureSet)
                data{i, 1} = obj.featureSet(i).name;
                data{i, 2} = obj.featureSet(i).key;
                rgbColor = uint8(obj.featureSet(i).color * 255);
                data{i, 3} = sprintf('<html><div style="width: 100px; background-color: rgb(%d, %d, %d)">&nbsp;</div></html>', rgbColor);
                if obj.featureSet(i).isRange
                    data{i, 4} = 'Range';
                else
                    data{i, 4} = 'Point';
                end
            end
            
            set(obj.settingsTable, 'Data', data);
        end
        
        
        function handleSettingWasEdited(obj, ~, event)
            setNum = event.Indices(1);
            if event.Indices(2) == 1
                obj.featureSet(setNum).name = event.NewData;
            elseif event.Indices(2) == 2
                newKey = lower(event.NewData(1));
                % Only a-z and 0-9 are allowed.
                if ~isempty(regexp(newKey, '[a-z0-9]', 'start', 'once'))
                    obj.featureSet(setNum).key = newKey;
                else
                    beep;
                end
            elseif event.Indices(2) == 3
                obj.featureSet(setNum).color = event.NewData;
            elseif event.Indices(2) == 4
                obj.featureSet(setNum).isRange = strcmp(event.NewData, 'Range');
            end
            
            obj.updateSettingsData();
            
            if isempty(strfind(obj.reporterName, '(edited)'))
                obj.reporterName = [obj.reporterName ' (edited)'];
            end
        end
        
        
        function handleAddFeatureType(obj, ~, ~)
            newType.name = 'New Feature';
            newType.key = '';
            newType.color = [0 0 0];
            newType.isRange = true;
            
            obj.featureSet(end + 1) = newType;
            
            obj.updateSettingsData();
            
            if isempty(strfind(obj.reporterName, '(edited)'))
                obj.reporterName = [obj.reporterName ' (edited)'];
            end
        end
        
        
        function handleFeatureSetWasSelected(obj, ~, event)
            if isempty(event.Indices)
                obj.selectedSet = [];
            else
                obj.selectedSet = event.Indices(1, 1);
                
                if event.Indices(1, 2) == 3
                    % Pick a new color.
                    obj.featureSet(obj.selectedSet).color = uisetcolor(obj.featureSet(obj.selectedSet).color);
                    
                    obj.updateSettingsData();
                    
                    if isempty(strfind(obj.reporterName, '(edited)'))
                        obj.reporterName = [obj.reporterName ' (edited)'];
                    end
                end
            end
        end
        
        
        function handleRemoveFeatureType(obj, ~, ~)
            if isempty(obj.selectedSet)
                beep
            else
                obj.featureSet(obj.selectedSet) = [];
                obj.selectedSet = [];
                
                obj.updateSettingsData();
                
                if isempty(strfind(obj.reporterName, '(edited)'))
                    obj.reporterName = [obj.reporterName ' (edited)'];
                end
            end
        end
        
        
        function updateFeatureSetsPopup(obj)
            menuItems = {};
            curItem = [];
            if ispref('Tempo', 'AnnotationFeatureSets');
                savedSets = getpref('Tempo', 'AnnotationFeatureSets');
            else
                savedSets = struct('name', {}, 'features', {});
            end
            for i = 1:length(savedSets)
                menuItems{end + 1} = savedSets(i).name; %#ok<AGROW>
                if strcmp(savedSets(i).name, obj.lastChosenFeatureSetName)
                    curItem = i;
                end
            end
            if ~isempty(menuItems)
                menuItems{end + 1} = '';
            end
            menuItems{end + 1} = 'Save Features As...';
            if isempty(curItem)
                curItem = length(menuItems);
            else
                menuItems{end + 1} = ['Delete ' obj.lastChosenFeatureSetName '...'];
            end
            set(obj.featureSetsPopup, 'String', menuItems, 'Value', curItem);
        end
        
        
        function handleFeatureSetsPopupChanged(obj, ~, ~)
            menuItems = get(obj.featureSetsPopup, 'String');
            chosenItem = menuItems{get(obj.featureSetsPopup, 'Value')};
            
            if strncmp(chosenItem, 'Save', 4)
                % Save the current set.
                setName = inputdlg('Enter a name for the feature set...', 'Tempo');
                if ~isempty(setName)
                    newSet.name = setName{1};
                    newSet.features = obj.featureSet;
                    
                    if ispref('Tempo', 'AnnotationFeatureSets')
                        savedSets = getpref('Tempo', 'AnnotationFeatureSets');
                    else
                        savedSets = struct('name', {}, 'features', {});
                    end
                    
                    if ismember(setName, menuItems(1:length(savedSets)))
                        answer = questdlg(['Are you sure you wish to replace "' newSet.name '"?'], 'Tempo', 'Cancel', 'Replace', 'Replace');
                        if strcmp(answer, 'Replace')
                            for i = 1:length(savedSets)
                                if strcmp(savedSets(i).name, newSet.name)
                                    savedSets(i) = newSet;
                                    setpref('Tempo', 'AnnotationFeatureSets', savedSets);
                                    break;
                                end
                            end
                        end
                    else
                        savedSets(end + 1) = newSet;
                        setpref('Tempo', 'AnnotationFeatureSets', savedSets);
                    end
                    
                    obj.updateFeatureSetsPopup();
                end
            elseif strncmp(chosenItem, 'Delete', 6)
                % Delete a feature set from the prefs.
                setName = chosenItem(8:end-3);
                answer = questdlg(['Are you sure you wish to delete "' setName '"?'], 'Tempo', 'Cancel', 'Delete', 'Delete');
                if strcmp(answer, 'Delete')
                    if ispref('Tempo', 'AnnotationFeatureSets');
                        savedSets = getpref('Tempo', 'AnnotationFeatureSets');
                    else
                        savedSets = struct('name', {}, 'features', {});
                    end
                    for i = 1:length(savedSets)
                        if strcmp(savedSets(i).name, setName)
                            savedSets(i) = [];
                            setpref('Tempo', 'AnnotationFeatureSets', savedSets);
                            break;
                        end
                    end
                end
                obj.updateFeatureSetsPopup();
            elseif ~isempty(chosenItem)
                % Use a feature set.
                if ispref('Tempo', 'AnnotationFeatureSets');
                    savedSets = getpref('Tempo', 'AnnotationFeatureSets');
                else
                    savedSets = struct('name', {}, 'features', {});
                end
                for i = 1:length(savedSets)
                    if strcmp(savedSets(i).name, chosenItem)
                        obj.lastChosenFeatureSetName = chosenItem;
                        obj.reporterName = chosenItem;
                        setpref('Tempo', 'AnnotationLastChosenFeatureSet', chosenItem);
                        obj.featureSet = savedSets(i).features;
                        obj.updateSettingsData();
                        obj.updateFeatureSetsPopup();
                        break;
                    end
                end
            end
        end
        
        
        function handleCancelEditSettings(obj, ~, ~)
            obj.settingsEdited = false;
            uiresume;
        end
        
        
        function handleSaveEditSettings(obj, ~, ~)
            if isempty(obj.name)
                obj.name = obj.reporterName;
            end
            
            obj.settingsEdited = true;
            uiresume;

            notify(obj, 'FeatureTypesDidChange');
            notify(obj, 'FeaturesDidChange', FeaturesChangedEventData('update', obj.features()));
        end
        
        
        function handled = keyWasPressedInPanel(obj, keyEvent, panel)
            handled = false;
            for i = 1:length(obj.featureSet)
                featureDef = obj.featureSet(i);
                if keyEvent.Character == featureDef.key
                    feature = [];
                    
                    if featureDef.isRange
                        if panel.controller.isPlaying
                            % Allow the user to create a range feature during playback.
                            % Wait until the key release to add the feature.
                            feature = Feature(featureDef.name, [panel.controller.currentTime panel.controller.currentTime + 0.01], ...
                                              'Color', featureDef.color);
                            obj.rangeFeatureBeingAdded = feature;
                        elseif panel.controller.selectedRange(2) > panel.controller.selectedRange(1)
                            % Add the current selection as a new feature.
                            feature = Feature(featureDef.name, panel.controller.selectedRange, ...
                                              'Color', featureDef.color);
                        else
                            % The selection is not a range.
                            beep
                        end
                    else
                        if panel.controller.selectedRange(1) == panel.controller.selectedRange(2)
                            % Add a point feature at the start of the current time.
                            feature = Feature(featureDef.name, panel.controller.currentTime, ...
                                              'Color', featureDef.color);
                        else
                            % The selection is  a range.
                            beep
                        end
                    end
                    
                    if ~isempty(feature) 
                        if ~any(cellfun(@(x) strcmp(x.type,feature.type) && all(x.range==feature.range), obj.features()))
                            obj.addFeatures({feature});

                            panel.selectFeature(feature);

                            panel.controller.addUndoableAction(['Add ' feature.type], ...
                                                               @() obj.removeFeatures({feature}), ...
                                                               @() obj.addFeatures({feature}), ...
                                                               panel);
                        else
                            beep
                        end
                    end
                    
                    handled = true;
                    break;
                end
            end
        end
        
        
        function currentTimeChangedInPanel(obj, panel) %#ok<INUSD>
            if ~isempty(obj.rangeFeatureBeingAdded)
                % Update the start or end time of a range feature during playback.
                % TODO: This isn't working.  The key release event comes in during the key press and messes things up.
%                 newTime = panel.controller.currentTime;
%                 if panel.controller.playRate > 0
%                     obj.rangeFeatureBeingAdded.endTime = newTime;
%                 else
%                     obj.rangeFeatureBeingAdded.startTime = newTime;
%                 end
            end
        end
        
        
        function handled = keyWasReleasedInPanel(obj, ~, panel)
            if ~isempty(obj.rangeFeatureBeingAdded)
                % Finish creating a range feature during playback.
                % Sometimes the currentTime is incorrectly the time of the key down (?)
                newTime = panel.controller.currentTime;
                if panel.controller.playRate > 0
                    obj.rangeFeatureBeingAdded.endTime = max([newTime obj.rangeFeatureBeingAdded.endTime]);
                else
                    obj.rangeFeatureBeingAdded.startTime = min([newTime obj.rangeFeatureBeingAdded.startTime]);
                end
                obj.rangeFeatureBeingAdded = [];
                
                handled = true;
            else
                handled = false;
            end
        end
    end
    
end
