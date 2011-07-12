function [fileName, pathName] = uigetfile2(title)
    if ismac && verLessThan('matlab', '7.12')
        % Use the older AWT-style file dialog which has a native Mac look and feel.
        %desktop = com.mathworks.mde.desk.MLDesktop.getInstance();
        %mainFrame = desktop.getMainFrame();
        javaFrame = getRootPanel(gcf);
        fd = java.awt.FileDialog(javaFrame, '');
        fd.setTitle(title);
        java.lang.System.setProperty('apple.awt.fileDialogForDirectories', 'false');
        fd.show()
        if isempty(fd.getFile())
            return % the user cancelled
        end
        pathName = char(fd.getDirectory());
        fileName = char(fd.getFile());
    else
        [fileName, pathName] = uigetfile('*', title, 'MultiSelect', 'on');
    end
end
