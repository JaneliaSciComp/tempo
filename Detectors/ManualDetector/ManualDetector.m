classdef ManualDetector < FeatureDetector
    
    properties
        % TODO: support pairs of hot keys/feature types
        hotKey
        featureType
    end
    
    
    methods(Static)
        
        function n = typeName()
            n = 'Manual Annotation';
        end
        
        function ft = possibleFeatureTypes()
            ft = {'Manual Annotation'};
        end
        
    end
    
    
    methods
        
        function obj = ManualDetector(controller)
            obj = obj@FeatureDetector(controller);
            obj.name = 'Manual Annotation';
            
            % TODO: Is there some way to set this based off of what the user has seen?  Add (or extend to) the displayRange every time a feature is added?
            %       If so then it would be a way for users to keep track of what they have worked on.
            obj.timeRangeDetected([0 controller.duration]);
        end
        
        
        function s = settingNames(~)
            s = {};
        end
        
        
        function n = detectFeatures(~, ~)
            % Nothing to do.
            n = [];
        end
        
        
        function handled = keyWasPressed(obj, keyEvent)
            if keyEvent.Character == obj.hotKey     % or .Key?
                obj.addFeature(Feature(obj.featureType, obj.controller.selectedRange));
                
                handled = true;
            else
                handled = false;
            end
        end
    end
    
end
