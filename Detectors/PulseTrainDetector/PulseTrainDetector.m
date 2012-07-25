classdef PulseTrainDetector < FeatureDetector
    
    properties    
        baseReporter
        pulseFeatureType
        maxIPI = 0.1
        minPulses = 3
    end
    
    
    methods(Static)
        
        function n = typeName()
            n = 'Pulse Train';
        end
        
        function ft = possibleFeatureTypes()
            ft = {'Pulse Train'};
        end
        
    end
    
    
    methods
        
        function obj = PulseTrainDetector(recording)
            obj = obj@FeatureDetector(recording);
            obj.name = 'Pulse Train Detector';
        end
        
        
        function s = settingNames(~)
            s = {};
        end
        
        
        function setRecording(obj, recording)
            setRecording@FeatureDetector(obj, recording);
        end
        
        
        function n = detectFeatures(obj, timeRange)
            n = 0;
            
            pulses = obj.baseReporter.features(obj.pulseFeatureType);
            pulseTimes = arrayfun(@(x) x.sampleRange(1), pulses);
            
            obj.updateProgress('Looking for pulse trains...');
            startPulse = 1;
            for i = 2:length(pulseTimes)
                if pulseTimes(i) - pulseTimes(i-1) > obj.maxIPI || i == length(pulseTimes)
                    if i - startPulse >= obj.minPulses
                        ipis = pulseTimes(startPulse + 1:i - 1) - pulseTimes(startPulse:i - 2);
                        ipiMean = mean(ipis);
                        ipiStd = std(ipis);
                        obj.addFeature(Feature('Pulse Train', [pulseTimes(startPulse) - ipiMean / 2 pulseTimes(i - 1) + ipiMean / 2], ...
                                               'pulseCount', i - startPulse, ...
                                               'duration', pulseTimes(i - 1) - pulseTimes(startPulse), ...
                                               'ipiMean', ipiMean, ...
                                               'ipiStd', ipiStd, ...
                                               'ipiStdErr', ipiStd / sqrt(length(ipis))));
                        n = n + 1;
                    end
                    
                    startPulse = i;
                end
            end
            
            obj.timeRangeDetected(timeRange);
        end
        
    end
    
end
