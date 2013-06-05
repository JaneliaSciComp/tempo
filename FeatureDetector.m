classdef FeatureDetector < FeatureReporter
    
    properties
        detectedTimeRanges;    % An nx2 matrix of non-overlapping time ranges (start, end) in ascending order.
    end
    
    
    methods(Static)
        
        function n = typeName()
            % Return a name for this type of detector.
            
            n = 'Feature';
        end
        
        function initialize
            % Perform any set up for all instances of this detector type.
        end
        
        function n = actionName()
            n = 'Detecting features...';
        end
        
    end
    
    
    methods
        
        function obj = FeatureDetector(controller, varargin)
            obj = obj@FeatureReporter(controller, varargin{:});
            
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
            try
                edited = settingsFunc(obj);
            catch ME
                if strcmp(ME.identifier, 'MATLAB:UndefinedFunction')
                    edited = true;
                else
                    rethrow(ME);
                end
            end
        end
        
        
        function showSettings(obj)
            % Present a GUI to edit this detector's settings.
            % Returns true if the settings were changed, false if the user cancelled.
            
            % Pass this detector to the GUI.
            settingsFunc = obj.settingsFunc();
            try
                settingsFunc(obj, 'Editable', false);
            catch ME
                if ~strcmp(ME.identifier, 'MATLAB:UndefinedFunction')
                    rethrow(ME);
                end
            end
        end
        
        
        function s = settings(obj)
            % Return a structure containing all of the settings of this detector.
            
            s = struct();
            for setting = obj.settingNames()
                s.(setting{1}) = obj.(setting{1});
            end
        end
        
        
        function timeRangeDetected(obj, timeRange)
            % Merge the new time range with the existing time ranges.
            % The new range can intersect or completely replace existing ranges.
            
            % TODO: this breaks if timeRange is entirely within obj.detectedTimeRanges
            
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
        
    end
    
    
    methods (Abstract)
        
        % Subclasses must define this method.
        n = detectFeatures(obj, timeRange)
        
    end
    
end
