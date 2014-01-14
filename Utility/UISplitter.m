classdef UISplitter < handle
    
    properties
        position = 0.5
        orientation = 'horizontal'
        paneOneIsVisible = true
        paneOneMinSize = 200
        paneTwoIsVisible = true
        paneTwoMinSize = 200
    end
    
    properties (Access = private)
        parent 
        
        paneOne   % left or top pane
        paneTwo   % right or bottom pane
        
        divider
        color = get(0, 'defaultUicontrolBackgroundColor')
        
        previousWindowMouseMotionCallback
        previousWindowMouseUpCallback
    end
    
    methods
        
        function obj = UISplitter(parent, paneOne, paneTwo, orientation)
            obj.parent = parent;
            obj.paneOne = paneOne;
            obj.paneTwo = paneTwo;
            if nargin > 3
                % Don't call setOrientation because it will arrange the panes prematurely and trigger their resize methods.
                if ~ismember(orientation, {'horizontal', 'vertical'})
                    error('UISplitter:InvalidOrientation', 'A UISplitter''s orientation must be ''horizontal'' or ''vertical''.');
                end
                obj.orientation = orientation;
            end
            
            % Create a little thumb icon to put in the middle of the divider.
            thumbIcon = zeros(6, 6, 3);
            thumbIcon(:,:,1) = [237 237 115 115 237 237; 237 64 128 144 160 237; 115 128 237 237 178 221; 115 144 237 237 221 233; 237 160 178 221 255 237; 237 237 221 233 237 237];
            thumbIcon(:,:,2) = [237 237 115 115 237 237; 237 64 128 144 160 237; 115 128 237 237 178 221; 115 144 237 237 221 233; 237 160 178 221 255 237; 237 237 221 233 237 237];
            thumbIcon(:,:,3) = [237 237 115 115 237 237; 237 64 128 144 160 237; 115 128 237 237 178 221; 115 144 237 237 221 233; 237 160 178 221 255 237; 237 237 221 233 237 237];
            thumbIcon = thumbIcon / 255.0;
            
            obj.divider = uipanel(obj.parent, ...
                'BorderType', 'none', ...
                'BorderWidth', 0, ...
                'BackgroundColor', obj.color, ...
                'SelectionHighlight', 'off', ...
                'ButtonDownFcn', @(hObject, eventdata)handleMouseDown(obj, hObject, eventdata), ... 
                'Units', 'pixels', ...
                'Position', [0 0 100 6]);
%             uicontrol(...
%                 'Parent', obj.divider, ...
%                 'Style', 'pushbutton', ...
%                 'CData', thumbIcon, ...
%                 'Units', 'normalized', ...
%                 'Position', [0.0 0.0 1.0 1.0], ...
%                 'Callback', @(hObject, eventdata)handleMouseDown(obj, hObject, eventdata), ... 
%                 'HitTest', 'on', ...
%                 'Enable', 'on');
        end
        
        
        function showPaneOne(obj, doShow)
            % Show or hide the first pane.
            if obj.paneOneIsVisible ~= doShow
                obj.paneOneIsVisible = doShow;
                set(obj.paneOne, 'Visible', onOff(doShow));
                obj.arrangePanes();
            end
        end
        
        
        function showPaneTwo(obj, doShow)
            % Show or hide the second pane.
            if obj.paneTwoIsVisible ~= doShow
                obj.paneTwoIsVisible = doShow;
                set(obj.paneTwo, 'Visible', onOff(doShow));
                obj.arrangePanes();
            end
        end
        
        
        function resize(obj)
            obj.arrangePanes();
        end
        
        
        function handleMouseDown(obj, ~, ~)
            % Steal the figure's mouse motion and mouse up callbacks while we drag the divider.
            obj.previousWindowMouseMotionCallback = get(gcf, 'WindowButtonMotionFcn');
            obj.previousWindowMouseUpCallback = get(gcf, 'WindowButtonUpFcn');
            
            set(gcf, 'WindowButtonMotionFcn', @(source, event)handleMouseMotion(obj, source, event));
            set(gcf, 'WindowButtonUpFcn', @(source, event)handleMouseUp(obj, source, event));
        end
        
        
        function handleMouseMotion(obj, ~, ~)
            % Determine the new divider position based on the mouse's position with the parent.
            prevUnits = get(obj.parent, 'Units');
            set(obj.parent, 'Units', 'pixels');
            clickedPoint = get(obj.parent, 'CurrentPoint');
            parentPos = get(obj.parent, 'Position');
            set(obj.parent, 'Units', prevUnits);
            
            if obj.orientation(1) == 'h'
                newPixelPosition = clickedPoint(1);
                parentSize = parentPos(3);
            else
                newPixelPosition = clickedPoint(2);
                parentSize = parentPos(4);
            end
            newPosition = newPixelPosition / parentSize;
            
            % Make sure neither pane gets too small.
            % The minimums can either by a fraction or a pixel count.
            pageOneMin = obj.paneOneMinSize;
            if pageOneMin > 1.0
                pageOneMin = pageOneMin / parentSize;   % Convert pixels to fraction.
            end
            pageTwoMin = obj.paneTwoMinSize;
            if pageTwoMin > 1.0
                pageTwoMin = pageTwoMin / parentSize;   % Convert pixels to fraction.
            end
            halfDividerWidth = 4.0 / parentSize;
            newPosition = max([newPosition,       pageOneMin + halfDividerWidth]);
            newPosition = min([newPosition, 1.0 - pageTwoMin - halfDividerWidth]);
            obj.position = newPosition;
            
            obj.arrangePanes();
        end
        
        
        function handleMouseUp(obj, ~, ~)
            % Restore the figure's mouse motion and mouse up callbacks.
            set(gcf, 'WindowButtonMotionFcn', obj.previousWindowMouseMotionCallback);
            set(gcf, 'WindowButtonUpFcn', obj.previousWindowMouseUpCallback);
        end
        
        
        function setOrientation(obj, orientation)
            if ~ismember(orientation, {'horizontal', 'vertical'})
                error('UISplitter:InvalidOrientation', 'A UISplitter''s orientation must be ''horizontal'' or ''vertical''.');
            end
            
            if ~strcmp(orientation, obj.orientation)
                obj.orientation = orientation;
                
                obj.arrangePanes();
            end
        end
        
        
        function arrangePanes(obj)
            % Get the size of the the parent in pixels.
            prevUnits = get(obj.parent, 'Units');
            set(obj.parent, 'Units', 'pixels');
            parentPos = get(obj.parent, 'Position');
            set(obj.parent, 'Units', prevUnits);
            
            if obj.orientation(1) == 'h'
                % Arrage the panes to the left and right of each other.
                
                if obj.position > 1
                    % Pane one should be a fixed number of pixels wide.
                    pixelPosition = obj.position;
                elseif obj.position < 0
                    % Pane two should be a fixed number of pixels wide.
                    pixelPosition = parentPos(3) + obj.position;
                else
                    % The position is a fraction of the parent.
                    pixelPosition = floor(parentPos(3) * obj.position);
                end
                
                % Resize the left pane.
                prevUnits = get(obj.paneOne, 'Units');
                set(obj.paneOne, 'Units', 'pixels', ...
                                 'Position', [0, 0, pixelPosition - 4, parentPos(4)]);
                set(obj.paneOne, 'Units', prevUnits);
                
                % Resize the divider.
                set(obj.divider, 'Position', [pixelPosition - 4, 0, 8, parentPos(4)]);
                 
                % Resize the right pane.
                prevUnits = get(obj.paneTwo, 'Units');
                set(obj.paneTwo, 'Units', 'pixels', ...
                                 'Position', [pixelPosition + 4, 0, parentPos(3) - pixelPosition - 4, parentPos(4)]);
                set(obj.paneTwo, 'Units', prevUnits);
            else
                % Arrage the panes above and below each other.
                
                if obj.position > 1
                    % Pane one should be a fixed number of pixels wide.
                    pixelPosition = obj.position;
                elseif obj.position < 0
                    % Pane two should be a fixed number of pixels wide.
                    pixelPosition = parentPos(4) + obj.position;
                else
                    % The position is a fraction of the parent.
                    pixelPosition = floor(parentPos(4) * obj.position);
                end
                
                % Resize the top pane.
                prevUnits = get(obj.paneOne, 'Units');
                set(obj.paneOne, 'Units', 'pixels', ...
                                 'Position', [0, pixelPosition + 4, parentPos(3), parentPos(3) - pixelPosition - 4]);
                set(obj.paneOne, 'Units', prevUnits);
                
                % Resize the divider.
                set(obj.divider, 'Position', [0, pixelPosition - 4, parentPos(3), 8]);
                 
                % Resize the bottom pane.
                prevUnits = get(obj.paneTwo, 'Units');
                set(obj.paneTwo, 'Units', 'pixels', ...
                                 'Position', [0, 0, parentPos(3), pixelPosition - 4]);
                set(obj.paneTwo, 'Units', prevUnits);
            end
        end
        
    end
    
end
