classdef FeaturesAnnotator < FeaturesReporter
    
    properties
        featureSet
        featureSets
    end
    
    properties (Transient)
        rangeFeatureBeingAdded
        
        settingsEdited
        settingsTable
        selectedSet
    end
    
    
    methods(Static)
        
        function n = typeName()
            n = 'Manual Annotations';
        end
        
        function ft = possibleFeatureTypes()
            % TODO: can't do this statically
            ft = {};
        end
        
    end
    
    
    methods
        
        function obj = FeaturesAnnotator(controller)
            obj = obj@FeaturesReporter(controller);
            
            obj.featureSet(1).name = 'First leg';
            obj.featureSet(1).key = '1';
            obj.featureSet(1).color = [1 0 0];
            obj.featureSet(1).isRange = true;
            
            obj.featureSet(2).name = 'Head grooming';
            obj.featureSet(2).key = 'h';
            obj.featureSet(2).color = [0.5 0 0];
            obj.featureSet(2).isRange = true;
            
            obj.featureSet(3).name = 'Third leg';
            obj.featureSet(3).key = '3';
            obj.featureSet(3).color = [0.5 0.5 0.25];
            obj.featureSet(3).isRange = true;
            
            obj.featureSet(4).name = 'Wing grooming';
            obj.featureSet(4).key = 'w';
            obj.featureSet(4).color = [0 0.25 0.5];
            obj.featureSet(4).isRange = true;
            
            obj.featureSet(5).name = 'Abdominal grooming';
            obj.featureSet(5).key = 'a';
            obj.featureSet(5).color = [0 0.5 0];
            obj.featureSet(5).isRange = true;
            
        end
        
        
        function types = featureTypes(obj)
            % Override the base class so we show all types and preserve the order.
            types = {obj.featureSet.name};
        end
        
        
        function edited = editSettings(obj)
            windowSize = [400 200];
            
            window = dialog(...
                'Units', 'points', ...
                'Name', 'Annotations', ...
                'Position', [100, 100, windowSize(1:2)], ...
                'Visible', 'off', ...
                'WindowKeyPressFcn', @(source, event)handleEditSettingsKeyPress(obj, source, event));
            
            obj.settingsTable = uitable(window, ...
                'ColumnName', {'Name', 'Key', 'Color', 'Range'}, ...
                'ColumnFormat', {'char', 'char', 'char', 'logical'}, ...
                'ColumnEditable', [true, true, false, true], ...
                'ColumnWidth', {windowSize(1) - 60 - 60 - 60 - 24, 60, 60, 60}, ...
                'RowName', [], ...
                'Data', obj.settingsData(), ...
                'Units', 'pixels', ...
                'Position', [10, 10 + 20 + 10 + 20, windowSize(1) - 10 - 10, windowSize(2) - 10 - 20 - 10 - 20 - 10], ...
                'CellEditCallback', @(source, event)handleSettingWasEdited(obj, source, event), ...
                'CellSelectionCallback', @(source, event)handleFeatureSetWasSelected(obj, source, event));
            % TODO: resize the name column to use any extra width
            handles.addButton = uicontrol(...
                'Parent', window,...
                'Units', 'points', ...
                'Callback', @(source, event)handleAddFeatureType(obj, source, event), ...
                'Position', [10 - 1, 10 + 20 + 10 + 1, 20, 20], ...
                'String', '+', ...
                'Tag', 'addButton');
            handles.removeButton = uicontrol(...
                'Parent', window,...
                'Units', 'points', ...
                'Callback', @(source, event)handleRemoveFeatureType(obj, source, event), ...
                'Position', [10 + 20 - 2, 10 + 20 + 10 + 1, 20, 20], ...
                'String', '-', ...
                'Tag', 'removeButton');
            handles.baseReporterPopup = uicontrol(...
                'Parent', window, ...
                'Units', 'points', ...
                'Position', [10 + 20 + 20 - 7, 10 + 20 + 10, windowSize(1) - 10 - 20 - 20 + 2, 20], ...
                'Callback', @(source, event)handlePresetsPopupChanged(obj, source, event), ...
                'String', {'Save As...'}, ...
                'Style', 'popupmenu', ...
                'Value', 1, ...
                'Tag', 'presetsPopup');
            
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
        
        
        function data = settingsData(obj)
            data = cell(length(obj.featureSet), 4);
            
            for i = 1:length(obj.featureSet)
                data{i, 1} = obj.featureSet(i).name;
                data{i, 2} = obj.featureSet(i).key;
                rgbColor = uint8(obj.featureSet(i).color * 255);
                data{i, 3} = sprintf('<html><div style="width: 100px; background-color: rgb(%d, %d, %d)">&nbsp;</div></html>', rgbColor);
                data{i, 4} = obj.featureSet(i).isRange;
            end
        end
        
        
        function handleSettingWasEdited(obj, ~, event)
            setNum = event.Indices(1);
            if event.Indices(2) == 1
                obj.featureSet(setNum).name = event.NewData;
            elseif event.Indices(2) == 2
                obj.featureSet(setNum).key = event.NewData;
            elseif event.Indices(2) == 3
                obj.featureSet(setNum).color = event.NewData;
            elseif event.Indices(2) == 4
                obj.featureSet(setNum).isRange = event.NewData;
            end
        end
        
        
        function handleAddFeatureType(obj, ~, ~)
            newType.name = 'New Feature';
            newType.key = '';
            newType.color = [0 0 0];
            newType.isRange = true;
            
            obj.featureSet(end + 1) = newType;
            
            set(obj.settingsTable, 'Data', obj.settingsData());
        end
        
        
        function handleFeatureSetWasSelected(obj, ~, event)
            if isempty(event.Indices)
                obj.selectedSet = [];
            else
                obj.selectedSet = event.Indices(1, 1);
                
                if event.Indices(1, 2) == 3
                    % Pick a new color.
                    obj.featureSet(obj.selectedSet).color = uisetcolor(obj.featureSet(obj.selectedSet).color);
                    
                    set(obj.settingsTable, 'Data', obj.settingsData());
                end
            end
        end
        
        
        function handleRemoveFeatureType(obj, ~, ~)
            if isempty(obj.selectedSet)
                beep
            else
                obj.featureSet(obj.selectedSet) = [];
                obj.selectedSet = [];
                
                set(obj.settingsTable, 'Data', obj.settingsData());
            end
        end
        
        
        function handlePresetsPopupChanged(obj, ~, ~)
        end
        
        
        function handleCancelEditSettings(obj, ~, ~)
            obj.settingsEdited = false;
            uiresume;
        end
        
        
        function handleSaveEditSettings(obj, ~, ~)
            obj.settingsEdited = true;
            uiresume;
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
                            feature = Feature(featureDef.type, [panel.controller.currentTime panel.controller.currentTime + 0.01], ...
                                              'Color', featureDef.color);
                            obj.rangeFeatureBeingAdded = feature;
                        elseif panel.controller.selectedRange(2) > panel.controller.selectedRange(1)
                            % Add the current selection as a new feature.
                            feature = Feature(featureDef.type, panel.controller.selectedRange, ...
                                              'Color', featureDef.color);
                        else
                            % The selection is not a range.
                            beep
                        end
                    else
                        % Add a point feature at the start of the current time.
                        feature = Feature(featureDef.type, panel.controller.currentTime, ...
                                          'Color', featureDef.color);
                    end
                    
                    if ~isempty(feature)
                        obj.addFeatures({feature});
                        
                        panel.selectFeature(feature);
                        
                        panel.controller.addUndoableAction(['Add ' feature.type], ...
                                                           @() obj.removeFeatures({feature}), ...
                                                           @() obj.addFeatures({feature}), ...
                                                           panel);
                    end
                    
                    handled = true;
                    break;
                end
            end
        end
        
        
        function currentTimeChangedInPanel(obj, panel)
            if ~isempty(obj.rangeFeatureBeingAdded)
                % Update the end time of the feature.
                % TODO: this isn't working: the patch created in keyPress is invalid when the code below triggers its update
%                 endTime = panel.controller.currentTime;
%                 if endTime < obj.rangeFeatureBeingAdded.startTime + 0.01
%                     endTime = obj.rangeFeatureBeingAdded.startTime + 0.01;
%                 end
%                 obj.rangeFeatureBeingAdded.endTime = endTime;
            end
        end
        
        
        function handled = keyWasReleasedInPanel(obj, ~, panel)
            % Finish creating a range feature during playback.
            if ~isempty(obj.rangeFeatureBeingAdded)
                % Update the end time of the feature.
                endTime = panel.controller.currentTime;
                if endTime < obj.rangeFeatureBeingAdded.startTime + 0.01
                    endTime = obj.rangeFeatureBeingAdded.startTime + 0.01;
                end
                obj.rangeFeatureBeingAdded.endTime = endTime;
                obj.rangeFeatureBeingAdded = [];
                
                handled = true;
            else
                handled = false;
            end
        end
    end
    
end
