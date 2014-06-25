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
                if nchan>1
                    [obj.channel, ok] = listdlg('ListString', cellfun(@(x)num2str(x), {info.ObjInfo.Channel.Index}'), ...
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
            obj.sampleRate = info.ObjInfo.SampleRate;
            obj.data = daqread(obj.filePath, 'Channels', obj.channel);
            obj.sampleCount = length(obj.data);
            obj.name = sprintf('%s (channel %d)', obj.name, obj.channel);
        end
        
    end
    
end
