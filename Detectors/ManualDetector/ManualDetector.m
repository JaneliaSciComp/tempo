classdef ManualDetector < FeatureDetector
    
    properties
        % TODO: support pairs of hot keys/feature types
        hotKey
        featureType
    end
    
    
    methods(Static)
        
        function n = typeName()
            n = 'Manual Annotations';
        end
        
        function ft = possibleFeatureTypes()
            ft = {'Manual Annotation'};
        end
        
    end
    
    
    methods
        
        function obj = ManualDetector(controller)
            obj = obj@FeatureDetector(controller);
            
            % TODO: Is there some way to set this based off of what the user has seen?  Add (or extend to) the displayRange every time a feature is added?
            %       If so then it would be a way for users to keep track of what they have worked on.
            obj.addFeaturesInTimeRange([], [0 controller.duration]);
        end
        
        
        function s = settingNames(~)
            s = {'hotKey', 'featureType'};
        end
        
        
        function features = detectFeatures(~, ~)
            % Nothing to do.
            features = [];
        end
        
        
        function handled = keyWasPressed(obj, keyEvent)
            if keyEvent.Character == obj.hotKey     % or .Key?
                features = {Feature(obj.featureType, obj.controller.selectedRange)};
                obj.addFeatures(features);
                
                obj.controller.addUndoableAction(['Add ' obj.featureType], ...
                                                  @() obj.removeFeatures(features), ...
                                                  @() obj.addFeatures(features));
                
                handled = true;
            else
                handled = false;
            end
        end
    end
    
end
