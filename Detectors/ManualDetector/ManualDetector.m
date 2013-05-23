classdef ManualDetector < FeatureDetector
    
    properties
        % TODO: support pairs of hot keys/feature types
        hotKey
        featureType
    end
    
    
    methods(Static)
        
        function n = typeName()
            n = 'Manual Detector';
        end
        
        function ft = possibleFeatureTypes()
            ft = {'Manual Detector'};
        end
        
    end
    
    
    methods
        
        function obj = ManualDetector(controller)
            obj = obj@FeatureDetector(controller);
            obj.name = 'Manual Detector';
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
