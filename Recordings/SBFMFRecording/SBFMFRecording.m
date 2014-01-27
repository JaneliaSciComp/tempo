classdef SBFMFRecording < VideoRecording
    
    properties
        highlightForeground = false     % TODO: expose a UI to set this
    end
    
    properties (Transient)
        sbfmfFile
        
        haveImageToolbox
    end
    
    
    methods (Static)
        function canLoad = canLoadFromPath(filePath)
            canLoad = false;
            try
                canLoad = SBFMF.isSBFMFFile(filePath);
            catch ME
                disp(getReport(ME));
            end
        end
    end
    
    methods
        
        function obj = SBFMFRecording(controller, varargin)
            obj = obj@VideoRecording(controller, varargin{:});
            
            obj.haveImageToolbox = license('checkout', 'image_toolbox');
        end
        
        
        function loadData(obj)
            try
                obj.sbfmfFile = SBFMF.openFile(obj.filePath);
            catch ME
                disp(['Could not load the SBFMF file: ' ME.message]);
                rethrow(ME);
            end
            
            obj.sampleRate = obj.sbfmfFile.frameRate;
            obj.sampleCount = obj.sbfmfFile.frameCount;
        end
        
        
        function [frameImage, frameNum] = frameAtTime(obj, time)
            if obj.highlightForeground
                % Highlight the difference between the pixels in the frame and the background.
                
                % Get the frame and the mask from the SBFMF.
                [frameImage, frameNum, frameMask] = obj.sbfmfFile.getFrameAtTime(obj.timeOffset + time);
                
                % Darken the background pixels.
                frameImage(~frameMask) = frameImage(~frameMask) * 0.4;
                
                if obj.haveImageToolbox
                    % Also lighten the perimiter of the foreground pixels.
                    % This lets you see dark foreground pixels on a dark background.
                    perimMask = bwperim(frameMask);
                    frameImage(perimMask) = uint8(power(double(frameImage(perimMask)), 1.1));
                end
            else
                % Just get the frame.
                [frameImage, frameNum] = obj.sbfmfFile.getFrameAtTime(obj.timeOffset + time);
            end
            
            % Convert grayscale to RGB.
            frameImage = repmat(frameImage / 255, [1 1 3]);
        end
        
    end
    
end
