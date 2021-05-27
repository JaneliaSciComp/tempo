classdef ManualDetector < FeaturesDetector
    
    % This is just a dummy class to allow workspaces saved with the old manual detector to open in newer Tempo's that use FeaturesAnnotator's instead.
    
    methods (Static = true)
        
        function obj = loadobj(data)
            obj = FeaturesAnnotator([]);
            
            obj.name = data.name;
            obj.featuresColor = data.featuresColor;
            
            obj.featureSet = [];
            obj.featureSet(1).name = data.featureType;
            obj.featureSet(1).key = data.hotKey;
            obj.featureSet(1).color = data.featuresColor;
            obj.featureSet(1).isRange = true;
            
            obj.addFeatures(data.featureList(1:data.featureCount));
        end

    end
    
end
