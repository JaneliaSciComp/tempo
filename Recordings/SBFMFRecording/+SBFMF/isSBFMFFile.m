function isSBFMF = isSBFMFFile(filePath)
    % Test if the file at the indicated path is in SBFMF format.
    
    isSBFMF = false;

    if exist(filePath, 'file')
        % Check if the file is a known version of SBFMF.
        % TODO: any other versions lurking out there?
        fid = fopen(filePath, 'rb' , 'ieee-le');
        if fid >= 0
            try
                % version: 4 byte length + string
                verBytes = fread(fid, 1, 'uint32');
                version = fread(fid, 4, '*char')';   %hack
                isSBFMF = strncmp(version, '0.3b', 4);
                fclose(fid);
            catch ME
                fclose(fid);
                rethrow(ME);
            end
        end
    end
end
