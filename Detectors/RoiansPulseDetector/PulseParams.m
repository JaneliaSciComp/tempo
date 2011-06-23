function varargout = PulseParams(varargin)
    % PULSEPARAMS MATLAB code for PulseParams.fig
    %      PULSEPARAMS, by itself, creates a new PULSEPARAMS or raises the existing
    %      singleton*.
    %
    %      H = PULSEPARAMS returns the handle to a new PULSEPARAMS or the handle to
    %      the existing singleton*.
    %
    %      PULSEPARAMS('CALLBACK',hObject,eventData,handles,...) calls the local
    %      function named CALLBACK in PULSEPARAMS.M with the given input arguments.
    %
    %      PULSEPARAMS('Property','Value',...) creates a new PULSEPARAMS or raises the
    %      existing singleton*.  Starting from the left, property value pairs are
    %      applied to the GUI before PulseParams_OpeningFcn gets called.  An
    %      unrecognized property name or invalid value makes property application
    %      stop.  All inputs are passed to PulseParams_OpeningFcn via varargin.
    %
    %      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
    %      instance to run (singleton)".
    %
    % See also: GUIDE, GUIDATA, GUIHANDLES

    % Edit the above text to modify the response to help PulseParams

    % Last Modified by GUIDE v2.5 12-Jan-2011 11:01:57

    % Begin initialization code - DO NOT EDIT
    gui_Singleton = 1;
    gui_State = struct('gui_Name',       mfilename, ...
                       'gui_Singleton',  gui_Singleton, ...
                       'gui_OpeningFcn', @PulseParams_OpeningFcn, ...
                       'gui_OutputFcn',  @PulseParams_OutputFcn, ...
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


% --- Executes just before PulseParams is made visible.
function PulseParams_OpeningFcn(hObject, eventdata, handles, varargin) %#ok<*INUSL>

    % Choose default command line output for PulseParams
    handles.output = hObject;
    guidata(hObject, handles);

    % Insert custom Title and Text if specified by the user
    % Hint: when choosing keywords, be sure they are not easily confused 
    % with existing figure properties.  See the output of set(figure) for
    % a list of figure properties.
    if(nargin > 3)
        for index = 1:2:(nargin-3),
            if nargin-3==index, break, end
            switch lower(varargin{index})
             case 'title'
              set(hObject, 'Name', varargin{index+1});
             case 'string'
              set(handles.text1, 'String', varargin{index+1});
            end
        end
    end

    % Determine the position of the dialog - centered on the callback figure
    % if available, else, centered on the screen
    FigPos=get(0,'DefaultFigurePosition');
    OldUnits = get(hObject, 'Units');
    set(hObject, 'Units', 'pixels');
    OldPos = get(hObject,'Position');
    FigWidth = OldPos(3);
    FigHeight = OldPos(4);
    if isempty(gcbf)
        ScreenUnits=get(0,'Units');
        set(0,'Units','pixels');
        ScreenSize=get(0,'ScreenSize');
        set(0,'Units',ScreenUnits);

        FigPos(1)=1/2*(ScreenSize(3)-FigWidth);
        FigPos(2)=2/3*(ScreenSize(4)-FigHeight);
    else
        GCBFOldUnits = get(gcbf,'Units');
        set(gcbf,'Units','pixels');
        GCBFPos = get(gcbf,'Position');
        set(gcbf,'Units',GCBFOldUnits);
        FigPos(1:2) = [(GCBFPos(1) + GCBFPos(3) / 2) - FigWidth / 2, ...
                       (GCBFPos(2) + GCBFPos(4) / 2) - FigHeight / 2];
    end
    FigPos(3:4)=[FigWidth FigHeight];
    set(hObject, 'Position', FigPos);
    set(hObject, 'Units', OldUnits);

    % Make the GUI modal
    set(handles.figure1, 'WindowStyle', 'modal')

    % UIWAIT makes untitled wait for user response (see UIRESUME)
    uiwait(handles.figure1);
end


function varargout = PulseParams_OutputFcn(hObject, eventdata, handles) 
    % varargout  cell array for returning output args (see VARARGOUT);
    % hObject    handle to figure
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)

    % Get default command line output from handles structure
    varargout{1} = handles.output;
    
    delete(handles.figure1);
end


% --- Executes on button press in okButton.
function okButton_Callback(hObject, eventdata, handles)
    uiresume(handles.figure1);
end


% --- Executes on button press in cancelButton.
function cancelButton_Callback(hObject, eventdata, handles)
    uiresume(handles.figure1);
end


function minIPIEdit_Callback(hObject, eventdata, handles) %#ok<*INUSD>
    % Hints: get(hObject,'String') returns contents of minIPIEdit as text
    %        str2double(get(hObject,'String')) returns contents of minIPIEdit as a double
end


function minIPIEdit_CreateFcn(hObject, eventdata, handles) %#ok<*DEFNU>
    % Hint: edit controls usually have a white background on Windows.
    %       See ISPC and COMPUTER.
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end


function maxIPIEdit_Callback(hObject, eventdata, handles)
    % Hints: get(hObject,'String') returns contents of maxIPIEdit as text
    %        str2double(get(hObject,'String')) returns contents of maxIPIEdit as a double
end


function maxIPIEdit_CreateFcn(hObject, eventdata, handles)
    % Hint: edit controls usually have a white background on Windows.
    %       See ISPC and COMPUTER.
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end


function minFreqEdit_Callback(hObject, eventdata, handles)
    % Hints: get(hObject,'String') returns contents of minFreqEdit as text
    %        str2double(get(hObject,'String')) returns contents of minFreqEdit as a double
end


function minFreqEdit_CreateFcn(hObject, eventdata, handles)
    % Hint: edit controls usually have a white background on Windows.
    %       See ISPC and COMPUTER.
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end


function maxFreqEdit_Callback(hObject, eventdata, handles)
    % Hints: get(hObject,'String') returns contents of maxFreqEdit as text
    %        str2double(get(hObject,'String')) returns contents of maxFreqEdit as a double
end


function maxFreqEdit_CreateFcn(hObject, eventdata, handles)
    % Hint: edit controls usually have a white background on Windows.
    %       See ISPC and COMPUTER.
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end


function figure1_CloseRequestFcn(hObject, eventdata, handles)
    if isequal(get(hObject, 'waitstatus'), 'waiting')
        % The GUI is still in UIWAIT, us UIRESUME
        uiresume(hObject);
    else
        % The GUI is no longer waiting, just close it
        delete(hObject);
    end
end


function figure1_KeyPressFcn(hObject, eventdata, handles)
    % Check for "enter" or "escape"
    if isequal(get(hObject, 'CurrentKey'), 'escape')
        % User said no by hitting escape
        handles.output = 'No';
        guidata(hObject, handles);

        uiresume(handles.figure1);
    end    

    if isequal(get(hObject, 'CurrentKey'), 'return')
        uiresume(handles.figure1);
    end    
end


% --- Executes during object creation, after setting all properties.
function figure1_CreateFcn(hObject, eventdata, handles)
end

