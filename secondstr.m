function s = secondstr(seconds, format)
    switch format
        case 0
            s = sprintf('%.2f', seconds);
        case 1
            if seconds < 60 * 60
                s = sprintf('%d:%05.2f', floor(seconds / 60), mod(seconds, 60));
            elseif seconds < 60 * 60 * 24
                s = sprintf('%d:%02d:%05.2f', floor(seconds / 60 / 60), mod(floor(seconds / 60), 60), mod(floor(seconds), 60));
            else
                s = '';
            end
    end
end
