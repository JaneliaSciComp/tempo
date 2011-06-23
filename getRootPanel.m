% From Yair Altman's findjobj utility (www.undocumentedmatlab.com)
function [jRootPane,contentSize] = getRootPanel(hFig)
    try
        contentSize = [0,0];  % initialize
        jRootPane = hFig;
        figName = get(hFig,'name');
        if strcmpi(get(hFig,'number'),'on')
            figName = regexprep(['Figure ' num2str(hFig) ': ' figName],': $','');
        end
        mde = com.mathworks.mde.desk.MLDesktop.getInstance;
        jFigPanel = mde.getClient(figName);
        jRootPane = jFigPanel;
        jRootPane = jFigPanel.getRootPane;
    catch
        try
            warning('off','MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');  % R2008b compatibility
            jFrame = get(hFig,'JavaFrame');
            jFigPanel = get(jFrame,'FigurePanelContainer');
            jRootPane = jFigPanel;
            jRootPane = jFigPanel.getComponent(0).getRootPane;
        catch
            % Never mind
        end
    end
    try
        % If invalid RootPane - try another method...
        warning('off','MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');  % R2008b compatibility
        jFrame = get(hFig,'JavaFrame');
        jAxisComponent = get(jFrame,'AxisComponent');
        jRootPane = jAxisComponent.getParent.getParent.getRootPane;
    catch
        % Never mind
    end
    try
        % If invalid RootPane, retry up to N times
        tries = 10;
        while isempty(jRootPane) && tries>0  % might happen if figure is still undergoing rendering...
            drawnow; pause(0.001);
            tries = tries - 1;
            jRootPane = jFigPanel.getComponent(0).getRootPane;
        end

        % If still invalid, use FigurePanelContainer which is good enough in 99% of cases... (menu/tool bars won't be accessible, though)
        if isempty(jRootPane)
            jRootPane = jFigPanel;
        end
        contentSize = [jRootPane.getWidth, jRootPane.getHeight];

        % Try to get the ancestor FigureFrame
        jRootPane = jRootPane.getTopLevelAncestor;
    catch
        % Never mind - FigurePanelContainer is good enough in 99% of cases... (menu/tool bars won't be accessible, though)
    end
end
