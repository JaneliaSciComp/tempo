function dataType = convertDataType(charOrClass)
    % Convert between a data type character and a MATLAB class name.
    % Data types from <http://docs.python.org/2/library/struct.html#format-characters>
        
    persistent dataTypes;
    
    if isempty(dataTypes)
        dataTypes = struct('typeChar', {'c', 's', 'p', 'b', 'B', 'h', 'H', 'i', 'l', 'I', 'L', 'q', 'Q', 'f', 'd'}, ...
                           'matlabClass', {'char', 'char', 'char', 'int8', 'uint8', 'int16', 'uint16', 'int32', 'int32', 'uint32', 'uint32', 'int64', 'uint64', 'float', 'double'}, ...
                           'bytesPerElement', {1, 1, 1, 1, 1, 2, 2, 4, 4, 4, 4, 8, 8, 4, 8});
    end
    
    if length(charOrClass) == 1
        % Look up the data type by its type character.
        dataInd = find(strcmp({dataTypes.typeChar}, charOrClass));
    else
        % Look up the data type by its MATLAB class name.
        dataInd = find(strcmp({dataTypes.matlabClass}, charOrClass));
    end
    if isempty(dataInd)
        error('UFMF:UnknownDataType', 'Unknown data type ''%s''.', charOrClass);
    else
        dataType = dataTypes(dataInd);
    end
end
