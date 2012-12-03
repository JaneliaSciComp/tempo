classdef FeaturesPanel < TimelinePanel

	properties
        reporter
	end
	
	methods
	
		function obj = FeaturesPanel(controller, reporter)
			obj = obj@TimelinePanel(controller);
            
            obj.reporter = reporter;
            
            obj.axesBorder = [0 0 16 0];
        end
        
        
        function handled = keyWasPressed(obj, keyEvent)
            % Handle option/alt arrow keys to jump from feature to feature.
            % TODO: how will this work with multiple panels?
            
            timeChange = 0;
            shiftDown = any(ismember(keyEvent.Modifier, 'shift'));
            if any(ismember(keyEvent.Modifier, 'alt'));
                if strcmp(keyEvent.Key, 'leftarrow')
                    handles = updateFeatureTimes(handles);
                    earlierFeatureTimes = handles.featureTimes(handles.featureTimes < handles.currentTime);
                    if isempty(earlierFeatureTimes)
                        beep;
                    else
                        timeChange = earlierFeatureTimes(end) - handles.currentTime;
                    end
                elseif strcmp(keyEvent.Key, 'rightarrow')
                    handles = updateFeatureTimes(handles);
                    laterFeatureTimes = handles.featureTimes(handles.featureTimes > handles.currentTime);
                    if isempty(laterFeatureTimes)
                        beep;
                    else
                        timeChange = laterFeatureTimes(1) - handles.currentTime;
                    end
                end
            end

            if timeChange ~= 0
                newTime = max([0 min([obj.controller.maxMediaTime obj.controller.currentTime + timeChange])]);
                if shiftDown
                    if obj.controller.currentTime == obj.controller.selectedTime(1)
                        obj.controller.selectedTime = sort([obj.controller.selectedTime(2) newTime]);
                    else
                        obj.controller.selectedTime = sort([newTime obj.controller.selectedTime(1)]);
                    end
                else
                    obj.controller.selectedTime = [newTime newTime];
                end
                obj.controller.currentTime = newTime;
                obj.controller.displayedTime = newTime;
                
                handled = true;
            else
                handled = keyWasPressed@TimelinePanel(obj, keyEvent);
            end
        end
        
	end
	
end
