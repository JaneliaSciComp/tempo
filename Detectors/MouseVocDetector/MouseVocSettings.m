function varargout = MouseVocSettings(varargin)
% MOUSEVOCSETTINGS MATLAB code for MouseVocSettings.fig
%      MOUSEVOCSETTINGS, by itself, creates a new MOUSEVOCSETTINGS or raises the existing
%      singleton*.
%
%      H = MOUSEVOCSETTINGS returns the handle to a new MOUSEVOCSETTINGS or the handle to
%      the existing singleton*.
%
%      MOUSEVOCSETTINGS('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in MOUSEVOCSETTINGS.M with the given input arguments.
%
%      MOUSEVOCSETTINGS('Property','Value',...) creates a new MOUSEVOCSETTINGS or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before MouseVocSettings_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to MouseVocSettings_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help MouseVocSettings

% Last Modified by GUIDE v2.5 14-Nov-2012 17:00:13

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @MouseVocSettings_OpeningFcn, ...
                   'gui_OutputFcn',  @MouseVocSettings_OutputFcn, ...
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


% --- Executes just before MouseVocSettings is made visible.
function MouseVocSettings_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to MouseVocSettings (see VARARGIN)

if (nargin ~= 4 && nargin ~= 6) || ~isa(varargin{1}, 'MouseVocDetector')
    error 'MouseVocSettings() must be passed a single MouseVocDetector object.'
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
    if strcmp(field,'NFFT')
      eval(['num2str(handles.detector.' field{1} ',''%g,''); set(handles.' field{1} 'Edit, ''String'', ans(1:end-1))'])
    else
      eval(['set(handles.' field{1} 'Edit, ''String'', num2str(handles.detector.' field{1} '))'])
    end
    if ~handles.editable
        eval(['set(handles.' field{1} 'Edit, ''Enable'', ''off'')'])
    end
end

uiwait(handles.settingsFigure);


% --- Outputs from this function are returned to the command line.
function varargout = MouseVocSettings_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;
delete(handles.settingsFigure);



function NWEdit_Callback(hObject, eventdata, handles)
% hObject    handle to NWEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of NWEdit as text
%        str2double(get(hObject,'String')) returns contents of NWEdit as a double

str2num(get(hObject,'String'));
if (isempty(ans) || ~isinteger(ans) || (ans<=0))
  warndlg('NW must be a positive integer, >=(K+1)/2');
end


% --- Executes during object creation, after setting all properties.
function NWEdit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to NWEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function KEdit_Callback(hObject, eventdata, handles)
% hObject    handle to KEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of KEdit as text
%        str2double(get(hObject,'String')) returns contents of KEdit as a double

str2num(get(hObject,'String'));
if (isempty(ans) || ~isinteger(ans) || (ans<=0))
  warndlg('K must be a positive integer, <=2*NW-1');
end


% --- Executes during object creation, after setting all properties.
function KEdit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to KEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function PValEdit_Callback(hObject, eventdata, handles)
% hObject    handle to PValEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of PValEdit as text
%        str2double(get(hObject,'String')) returns contents of PValEdit as a double

str2num(get(hObject,'String'));
if (isempty(ans) || (ans<=0))
  warndlg('PVal must be a positive float');
end


% --- Executes during object creation, after setting all properties.
function PValEdit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to PValEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function NFFTEdit_Callback(hObject, eventdata, handles)
% hObject    handle to NFFTEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of NFFTEdit as text
%        str2double(get(hObject,'String')) returns contents of NFFTEdit as a double

str2num(get(hObject,'String'));
if (isempty(ans) || (sum(sign(ans)~=1)>0))
  warndlg('NFFT must be a comma-separated list of positive floats');
end


% --- Executes during object creation, after setting all properties.
function NFFTEdit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to NFFTEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function MergeTimeEdit_Callback(hObject, eventdata, handles)
% hObject    handle to MergeTimeEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of MergeTimeEdit as text
%        str2double(get(hObject,'String')) returns contents of MergeTimeEdit as a double

str2num(get(hObject,'String'));
if (isempty(ans) || (ans<1))
  warndlg('merge time must be a positive float');
end


% --- Executes during object creation, after setting all properties.
function MergeTimeEdit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to MergeTimeEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function MergeFreqEdit_Callback(hObject, eventdata, handles)
% hObject    handle to MergeFreqEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of MergeFreqEdit as text
%        str2double(get(hObject,'String')) returns contents of MergeFreqEdit as a double

str2num(get(hObject,'String'));
if (isempty(ans) || ((ans~=0) && (ans~=1)))
  warndlg('merge freq must be 0 or 1');
end


% --- Executes during object creation, after setting all properties.
function MergeFreqEdit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to MergeFreqEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function MergeFreqOverlapEdit_Callback(hObject, eventdata, handles)
% hObject    handle to MergeFreqOverlapEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of MergeFreqOverlapEdit as text
%        str2double(get(hObject,'String')) returns contents of MergeFreqOverlapEdit as a double

str2num(get(hObject,'String'));
if (isempty(ans) || (ans<0) || (ans>1))
  warndlg('merge freq must be between 0 and 1');
end


% --- Executes during object creation, after setting all properties.
function MergeFreqOverlapEdit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to MergeFreqOverlapEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function MergeFreqRatioEdit_Callback(hObject, eventdata, handles)
% hObject    handle to MergeFreqRatioEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of MergeFreqRatioEdit as text
%        str2double(get(hObject,'String')) returns contents of MergeFreqRatioEdit as a double


% --- Executes during object creation, after setting all properties.
function MergeFreqRatioEdit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to MergeFreqRatioEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function MergeFreqFractionEdit_Callback(hObject, eventdata, handles)
% hObject    handle to MergeFreqFractionEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of MergeFreqFractionEdit as text
%        str2double(get(hObject,'String')) returns contents of MergeFreqFractionEdit as a double

str2num(get(hObject,'String'));
if (isempty(ans) || (ans<0) || (ans>1))
  warndlg('merge freq must be between 0 and 1');
end


% --- Executes during object creation, after setting all properties.
function MergeFreqFractionEdit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to MergeFreqFractionEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function ObjSizeEdit_Callback(hObject, eventdata, handles)
% hObject    handle to ObjSizeEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of ObjSizeEdit as text
%        str2double(get(hObject,'String')) returns contents of ObjSizeEdit as a double

str2num(get(hObject,'String'));
if (isempty(ans) || ~isinteger(ans) || (ans<1))
  warndlg('obj size must be a positive integer');
end


% --- Executes during object creation, after setting all properties.
function ObjSizeEdit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ObjSizeEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function ConvWidthEdit_Callback(hObject, eventdata, handles)
% hObject    handle to ConvWidthEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of ConvWidthEdit as text
%        str2double(get(hObject,'String')) returns contents of ConvWidthEdit as a double

str2num(get(hObject,'String'));
if (isempty(ans) || ~isinteger(ans) || (ans<1))
  warndlg('conv width must be a positive integer');
end


% --- Executes during object creation, after setting all properties.
function ConvWidthEdit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ConvWidthEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function ConvHeightEdit_Callback(hObject, eventdata, handles)
% hObject    handle to ConvHeightEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of ConvHeightEdit as text
%        str2double(get(hObject,'String')) returns contents of ConvHeightEdit as a double

str2num(get(hObject,'String'));
if (isempty(ans) || ~isinteger(ans) || (ans<1))
  warndlg('conv height must be a positive integer');
end


% --- Executes during object creation, after setting all properties.
function ConvHeightEdit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ConvHeightEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function FreqLowEdit_Callback(hObject, eventdata, handles)
% hObject    handle to FreqLowEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of FreqLowEdit as text
%        str2double(get(hObject,'String')) returns contents of FreqLowEdit as a double

str2num(get(hObject,'String'));
if (isempty(ans) || (ans<1))
  warndlg('freq low must be a positive float');
end


% --- Executes during object creation, after setting all properties.
function FreqLowEdit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to FreqLowEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function FreqHighEdit_Callback(hObject, eventdata, handles)
% hObject    handle to FreqHighEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of FreqHighEdit as text
%        str2double(get(hObject,'String')) returns contents of FreqHighEdit as a double

str2num(get(hObject,'String'));
if (isempty(ans) || (ans<1))
  warndlg('freq high must be a positive float');
end


% --- Executes during object creation, after setting all properties.
function FreqHighEdit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to FreqHighEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function NSegEdit_Callback(hObject, eventdata, handles)
% hObject    handle to NSegEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of NSegEdit as text
%        str2double(get(hObject,'String')) returns contents of NSegEdit as a double

str2num(get(hObject,'String'));
if (isempty(ans) || ~isinteger(ans) || (ans<1))
  warndlg('nharm must be a positive integer');
end


% --- Executes during object creation, after setting all properties.
function NSegEdit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to NSegEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



% --- Executes on button press in ButtonOK.
function ButtonOK_Callback(hObject, eventdata, handles)
% hObject    handle to ButtonOK (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

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


% --- Executes on button press in ButtonCancel.
function ButtonCancel_Callback(hObject, eventdata, handles)
% hObject    handle to ButtonCancel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

handles.output = false;
guidata(hObject, handles);
uiresume(handles.settingsFigure);
