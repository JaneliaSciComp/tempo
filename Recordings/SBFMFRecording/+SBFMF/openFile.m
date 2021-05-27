function obj = openFile(filePath)
    % Open an existing SBFMF file.
    
    obj = SBFMF.SBFMFFile(filePath, 'read');
end
