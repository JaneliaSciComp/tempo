classdef FeatureDetector < handle
    
    properties
        name;
        featureTypes;
        waitBarHandle;
        contextualMenu;
        detectedTimeRanges = [];    % An nx2 matrix of non-overlapping time ranges (start, end) in ascending order.
    end
    
    
    properties (Access = private)
        featureList = Feature.empty();
    end
    
    
    properties (SetAccess = private)
        % Can only be set by initializer.
        recording
    end
    
    
    methods(Static)
        
        function n = typeName()
            % Return a name for this type of detector.
            
            n = 'Feature';
            
% TODO: it would be cool to do this automatically from the class name but only the base class seems to be accessible at this point.
%             n = class(???);
%             if numel(n) > 7 && strcmp(n(end-7:end), 'Detector')
%                 n = n(1:end-8);
%             end
%             n = regexprep(n, '([^A-Z])([A-Z])', '$1 $2');
%             n = strrep(n, '_', ' ');
            
        end
        
        function initialize
            % Perform any set up for all instances of this detector type.
        end
        
    end
    
    
    methods
        
        function obj = FeatureDetector(recording, varargin)
            obj = obj@handle();
            
            obj.recording = recording;
            
            % TODO: what if the detector wants to look at the video?
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
        
        
        function f = features(obj)
            f = obj.featureList;
        end
        
    end
    
    
    methods (Sealed)
        
        function startProgress(obj)
            obj.waitBarHandle = waitbar(0, 'Detecting features...', 'Name', obj.name);
        end
        
        
        function updateProgress(obj, message, fractionComplete)
            if nargin < 3
                fractionComplete = 0;
            end
            waitbar(fractionComplete, obj.waitBarHandle, message);
        end
        
        
        function endProgress(obj)
            close(obj.waitBarHandle);
            obj.waitBarHandle = [];
        end
        
    end
    
    
    methods (Abstract)
        
        % Subclasses must define this method.
        detectFeatures(obj, timeRange)
        
    end
    
    
    methods (Access = protected)
        
        function addFeature(obj, feature)
            % Add the feature to the list.
            obj.featureList(end + 1) = feature;
            
            obj.featureTypes = unique({obj.featureList.type});
        end
        
    end
    
end
