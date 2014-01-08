classdef PulseTrainDetector < FeatureDetector
    
    properties    
        baseReporter
        pulseFeatureType
        maxIPI = 0.1
        minPulses = 3
    end
    
    
    methods(Static)
        
        function n = typeName()
            n = 'Pulse Trains';
        end
        
        function ft = possibleFeatureTypes()
            ft = {'Pulse Train'};
        end
        
    end
    
    
    methods
        
        function obj = PulseTrainDetector(controller)
            obj = obj@FeatureDetector(controller);
            obj.name = 'Pulse Train Detector';
        end
        
        
        function s = settingNames(~)
            s = {'baseReporter', 'pulseFeatureType', 'maxIPI', 'minPulses'};
        end
        
        
        function features = detectFeatures(obj, timeRange)
            features = {};
            
            pulses = obj.baseReporter.features(obj.pulseFeatureType);
            pulseTimes = sort([pulses.startTime]);
            
            obj.updateProgress('Looking for pulse trains...');
            
            % Find any series of at least obj.minPulses pulses that are no more than obj.maxIPI seconds apart.
            startPulse = 1;
            for i = 2:length(pulseTimes)
                if pulseTimes(i) - pulseTimes(i-1) > obj.maxIPI || i == length(pulseTimes)
                    if i - startPulse >= obj.minPulses && ...
                            pulseTimes(startPulse) < timeRange(2) && pulseTimes(i - 1) > timeRange(1)
                        ipis = pulseTimes(startPulse + 1:i - 1) - pulseTimes(startPulse:i - 2);
                        ipiMean = mean(ipis);
                        ipiStd = std(ipis);
                        feature = Feature('Pulse Train', [pulseTimes(startPulse) - ipiMean / 2 pulseTimes(i - 1) + ipiMean / 2], ...
                                          'pulseCount', i - startPulse, ...
                                          'ipiMean', ipiMean, ...
                                          'ipiStd', ipiStd, ...
                                          'ipiStdErr', ipiStd / sqrt(length(ipis)));
                        features{end + 1} = feature; %#ok<AGROW>
                    end
                    
                    startPulse = i;
                end
            end
        end
        
    end
    
end
