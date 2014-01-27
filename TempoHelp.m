classdef TempoHelp < Singleton

    properties (Access=private)
        window
        toolbar
        browser
        
        helpPath
    end
    
    
    methods
        
        function obj = TempoHelp()
            obj = obj@Singleton();
            
            if isempty(obj.window)
                % Get the root of the documentation folder.
                [tempoRoot, ~, ~] = fileparts(mfilename('fullpath'));
                obj.helpPath = fullfile(tempoRoot, 'Documentation');
                
                obj.window = figure('Name', 'Tempo Help', ...
                    'NumberTitle', 'off', ...
                    'Toolbar', 'none', ...
                    'MenuBar', 'none', ...
                    'Position', getpref('Tempo', 'HelpWindowPosition', [100 100 700 400]), ...
                    'Color', [0.4 0.4 0.4], ...
                    'CloseRequestFcn', @(source, event)handleClose(obj, source, event), ...
                    'Visible', 'off');
                
                % Create the HTML browser control.
                jObject = com.mathworks.mlwidgets.html.HTMLBrowserPanel;
                [obj.browser, container] = javacomponent(jObject, [], obj.window);
                obj.browser.addToolbar();
                set(container, 'Units', 'norm', 'Position', [0.0, 0.0, 1.0, 1.0]);
            end
        end
        
        
        function openPage(obj, pageGroup, pageName)
            % Open the specified help page.
            
            if nargin == 1
                helpFilePath = fullfile(obj.helpPath, 'index.html');
            elseif nargin == 2
                helpFilePath = fullfile(obj.helpPath, [pageGroup '.html']);
                if ~exist(helpFilePath, 'file')
                    helpFilePath = fullfile(obj.helpPath, pageGroup, 'index.html');
                end
            else
                helpFilePath = fullfile(obj.helpPath, pageGroup, [pageName '.html']);
            end
            
            obj.browser.setCurrentLocation(['file://' helpFilePath]);
            
            % Make sure the window is showing.
            set(obj.window, 'Visible', 'on');
        end
        
        
        function handleGoHome(obj, ~, ~)
            obj.openPage();
        end
        
        
        function handleGoBack(obj, ~, ~)
            % TODO
        end
        
        
        function handleClose(obj, ~, ~)
            % Remember the window position.
            setpref('Tempo', 'HelpWindowPosition', get(obj.window, 'Position'));
            
            % Don't really close, just hide.
            set(obj.window, 'Visible', 'off');
        end
        
    end
    
end
