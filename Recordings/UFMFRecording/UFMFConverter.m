function UFMFConverter(varargin)
    % Parse the inputs.
    inputs = readInputs(varargin{:});
    
    if isempty(inputs.inputFiles) || isempty(inputs.outputFile)
        return
    end
    
    if exist(inputs.outputFile, 'file')
        delete(inputs.outputFile);
    end
    
    ufmf = UFMF(inputs.outputFile);
	ufmf.numMeans = inputs.bgNumMeans;
	ufmf.bgUpdateSecs = inputs.bgUpdateSecs;
	ufmf.bgInitialMeans = inputs.bgInitialMeans;
	ufmf.bgThreshold = inputs.bgThreshold;
	ufmf.useBoxes = inputs.useBoxes;
	ufmf.smallestBoxSize = inputs.smallestBoxSize;
    
    ufmf.printStats = true;
    
    % Set up for any image dilation.
    if isempty(inputs.dilation)
        dilationSE = [];
    else
        dilationSE = strel(inputs.dilation, inputs.dilationRadius);
    end
    
    % Start gathering stats.
    startTime = now;
    totalFrames = 0;
    inputBytes = 0;
    
    lastStatusTime = now;
    
    % Loop through each of the input video files and append them together.
    % TODO: will they be in the correct order if chosen from the UI?
    for fileIndex = 1:length(inputs.inputFiles)
        inputFile = inputs.inputFiles{fileIndex};
        
        [~, fileName, fileExt] = fileparts(inputFile);
        fprintf('Converting %s%s to UFMF...\n', fileName, fileExt);
        
        vr = VideoReader(inputFile); %#ok<TNMLP>
        
        if fileIndex == 1
            % Do one-time set up for the first video encountered.
            if isempty(inputs.quadrant)
                rois = [1 1 vr.Width vr.Height];
            else
                halfWidth = vr.Width / 2;
                halfHeight = vr.Height / 2;
                rois = [1 1 halfHeight halfWidth];
                if inputs.quadrant(1) == 'L'
                    rois(2) = halfHeight + 1;
                end
                if inputs.quadrant(2) == 'R'
                    rois(1) = halfWidth + 1;
                end
                roiInd = 1;
                
                % TODO: could support more than one ROI at a time which would be faster...
            end
            ufmf.frameRate = vr.FrameRate;
            
            % Prime the background model with ten frames from throughout the movie to avoid initial artifacts.
%             for frameI = 1:vr.NumberOfFrames/10:vr.NumberOfFrames
%                 im = read(vr, frameI);
%                 if ~isempty(dilationSE)
%                     im = imdilate(im, dilationSE);
%                 end
%                 frameTime = frameI / vr.FrameRate;
%                 bg = UpdateBG(bg, im, frameI, frameTime);
%             end
%             bg.lastupdatetime = -inf;
        else
            % TODO: check that subsequent movies are the same size, etc.
        end
        
        % Loop through each frame of this movie and append it to the UFMF.
        for frameIndex = 1:vr.NumberOfFrames
            im = read(vr, frameIndex);
            
            % If called for then blur the image slightly to reduce noise.
            if ~isempty(dilationSE)
                im = imdilate(im, dilationSE);
            end
            
            % Extract the region of interest.
            roi = rois(roiInd, :);
            imROI = im(roi(2):roi(2)+roi(4)-1, roi(1):roi(1)+roi(3)-1, :);
            
            % Add it.
            ufmf.addFrame(imROI);
            
            % Show progress every 15 seconds.
            if now - lastStatusTime > 15 / (24 * 60 * 60)
                percentComplete = frameIndex / vr.NumberOfFrames * 100.0;
                fprintf('    %g%% ...\n', percentComplete);
                lastStatusTime = now;
            end
        end
        
        % Gather stats.
        totalFrames = totalFrames + vr.NumberOfFrames;
        fileInfo = dir(inputFile);
        inputBytes = inputBytes + fileInfo.bytes;
        
        delete(vr);
        clear vr;
    end
    
    % Close up the UFMF now that all movies have been converted.
    ufmf.close();
    
    elapsedTime = (now - startTime) * (24 * 60 * 60);
    fileInfo = dir(inputs.outputFile);
    outputBytes = fileInfo.bytes;
    fprintf('UFMF conversion complete.\n');
    fprintf('   Elapsed time: %.1f secs\n', elapsedTime);
    fprintf('   FPS: %.1f\n', totalFrames / elapsedTime);
    fprintf('   Compression: %.1f %% (%.1f MB -> %.1f MB) \n', inputBytes / outputBytes * 100.0, inputBytes / 1024 / 1204, outputBytes / 1024 / 1024);
    
    % Base: 61.7 KB, 244 comps
    
    % Dilate/close holes: 72.5 KB, 260 comps
    % Dilate/close holes/open: 72.5 KB, 258 comps
    
    % Pre-dilate square 1: 61.7 KB, 344 comps
    % Pre-dilate square 3: 57.0 KB, 174 comps
    
    % File MB    KB/frame    # Comps    Pre-dilate    Dilate    Close    Open
    %  157.4      147.5        1503         
    %  149.9      140.1         850        sq2
    %  140.3      137.5         717        sq3
    %  171.5      169.5        1185                    sq2        Y
    %  158.4      156.0         713        sq2         sq2        Y
    %  156.4      154.0         603        sq3         sq2        Y
    %  155.7      153.3         353                    sq2        Y        5
    %  151.8      149.2         366        sq2         sq2        Y        5
    %  151.0      148.4         317        sq3         sq2        Y        5
end


function inputs = readInputs(varargin)
    parser = inputParser;
    
    parameterNames = {'bgNumMeans', 'bgUpdateSecs', 'bgThreshold', 'useBoxes', 'keyFrameSecs', ...
                      'quadrant', 'dilation', 'dilationRadius'};
    if ~isempty(varargin)
        if ~ismember(varargin{1}, parameterNames)
            parser.addOptional('inputFiles', {}, @(x) ischar(x) || iscell(x));
            if length(varargin) > 1 && ~ismember(varargin{2}, parameterNames)
                parser.addOptional('outputFile', '', @(x) ischar(x));
            end
        end
    end
    
    % Background calculation parameters.
    parser.addParamValue('bgNumMeans', 1, @(x) isnumeric(x) && x > 0);  % The number of mean frames to calculate.
    parser.addParamValue('bgUpdateSecs', 10, @(x) isnumeric(x));        % The number of seconds between BG updates.
    parser.addParamValue('bgInitialMeans', 0, @(x) isnumeric(x));       % Always compute the background for this many initial frames.
    parser.addParamValue('bgThreshold', 10, @(x) isnumeric(x));         % The pixel difference between BG and FG.
    parser.addParamValue('useBoxes', true, @(x) islogical(x));          % Whether to use box-based compression.
    parser.addParamValue('smallestBoxSize', 1, @(x) isnumeric(x));      % The smallest number of pixels in connected components.
    
    % Image processing options
    parser.addParamValue('quadrant', '', @(x) ischar(x) && ismember(x, {'UL', 'UR', 'LL', 'LR'}));
    parser.addParamValue('dilation', '', @(x) ischar(x) && ismember(x, {'diamond', 'octagon', 'square'}));
    parser.addParamValue('dilationRadius', 3, @(x) x > 0 && x < 10);
    
    parser.parse(varargin{:});
    inputs = parser.Results;
    
    if ~isfield(inputs, 'inputFiles') || isempty(inputs.inputFiles)
        % Prompt for file(s)
        [fileNames, pathName] = uigetfile('*.*', 'Select one or more movie files to append:', 'MultiSelect', 'on');
        if isscalar(fileNames)
            % the user cancelled
        elseif ischar(fileNames)
            inputs.inputFiles = {fullfile(pathName, fileNames)};
        elseif iscell(fileNames)
            inputs.inputFiles = fullfile(pathName, fileNames);
        end
    elseif ischar(inputs.inputFiles)
        inputs.inputFiles = {inputs.inputFiles};
    end
    
    % Open the output UFMF file for writing.
    if ~isfield(inputs, 'outputFile') || isempty(inputs.outputFile)
        % Prompt for path
        [fileName, pathName] = uiputfile('*.ufmf', 'Save movie as UFMF:');
        if isscalar(fileName)
            % the user cancelled
        else
            inputs.outputFile = fullfile(pathName, fileName);
        end
    end
end
