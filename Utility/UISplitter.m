classdef UISplitter < handle
    
    properties
        position = 0.4
        orientation = 'horizontal'
        paneOneMinSize = 200
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
        
        thumbAxes
    end
    
    methods
        
        function obj = UISplitter(parent, paneOne, paneTwo, orientation)
            obj.parent = parent;
            obj.paneOne = paneOne;
            obj.paneTwo = paneTwo;
            if nargin > 3
                obj.orientation = orientation;
            end
            
            obj.divider = uipanel(obj.parent, ...
                'BorderType', 'beveledout', ...
                'BorderWidth', 1, ...
                'BackgroundColor', obj.color, ...
                'SelectionHighlight', 'off', ...
                'ButtonDownFcn', @(hObject, eventdata)handleMouseDown(obj, hObject, eventdata), ... 
                'Units', 'pixels', ...
                'Position', [0 0 100 6]);
            
            % Create a little thumb in the middle of the divider.
            obj.thumbAxes = axes(...
                'Parent', obj.divider, ...
                'Color', 'none', ...
                'HitTest', 'off', ...
                'Units', 'pixels', ...
                'Position', [0 100 6 6]);
            thumbIcon = zeros(6, 6, 3);
            thumbIcon(:,:,1) = [237 237 115 115 237 237; 237 64 128 144 160 237; 115 128 237 237 178 221; 115 144 237 237 221 233; 237 160 178 221 255 237; 237 237 221 233 237 237] / 255.0;
            thumbIcon(:,:,2) = [237 237 115 115 237 237; 237 64 128 144 160 237; 115 128 237 237 178 221; 115 144 237 237 221 233; 237 160 178 221 255 237; 237 237 221 233 237 237] / 255.0;
            thumbIcon(:,:,3) = [237 237 115 115 237 237; 237 64 128 144 160 237; 115 128 237 237 178 221; 115 144 237 237 221 233; 237 160 178 221 255 237; 237 237 221 233 237 237] / 255.0;
            image(thumbIcon, 'HitTest', 'off');
            axis off;
            axis image;
            
            % Add listeners to the two panes so we can see when they are made visible/invisible.
            addlistener(paneOne, 'Visible', 'PostSet', @(source, event)handlePaneVisibilityChanged(obj, source, event));
            addlistener(paneTwo, 'Visible', 'PostSet', @(source, event)handlePaneVisibilityChanged(obj, source, event));
        end
        
        
        function handlePaneVisibilityChanged(obj, ~, ~)
            obj.arrangePanes();
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
            % Determine the new divider position based on the mouse's position within the parent.
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
            
            % Finally set the new position.
            obj.position = newPosition;
        end
        
        
        function handleMouseUp(obj, ~, ~)
            % Restore the figure's mouse motion and mouse up callbacks.
            set(gcf, 'WindowButtonMotionFcn', obj.previousWindowMouseMotionCallback);
            set(gcf, 'WindowButtonUpFcn', obj.previousWindowMouseUpCallback);
        end
        
        
        function set.position(obj, position)
            wasEmpty = isempty(obj.position);
            if obj.position ~= position
                obj.position = position;
                
                if ~wasEmpty
                    % Don't arrange the panes if we were just constructed so they aren't 
                    % prematurely arranged and trigger their resize methods.
                    obj.arrangePanes();
                end
            end
        end
        
        
        function set.orientation(obj, orientation)
            if ~ismember(orientation, {'horizontal', 'vertical'})
                error('UISplitter:InvalidOrientation', 'A UISplitter''s orientation must be ''horizontal'' or ''vertical''.');
            end
            
            wasEmpty = isempty(obj.orientation);
            if ~strcmp(orientation, obj.orientation)
                obj.orientation = orientation;
                
                if ~wasEmpty
                    % Don't arrange the panes if we were just constructed so they aren't 
                    % prematurely arranged and trigger their resize methods.
                    obj.arrangePanes();
                end
            end
        end
        
        
        function arrangePanes(obj)
            % Get the size of the the parent in pixels.
            prevUnits = get(obj.parent, 'Units');
            set(obj.parent, 'Units', 'pixels');
            parentPos = get(obj.parent, 'Position');
            set(obj.parent, 'Units', prevUnits);
            
            paneOneIsVisible = onOff(get(obj.paneOne, 'Visible'));
            paneTwoIsVisible = onOff(get(obj.paneTwo, 'Visible'));
            
            if ~paneOneIsVisible && ~paneTwoIsVisible
                % Neither pane is visible, hide the divider.
                set(obj.divider, 'Visible', 'off');
            elseif ~paneTwoIsVisible
                % Let the first pane have all of the space.
                set(obj.divider, 'Visible', 'off');
                prevUnits = get(obj.paneOne, 'Units');
                set(obj.paneOne, 'Units', 'pixels', 'Position', [0 0 parentPos(3:4)]);
                set(obj.paneOne, 'Units', prevUnits);
            elseif ~paneOneIsVisible
                % Let the second pane have all of the space.
                set(obj.divider, 'Visible', 'off');
                prevUnits = get(obj.paneTwo, 'Units');
                set(obj.paneTwo, 'Units', 'pixels', 'Position', [0 0 parentPos(3:4)]);
                set(obj.paneTwo, 'Units', prevUnits);
            elseif obj.orientation(1) == 'h'
                % Arrage the panes to the left and right of each other.
                set(obj.divider, 'Visible', 'on');
                
                % Position the thumb at the center of the divider.
                set(obj.thumbAxes, 'Position', [0, parentPos(4) / 2 - 3, 6, 6]);
                
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
                set(obj.divider, 'Visible', 'on');
                
                % Position the thumb at the center of the divider.
                set(obj.thumbAxes, 'Position', [parentPos(3) / 2 - 3, 1, 6, 6]);
                
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
