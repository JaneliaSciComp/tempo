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
                
                obj.createToolbar();
                
                % Create the HTML browser control.
                jObject = com.mathworks.mlwidgets.html.HTMLBrowserPanel;
                [obj.browser, container] = javacomponent(jObject, [], obj.window);
                set(container, 'Units', 'norm', 'Position', [0.0, 0.0, 1.0, 1.0]);
            end
        end
        
        
        function createToolbar(obj)
            % Home | Back Forward | Search(?)
            obj.toolbar = uitoolbar(obj.window);
            
            [tempoRoot, ~, ~] = fileparts(mfilename('fullpath'));
            iconRoot = fullfile(tempoRoot, 'Icons');
            defaultBackground = get(0, 'defaultUicontrolBackgroundColor');
            
            iconData = double(imread(fullfile(iconRoot, 'Home.png'), 'BackgroundColor', defaultBackground)) / 255;
            uipushtool(obj.toolbar, ...
                'Tag', 'home', ...
                'CData', iconData, ...
                'TooltipString', 'Show the main Tempo help page',... 
                'ClickedCallback', @(hObject, eventdata)handleGoHome(obj, hObject, eventdata));
        end
        
        
        function openPage(obj, pageGroup, pageName)
            % Open the specified help page.
            
            if nargin == 1
                helpFilePath = fullfile(obj.helpPath, 'index.html');
            elseif nargin == 2
                helpFilePath = fullfile(obj.helpPath, pageGroup, 'index.html');
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
