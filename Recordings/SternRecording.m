classdef SternRecording < AudioRecording
    
    methods (Static)
        function canLoad = canLoadFromPath(filePath)
            % See if the file's extension is .bin.
            [~, ~, fileExt] = fileparts(filePath);
            canLoad = strcmp(fileExt, '.bin');
            if (canLoad)
                fid = fopen(filePath, 'r');
                try
                    version = fread(fid, 1, 'double');
                    canLoad = ((version >= 1) && (version <= 3));
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
        
        
        function loadParameters(obj, parser)
            loadParameters@Recording(obj, parser);
            obj.channel = parser.Results.Channel;
            
            if isempty(obj.channel)
                fid = fopen(obj.filePath, 'r');
                fread(fid, 2, 'double');    % skip over the version # and sample rate
                nchan = fread(fid, 1, 'double');
                obj.channel=1;
                if nchan>1
                    [obj.channel, ok] = listdlg('ListString', cellstr(num2str((1:nchan)')), ...
                                                'PromptString', {'Choose the channel to open:'}, ...
                                                'SelectionMode', 'single', ...
                                                'Name', 'Open BIN File');
                    if ~ok
                        error('Tempo:UserCancelled', 'The user cancelled opening the BIN file.');
                    end
                    fclose(fid);
                end
            end
        end
        
        function loadData(obj)
            fid = fopen(obj.filePath, 'r');
            try
                version=fread(fid, 1, 'double');
                sampleRate = fread(fid, 1, 'double');
                nchan = fread(fid, 1, 'double');
                switch version
                    case 1
                        first=ftell(fid);
                        fseek(fid,0,'eof');
                        last=ftell(fid);
                        obj.sampleCount=(last-first+1)/8/nchan;
                    case 2
                        first=ftell(fid);
                        fseek(fid,0,'eof');
                        last=ftell(fid);
                        obj.sampleCount=(last-first+1)/4/nchan;
                    case 3
                        tmp=fread(fid,[2 nchan],'double');
                        step=tmp(1,nchan);
                        offset=tmp(2,nchan);
                        fread(fid, obj.channel-1, 'int16');  % skip over first channels
                        first=ftell(fid);
                        fseek(fid,0,'eof');
                        last=ftell(fid);
                        obj.sampleCount=(last-first+1)/2/nchan;
                end
                fclose(fid);
            catch ME
                fclose(fid);
                rethrow(ME);
            end

            obj.loadDataBuffer(1);
        end
        
        function newData = readData(obj, readStart, readLength)
            fid = fopen(obj.filePath, 'r');
            try
                version=fread(fid, 1, 'double');
                obj.sampleRate = fread(fid, 1, 'double');
                nchan = fread(fid, 1, 'double');
                switch version
                    case 1
                        fread(fid, obj.channel-1, 'double');  % skip over first channels
                        fseek(fid, 8*readStart*nchan, 'cof');
                        newData = fread(fid, readLength, 'double', 8*(nchan-1));
                    case 2
                        fread(fid, obj.channel-1, 'single');  % skip over first channels
                        fseek(fid, 4*readStart*nchan, 'cof');
                        newData = fread(fid, readLength, 'single', 4*(nchan-1));
                    case 3
                        tmp=fread(fid,[2 nchan],'double');
                        step=tmp(1,nchan);
                        offset=tmp(2,nchan);
                        fread(fid, obj.channel-1, 'int16');  % skip over first channels
                        fseek(fid, 2*readStart*nchan, 'cof');
                        newData =fread(fid,readLength,'int16', 2*(nchan-1));
                        newData = newData*step+offset;
                end
                obj.name = sprintf('%s (channel %d)', obj.name, obj.channel);
                fclose(fid);
            catch ME
                fclose(fid);
                rethrow(ME);
            end
        end
        
        
        function f = format(obj) %#ok<MANU>
            f = 'Stern lab (Omnivore) ''.bin'' audio';
        end
        
    end
    
end
