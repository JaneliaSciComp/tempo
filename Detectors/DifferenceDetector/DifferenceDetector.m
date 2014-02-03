classdef DifferenceDetector < FeaturesDetector
    
    properties    
        originalReporter
        originalFeatureName
        newReporter
        newFeatureName
        
        timeThreshold = 0.01
        frequencyThreshold = 10
    end
    
    
    methods(Static)
        
        function n = typeName()
            n = 'Differences';
        end
        
        function ft = possibleFeatureTypes()
            ft = {'Added', 'Removed'};
        end
        
    end
    
    
    methods
        
        function obj = DifferenceDetector(controller)
            obj = obj@FeaturesDetector(controller);
        end
        
        
        function s = settingNames(~)
            s = {'originalReporter', 'originalFeatureName', 'newReporter', 'newFeatureName'};
        end
        
        
        function features = detectFeatures(obj, timeRange)
            features = {};
            
            % Get the features of the original reporter sorted by start time and restricted to overlapping the time range.
            originalFeatures = obj.originalReporter.features(obj.originalFeatureName);
            originalFeatures = originalFeatures(cellfun(@(f) f.startTime <= timeRange(2) && f.endTime >= timeRange(1), originalFeatures));
            [~, sortInd] = sort(cellfun(@(f) f.startTime, originalFeatures));
            originalFeatures = originalFeatures(sortInd);
            
            % Get the features of the new reporter sorted by start time and restricted to overlapping the time range.
            newFeatures = obj.newReporter.features(obj.newFeatureName);
            newFeatures = newFeatures(cellfun(@(f) f.startTime <= timeRange(2) && f.endTime >= timeRange(1), newFeatures));
            [~, sortInd] = sort(cellfun(@(f) f.startTime, newFeatures));
            newFeatures = newFeatures(sortInd);
            
            featureCount = length(originalFeatures) + length(newFeatures);
            origFeatureCount = featureCount;
            while featureCount > 0
                obj.updateProgress('Looking for differences...', 1.0 - featureCount / origFeatureCount);
                
                % Compare the earliest feature from each reporter still in the queues.
                if isempty(originalFeatures)
                    origFeature = [];
                else
                    origFeature = originalFeatures{1};
                end
                if isempty(newFeatures)
                    newFeature = [];
                else
                    newFeature = newFeatures{1};
                end
                
                if isempty(origFeature)
                    features{end + 1} = Feature('Added', newFeature.range); %#ok<AGROW>
                    newFeatures(1) = [];
                    featureCount = featureCount - 1;
                elseif isempty(newFeature)
                    features{end + 1} = Feature('Removed', origFeature.range); %#ok<AGROW>
                    originalFeatures(1) = [];
                    featureCount = featureCount - 1;
                elseif origFeature.matches(newFeature, obj.timeThreshold, obj.frequencyThreshold);
                    % No difference.
                    originalFeatures(1) = [];
                    newFeatures(1) = [];
                    featureCount = featureCount - 2;
                elseif origFeature.startTime < newFeature.startTime
                    features{end + 1} = Feature('Removed', origFeature.range); %#ok<AGROW>
                    originalFeatures(1) = [];
                    featureCount = featureCount - 1;
                else
                    features{end + 1} = Feature('Added', newFeature.range); %#ok<AGROW>
                    newFeatures(1) = [];
                    featureCount = featureCount - 1;
                end
            end
        end
        
    end
    
end
