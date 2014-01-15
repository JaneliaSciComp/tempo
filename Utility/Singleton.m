classdef Singleton < handle
    
    properties (Constant)
        instances = containers.Map;
    end
    
    
    properties
        name
    end
    
    
    methods
        
        function obj = Singleton(name, varargin)
            % Create a new instance or return an existing instance with the same name.
            
            objClass = class(obj);
            
            if isempty(obj.instances) || ~isKey(obj.instances, objClass)
                obj.instances(objClass) = containers.Map; %#ok<MCCSP>
            end
            
            if nargin == 0
                name = 'default';
            end
            
            classInstances = obj.instances(objClass);
            if isempty(classInstances) || ~isKey(classInstances, name)
                % Create a new instance
                obj.name = name;
                
                classInstances(obj.name) = obj; %#ok<NASGU>
                
                % Make sure to remove the object from our map if it gets deleted.
                addlistener(obj, 'ObjectBeingDestroyed', @Singleton.removeInstance);
            else
                % Return an existing instance.
                obj = classInstances(name);
            end
        end
        
    end
    
    
    methods (Static)
        
        function i = all(className)
            if isempty(Singleton.instances) || ~isKey(Singleton.instances, className)
                i = [];
            else
                i = values(Singleton.instances(className));
                i = [i{:}];
            end
        end
        
        
        function e = exists(className, objectName)
            if isempty(Singleton.instances) || ~isKey(Singleton.instances, className)
                e = false;
            else
                classInstances = Singleton.instances(className);
                e = ~isempty(classInstances) && isKey(classInstances, objectName);
            end
        end
        
        
        function removeInstance(obj, ~)
            if ~isempty(Singleton.instances) && isKey(Singleton.instances, class(obj))
                classInstances = Singleton.instances(class(obj));
                if ~isempty(classInstances) && isKey(classInstances, obj.name)
                    %disp(['Removing singleton ' class(obj) ' ' obj.name]);
                    remove(classInstances, obj.name);
                end
            end
        end
        
    end
    
end
