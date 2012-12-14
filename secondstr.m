function s = secondstr(seconds, format, minFields)
    if nargin == 2
        minFields = 0;
    end
    switch format
        case 0
            s = sprintf('%.2f', seconds);
        case 1
            if seconds < 60 && minFields < 2
                % seconds
                s = sprintf('%.2f', seconds);
            elseif seconds < 60 * 60 && minFields < 3
                % minutes:seconds
                s = sprintf('%d:%05.2f', floor(seconds / 60), mod(seconds, 60));
            elseif seconds < 60 * 60 * 24
                % hours:minutes:seconds
                s = sprintf('%d:%02d:%05.2f', floor(seconds / 60 / 60), mod(floor(seconds / 60), 60), mod(floor(seconds), 60));
            else
                s = '';
            end
    end
end
