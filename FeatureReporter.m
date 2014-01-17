classdef FeatureReporter < handle
    
    properties
        name;
        featuresColor = [0 0 1];
    end
    
    
    properties (Transient)
        controller
        waitBarHandle;
        contextualMenu;
    end
    
    
    properties (Access = private)
        featureList;
        featureListSize;
        featureCount;
    end
    
    
    properties (Dependent = true)
        duration
    end
    
    
    events
        FeaturesDidChange
    end
    
    
    methods(Static)
        
        function n = typeName()
            % Return a name for this type of detector.
            
            n = 'Feature';
        end
        
        function ft = possibleFeatureTypes()
            % Return a list of the types of features this reporter can report.
            
            ft = {};
        end
        
        function initialize
            % Perform any set up for all instances of this detector type.
        end
        
        function n = actionName()
            n = 'Reporting features...';
        end
        
    end
    
    
    methods
        
        function obj = FeatureReporter(controller, varargin)
            obj = obj@handle();
            
            obj.controller = controller;
            
            obj.featureList = cell(1, 1000);
            obj.featureListSize = 1000;
            obj.featureCount = 0;
        end
        
        
        function f = features(obj, featureType)
            f = obj.featureList(1:obj.featureCount);
            
            if nargin > 1
                inds = strcmp({f.type}, featureType);
                f = f{inds};
            end
        end
        
        
        function setFeatures(obj, featureList)
            obj.featureList = num2cell(featureList);
            obj.featureListSize = length(featureList);
            obj.featureCount = obj.featureListSize;
            
            notify(obj, 'FeaturesDidChange');
        end
        
        
        function ft = featureTypes(obj)
            % Return the list of feature types that are being reported.  (a subset of the list returned by possibleFeatureTypes)
            % The list of types could be cached but this code is pretty fast.
            f = [obj.featureList{1:obj.featureCount}];
            if isempty(f)
                ft = {};
            else
                ft = unique({f.type});
            end
        end
        
        
        function addFeatures(obj, features)
            % Add the features to the list.
            numFeatures = length(features);
            obj.featureCount = obj.featureCount + numFeatures;
            while obj.featureCount > obj.featureListSize
                % Pre-allocate space for another 1000 features.
                obj.featureList = horzcat(obj.featureList, cell(1, 1000));
                obj.featureListSize = obj.featureListSize + 1000;
            end
            for i = 1:numFeatures
                if iscell(features)
                    obj.featureList{obj.featureCount - numFeatures + i} = features{i};
                else
                    obj.featureList{obj.featureCount - numFeatures + i} = features(i);
                end
            end
            
            notify(obj, 'FeaturesDidChange');
        end
        
        
        function removeFeatures(obj, features)
            featureWasRemoved = false;
            
            for j = 1:length(features)
                if iscell(features)
                    feature = features{j};
                else
                    feature = features(j);
                end
                
                pos = cellfun(@(f) eq(f, feature), {obj.featureList{1:obj.featureCount}});
                obj.featureList(pos) = [];
                obj.featureListSize = obj.featureListSize - 1;
                obj.featureCount = obj.featureCount - 1;
                
                featureWasRemoved = true;
            end
            
            if featureWasRemoved
                notify(obj, 'FeaturesDidChange');
            end
            
        end
        
        
        function d = get.duration(obj)
            % TODO: this value could be pre-computed
            fs = obj.features();
            if isempty(fs)
                d = 0;
            else
                d = max(cellfun(@(f) f.endTime, fs));
            end
        end
        
        
        function handled = keyWasPressedInPanel(obj, keyEvent, panel) %#ok<INUSD>
            handled = false;
        end
        
        
        function exportFeatures(obj)
            [fileName, pathName, filterIndex] = uiputfile({'*.mat', 'MATLAB file';'*.txt', 'Text file'}, 'Save features as', 'features.mat');
            
            if ischar(fileName)
                features = sort(obj.features());
                
                lowFreqs = [features.lowFreq];
                highFreqs = [features.highFreq];
                haveFreqRanges = any(~isinf(lowFreqs)) || any(~isinf(highFreqs));
                
                if filterIndex == 1
                    % Export as a MATLAB file
                    s.features = features;
                    s.featureTypes = {features.type};
                    s.startTimes = [features.startTime];
                    s.stopTimes = [features.endTime];
                    
                    if haveFreqRanges
                        s.lowFreqs = lowFreqs;
                        s.highFreqs = highFreqs; %#ok<STRNU>
                    end
                    
                    save(fullfile(pathName, fileName), '-struct', 's');
                else
                    % Export as an Excel tsv file
                    fid = fopen(fullfile(pathName, fileName), 'w');
                    
                    propNames = {};
                    ignoreProps = {'type', 'range', 'contextualMenu', 'startTime', 'endTime', 'lowFreq', 'highFreq', 'duration'};
                    
                    % Find all of the feature properties so we know how many columns there will be.
                    for f = 1:length(features)
                        feature = features(f);
                        props = properties(feature);
                        for p = 1:length(props)
                            if ~ismember(props{p}, ignoreProps)
                                propName = [feature.type ':' props{p}];
                                if ~ismember(propName, propNames)
                                    propNames{end + 1} = propName; %#ok<AGROW>
                                end
                            end
                        end
                    end
                    propNames = sort(propNames);
                    
                    % Export a header row.
                    fprintf(fid, 'Type\tStart Time\tEnd Time');
                    if haveFreqRanges
                        fprintf(fid, '\tLow Freq\tHigh Freq');
                    end
                    for p = 1:length(propNames)
                        fprintf(fid, '\t%s', propNames{p});
                    end
                    fprintf(fid, '\n');
                    
                    % Export the features.
                    for i = 1:length(features)
                        feature = features(i);
                        fprintf(fid, '%s\t%f\t%f', feature.type, feature.startTime, feature.endTime);
                        if haveFreqRanges
                            if isinf(feature.lowFreq)
                                fprintf(fid, '\t');
                            else
                                fprintf(fid, '\t%f', feature.lowFreq);
                            end
                            if isinf(feature.highFreq)
                                fprintf(fid, '\t');
                            else
                                fprintf(fid, '\t%f', feature.highFreq);
                            end
                        end
                        
                        propValues = cell(1, length(propNames));
                        props = sort(properties(feature));
                        for j = 1:length(props)
                            if ~ismember(props{j}, ignoreProps)
                                propName = [feature.type ':' props{j}];
                                index = strcmp(propNames, propName);
                                value = feature.(props{j});
                                if isnumeric(value)
                                    value = num2str(value);
                                end
                                propValues{index} = value;
                            end
                        end
                        for p = 1:length(propNames)
                            fprintf(fid, '\t%s', propValues{p});
                        end
                        fprintf(fid, '\n');
                    end
                    
                    fclose(fid);
                end
            end
        end
        
    end
    
    
    methods (Sealed)
        
        function startProgress(obj)
            action = obj.actionName();
            obj.waitBarHandle = waitbar(0, action, 'Name', obj.name);
            axesH = findobj(obj.waitBarHandle, 'type', 'axes');
            titleH = get(axesH, 'Title');
            set(titleH, 'FontSize', 12)
        end
        
        
        function updateProgress(obj, message, fractionComplete)
            global DEBUG
            
            if nargin < 3
                fractionComplete = 0;
            end
            waitbar(fractionComplete, obj.waitBarHandle, message);
            
            if DEBUG
                disp(message);
            end
        end
        
        
        function endProgress(obj)
            close(obj.waitBarHandle);
            obj.waitBarHandle = [];
        end
        
    end
    
end
