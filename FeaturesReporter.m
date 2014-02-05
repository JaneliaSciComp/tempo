classdef FeaturesReporter < handle
    
    properties
        name;
        featuresColor = [0 0 1];
    end
    
    
    properties (Transient)
        controller
        featuresRange
    end
    
    
    properties (Transient, Access = private)
        waitBarHandle
        cachedFeatureTypes
    end
    
    
    properties (Access = private)
        featureList = {}
        featureListSize
        featureCount
    end
    
    
    properties (Dependent = true)
        duration
    end
    
    
    events
        FeatureTypesDidChange
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
        
        function obj = FeaturesReporter(controller, varargin)
            obj = obj@handle();
            
            obj.controller = controller;
            
            obj.featureList = cell(1, 1000);
            obj.featureListSize = 1000;
            obj.featureCount = 0;
        end
        
        
        function fs = features(obj, featureType)
            fs = obj.featureList(1:obj.featureCount);
            
            if nargin > 1
                inds = cellfun(@(f) strcmp(f.type, featureType), fs);
                fs = fs(inds);
            end
        end
        
        
        function setFeatures(obj, featureList)
            if iscell(featureList)
                obj.featureList = featureList;
            else
                obj.featureList = num2cell(featureList);
            end
            obj.featureListSize = length(featureList);
            obj.featureCount = obj.featureListSize;
            
            obj.cachedFeatureTypes = {};
            
            notify(obj, 'FeaturesDidChange');
        end
        
        
        function types = featureTypes(obj)
            % Return the list of feature types that are being reported.
            if isempty(obj.cachedFeatureTypes)
                obj.cachedFeatureTypes = unique(cellfun(@(f) f.type, obj.featureList(1:obj.featureCount), 'UniformOutput', false));
            end
            
            types = obj.cachedFeatureTypes;
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
                    features{i}.reporter = obj;
                    obj.featureList{obj.featureCount - numFeatures + i} = features{i};
                else
                    features(i).reporter = obj;
                    obj.featureList{obj.featureCount - numFeatures + i} = features(i);
                end
            end
            
            % Check if any of the new features have a new type.
            if iscell(features)
                ~all(ismember(cellfun(@(f) f.type, features, 'UniformOutput', false), obj.featureTypes()));
            else
                [tmp{1:length(features)}]=deal(features.type);
                ~all(ismember(tmp, obj.featureTypes()));
            end
            if ans
                obj.cachedFeatureTypes = [];    % indicate that the types must be recalculated
                notify(obj, 'FeatureTypesDidChange', FeaturesChangedEventData('add', features));
            end
            
            obj.featuresRange = [];         % indicate that the range must be recalculated
            
            notify(obj, 'FeaturesDidChange', FeaturesChangedEventData('add', features));
        end
        
        
        function removeFeatures(obj, features)
            featureWasRemoved = false;
            
            for j = 1:length(features)
                if iscell(features)
                    feature = features{j};
                else
                    feature = features(j);
                end
                
                pos = cellfun(@(f) eq(f, feature), obj.featureList(1:obj.featureCount));
                obj.featureList(pos) = [];
                obj.featureListSize = obj.featureListSize - 1;
                obj.featureCount = obj.featureCount - 1;
                
                featureWasRemoved = true;
            end
            
            if featureWasRemoved
                obj.featuresRange = []; % indicate that the range must be recalculated
                
                notify(obj, 'FeaturesDidChange', FeaturesChangedEventData('remove', features));
            end
            
        end
        
        
        function d = get.duration(obj)
            range = obj.featuresRange();
            d = range(2);
        end
        
        
        function range = get.featuresRange(obj)
            % Return the maximum range of all features in time and frequency.
            if isempty(obj.featuresRange)
                % Calculate the maximum range of all features.
                obj.featuresRange = [0 0 -inf inf];
                features = obj.featureList(1:obj.featureCount);
                if ~isempty(features)
                    % Get the min and max in time and frequency of all features.
                    
                    minTime = min(cellfun(@(f) f.startTime, features));
                    maxTime = max(cellfun(@(f) f.endTime, features));
                    
                    lowFreqs = cellfun(@(f) f.lowFreq, features);
                    minFreq = min(lowFreqs(lowFreqs > -Inf));
                    if isempty(minFreq)
                        minFreq = -Inf;
                    end
                    
                    maxFreqs = cellfun(@(f) f.highFreq, features);
                    maxFreq = max(maxFreqs(maxFreqs < Inf));
                    if isempty(maxFreq)
                        maxFreq = Inf;
                    end
                    
                    obj.featuresRange = [minTime maxTime minFreq maxFreq];
                end
            end
            
            range = obj.featuresRange;
        end
        
        
        function handled = keyWasPressedInPanel(obj, keyEvent, panel) %#ok<INUSD>
            handled = false;
        end
        
        
        function exportFeatures(obj)
            [fileName, pathName, filterIndex] = uiputfile({'*.mat', 'MATLAB file';'*.txt', 'Text file'}, 'Save features as', 'features.mat');
            
            if ischar(fileName)
                features = obj.features();
                [~, ind] = sort(cellfun(@(f) f.startTime, features));
                features = features(ind);
                
                lowFreqs = cellfun(@(f) f.lowFreq, features);
                highFreqs = cellfun(@(f) f.highFreq, features);
                haveFreqRanges = any(~isinf(lowFreqs)) || any(~isinf(highFreqs));
                
                if filterIndex == 1
                    % Export as a MATLAB file
                    s.features = features;
                    s.featureTypes = cellfun(@(f) f.type, features, 'UniformOutput', false);
                    s.startTimes = cellfun(@(f) f.startTime, features);
                    s.stopTimes = cellfun(@(f) f.endTime, features);
                    
                    if haveFreqRanges
                        s.lowFreqs = lowFreqs;
                        s.highFreqs = highFreqs; 
                    end
                    
                    save(fullfile(pathName, fileName), '-struct', 's');
                else
                    % Export as an Excel tsv file
                    fid = fopen(fullfile(pathName, fileName), 'w');
                    
                    propNames = {};
                    ignoreProps = {'type', 'range', 'color', 'startTime', 'endTime', 'lowFreq', 'highFreq', 'duration'};
                    
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
