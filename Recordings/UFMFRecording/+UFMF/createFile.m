function obj = createFile(filePath, varargin)
    % Create a new UFMF file at the indicated path.
    %
    % Optional params:
    %   'FixedSizeBoxes'    {'on'} | 'off'
    %   'MinimizeBoxes'     {'on'} | 'off'
    %   'SmallestBoxSize'   {1} through inf
    obj = UFMF.UFMFFile(filePath, 'write', varargin{:});
end
