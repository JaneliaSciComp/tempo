function otherFormat = convertTime(secondsOrString, minFields)
    % Convert between a number of seconds and the string representation.
    
    % TODO: unit tests
    
    if ischar(secondsOrString)
        % The string should be in the format xx:xx:xx.xx xx:xx.xx or xx.xx.
        pieces = regexp(secondsOrString, ':', 'split');
        
        % Start with any seconds.
        otherFormat = str2double(pieces(end));
        pieces(end) = [];
        
        if ~isempty(pieces)
            % Look for minutes
            otherFormat = otherFormat + 60 * str2double(pieces(end));
            pieces(end) = [];
        end
        
        if ~isempty(pieces)
            % Look for hours
            otherFormat = otherFormat + 60 * 60 * str2double(pieces(end));
            pieces(end) = [];
        end
        
        if ~isempty(pieces)
            error('Tempo:InvalidTimeString', 'An invalid time string was passed to convertTime');
        end
    elseif isnumeric(secondsOrString) && isscalar(secondsOrString)
        if nargin == 1
            minFields = 0;
        end
        if secondsOrString < 60 && minFields < 2
            % seconds
            otherFormat = sprintf('%.2f', secondsOrString);
        elseif secondsOrString < 60 * 60 && minFields < 3
            % minutes:seconds
            otherFormat = sprintf('%d:%05.2f', floor(secondsOrString / 60), mod(secondsOrString, 60));
        elseif secondsOrString < 60 * 60 * 24
            % hours:minutes:seconds
            otherFormat = sprintf('%d:%02d:%05.2f', floor(secondsOrString / 60 / 60), mod(floor(secondsOrString / 60), 60), mod(secondsOrString, 60));
        else
            error('Tempo:InvalidTime', 'An invalid time was passed to convertTime');
        end
    end
end
