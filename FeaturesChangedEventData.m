classdef FeaturesChangedEventData < event.EventData
    
    properties
        type        % add, remove
        features
    end
    
    methods
        
        function data = FeaturesChangedEventData(type, features)
            data.type = type;
            data.features = features;
        end
        
    end
end
