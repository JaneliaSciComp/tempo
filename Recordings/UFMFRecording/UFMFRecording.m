classdef UFMFRecording < VideoRecording
    
    properties (Transient)
        fileHeader
    end
    
    
    methods (Static)
        function canLoad = canLoadFromPath(filePath)
            canLoad = false;
            try
                [~, ~, ext] = fileparts(filePath);
                % TODO: read header?
                canLoad = strcmp(ext, '.ufmf');
            catch ME
                disp(getReport(ME));
            end
        end
    end
    
    methods
        
        function obj = UFMFRecording(controller, varargin)
            obj = obj@VideoRecording(controller, varargin{:});
        end
        
        
        function loadData(obj)
            try
                obj.fileHeader = ufmf_read_header(obj.filePath);
                
                % We shouldn't need this but if you want to jump to the first frame with actual motion this (slow) code helps:
                %    boxCount = ufmf_read_nboxes(obj.fileHeader, 1:obj.fileHeader.nframes);
                %    [~, firstFrame] = max(boxCount);
                % It could be made much faster since we would only need the first non-zero frame.
            catch ME
                disp(['Could not load data from UFMF file: ' ME.message]);
                rethrow ME
            end
            
            obj.sampleRate = 30;
            obj.sampleCount = obj.fileHeader.nframes;
        end
        
        
        function d = frameAtTime(obj, time)
            frameNum = min([floor((time + obj.timeOffset) * obj.sampleRate + 1) obj.sampleCount]);
            
            d = ufmf_read_frame(obj.fileHeader, frameNum);
        end
        
        
        function delete(obj)
            if isfield(obj.fileHeader, 'fid')
                fclose(obj.fileHeader.fid);
            end
        end
        
    end
    
end
