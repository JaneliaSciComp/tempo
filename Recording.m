classdef Recording < handle
    
    properties
        name
        filePath
        data
        sampleRate
        beginning
        duration
        maxAmp
        
        videoReader
        videoSize = [0 0]
        
        isAudio = false
        isVideo = false
        
        timeOffset = 0  % in seconds.  (allows recordings to be offset in time to sync up with other recordings)
    end
    
    
    properties (Access = private)
        reporterList = {};
    end
    
    
    methods
        
        function obj = Recording(filePath, objrecs, varargin)
            obj = obj@handle();
            
            obj.filePath = filePath;
            [~, obj.name, ext] = fileparts(filePath);
            
            if strcmp(ext, '.wav')
                obj.isAudio = true;
                [obj.data, obj.sampleRate] = wavread(filePath, 'native');
                obj.data = double(obj.data);
                obj.duration = length(obj.data) / obj.sampleRate;
            elseif strcmp(ext, '.avi') ||  strcmp(ext, '.mov')
                obj.isVideo = true;
                obj.videoReader = VideoReader(filePath);
                obj.data = [];
                obj.sampleRate = get(obj.videoReader, 'FrameRate');
                obj.duration = get(obj.videoReader, 'Duration');
                obj.videoSize = [get(obj.videoReader, 'Height') get(obj.videoReader, 'Width')];
            elseif strcmp(ext, '.daq')
                info = daqread(filePath, 'info');
                
                if nargin > 1 && ~isempty(varargin{1})
                    channel = varargin{1};
                    ok = true;
                else
                    % Ask the user which channel to open.
                    [channel, ok] = listdlg('ListString', cellfun(@(x)num2str(x), {info.ObjInfo.Channel.Index}'), ...
                                            'PromptString', {'Choose the channel to open:', '(1-8: optical, 9: acoustic)'}, ...
                                            'SelectionMode', 'single', ...
                                            'Name', 'Open DAQ File');
                end
                if ok
                    obj.isAudio = true;
                    obj.sampleRate = info.ObjInfo.SampleRate;
                    obj.data = daqread(filePath, 'Channels', channel);
                    obj.duration = length(obj.data) / obj.sampleRate;
                    obj.name = sprintf('%s (channel %d)', obj.name, channel);
                else
                    obj = Recording.empty();
                end
            elseif strcmp(ext, '.bin')  % stern's .bin files
                fid=fopen(filePath,'r');
                version=fread(fid,1,'double');
                if(version~=1)  error('not a valid .bin file');  end
                obj.sampleRate=fread(fid,1,'double');
                nchan=fread(fid,1,'double');
                [channel, ok] = listdlg('ListString', cellstr(num2str([1:nchan]')), ...
                                        'PromptString', {'Choose the channel to open:'}, ...
                                        'SelectionMode', 'single', ...
                                        'Name', 'Open BIN File');
                if ok
                    fread(fid,channel,'double');  % skip over first timestamp and first channels
                    obj.data=fread(fid,inf,'double',8*(nchan-1));
                    obj.duration = length(obj.data) / obj.sampleRate;
                    obj.name = sprintf('%s (channel %d)', obj.name, channel);
                    obj.isAudio = true;
                    fclose(fid);
                else
                    obj = Recording.empty();
                end
            elseif strncmp(ext, '.ch', 2)  % egnor's .ch? files
                idx=find([objrecs.isAudio],1,'first');
                fid=fopen(filePath,'r');
                if(isempty(idx))
                  inputdlg('sample rate: ','',1,{'450450'});
                  obj.sampleRate=str2num(char(ans));
                  fseek(fid,0,'eof');
                  len=ftell(fid)/4/obj.sampleRate/60;
                  fseek(fid,0,'bof');
                  obj.beginning=1;
                  if(len>2)
                    inputdlg(['recording is ' num2str(len,3) ' min long.  starting at which minute should i read a 1-min block of data? '],'',1,{'1'});
                    obj.beginning=str2num(char(ans));
                  end
                else
                  obj.sampleRate=objrecs(idx).sampleRate;
                  obj.beginning=objrecs(idx).beginning;
                end
                %set(handles.figure1,'pointer','watch');
                fseek(fid,60*(obj.beginning-1)*obj.sampleRate*4,'bof');
                obj.data=fread(fid,1*60*obj.sampleRate,'single');
                fclose(fid);
                obj.duration = length(obj.data) / obj.sampleRate;
                obj.isAudio = true;
                %set(handles.figure1,'pointer','arrow');
            end
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
            frameNum = min([floor((time + obj.timeOffset) * obj.sampleRate + 1) obj.videoReader.NumberOfFrames]);
            d = read(obj.videoReader, frameNum);
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
        

        function addReporter(obj, reporter)
            obj.reporterList{end + 1} = reporter;
        end
        
        
        function removeReporter(obj, reporter)
            index = find(obj.reporterList == reporter);
            obj.reporterList{index} = []; %#ok<FNDSB>
        end
        
        
        function d = reporters(obj)
            % This function allows one detector to use the results of another, e.g. detecting pulse trains from a list of pulses.
            
            d = obj.reporterList;
        end
        
    end
    
end
