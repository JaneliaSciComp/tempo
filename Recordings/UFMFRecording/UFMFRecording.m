classdef UFMFRecording < VideoRecording
    
    properties (Transient)
        ufmfFile
    end
    
    
    methods (Static)
        function canLoad = canLoadFromPath(filePath)
            canLoad = false;
            try
                canLoad = UFMF.isUFMFFile(filePath);
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
                obj.ufmfFile = UFMF.openFile(obj.filePath);
                % DEBUG: obj.ufmfFile.showBoxes = true;
            catch ME
                disp(['Could not load the UFMF file: ' ME.message]);
                rethrow(ME);
            end
            
            obj.sampleRate = obj.ufmfFile.frameRate;
            obj.sampleCount = obj.ufmfFile.frameCount;
        end
        
        
        function d = frameAtTime(obj, time)
            d = obj.ufmfFile.getFrameAtTime(obj.timeOffset + time);
        end
        
        
        function delete(obj)
            if ~isempty(obj.ufmfFile)
                obj.ufmfFile.close();
            end
        end
        
    end
    
end
