classdef SternRecording < AudioRecording
    
    properties
      channel
    end
    
    methods (Static)
        function canLoad = canLoadFromPath(filePath)
            % See if the file's extension is .bin.
            [~, ~, fileExt] = fileparts(filePath);
            canLoad = strcmp(fileExt, '.bin');
            if (canLoad)
                fid = fopen(filePath, 'r');
                try
                    version = fread(fid, 1, 'double');
                    canLoad = (version == 1);
                    fclose(fid);
                catch ME
                    % Make sure the file gets closed.
                    fclose(fid);
                    rethrow(ME);
                end
            end
        end
    end
    
    methods
        
        function obj = SternRecording(controller, varargin)
            obj = obj@AudioRecording(controller, varargin{:});
        end
        
        
        function addParameters(obj, parser)
            addParameters@AudioRecording(obj, parser);
            
            addParamValue(parser, 'Channel', [], @(x) isnumeric(x) && isscalar(x));
        end
        
        
        function loadParameters(obj, parser)
            loadParameters@AudioRecording(obj, parser);
            
            obj.channel = parser.Results.Channel;
            
            if isempty(obj.channel)
                fid = fopen(obj.filePath, 'r');
                try
                    fread(fid, 2, 'double');    % skip over the version # and sample rate
                    nchan = fread(fid, 1, 'double');
                    [obj.channel, ok] = listdlg('ListString', cellstr(num2str((1:nchan)')), ...
                                                'PromptString', {'Choose the channel to open:'}, ...
                                                'SelectionMode', 'single', ...
                                                'Name', 'Open BIN File');
                    if ~ok
                        error('Tempo:UserCancelled', 'The user cancelled opening the BIN file.');
                    end
                    fclose(fid);
                catch ME
                    % Make sure the file gets closed.
                    fclose(fid);
                    rethrow(ME);
                end
            end
        end
        
        
        function loadData(obj)
            fid = fopen(obj.filePath, 'r');
            try
                fread(fid, 1, 'double');    % skip over version #
                obj.sampleRate = fread(fid, 1, 'double');
                nchan = fread(fid, 1, 'double');
                fread(fid, obj.channel-1, 'double');  % skip over first channels
                [obj.data, obj.sampleCount] = fread(fid, inf, 'double', 8*(nchan-1));
                obj.name = sprintf('%s (channel %d)', obj.name, obj.channel);
                fclose(fid);
            catch ME
                % Make sure the file gets closed.
                fclose(fid);
                rethrow(ME);
            end
        end
        
        
        function f = format(obj) %#ok<MANU>
            f = 'Stern lab (Omnivore) ''.bin'' audio';
        end
        
    end
    
end
