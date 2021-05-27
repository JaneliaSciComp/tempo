classdef TimelinePanel < TempoPanel
	
    properties
        showsFrequencyRange = false
    end
    
	properties (Transient)
        timeLine
        selectionPatch
        
        axesXLim = [0 0]
        
        displayRangeListener
        selectedRangeListener
	end
	
	methods
		
		function obj = TimelinePanel(controller, varargin)
			obj = obj@TempoPanel(controller, varargin{:});
             
            obj.handleSelectedRangeChanged();
%             obj.handleDisplayRangeChanged();
        end
        
        
        function createUI(obj, varargin)
            createUI@TempoPanel(obj, varargin{:});
            
            % Use a line to indicate the current time in the axes.
            obj.timeLine = line([0 0], [-100000 200000], 'Color', [1 0 0], 'HitTest', 'off', 'HandleVisibility', 'off');
            
            % Use a filled rectangle to indicate the current selection in the axes.
            obj.selectionPatch = patch([0 1 1 0], [-100000 -100000 200000 200000], 'r', 'FaceAlpha', 0.2, 'EdgeColor', 'none', 'Visible', 'off', 'HitTest', 'off', 'HandleVisibility', 'off');
            
            % Add listeners so we know when the current time and selection change.
            obj.displayRangeListener = addlistener(obj.controller, 'displayRange', 'PostSet', @(source, event)handleDisplayRangeChanged(obj, source, event));
            obj.selectedRangeListener = addlistener(obj.controller, 'selectedRange', 'PostSet', @(source, event)handleSelectedRangeChanged(obj, source, event));
            
            obj.axesXLim = [0 0];
		end
        
        
        function handleSelectedRangeChanged(obj, ~, ~)
            if ~obj.isHidden
                if obj.showsFrequencyRange
                    % Hide the current time indicator if the user has chosen a range of frequencies.
                    if isinf(obj.controller.selectedRange(3))
                        set(obj.timeLine, 'Visible', 'on');
                        set(obj.selectionPatch, 'EdgeColor', 'none');
                    else
                        set(obj.timeLine, 'Visible', 'off');
                        set(obj.selectionPatch, 'EdgeColor', 'red');
                    end
                end
                
                % Update the position and visibility of the current selection indicator.
                if obj.controller.selectedRange(1) ~= obj.controller.selectedRange(2)
                    minTime = obj.controller.selectedRange(1);
                    maxTime = obj.controller.selectedRange(2);
                    if ~obj.showsFrequencyRange
                        set(obj.selectionPatch, 'XData', [minTime maxTime maxTime minTime], ...
                                                'Visible', 'on');
                    else
                        minFreq = obj.controller.selectedRange(3);
                        maxFreq = obj.controller.selectedRange(4);
                        
                        % Map the min and max freq's to the range of the axes.
                        % (The YLim of the axes should be the same as the displayRange but it's not exact.)
                        freqHeight = obj.controller.displayRange(4) - obj.controller.displayRange(3);
                        yLim = get(obj.axes, 'YLim');
                        axesHeight = yLim(2) - yLim(1);
                        minFreq = yLim(1) + max((minFreq - obj.controller.displayRange(3)) / freqHeight, 0) * axesHeight;
                        maxFreq = yLim(1) + min((maxFreq - obj.controller.displayRange(3)) / freqHeight, 1) * axesHeight;
                        set(obj.selectionPatch, 'XData', [minTime maxTime maxTime minTime], ...
                                                'YData', [minFreq minFreq maxFreq maxFreq], ...
                                                'Visible', 'on');
                    end
                else
                    set(obj.selectionPatch, 'Visible', 'off');
                end
            end
        end
        
        
        function handleDisplayRangeChanged(obj, ~, ~)
            if ~obj.isHidden && ~isempty(obj.controller) && ~isempty(obj.controller.displayRange)
                % For performance only update the axes if the time range has changed.
                % The spectogram needs to update even when playback stops and the range doesn't change so it's special cased.
                if ~isempty(obj.controller.displayRange) && (any(obj.axesXLim ~= obj.controller.displayRange(1:2)) || isa(obj, 'SpectrogramPanel'))
                    set(obj.axes, 'XLim', obj.controller.displayRange(1:2));
                    obj.axesXLim = obj.controller.displayRange(1:2);
                
                    % Let the subclass update the axes content.
                    obj.updateAxes(obj.controller.displayRange)
                end
            end
        end
        
        
        function handleResize(obj, source, event)
            handleResize@TempoPanel(obj, source, event);
            if ~obj.isHidden
                obj.handleDisplayRangeChanged(source, event);
            end
        end
        
        
        function setEditedRange(obj, editedObject, range, ~)
            if editedObject == obj.axes
                % The user modified the selection with the mouse.
                
                % If the current time was at the beginning or end of the selection then keep it there.
                % TODO: does this still work with modifying a feature?
                if obj.controller.currentTime == obj.controller.selectedRange(1)
                    obj.controller.currentTime = range(1);
                elseif obj.controller.currentTime == obj.controller.selectedRange(2)
                    obj.controller.currentTime = range(2);
                end
                
                obj.controller.selectedRange = range;
            end
        end
        
        
        function showSelection(obj, flag)
            if ~obj.isHidden
                % Show or hide the current time line and selected time indicators.
                if flag
                    if ~obj.showsFrequencyRange && ~isinf(obj.controller.selectedRange(3))
                        set(obj.timeLine, 'Visible', 'on');
                    end
                    if obj.controller.selectedRange(1) ~= obj.controller.selectedRange(2)
                        set(obj.selectionPatch, 'Visible', 'on');
                    else
                        set(obj.selectionPatch, 'Visible', 'off');
                    end
                else
                    set([obj.timeLine, obj.selectionPatch], 'Visible', 'off');
                end
            end
        end
        
        
        function currentTimeChanged(obj)
            % Update the position of the current time indicator.
            set(obj.timeLine, 'XData', [obj.controller.currentTime obj.controller.currentTime]);
            
            % Make sure they are still rendered in front of all other objects.
            % In case new features, etc. have been added.
            if ~obj.controller.isPlaying
                uistack([obj.timeLine, obj.selectionPatch], 'top');
            end
        end
        
        
        function setHidden(obj, hidden)
			setHidden@TempoPanel(obj, hidden);
            
            if ~obj.isHidden
                % Make sure everything is in sync.
                obj.handleSelectedRangeChanged([], []);
                obj.handleDisplayRangeChanged([], []);
            end
        end
        
        
        function updateAxes(obj, timeRange) %#ok<INUSD>
            % TODO: make abstract?
        end
		
        
        function handled = keyWasPressed(obj, keyEvent)
            % Handle keyboard navigation of the timeline.
            % Arrow keys move the display left/right by one tenth of the displayed range.
            % Page up/down moves left/right by a full window's worth.
            % Command+arrow keys moves to the beginning/end of the timeline.
            % Option+left/right arrow key moves to the previous/next feature.
            % Shift plus any of the above extends the selection.
            % Up/down arrow keys zoom out/in
            % Command+up arrow zooms all the way out
            handled = false;
            timeChange = 0;
            pageSize = obj.controller.displayRange(2) - obj.controller.displayRange(1);
            stepSize = pageSize / 10;
            shiftDown = any(ismember(keyEvent.Modifier, 'shift'));
            altDown = any(ismember(keyEvent.Modifier, 'alt'));
            cmdDown = any(ismember(keyEvent.Modifier, 'command'));
            if strcmp(keyEvent.Key, 'leftarrow')
                if cmdDown
                    timeChange = -obj.controller.currentTime;
                elseif ~altDown
                    timeChange = -stepSize;
                end
            elseif strcmp(keyEvent.Key, 'rightarrow')
                if cmdDown
                    timeChange = obj.controller.duration - obj.controller.currentTime;
                elseif ~altDown
                    timeChange = stepSize;
                end
            elseif strcmp(keyEvent.Key, 'pageup')
                timeChange = -2/3*pageSize;
            elseif strcmp(keyEvent.Key, 'pagedown')
                timeChange = 2/3*pageSize;
            elseif strcmp(keyEvent.Key, 'uparrow')
                if cmdDown
                    obj.controller.setZoom(1);
                else
                    obj.controller.setZoom(obj.controller.zoom / 2);
                end
                
                handled = true;
            elseif strcmp(keyEvent.Key, 'downarrow')
                % TODO: is there a maximum zoom that could be set if command was down?  one pixel per sample?
                obj.controller.setZoom(obj.controller.zoom * 2);
                
                handled = true;
            end

            if timeChange ~= 0
                set(obj.controller.figure, 'Pointer', 'watch'); drawnow
                
                newTime = max([0 min([obj.controller.duration obj.controller.currentTime + timeChange])]);
                if shiftDown
                    if obj.controller.currentTime == obj.controller.selectedRange(1)
                        obj.controller.selectedRange = [sort([obj.controller.selectedRange(2) newTime]) obj.controller.selectedRange(3:4)];
                    else
                        obj.controller.selectedRange = [sort([newTime obj.controller.selectedRange(1)]) obj.controller.selectedRange(3:4)];
                    end
                else
                    obj.controller.selectedRange = [newTime newTime obj.controller.selectedRange(3:4)];
                end
                obj.controller.currentTime = newTime;
                obj.controller.centerDisplayAtTime(newTime);
                
                set(obj.controller.figure, 'Pointer', 'arrow'); drawnow update
                
                handled = true;
            elseif ~handled
                handled = keyWasPressed@TempoPanel(obj, keyEvent);
            end
        end
        
        
        function close(obj)
            delete(obj.displayRangeListener);
            obj.displayRangeListener = [];
            delete(obj.selectedRangeListener);
            obj.selectedRangeListener = [];
            
            close@TempoPanel(obj);
        end
        
        
        function delete(obj)
            delete(obj.displayRangeListener);
            obj.displayRangeListener = [];
            delete(obj.selectedRangeListener);
            obj.selectedRangeListener = [];
        end
        
	end
	
end
