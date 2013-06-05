classdef EgnorRecording < AudioRecording
    
    properties
        beginning
    end
    
    
    methods (Static)
        function canLoad = canLoadFromPath(filePath)
            % See if the file's extension is .ch1, .ch2, etc.
            [~, ~, fileExt] = fileparts(filePath);
            canLoad = ~isempty(regexp(fileExt, '^\.ch[0-9]$', 'once'));
        end
    end
    
    methods
        
        function obj = EgnorRecording(controller, varargin)
            obj = obj@AudioRecording(controller, varargin{:});
        end
        
        
        function loadParameters(obj, parser)
            loadParameters@AudioRecording(obj, parser);
            
            if isempty(obj.beginning)
                % See if there is another .ch file loaded whose sample rate we can copy.
                audioInd = [];
                for i = 1:length(obj.controller.recordings)
                    if isa(obj.controller.recordings{i}, 'EgnorRecording') && obj ~= obj.controller.recordings{i}
                        audioInd = i;
                    end
                end
                if isempty(audioInd)
                    % Ask the user for the sample rate.
                    rate = inputdlg('Enter the sample rate:', '', 1, {'450450'});
                    if isempty(rate)
                        error('Tempo:UserCancelled', 'The user cancelled opening the .ch file.');
                    else
                        obj.sampleRate = str2double(rate{1});
                        
                        % Get the time window to load.
                        chLen = obj.duration / 60;
                        obj.beginning=1;
                        if chLen > 2
                            % Also ask the user which chunk of the file to load.
                            begin = inputdlg(['Recording is ' num2str(chLen,3) ' min long.  starting at which minute should i read a 1-min block of data? '],'',1,{'1'});
                            if isempty(begin)
                                error('Tempo:UserCancelled', 'The user cancelled opening the .ch file.');
                            else
                                obj.beginning = str2double(begin{1});
                            end
                        end
                    end
                else
                    % Use the sample rate and time window from a previously opened recording.
                    obj.sampleRate = obj.controller.recordings{audioInd}.sampleRate;
                    obj.beginning = obj.controller.recordings{audioInd}.beginning;
                end
            end
        end
        
        
        function loadData(obj)
            info = dir(obj.filePath);
            obj.sampleCount = info.bytes / 4;
            
            fid = fopen(obj.filePath, 'r');
            try
                fseek(fid, 60 * (obj.beginning - 1) * obj.sampleRate * 4, 'bof');
                obj.data = fread(fid, 1 * 60 * obj.sampleRate, 'single');
            catch ME
                fclose(fid);
                rethrow(ME);
            end
            fclose(fid);
        end
        
    end
    
end
