classdef UFMF < handle
    
    % TODO: make sure none of the reading code touches the image toolbox
    
    properties (SetAccess=private)
        version = 4
    end
    
    properties
        numMeans = 1
    	bgUpdateSecs = 10
    	bgInitialMeans = 0
    	bgThreshold = 10
        
        useBoxes = true
        smallestCompPix = 1
        
        frameRate
        
        printStats = false
    end
    
    properties (Access=private)
        header
        bgModel
        
        frameCount = 0
        
        frameIndex
        
        fileID
        isReadOnly
        isWritable
    end
    
    
    methods (Static)
        
        function obj = openFile(filePath)
            obj = UFMF(filePath, 'read');
        end
        
        function obj = createFile(filePath)
            obj = UFMF(filePath, 'write');
        end
        
    end
    
    
    methods
        
        function obj = UFMF(filePath)
            % If a file at the path exists then open it, otherwise write to it.
            
            if exist(filePath, 'file')  % TODO: or ???
                % Open the UFMF file for reading.
                obj.fileID = fopen(filePath, 'r');
                if obj.fileID < 0
                    error('UFMF:IOError', 'Could not open UFMF file for reading.');
                end
                obj.isReadOnly = true;
                obj.isWritable = false;
            else
                % Open the UFMF file for writing.
                obj.fileID = fopen(filePath, 'w');
                if obj.fileID < 0
                    error('UFMF:IOError', 'Could not open UFMF file for writing.');
                end
                obj.isReadOnly = false;
                obj.isWritable = true;
            end
        end
        
        
        function im = getFrame(obj, frameInd)
            im = [];
            
            % TODO: read in a frame
            if isinteger(frameInd)
                % Get the frame at the index.
            else
                % Get the frame at the time.
            end
        end
        
        
        function addFrame(obj, frameImage, frameIndex, frameTime)
            if obj.isReadOnly
                error('UFMF:ReadOnly', 'This UFMF file is only available for reading.');
            end
            if ~obj.isWritable
                error('UFMF:FileIsClosed', 'This UFMF file has been closed.');
            end
            
            if nargin < 3
                % Determine the frame index and time automatically from frame rate, etc.
                frameIndex = obj.frameCount + 1;
                frameTime = frameIndex / obj.frameRate;
            end
            
            if obj.frameCount == 0
                % Perform initial set up when the first frame comes in.
                obj.setupBGModel();
                obj.writeHeader(frameImage);
            end
            
            % Update the background model if necessary, may generate a key frame.
            obj.updateBGModel(frameImage, frameIndex, frameTime);
            
            % Write the frame itself.
            obj.writeFrame(frameImage, frameTime);
            
            obj.frameCount = obj.frameCount + 1;
        end
        
        
        function close(obj)
            if ~obj.isReadOnly && obj.isWritable
                obj.writeIndex();
                
                fclose(obj.fileID);
                obj.fileID = [];
                obj.isWritable = false;
            end
            
            % TODO: convert it to read-style so you can immediately call getFrame?
        end
        
        
        function delete(obj)
            if ~isempty(obj.fileID)
                fclose(obj.fileID);
            end
        end
        
    end
    
    
    %% UFMF Reading
    
    methods (Access = private)
        
        function [frameImage, timeStamp] = readFrame(obj, frameIndex)
            frameImage = [];
            timeStamp = -inf;
        end
        
    end
    
    
    %% UFMF Writing
    
    methods (Access = private)
        
        function setupBGModel(obj)
            % Set up the initial background model.
            obj.frameIndex.loc = [];
            obj.frameIndex.locLoc = [];
            obj.bgModel.lastkeyframetime = -inf;
            tmp = struct('loc', cast([], 'int64'),'timestamp',[]);
            obj.frameIndex.frame = tmp;
            obj.frameIndex.keyframe.mean = tmp;
            obj.bgModel.nframes = 0;
            obj.bgModel.meanImage = [];
            obj.bgModel.lastupdatetime = -inf;
        end
        
        
        function updateBGModel(obj, frameImage, frameIndex, timeStamp)
            % check if an update is needed
            if  frameIndex < obj.bgInitialMeans || timeStamp - obj.bgModel.lastupdatetime >= obj.bgUpdateSecs
                % set time of this update
                obj.bgModel.lastupdatetime = timeStamp;

                % update nframes
                n = min(obj.bgModel.nframes + 1, obj.numMeans);
                obj.bgModel.nframes = n;
                
                % update the mean image
                % TODO: investigate whether we should be storing the mean image as a double cuz
                % matlab's image arithmetic functions suck. 
                if isempty(obj.bgModel.meanImage)
                    %[rows, columns, colors] = size(frameImage);
                    obj.bgModel.meanImage = uint8(frameImage); %zeros([rows, columns, colors], 'uint8');
                else
                    obj.bgModel.meanImage = imlincomb((n-1)/n, obj.bgModel.meanImage, ...
                                                          1/n, frameImage);
                end
                obj.writeKeyFrame(timeStamp);
                
                if obj.printStats && frameIndex >= obj.bgInitialMeans
                    fprintf('BG update %d at %s\n', obj.bgModel.nframes, num2str(timeStamp));
                end
            end
        end
        
        
        function [boundingBoxes, diffImage] = subtractBackground(obj, frameImage)
            % Perform background substraction.
            diffImage = imabsdiff(frameImage, obj.bgModel.meanImage);
            
            % Convert to grayscale if needed.
            ncolors = size(diffImage, 3);
            if ncolors > 1
              diffImage = sum(diffImage, 3) / ncolors;
            end
            
            % Find pixels that vary more than the threshold.
            diffImage = diffImage >= obj.bgThreshold;       
            
            if obj.useBoxes
                % Try to reduce the number of connected components.
                %diffim = imdilate(diffim, strel('square', 2));
                %diffim = imfill(diffim, 'holes');
                if obj.smallestCompPix > 1
                    % Remove isolated pixels.
                    diffImage = bwareaopen(diffImage, obj.smallestCompPix);
                end
                
                % subplot(1,2,1);image(frameImage);axis image;subplot(1,2,2);imagesc(diffImage);axis image;
                boundingBoxes = regionprops(bwconncomp(diffImage),'boundingbox');
                boundingBoxes = cat(1, boundingBoxes.BoundingBox);
            else
                [y, x] = find(diffImage);
                boundingBoxes = [x, y] - .5;
                boundingBoxes(:, 3:4) = 1;
            end
        end
        
        
        function writeHeader(obj, frameImage)
            if size(frameImage, 3) == 3,
              coding = 'RGB8';
            else
              coding = 'MONO8';
            end

            if obj.useBoxes
              max_width = size(frameImage, 2);
              max_height = size(frameImage, 1);
            else
              max_width = 1;
              max_height = 1;  
            end

            % ufmf: 4
            fwrite(obj.fileID,'ufmf','schar');
            % version: 4
            fwrite(obj.fileID, obj.version, 'uint');
            % index location: 0 for now: 8
            obj.frameIndex.locLoc = ftell(obj.fileID);
            fwrite(obj.fileID, 0, 'uint64');

            % max width: 2
            fwrite(obj.fileID, max_height, 'ushort');
            % max height: 2
            fwrite(obj.fileID, max_width, 'ushort');
            % whether it is fixed size patches: 1
            fwrite(obj.fileID, ~obj.useBoxes, 'uchar');
            % raw coding string length: 1
            fwrite(obj.fileID, length(coding), 'uchar');
            % coding: length(coding)
            fwrite(obj.fileID, coding);
        end
        
        
        function writeKeyFrame(obj, timeStamp)
            KEYFRAME_CHUNK = 0;
            keyframe_type = 'mean';

            % update lastkeyframetime
            obj.bgModel.lastkeyframetime = timeStamp;

            loc = ftell(obj.fileID);
            % store in index
            obj.frameIndex.keyframe.mean.loc(end+1) = loc;
            % also store timestamp
            obj.frameIndex.keyframe.mean.timestamp(end+1) = timeStamp;

            % write the chunk type
            fwrite(obj.fileID,KEYFRAME_CHUNK,'uchar');
            % write the keyframe type
            fwrite(obj.fileID,length(keyframe_type),'uchar');
            fwrite(obj.fileID,keyframe_type,'char');

            % write the data type (based on format characters from http://docs.python.org/2/library/struct.html)
            dtype = matlabclass2dtypechar(class(obj.bgModel.meanImage));
            fwrite(obj.fileID,dtype,'char');

            % images are sideways: swap width and height
            % width, height
            fwrite(obj.fileID,[size(obj.bgModel.meanImage,2),size(obj.bgModel.meanImage,1)],'ushort');

            % timestamp
            fwrite(obj.fileID,timeStamp,'double');

            % write the frame
            fwrite(obj.fileID,permute(obj.bgModel.meanImage,[3,2,1]),class(obj.bgModel.meanImage));
        end
        
        
        function writeFrame(obj, frameImage, timeStamp)
%             % if the background has been updated since the last time a background keyframe was written to file
%             if obj.bgModel.lastupdatetime > obj.bgModel.lastkeyframetime
%               % if the time since the last background keyframe time was at least KeyframePeriod
%               dt = timeStamp - obj.bgModel.lastkeyframetime;
%               if dt >= obj.keyFrameSecs
%                 % then write the current background model
%                 obj.writeKeyFrame(timeStamp);
%               end
%             end
            
            [boundingBoxes, diffImage] = subtractBackground(obj, frameImage);
            ncc = size(boundingBoxes, 1);
            
            FRAME_CHUNK = 1;

            % get location of this frame
            loc = ftell(obj.fileID);
            % store in index
            obj.frameIndex.frame.loc(end+1) = loc;
            % also store timestamp
            obj.frameIndex.frame.timestamp(end+1) = timeStamp;

            % write chunk type: 1
            fwrite(obj.fileID, FRAME_CHUNK, 'uchar');
            % write timestamp: 8
            fwrite(obj.fileID, timeStamp, 'double');
            % write number of points: 4
            fwrite(obj.fileID, ncc, 'uint32');

            dtype = class(frameImage);
            if obj.useBoxes
              for j = 1:ncc
                fwrite(obj.fileID, [boundingBoxes(j,[1,2])-.5,boundingBoxes(j,[3,4])], 'ushort');
                tmp = frameImage(boundingBoxes(j,2)+.5:boundingBoxes(j,2)+boundingBoxes(j,4)-.5,boundingBoxes(j,1)+.5:boundingBoxes(j,1)+boundingBoxes(j,3)-.5,:);
                fwrite(obj.fileID, permute(tmp,[3,2,1]), dtype);
              end
            else
                %   % this is kind of complicated because the coordinates must be ushorts and
                %   % the pixels must be uint8s.
                %   tmp = permute(im,[3,1,2]);
                %   fwrite(fid,cat( 1, reshape(typecast( cast(bb(:,2)'-.5,'uint16'), 'uint8' ),[2,ncc]), ...
                %     reshape(typecast( cast(bb(:,1)'-.5,'uint16'), 'uint8' ),[2,ncc]), ...
                %     cast(tmp(:,isfore), 'uint8') ),'uint8');

                % faster to write in this order in Matlab: all pixel locations followed
                % by all pixels; doing the complicated stuff above works almost as fast,
                % but is ... complicated. 
                fwrite(obj.fileID, boundingBoxes(:,[2,1])-.5,'ushort');
                tmp = permute(frameImage,[3,2,1]);
                % index by color, then column, then row
                fwrite(obj.fileID, tmp(:,diffImage), dtype);
%                 for color = 1:size(im,3),
%                     tmp = im(:,:,color);
%                     fwrite(fid,tmp(diffImage),dtype);
%                 end
            end
            
% TODO: ?
%             if nargout > 1
%                 stats.bytes = ftell(obj.fileID) - loc - (1 + 8 + 4);
%                 stats.components = ncc;
%                 %fprintf('Frame size: %g KB, %d comps\n', stats.bytes / 1024, stats.components);
%             end
        end
        
        
        function writeIndex(obj)
            % Finish writing the UFMF by writing the indices to the file and closing.
            % We write the index at the end of the file using subfunction write_dict.
            % We store the location of the index in the file at the location stored in
            % obj.frameIndex.locLoc. 
            INDEX_DICT_CHUNK = 2;

            % start of index chunk
            fwrite(obj.fileID, INDEX_DICT_CHUNK, 'uchar');
            obj.frameIndex.loc = ftell(obj.fileID);
            
            % write index
            obj.writeDict(obj.frameIndex);

            fseek(obj.fileID, obj.frameIndex.locLoc, 'bof');
            fwrite(obj.fileID, obj.frameIndex.loc,'uint64');
        end
        
        
        function writeDict(obj, dict)
            keys = fieldnames(dict);

            % write a d
            fwrite(obj.fileID, 'd');
            % write the number of fields
            fwrite(obj.fileID, length(keys), 'uchar');

            for j = 1:length(keys),
                key = keys{j};
                value = dict.(key);
                % write length of key name
                fwrite(obj.fileID, length(key), 'ushort');
                % write the key
                fwrite(obj.fileID, key);
                % if this is a struct, call recursively
                if isstruct(value),
                    obj.writeDict(value);
                else
                    % write a for array followed by the single char abbr of the class
                    dtypechar = matlabclass2dtypechar(class(value));
                    fwrite(obj.fileID, ['a', dtypechar]);
                    % write length of array * bytes_per_element
                    tmp = whos('value');
                    fwrite(obj.fileID, tmp.bytes, 'ulong');
                    % write the array
                    fwrite(obj.fileID, value, class(value));
                end
            end
        end
    end
end
    
    
