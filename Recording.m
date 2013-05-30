classdef Recording < handle
    
    properties
        controller
        
        name
        filePath
        
        data
        sampleRate
        sampleCount
        
        channel
        beginning
        maxAmp
        
        videoReader
        videoSize = [0 0]
        
        isAudio = false
        isVideo = false
        
        timeOffset = 0  % in seconds.  (allows recordings to be offset in time to sync up with other recordings)
    end
    
    properties (Dependent = true)
        duration
    end
    
    
    methods
        
        function obj = Recording(controller, varargin)
            obj = obj@handle();
            
            p = inputParser;
            addRequired(p, 'controller', @(x) isa(x, 'AnalysisController'));
            addOptional(p, 'FilePath', '', @(x) ischar(x) && exist(x, 'file'));
            addParamValue(p, 'Name', '', @(x) ischar(x));
            addParamValue(p, 'SampleRate', [], @(x) isnumeric(x) && isscalar(x));
            addParamValue(p, 'Channel', [], @(x) isnumeric(x) && isscalar(x));
            addParamValue(p, 'TimeOffset', 0, @(x) isnumeric(x) && isscalar(x));
            parse(p, controller, varargin{:});
            
            obj.controller = controller;
            
            obj.filePath = p.Results.FilePath;
            [~, fileName, fileExt] = fileparts(obj.filePath);
            
            if ~isempty(p.Results.Name)
                obj.name = p.Results.Name;
            elseif ~isempty(obj.filePath)
                obj.name = fileName;
            end
            
            obj.sampleRate = p.Results.SampleRate;
            obj.channel = p.Results.Channel;
            obj.timeOffset = p.Results.TimeOffset;
            
            if strcmp(fileExt, '.wav')
                % Open a WAVE file.
                
                obj.isAudio = true;
                [obj.data, obj.sampleRate] = audioread(obj.filePath, 'native');
                obj.data = double(obj.data);    % TODO: why not just use 'double' above instead?
                obj.sampleCount = length(obj.data);
            elseif strcmp(fileExt, '.avi') ||  strcmp(fileExt, '.mov')
                % Open a video file.
                
                obj.isVideo = true;
                obj.videoReader = VideoReader(obj.filePath);
                obj.data = [];
                obj.sampleRate = get(obj.videoReader, 'FrameRate');
                obj.sampleCount = get(obj.videoReader, 'NumberOfFrames');
                obj.videoSize = [get(obj.videoReader, 'Height') get(obj.videoReader, 'Width')];
            elseif strcmp(fileExt, '.daq')
                % Open a channel from a DAQ file.
                % TODO: allow opening more than one channel?
                
                info = daqread(obj.filePath, 'info');
                
                if ~isempty(obj.channel)
                    ok = true;
                else
                    % Ask the user which channel to open.
                    [obj.channel, ok] = listdlg('ListString', cellfun(@(x)num2str(x), {info.ObjInfo.Channel.Index}'), ...
                                                'PromptString', {'Choose the channel to open:', '(1-8: optical, 9: acoustic)'}, ...
                                                'SelectionMode', 'single', ...
                                                'Name', 'Open DAQ File');
                end
                if ok
                    obj.isAudio = true;
                    obj.sampleRate = info.ObjInfo.SampleRate;
                    obj.data = daqread(obj.filePath, 'Channels', obj.channel);
                    obj.sampleCount = length(obj.data);
                    obj.name = sprintf('%s (channel %d)', obj.name, obj.channel);
                else
                    obj = Recording.empty();
                end
            elseif strcmp(fileExt, '.bin')
                % Open one of the Stern lab's .bin files.
                
                fid = fopen(obj.filePath, 'r');
                try
                    version = fread(fid, 1, 'double');
                    if version ~= 1
                        error('not a valid .bin file');
                    end
                    obj.sampleRate = fread(fid, 1, 'double');
                    nchan = fread(fid, 1, 'double');
                    if ~isempty(obj.channel)
                        ok = true;
                    else
                        [obj.channel, ok] = listdlg('ListString', cellstr(num2str((1:nchan)')), ...
                                                    'PromptString', {'Choose the channel to open:'}, ...
                                                    'SelectionMode', 'single', ...
                                                    'Name', 'Open BIN File');
                    end
                    if ok
                        fread(fid, obj.channel, 'double');  % skip over first timestamp and first channels
                        obj.data = fread(fid, inf, 'double', 8*(nchan-1));
                        obj.name = sprintf('%s (channel %d)', obj.name, obj.channel);
                        obj.isAudio = true;
                    else
                        obj = Recording.empty();
                    end
                    fclose(fid);
                catch ME
                    % Make sure the file gets closed.
                    fclose(fid);
                    rethrow(ME);
                end
            elseif strncmp(fileExt, '.ch', 3)
                % Open one of the Egnor lab's .ch files
                
                info = dir(obj.filePath);
                obj.sampleCount = info.bytes / 4;
                
                audioInd = find([obj.controller.recordings.isAudio], 1, 'first');    % TODO: make sure it's a .ch?
                if isempty(audioInd)
                    % Ask the user for the sample rate.
                    rate = inputdlg('Enter the sample rate:', '', 1, {'450450'});
                    if isempty(rate)
                        obj = Recording.empty();    % The user cancelled.
                    else
                        obj.sampleRate = str2double(rate{1});
                        
                        % Get the time window to load.
                        chLen = obj.duration / 60;
                        obj.beginning=1;
                        if chLen > 2
                            % Also ask the user which chunk of the file to load.
                            begin = inputdlg(['Recording is ' num2str(chLen,3) ' min long.  starting at which minute should i read a 1-min block of data? '],'',1,{'1'});
                            if isempty(begin)
                                obj = Recording.empty();    % The user cancelled.
                            else
                                obj.beginning = str2double(begin{1});
                            end
                        end
                    end
                else
                    % Use the sample rate and time window from a previously opened recording.
                    obj.sampleRate = obj.controller.recordings(audioInd).sampleRate;
                    obj.beginning = obj.controller.recordings(audioInd).beginning;
                end
                
                if ~isempty(obj)
                    fid = fopen(obj.filePath, 'r');
                    try
                        %set(handles.figure1,'pointer','watch');
                        fseek(fid, 60 * (obj.beginning - 1) * obj.sampleRate * 4, 'bof');
                        obj.data = fread(fid, 1 * 60 * obj.sampleRate, 'single');
                    catch ME
                        fclose(fid);
                        %set(handles.figure1,'pointer','arrow');
                        rethrow(ME);
                    end
                    fclose(fid);
                    obj.isAudio = true;
                    %set(handles.figure1,'pointer','arrow');
                end
            end
        end
        
        
        function d = get.duration(obj)
            d = obj.sampleCount / obj.sampleRate;
        end
        
        
        function d = dataInTimeRange(obj, timeRange)
            if obj.isAudio
                sampleRange = floor((timeRange + obj.timeOffset) * obj.sampleRate);
                if sampleRange(1) < 1
                    sampleRange(1) = 1;
                end
                if sampleRange(2) > length(obj.data)
                    sampleRange(2) = length(obj.data);
                end
                d = obj.data(sampleRange(1):sampleRange(2));
            else
                d = [];
            end
        end
        
        
        function d = frameAtTime(obj, time)
            frameNum = min([floor((time + obj.timeOffset) * obj.sampleRate + 1) obj.sampleCount]);
            d = read(obj.videoReader, frameNum);
            
            if ndims(d) == 2 %#ok<ISMAT>
                % Convert monochrome to grayscale.
                d=repmat(d,[1 1 3]);
            end
        end
        
        
        function m = maxAmplitude(obj)
            if obj.isAudio
                if isempty(obj.maxAmp)
                    obj.maxAmp = max(obj.data);
                end
                m = obj.maxAmp;
            else
                m = 0;
            end
        end
        
    end
    
end
