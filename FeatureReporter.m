classdef FeatureReporter < handle
    
    properties
        name;
        waitBarHandle;
        contextualMenu;
        featuresColor = [0 0 1];
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
        
        function obj = FeatureReporter(recording, varargin)
            obj = obj@handle();
            
            obj.setRecording(recording);
            
            % TODO: what if the reporter wants to look at the video?
        end
        
        
        function setRecording(obj, recording)
            if ~isequal(recording, obj.recording)
                obj.recording = recording;
                obj.featureList = cell(1, 1000);
                obj.featureListSize = 1000;
                obj.featureCount = 0;
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
            % Return the list of feature types that are being reported.  (a subset of the list returned by possibleFeatureTypes)
            % The list of types could be cached but this code is pretty fast.
            f = [obj.featureList{1:obj.featureCount}];
            ft = unique({f.type});
        end
        
        
        function removeFeature(obj, feature)
            for i = 1:obj.featureListSize
                if obj.featureList{i} == feature
                    obj.featureList(i) = [];
                    obj.featureListSize = obj.featureListSize - 1;
                    break;
                end
                
            end
        end
    end
    
    
    methods (Sealed)
        
        function startProgress(obj)
            action = obj.actionName();
            obj.waitBarHandle = waitbar(0, action, 'Name', obj.name);
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
