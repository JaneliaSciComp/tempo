classdef FeatureDetector < handle
    
    properties
        name;
        waitBarHandle;
        contextualMenu;
        detectedTimeRanges;    % An nx2 matrix of non-overlapping time ranges (start, end) in ascending order.
    end
    
    
    properties (Access = private)
        featureList;
        featureListSize;
        featureCount;
    end
    
    
    properties (SetAccess = private)
        % Can only be changed by setRecording().
        recording
    end
    
    
    methods(Static)
        
        function n = typeName()
            % Return a name for this type of detector.
            
            n = 'Feature';
        end
        
        function initialize
            % Perform any set up for all instances of this detector type.
        end
        
    end
    
    
    methods
        
        function obj = FeatureDetector(recording, varargin)
            obj = obj@handle();
            
            obj.setRecording(recording);
            
            % TODO: what if the detector wants to look at the video?
        end
        
        
        function setRecording(obj, recording)
            obj.recording = recording;
            obj.featureList = cell(1, 1000);
            obj.featureListSize = 1000;
            obj.featureCount = 0;
            obj.detectedTimeRanges = [];
        end
        
        
        function f = settingsFunc(obj)
            % Return the function used to edit the settings of this detector.
            % By default the function is determined from the name of the object's class by 
            % replacing 'Detector' with 'Settings', but this behavior can be overridden.
            
            % Determine the function name from the class name.
            settingsFuncName = class(obj);
            if strcmp(settingsFuncName(end-7:end), 'Detector')
                settingsFuncName = settingsFuncName(1:end-8);
            end
            settingsFuncName = [settingsFuncName 'Settings'];
            
            % Return the function's handle.
            f = str2func(settingsFuncName);
        end
        
        
        function sn = settingNames(obj) %#ok<MANU>
            % Return the names of all settings.
            sn = {};
        end
        
        
        function edited = editSettings(obj)
            % Present a GUI to edit this detector's settings.
            % Returns true if the settings were changed, false if the user cancelled.
            
            % Pass this detector to the GUI.
            settingsFunc = obj.settingsFunc();
            edited = settingsFunc(obj);
        end
        
        
        function showSettings(obj)
            % Present a GUI to edit this detector's settings.
            % Returns true if the settings were changed, false if the user cancelled.
            
            % Pass this detector to the GUI.
            settingsFunc = obj.settingsFunc();
            settingsFunc(obj, 'Editable', false);
        end
        
        
        function s = settings(obj)
            % Return a structure containing all of the settings of this detector.
            
            s = struct();
            for setting = obj.settingNames()
                s.(setting) = obj.(setting{1});
            end
        end
        
        
        function timeRangeDetected(obj, timeRange)
            % Merge the new time range with the existing time ranges.
            % The new range can intersect or completely replace existing ranges.
            
            if isempty(obj.detectedTimeRanges)
                obj.detectedTimeRanges = timeRange;
            elseif timeRange(2) < obj.detectedTimeRanges(1, 1)
                obj.detectedTimeRanges = vertcat(timeRange, obj.detectedTimeRanges);
            elseif timeRange(1) > obj.detectedTimeRanges(end, 2)
                obj.detectedTimeRanges = vertcat(obj.detectedTimeRanges, timeRange);
            else
                firstRange = find(obj.detectedTimeRanges(:,2) >= timeRange(1), 1, 'first');
                lastRange = find(obj.detectedTimeRanges(:,1) < timeRange(2), 1, 'last');

                if obj.detectedTimeRanges(firstRange, 1) < timeRange(1)
                    timeRange(1) = obj.detectedTimeRanges(firstRange, 1);
                end
                if obj.detectedTimeRanges(lastRange, 2) > timeRange(2)
                    timeRange(2) = obj.detectedTimeRanges(lastRange, 2);
                end

                if lastRange > firstRange
                    obj.detectedTimeRanges(firstRange+1:lastRange, :) = [];
                end
                obj.detectedTimeRanges(firstRange,:) = timeRange;
            end
        end
        
        
        function f = features(obj, featureType)
            f = [obj.featureList{1:obj.featureCount}];
            
            if nargin > 1
                inds = strcmp({f.type}, featureType);
                f = f(inds);
            end
        end
        
        
        function ft = featureTypes(obj)
            % The list of types could be cached but this code is pretty fast.
            f = [obj.featureList{1:obj.featureCount}];
            ft = unique({f.type});
        end
    end
    
    
    methods (Sealed)
        
        function startProgress(obj)
            obj.waitBarHandle = waitbar(0, 'Detecting features...', 'Name', obj.name);
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
    
    
    methods (Abstract)
        
        % Subclasses must define this method.
        n = detectFeatures(obj, timeRange)
        
    end
    
    
    methods (Access = protected)
        
        function addFeature(obj, feature)
            % Add the feature to the list.
            obj.featureCount = obj.featureCount + 1;
            if obj.featureCount > obj.featureListSize
                % Pre-allocate space for another 1000 features.
                obj.featureList = horzcat(obj.featureList, cell(1, 1000));
                obj.featureListSize = obj.featureListSize + 1000;
            end
            obj.featureList{obj.featureCount} = feature;
        end
        
    end
    
end
