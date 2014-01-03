function otherForm = onOff(originalForm)
    % Convert 'on' and 'off' to true and false and vice-versa.
    
    % TODO: support arrays/cell arrays of values.
    
    otherForm = [];
    
    % Special case 1 and 0 to be the same as true and false.
    if isnumeric(originalForm)
        if originalForm == 1
            originalForm = true;
        elseif originalForm == 0
            originalForm = false;
        end
    end
    
    if islogical(originalForm)
        if originalForm
            otherForm = 'on';
        else
            otherForm = 'off';
        end
    elseif ischar(originalForm)
        if strcmp(originalForm, 'on')
            otherForm = true;
        elseif strcmp(originalForm, 'off')
            otherForm = false;
        end
    end
    
    if isempty(otherForm)
        error('onOff only accepts ''on'', ''off'', true, false, 0 or 1');
    end
end
