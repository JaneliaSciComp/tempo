function isUFMF = isUFMFFile(filePath)
    % Test if the file at the indicated path is in UFMF format.
    
    isUFMF = false;

    if exist(filePath, 'file')
        % Check if the file has 'ufmf' for its first four byte.
        fid = fopen(filePath, 'rb' , 'ieee-le');
        if fid >= 0
            try
                s = fread(fid, [1, 4], '*char');
                isUFMF = strcmp(s, 'ufmf');
                fclose(fid);
            catch ME
                fclose(fid);
                rethrow(ME);
            end
        end
    end
end
