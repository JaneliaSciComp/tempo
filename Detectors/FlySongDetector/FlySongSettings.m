function varargout = FlySongSettings(varargin)
    % FLYSONGSETTINGS MATLAB code for FlySongSettings.fig
    %      FLYSONGSETTINGS, by itself, creates a new FLYSONGSETTINGS or raises the existing
    %      singleton*.
    %
    %      H = FLYSONGSETTINGS returns the handle to a new FLYSONGSETTINGS or the handle to
    %      the existing singleton*.
    %
    %      FLYSONGSETTINGS('CALLBACK',hObject,eventData,handles,...) calls the local
    %      function named CALLBACK in FLYSONGSETTINGS.M with the given input arguments.
    %
    %      FLYSONGSETTINGS('Property','Value',...) creates a new FLYSONGSETTINGS or raises the
    %      existing singleton*.  Starting from the left, property value pairs are
    %      applied to the GUI before FlySongSettings_OpeningFcn gets called.  An
    %      unrecognized property name or invalid value makes property application
    %      stop.  All inputs are passed to FlySongSettings_OpeningFcn via varargin.
    %
    %      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
    %      instance to run (singleton)".
    %
    % See also: GUIDE, GUIDATA, GUIHANDLES

    % Edit the above text to modify the response to help FlySongSettings

    % Last Modified by GUIDE v2.5 25-Apr-2011 17:05:09
    
    % Begin initialization code - DO NOT EDIT
    gui_Singleton = 1;
    gui_State = struct('gui_Name',       mfilename, ...
                       'gui_Singleton',  gui_Singleton, ...
                       'gui_OpeningFcn', @FlySongSettings_OpeningFcn, ...
                       'gui_OutputFcn',  @FlySongSettings_OutputFcn, ...
                       'gui_LayoutFcn',  [] , ...
                       'gui_Callback',   []);
    if nargin && ischar(varargin{1})
        gui_State.gui_Callback = str2func(varargin{1});
    end
    
    if nargout
        [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
    else
        gui_mainfcn(gui_State, varargin{:});
    end
    % End initialization code - DO NOT EDIT
end


%#ok<*DEFNU>
%#ok<*INUSD>
%#ok<*INUSL>


% --- Executes just before FlySongSettings is made visible.
function FlySongSettings_OpeningFcn(hObject, eventdata, handles, varargin)
    if (nargin ~= 4 && nargin ~= 6) || ~isa(varargin{1}, 'FlySongDetector')
        error 'FlySongSettings() must be passed a single FlySongDetector object.'
    end
    
    handles.detector = varargin{1};
    handles.output = hObject;
    
    if nargin == 6 && strcmp(varargin{2}, 'Editable') && ~varargin{3}
        handles.editable = false;
        set(handles.cancelButton, 'Visible', 'off');
    else
        handles.editable = true;
    end
    
    guidata(hObject, handles);
    
    % Populate the fields.
    %   Modelled after: set(handles.ipiMinEdit, 'String', num2str(handles.detector.ipiMin));
    for field = handles.detector.settingNames()
        eval(['set(handles.' field{1} 'Edit, ''String'', num2str(handles.detector.' field{1} '))'])
        if ~handles.editable
            eval(['set(handles.' field{1} 'Edit, ''Enable'', ''off'')'])
        end
    end
    
    uiwait(handles.settingsFigure);
end


% --- Outputs from this function are returned to the command line.
function varargout = FlySongSettings_OutputFcn(hObject, eventdata, handles) 
    % varargout  cell array for returning output args (see VARARGOUT);
    % hObject    handle to figure
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)

    % Get default command line output from handles structure
    varargout{1} = handles.output;
    delete(handles.settingsFigure);
end


% --- Executes on button press in okButton.
function okButton_Callback(hObject, eventdata, handles)
    if handles.editable
        % Apply settings in GUI to detector
        for field = handles.detector.settingNames()
            value = eval(['get(handles.' field{1} 'Edit, ''String'')']);
            handles.detector.(field{1}) = str2num(value); %#ok<ST2NM>
        end

        % Indicate that the user accepted the settings and trigger the close of
        % the dialog.
        handles.output = true;
    else
        handles.output = false;
    end
    guidata(hObject, handles);
    uiresume(handles.settingsFigure);
end


% --- Executes on button press in cancelButton.
function cancelButton_Callback(hObject, eventdata, handles)
    % Indicate that the user cancelled and trigger the close of the dialog.
    handles.output = false;
    guidata(hObject, handles);
    uiresume(handles.settingsFigure);
end
