classdef UFMFRecording < VideoRecording
    
    properties
        highlightForeground = false     % TODO: expose a UI to set this
    end
    
    properties (Transient)
        ufmfFile
        
        haveImageToolbox
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
            
            obj.haveImageToolbox = license('checkout', 'image_toolbox');
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
        
        
        function [frameImage, frameNum] = frameAtTime(obj, time)
            if obj.highlightForeground
                % Highlight the difference between the pixels in the frame and the background.
                
                % Get the frame and the mask from the UFMF.
                [frameImage, frameNum, frameMask] = obj.ufmfFile.getFrameAtTime(obj.timeOffset + time);
                
                % Darken the background pixels.
                fullMask = repmat(frameMask, [1 1 3]);
                frameImage(~fullMask) = frameImage(~fullMask) * 0.4;
                
                if obj.haveImageToolbox
                    % Also lighten the perimiter of the foreground pixels.
                    % This lets you see dark foreground pixels on a dark background.
                    perimMask = bwperim(frameMask);
                    fullPerimMask = repmat(perimMask, [1 1 3]);
                    frameImage(fullPerimMask) = uint8(power(double(frameImage(fullPerimMask)), 1.1));
                end
            else
                % Just get the frame.
                [frameImage, frameNum] = obj.ufmfFile.getFrameAtTime(obj.timeOffset + time);
            end
        end
        
        
        function delete(obj)
            if ~isempty(obj.ufmfFile)
                obj.ufmfFile.close();
            end
        end
        
    end
    
end
