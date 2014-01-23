classdef SBFMFFile < handle
    
    properties (SetAccess=private)
        version
    end
    
    properties
        path                    % The path to the SBFMF file.
        
        differenceMode
        
        frameRate = []          % The frame rate for fixed rate movies.
        frameCount = 0          % The number of frames in the movie.
        frameSize = []          % The pixel size of each frame.
    end
    
    properties (Dependent)
        duration
    end
    
    properties (Access=private)
        fileID
        
        backgroundImage
        frameOffsets
        
        lastFrameNumRead = 0
    end
    
    
    methods
        
        function obj = SBFMFFile(filePath, mode, varargin)
            % Use a SBFMFFile instance to read from a SBFMF file.
            % 
            % >> sbfmfFile = SBFMF.openFile('my.sbfmf');
            % >> frameImage = sbfmfFile.getFrame();              % Get the first frame of the movie.
            % >> frameImage = sbfmfFile.getFrame();              % Get the second frame of the movie.
            % >> frameImage = sbfmfFile.getFrame(100);           % Get the 100th frame of the movie.
            % >> frameImage = sbfmfFile.getFrameAtTime(12.4);    % Get the frame at 12.4 seconds into the movie.
            
            if nargin < 1
                % This can happen when an empty matrix of SBFMFFile's gets auto-populated by MATLAB.
                % Just create a dummy object with the expectation that it will get replaced by a real instance.
                mode = 'empty';
            else
                obj.path = filePath;
                
                if nargin < 2
                    % Auto-detect the mode: if a file exists at the path then read it.
                    if exist(filePath, 'file')
                        mode = 'read';
                    end
                end
            end
            
            if strcmp(mode, 'read')
                % Open the SBFMF file for reading, binary, little-endian
                obj.fileID = fopen(filePath, 'rb' , 'ieee-le');
                if obj.fileID < 0
                    error('SBFMF:IOError', 'Could not open SBFMF file for reading.');
                end
                obj.readHeader();
            elseif strcmp(mode, 'empty')
                % Nothing to do.
            else
                error('SBFMF:ValueError', 'Invalid mode given for opening a SBFMF file: %s', mode);
            end
        end
        
        
        function d = get.duration(obj)
            if isempty(obj.frameRate)
                % Use the time stamps of the first and last frame.
                [~, startTime] = obj.readFrame(1);
                [~, endTime] = obj.readFrame(obj.frameCount);
                d = endTime - startTime;
            else
                % Use the frame count and rate.
                d = obj.frameCount / obj.frameRate;
            end
        end
        
        
        function [im, frameNum, frameMask] = getFrame(obj, frameNum)
            % Read in a frame from the SBFMF file by specifying a frame number or just getting the next one.
            % If the last frame has been read or there is no frame at the given number then an empty matrix will be returned.
            %
            % >> sbfmfFile = SBFMF.openFile('my.sbfmf');
            % >> im = sbfmfFile.getFrame();              % Get the next frame.
            % >> im = sbfmfFile.getFrame(132);           % Get a specific frame.
            % >> [im, frameNum] = sbfmfFile.getFrame();  % Get the next frame and which number it is.
            % >> [im, ~, mask] = sbfmfFile.getFrame();   % Also return a logical mask of where the image differs from the background.
            
            % TODO: Cache recent frames to speed up video scrubbing.
            
            if isempty(obj.path)
                error('SBFMF:NoSBFMFFile', 'This SBFMFFile instance has no SBFMF file to read from.');
            end
            
            if nargin < 2
                % Allow sequential grabbing without caring about the frame number.
                frameNum = obj.lastFrameNumRead + 1;
            end
            
            if nargout == 2
                % TODO: why ignore the frame num returned by readFrame?
                im = obj.readFrame(uint64(frameNum));
            else
                [im, ~, frameMask] = obj.readFrame(uint64(frameNum));
            end
            
            obj.lastFrameNumRead = frameNum;
        end
        
        
        function [im, frameNum, frameMask] = getFrameAtTime(obj, frameTime)
            % Read in a frame from the SBFMF file at a specific time.
            %
            % >> sbfmfFile = SBFMF.openFile('my.sbfmf');
            % >> im = sbfmfFile.getFrameAtTime(33.3);                % Get the frame at 33.3 seconds into the movie.
            % >> [im, frameNum] = sbfmfFile.getFrameAtTime(33.3);	% Also return the frame number.
            % >> [im, ~, mask] = sbfmfFile.getFrameAtTime(62.9);     % Also return a logical mask of where the image differs from the background.
            
            % TODO: this assumes a constant frame rate, would be better to lookup the index from the time stamps but it will be slow...
            
            if isempty(obj.path)
                error('SBFMF:NoSBFMFFile', 'This SBFMFFile instance has no SBFMF file to read from.');
            end
            
            if frameTime == 0.0
                frameNum = 1;
            else
                frameNum = ceil(obj.frameRate * frameTime);
            end
            if nargout > 2
                frameMask = [];
            end
            
            if frameNum > 0 && frameNum <= obj.frameCount
                if nargout > 2
                    [im, ~, frameMask] = obj.getFrame(frameNum);
                else
                    im = obj.getFrame(frameNum);
                end
            else
                im = [];
            end
        end
        
        
        function delete(obj)
            if ~isempty(obj.fileID)
                fclose(obj.fileID);
            end
        end
        
    end
    
    
    %% SBFMF Reading
    
    
    methods (Access = private)
        
        function readHeader(obj)
            % version: 4 byte length + version
            verBytes = fread(obj.fileID, 1, 'uint32');
            obj.version = fread(obj.fileID, verBytes, '*char')';
            if ~strcmp(obj.version, '0.3b')
                % TODO: any other versions lurking out there?
                error('SBFMF:UnknownVersion', 'Only SBFMF version 0.3b is supported.');
            end
            
            % # rows, # cols, # frames: 4 bytes each 
            obj.frameSize = flip([fread(obj.fileID, 1, 'uint32'), fread(obj.fileID, 1, 'uint32')]);
            obj.frameCount = fread(obj.fileID, 1, 'uint32');
            
            % Read in the difference mode: 4 bytes
            obj.differenceMode = double(fread(obj.fileID, 1, 'uint32'));
            
            % Read in the location of the frame index: 8 bytes
            indexloc = double(fread(obj.fileID, 1, 'uint64'));
            
            % Read in the background image: 4 * # rows * # cols bytes
            obj.backgroundImage = fread(obj.fileID, obj.frameSize(1) * obj.frameSize(2), 'double');
            obj.backgroundImage = reshape(obj.backgroundImage, [obj.frameSize(1), obj.frameSize(2)]);
            
            % Read in the list of offsets for each frame.
            fseek(obj.fileID, indexloc, 'bof');
            obj.frameOffsets = fread(obj.fileID, obj.frameCount, 'uint64');
            
            if isempty(obj.frameRate)
                % Assume a constant frame rate based on the frame count and first and last time stamps.
                obj.frameRate = (obj.frameCount - 1) / obj.duration;
            end
        end
        
        
        function [frameImage, timeStamp, frameMask] = readFrame(obj, frameNum)
            makeMask = nargout > 2;
            
            % Move to the start of the frame in the file.
            fseek(obj.fileID, obj.frameOffsets(frameNum), 'bof');
            
            % Count of pixels: 4 bytes
            pixelCount = fread(obj.fileID, 1, 'uint32');
            
            % Time stamp of frame: 4 bytes
            timeStamp = fread(obj.fileID, 1, 'double');
            
            % The indices of pixels that differ from the background: 4 * pixelCount bytes
            pixelInds = fread(obj.fileID, pixelCount, 'uint32') + 1;
            
            % The grayscale value of the pixels that differ from the background: pixelCount bytes
            pixels = fread(obj.fileID, pixelCount, 'uint8');
            
            % Draw the foreground pixels over the background image.
            frameImage = obj.backgroundImage;
            frameImage(pixelInds) = pixels;
            frameImage = frameImage';
            
            if makeMask
                % Create a logical mask indicating which pixels are in the foreground.
                frameMask = false(size(obj.backgroundImage));
                frameMask(pixelInds) = true(1, length(pixelInds));
                frameMask = frameMask';
            end
        end
    end
end
    
    
