classdef UndoManager < handle
    
    properties (Access=private)
        undoStack
        undoIndex
    end
    
    
    events
        UndoStackChanged
    end
    
    
    methods
        
        function obj = UndoManager()
            obj.undoStack = {};
            obj.undoIndex = 0;
        end
        
        
        function addAction(obj, actionName, undoAction, redoAction, context, userData)
            % Create a new action.
            action.name = actionName;
            action.undo = undoAction;
            action.redo = redoAction;
            action.context = context;
            if nargin < 6
                userData = [];
            end
            action.userData = userData;
            
            % Add the action to the stack.
            % Any redoable actions on the stack are cleared.
            % TODO: should there be a maximum size to the stack?
            obj.undoStack(obj.undoIndex + 1:end) = [];
            obj.undoIndex = obj.undoIndex + 1;
            obj.undoStack{obj.undoIndex} = action;
            
            notify(obj, 'UndoStackChanged');
            
%             % Mark the workspace as dirty.
%             % TODO: can this be determined by the state of the undo stack?
%             obj.needsSave = true;
        end
        
        
        function actionName = nextUndoAction(obj)
            if obj.undoIndex > 0
                actionName = obj.undoStack{obj.undoIndex}.name;
            else
                actionName = [];
            end
        end
        
        
        function actionName = nextRedoAction(obj)
            if obj.undoIndex < length(obj.undoStack)
                actionName = obj.undoStack{obj.undoIndex + 1}.name;
            else
                actionName = [];
            end
        end
        
        
        function userData = undo(obj, ~, ~)
            if obj.undoIndex == 0
                % There is nothing to undo.
                beep
            else
                % Perform the current undo action.
                action = obj.undoStack{obj.undoIndex};
                action.undo();
                userData = action.userData;
                
                % Move one place back in the stack.
                obj.undoIndex = obj.undoIndex - 1;
                
                notify(obj, 'UndoStackChanged');
                
%                 % Reset the display and selection to where it was when the action was performed.
%                 obj.displayRange = action.displayRange;
%                 obj.selectedRange = action.selectedRange;
            end
        end
        
        
        function userData = redo(obj, ~, ~)
            if obj.undoIndex == length(obj.undoStack)
                % There is nothing to redo.
                beep
            else
                % Perform the current redo action.
                action = obj.undoStack{obj.undoIndex + 1};
                action.redo();
                userData = action.userData;
                
                % Move one place forward in the stack.
                obj.undoIndex = obj.undoIndex + 1;
                
                notify(obj, 'UndoStackChanged');
                
%                 % Reset the display and selection to where it was when the action was performed.
%                 obj.displayRange = action.displayRange;
%                 obj.selectedRange = action.selectedRange;
           end
        end
        
        
        function clearUndoContext(obj, context)
            % Remove all actions associated with the context.
            i = length(obj.undoStack);
            while i > 0
                if obj.undoStack{i}.context == context
                    % Remove the action.
                    obj.undoStack(i) = [];
                    
                    % Make sure the index points to the first action prior to its current 
                    % action that is _not_ associated with the context being removed.
                    if obj.undoIndex >= i
                        obj.undoIndex = obj.undoIndex - 1;
                    end
                end
                i = i - 1;
            end
            
            notify(obj, 'UndoStackChanged');
        end
        
        
        function clearActions(obj)
            obj.undoStack = {};
            obj.undoIndex = 0;
            
            notify(obj, 'UndoStackChanged');
        end
        
        
        function printStack(obj)
            % For debugging.
            for i = 1:length(obj.undoStack)
                if i > obj.undoIndex
                    undoRedo = 'Redo';
                else
                    undoRedo = 'Undo';
                end
                fprintf('%s "%s" (%s)\n', undoRedo, obj.undoStack{i}.name, class(obj.undoStack{i}.context));
            end
        end
        
    end
    
end
