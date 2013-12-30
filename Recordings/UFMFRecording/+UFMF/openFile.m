function obj = openFile(filePath)
    % Open an existing UFMF file.
    
    obj = UFMF.UFMFFile(filePath, 'read');
end
