classdef DAQRecording < AudioRecording
    
    methods (Static)
        function canLoad = canLoadFromPath(filePath)
            canLoad = false;
            try
                daqread(filePath, 'info');
                canLoad = true;
            catch
            end
        end
    end
    
    methods
        
        function obj = DAQRecording(controller, varargin)
            obj = obj@AudioRecording(controller, varargin{:});
        end
        
        
        function loadParameters(obj, parser)
            loadParameters@Recording(obj, parser);
            obj.channel = parser.Results.Channel;
            
            if isempty(obj.channel)
                % Ask the user which channel to open.
                % TODO: allow opening more than one channel?
                info = daqread(obj.filePath, 'info');
                obj.channel=1;
                if length(info.ObjInfo.Channel)>1
                    [obj.channel, ok] = listdlg('ListString', cellfun(@(x)num2str(x), {info.ObjInfo.Channel.Index}','uniformoutput',false), ...
                                                'PromptString', 'Choose the channel to open:', ...
                                                'SelectionMode', 'single', ...
                                                'Name', 'Open DAQ File');
                    if ~ok
                        error('Tempo:UserCancelled', 'The user cancelled opening the DAQ file.');
                    end
                end
            end
        end
        
        
        function loadData(obj)
            info = daqread(obj.filePath, 'info');
            obj.sampleCount = info.ObjInfo.SamplesAcquired;
            obj.sampleRate = info.ObjInfo.SampleRate;
            obj.name = sprintf('%s (channel %d)', obj.name, obj.channel);
            
            obj.loadDataBuffer(1);
        end
        
        function newData = readData(obj, readStart, readLength)
            newData = daqread(obj.filePath, 'Channels', obj.channel, 'Samples', [readStart readStart+readLength]);
        end
    end
    
end
