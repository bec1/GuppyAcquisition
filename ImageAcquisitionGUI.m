function varargout = ImageAcquisitionGUI(varargin)
% IMAGEACQUISITIONGUI MATLAB code for ImageAcquisitionGUI.fig
%      IMAGEACQUISITIONGUI, by itself, creates a new IMAGEACQUISITIONGUI or raises the existing
%      singleton*.
%
%      H = IMAGEACQUISITIONGUI returns the handle to a new IMAGEACQUISITIONGUI or the handle to
%      the existing singleton*.
%
%      IMAGEACQUISITIONGUI('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in IMAGEACQUISITIONGUI.M with the given input arguments.
%
%      IMAGEACQUISITIONGUI('Property','Value',...) creates a new IMAGEACQUISITIONGUI or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before ImageAcquisitionGUI_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to ImageAcquisitionGUI_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help ImageAcquisitionGUI

% Last Modified by GUIDE v2.5 17-Aug-2018 10:58:26

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @ImageAcquisitionGUI_OpeningFcn, ...
                   'gui_OutputFcn',  @ImageAcquisitionGUI_OutputFcn, ...
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


% --- Executes just before ImageAcquisitionGUI is made visible.
function ImageAcquisitionGUI_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to ImageAcquisitionGUI (see VARARGIN)

setappdata(0  , 'hMainGui'    , gcf); %save the handle for main gui
%save all kind of imaging data in handle gcf
setappdata(gcf,   'DeviceHandle'    , 0); 
setappdata(gcf,   'ExposureTime'    , 1000); 
setappdata(gcf,   'DelayTime'    , 0);
setappdata(gcf, 'ROI', [0,0,1024,1024]);
setappdata(gcf, 'GuppyBinning','Mode1');
setappdata(gcf,'Ifabort',0);
% p = gcp(); % start parallel pool for image acquisition. This enables abort and other functionality during repeated acquisition
handles.exposuretime=1000;
handles.delaytime=0;
handles.guppybinning='Mode1';
handles.roi=[0,0,1024,1024];
%end of setting data

%Begin to initialize the saving folder
YearString = datestr(now,'yyyy');
MonthString = datestr(now,'yyyy-mm');
DataString = datestr(now,'yyyy-mm-dd');
handles.folder=['R:\Fermi3\Images\',YearString,'\', MonthString,'\',DataString];
set(handles.Floder,'String',handles.folder);

%Begin to searching for the imaging devices
handles.devicelist=SearchDevice();
if isempty(handles.devicelist)
    msgbox('Please plug in a Guppy camera')
else
    namelist=handles.devicelist(:,3);
    if exist('namelist.mat','file')==2
        out=load('namelist.mat');
        if length(out.namelist)==length(namelist)
            namelist=out.namelist;
        end
    end
    set(handles.DeviceList,'String',namelist);

    %initialize the handle to imaging device as 0
    handles.currentdevice=0;
    handles.isdevice=0;

    %initialize the image space in GUI
    blank=zeros(40,64);
    handles.img=image('Parent',handles.axes1,'CData',blank);

    %initialize the preview status
    handles.prv=0;

    %initialize the current showing image and last acquired image
    handles.currentimage=blank;
    handles.currentcrop=blank;
    handles.lastacquired=blank;
    %initialize the roll back
    handles.rollbacksize=10;
    handles.rollback={};

    %initialize the frame number and demagnification
    handles.framenum=3;
    handles.sfdemag=1;

    %initialize the mark
    handles.currentmark=0;
    handles.ifmark=0;
    setappdata(gcf,'IfMark',0);
    setappdata(gcf,'CurrentMark',0);

    % Choose default command line output for ImageAcquisitionGUI
    handles.output = hObject;

    % Update handles structure
    guidata(hObject, handles);
end

% UIWAIT makes ImageAcquisitionGUI wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = ImageAcquisitionGUI_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on selection change in RollBackList.
function RollBackList_Callback(hObject, eventdata, handles)
% hObject    handle to RollBackList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns RollBackList contents as cell array
%        contents{get(hObject,'Value')} returns selected item from RollBackList
var=get(hObject,'Value');
if (var>0) && (var<=size(handles.rollback,2))
    chosenimage=single(handles.rollback{var});
    NC=size(chosenimage,3);
    % update component list
    if NC==3
        componentlist={'OD';'With atoms';'Without atoms';'Dark field'};
        %componentlist={'PC';'With atoms';'Without atoms';'Dark field'};
    else
        componentlist=cell(NC,1);
        for i=1:NC
            componentlist{i}=num2str(i);
        end
    end
    set(handles.CompList,'String',componentlist);
    % update image on main axes
    if NC==3
        %show the OD picture
        handles.currentimage=real(-log((chosenimage(:,:,1)-chosenimage(:,:,3))./(chosenimage(:,:,2)-chosenimage(:,:,3))));
        %handles.currentimage=real((chosenimage(:,:,1)-chosenimage(:,:,3))./(chosenimage(:,:,2)-chosenimage(:,:,3)));
    else
        handles.currentimage=chosenimage(:,:,1);
    end
    handles.cuurentcrop=updatecrop(handles);
    updateshow( handles );
    set(handles.CompList,'Value',1);
end
guidata(hObject,handles);

% --- Executes during object creation, after setting all properties.
function RollBackList_CreateFcn(hObject, eventdata, handles)
% hObject    handle to RollBackList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in CompList.
function CompList_Callback(hObject, eventdata, handles)
% hObject    handle to CompList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns CompList contents as cell array
%        contents{get(hObject,'Value')} returns selected item from CompList

%first update the complist itself 
var=get(handles.RollBackList,'Value');
if (var>0) && (var<=size(handles.rollback,2))
    chosenimage=single(handles.rollback{var});
    NC=size(chosenimage,3);
    % update component list
    if NC==3
        componentlist={'OD';'With atoms';'Without atoms';'Dark field'};
        %componentlist={'PC';'With atoms';'Without atoms';'Dark field'};
    else
        componentlist=cell(NC,1);
        for i=1:NC
            componentlist{i}=num2str(i);
        end
    end
end
set(hObject,'String',componentlist);
%Choose the frame in image
imagenum=get(handles.RollBackList,'Value');
framenum=get(handles.CompList,'Value');
currentimage=single(handles.rollback{imagenum});
NC=size(currentimage,3);
if NC==3
    framenum=framenum-1;
end
if framenum>NC
    framenum=NC;
    num=framenum;
    if (NC==3)
        num=num+1;
    end
    set(handles.CompList,'Value',num);
end
if NC==3
    if framenum==0
        %show the OD picture
        handles.currentimage=real(-log((currentimage(:,:,1)-currentimage(:,:,3))./(currentimage(:,:,2)-currentimage(:,:,3))));
        %handles.currentimage=real((currentimage(:,:,1)-currentimage(:,:,3))./(currentimage(:,:,2)-currentimage(:,:,3)));
        %set(handles.CMCustom,'Value',1)
    else
        handles.currentimage=currentimage(:,:,framenum);
    end
else
    handles.currentimage=currentimage(:,:,framenum);
end
handles.currentcrop=updatecrop(handles);
updateshow( handles );
guidata(hObject,handles);



% --- Executes during object creation, after setting all properties.
function CompList_CreateFcn(hObject, eventdata, handles)
% hObject    handle to CompList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function Saveasdemag_Callback(hObject, eventdata, handles)
% hObject    handle to Saveasdemag (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of Saveasdemag as text
%        str2double(get(hObject,'String')) returns contents of Saveasdemag as a double


% --- Executes during object creation, after setting all properties.
function Saveasdemag_CreateFcn(hObject, eventdata, handles)
% hObject    handle to Saveasdemag (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in SaveAs.
function SaveAs_Callback(hObject, eventdata, handles)
% hObject    handle to SaveAs (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

k=str2num(get(handles.Saveasdemag,'String'));
if size(k,1)==0
    k=1;
end
var=get(handles.RollBackList,'Value');
if k==1
    savedata=handles.rollback{var};
else
    mag=max(min(1/k,10),0.1);
    savedata=imresize(handles.rollback{var},mag);
end
[FileName,PathName]=uiputfile([handles.folder,'\','*.fits']);
file=[PathName,FileName];
if FileName~=0
    fitswrite(savedata,file);
end
% --- Executes on button press in Abort.
function Abort_Callback(hObject, eventdata, handles)
% hObject    handle to Abort (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
setappdata(gcf,'Ifabort',1);
set(handles.AcqRep,'Value',0);
disp('abort');
errordlg('Please send a single trigger to the Guppy to clear the current acqusition!')
guidata(hObject,handles);

% --- Executes on button press in AcqOne.
function AcqOne_Callback(hObject, eventdata, handles)
% hObject    handle to AcqOne (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
EndPreview_Callback(handles.EndPreview, eventdata, handles);
% set the device 
vid = handles.currentdevice;
%Check if the saving folder exist, if not, create the folder
ex=exist(handles.folder,'dir');
if (ex~=7)
    mkdir(handles.folder);
end
%Check if the handle to the camera exist, if so, grab frames
if (vid~=0)
    N=handles.framenum;
    N=min(max(N,1),6);
    set(handles.Counting,'String','0');
    src = getselectedsource(vid);
    triggerconfig(vid, 'hardware', 'DeviceSpecific', 'DeviceSpecific');
    src.TriggerActivation = 'RisingEdge';
    src.TriggerMode = 'On';
    vid.TriggerRepeat = N;
    vid.FramesPerTrigger=1;
    vid.Timeout=1000000;
    src.ExposureAuto = 'Off';
    roi=vid.ROI;
    height=roi(4);
    width=roi(3);
    counter=0;
    set(handles.Status,'String','Image taking');
    tempimage=cell(1,N);
    start(vid);
    set(handles.Counting,'String','0');
    while counter<N
        tempimage{counter+1}=getsnapshot(vid);
        counter=counter+1;
        set(handles.Counting,'String',num2str(counter));
    end
    stop(vid);
    set(handles.Status,'String','Stand By');
    % resize the image if indicated
    k=handles.sfdemag;
    if k==1
        imag=zeros(height,width,N,'int16');
        for i=1:N
            imag(:,:,i)=tempimage{i};
        end
    else
        imag=[];
        for i=1:N
            imag(:,:,i)=imresize(tempimage{i},1/k);
        end
    end
    handles.lastacquired=imag;
    %save the picture
    if get(handles.SaveChk,'Value')
        time = datestr(now,'yyyy-mm-dd_HH-MM-SS');
        filename=[handles.folder,'\',time,'.fits'];
        fitswrite(handles.lastacquired,filename);
    end
   % display the image with atom on the main screen
   handles.currentimage=imag(:,:,1);
   handles.currentcrop=updatecrop(handles);
   updateshow(handles);
   %save the picture in roll back.
   if (size(handles.rollback,2)<handles.rollbacksize)
       handles.rollback=[imag,handles.rollback];
       %update roll back list
       str=cell(1,size(handles.rollback,2));
       for i=1:size(handles.rollback,2)
           str{i}=num2str(i);
       end
       set(handles.RollBackList,'String',str);
   else
       handles.rollback=[imag,handles.rollback(1:handles.rollbacksize-1)];
   end
else
    msgbox('Please select a Guppy device before continuing');
end

guidata(hObject, handles);


% --- Executes on button press in AcqRep.
function AcqRep_Callback(hObject, eventdata, handles)
% hObject    handle to AcqRep (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of AcqRep

EndPreview_Callback(handles.EndPreview, eventdata, handles);
% set the device
vid = handles.currentdevice;
%Check if the saving folder exist, if not, create the folder
ex=exist(handles.folder,'dir');
if (ex~=7)
    mkdir(handles.folder);
end
if (vid~=0) && get(hObject,'Value')
    setappdata(gcf,'Ifabort',0);
    N=handles.framenum;
    N=min(max(N,1),6);
    set(handles.Counting,'String','0');
    src = getselectedsource(vid);
    try
        triggerconfig(vid, 'hardware', 'DeviceSpecific', 'DeviceSpecific');
    catch
        disp('womp')
    end
    src.TriggerActivation = 'RisingEdge';
    src.TriggerMode = 'On';
    vid.TriggerRepeat = N;
    vid.FramesPerTrigger=1;
    vid.Timeout=1000000;
    src.ExposureAuto = 'Off';
    roi=vid.ROI;
    height=roi(4);
    width=roi(3);
    set(handles.Status,'String','Image taking');
        
    while get(hObject,'Value')
        counter=0;
        start(vid);
        tempimage=cell(1,N);
        set(handles.Counting,'String','0');
        while (counter<N) && not(getappdata(gcf,'Ifabort'))
%             out = feval(@getsnapshot,vid);
%             future = parfeval(p,@funcy,1,vid);
%             fetchOutputs(future);
%             counter = counter + 1
%             try
%                 [taken,imageout] = fetchNext(future,2);
%             catch E
%                 %warning('Failed to read an image: %s', getReport(E));
%                 taken = [];
%             end
%             if ~isempty(taken)
%                 tempimage{counter+1}=imageout;
%                 counter=counter+1;
%                 set(handles.Counting,'String',num2str(counter));
%             elseif getappdata(gcf,'Ifabort')
%                 disp('Aborted!');
%                 cancel(future);
%                 break;
%             end
            tempimage{counter+1}=getsnapshot(vid);
            counter=counter+1;
            set(handles.Counting,'String',num2str(counter));
        end
        stop(vid);
%         cancel(future);
        
        
        if not(getappdata(gcf,'Ifabort'))
            % resize the image if indicated
            k=handles.sfdemag;
            if k==1
                imag=zeros(height,width,N,'int16');
                for i=1:N
                    imag(:,:,i)=tempimage{i};
                end
            else
                imag=[];
                for i=1:N
                    imag(:,:,i)=imresize(tempimage{i},1/k);
                end
            end
            % display the image with atom on the main screen
            handles.currentimage=0.01*real(-log(double((imag(:,:,1)-imag(:,:,3))./(imag(:,:,2)-imag(:,:,3)))));
            handles.currentcrop=updatecrop(handles);
            updateshow(handles);
            caxis(handles.axes1,[0 4]);
%             imageshow=imag(:,:,1)/4;
%             if get(handles.CMDirect,'Value')
%                 %h=image(imageshow,'Parent',handles.axes1,'CDataMapping','direct');
%                 %colormap(handles.axes1,gray);
%             end
%             if get(handles.CMRescale,'Value')
%                 h=image(imageshow,'Parent',handles.axes1,'CDataMapping','scaled');
%                 colormap(handles.axes1,gray);
%             end
            %save the picture in roll back.
            if (size(handles.rollback,2)<handles.rollbacksize)
                handles.rollback=[imag,handles.rollback];
                %update roll back list
                str=cell(1,size(handles.rollback,2));
                for i=1:size(handles.rollback,2)
                    str{i}=num2str(i);
                end
                set(handles.RollBackList,'String',str);
            else
                handles.rollback=[imag,handles.rollback(1:handles.rollbacksize-1)];
            end
            guidata(hObject,handles);
            %save the picture to hard disk if indicated
            if get(handles.SaveChk,'Value')
                time = datestr(now,'yyyy-mm-dd_HH-MM-SS');
                filename=[handles.folder,'\',time,'.fits'];
                fitswrite(imag,filename);
            end
        end
    end
    set(handles.Status,'String','Stand By');
else
    msgbox('Please select a Guppy device before continuing');
end
guidata(hObject,handles);


% --- Executes on selection change in DeviceList.
function DeviceList_Callback(hObject, eventdata, handles)
% hObject    handle to DeviceList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns DeviceList contents as cell array
%        contents{get(hObject,'Value')} returns selected item from DeviceList


% --- Executes during object creation, after setting all properties.
function DeviceList_CreateFcn(hObject, eventdata, handles)
% hObject    handle to DeviceList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in Select.
function Select_Callback(hObject, eventdata, handles)
% hObject    handle to Select (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if handles.isdevice
    closepreview(handles.currentdevice);
    src = getselectedsource(handles.currentdevice);
    src.ExposureAuto = 'Off';
    delete(handles.currentdevice);
end
var=get(handles.DeviceList,'Value');
adaptor=handles.devicelist{var,1};
id=handles.devicelist{var,2};
handles.currentdevice=videoinput(adaptor,id, 'Mono16');
set(handles.CDtag,'String',['Current device: ',handles.devicelist{var,3}]);
name=imaqhwinfo(handles.currentdevice,'DeviceName');
setappdata(gcf,   'CurrentDevice'    , handles.currentdevice); 
src=getselectedsource(handles.currentdevice);
%Then read out the default camera setting of guppy camera
if (strfind(name,'guppy'))
    handles.exposuretime=src.ExposureTime;
    handles.delaytime=src.TriggerDelay;
    handles.guppybinning='Mode0';
    handles.roi=handles.devicelist.ROIPosition;
    setappdata(gcf,   'ExposureTime'    , handles.exposuretime); 
    setappdata(gcf,   'DelayTime'    , handles.delaytime);
    setappdata(gcf, 'ROI', handles.roi);
    setappdata(gcf, 'GuppyBinning',handles.guppybinning);
end
setappdata(gcf, 'DeviceHandle', handles.currentdevice); 
handles.isdevice=1;
guidata(hObject, handles);

% --- Executes on button press in Refresh.
function Refresh_Callback(hObject, eventdata, handles)
% hObject    handle to Refresh (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
%Begin to searching for the imaging devices'

%refresh the device list
handles.devicelist=SearchDevice();
namelist=handles.devicelist(:,3);

if exist('namelist.mat','file')==2
        out=load('namelist.mat');
        if length(out.namelist)==length(namelist)
            namelist=out.namelist;
        end
end

set(handles.DeviceList,'String',namelist);

guidata(hObject, handles);


% --- Executes on button press in ConfirmFld.
function ConfirmFld_Callback(hObject, eventdata, handles)
% hObject    handle to ConfirmFld (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

foldername=get(handles.FloderEdt,'String');
[x,y,z]=mkdir(foldername);
if x
    set(handles.Floder,'String',foldername);
    handles.folder=foldername;
else
    errordlg('Invalid directory!');
end
guidata(hObject, handles);


% --- Executes on button press in SaveChk.
function SaveChk_Callback(hObject, eventdata, handles)
% hObject    handle to SaveChk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of SaveChk


% --- Executes on button press in Browse.
function Browse_Callback(hObject, eventdata, handles)
% hObject    handle to Browse (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
folder_name = uigetdir;
set(handles.FloderEdt,'String',folder_name);
guidata(hObject, handles);


function FloderEdt_Callback(hObject, eventdata, handles)
% hObject    handle to FloderEdt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of FloderEdt as text
%        str2double(get(hObject,'String')) returns contents of FloderEdt as a double


% --- Executes during object creation, after setting all properties.
function FloderEdt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to FloderEdt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in StartPreview.
function StartPreview_Callback(hObject, eventdata, handles)
% hObject    handle to StartPreview (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
vid=handles.currentdevice;
if handles.isdevice
    src = getselectedsource(vid);
    src.IIDCMode = 'Mode6';
    if get(handles.AutoExp,'Value')
        src.ExposureAuto = 'Continuous';
    else
        GuppySetting;
    end
    src.TriggerMode = 'Off';



    if (handles.currentdevice~=0) && (handles.prv==0)
        vidRes = vid.VideoResolution; 
        nBands = vid.NumberOfBands; 
        %check if the size of marker agree with current size of ROI
        if not(all([vidRes(2),vidRes(1)]==size(handles.currentmark)))
            set(handles.Markinpreview,'Value',0);
        end
        h=figure(); %
        h2=axes('Parent',h); %
        handles.imgprv=image( zeros(vidRes(2), vidRes(1), nBands),'Parent',h2);
        setappdata(handles.imgprv,'Mark',handles.currentmark);
        setappdata(handles.imgprv,'UpdatePreviewWindowFcn',@mypreview_fcn);
        setappdata(handles.imgprv,'vidRes',vidRes);
        setappdata(handles.imgprv,'Markon',get(handles.Markinpreview,'Value'));
        set(handles.imgprv,'CDataMapping','scaled');
        preview(vid,handles.imgprv);
        set(h2,'DataAspectRatioMode','manual','DataAspectRatio',[1 1 1]) ;
    end
    guidata(hObject,handles);
else
    errordlg('No device!')
end
    

function mypreview_fcn(obj,event,himage)
ifmark=getappdata(himage,'Markon');
if ifmark
    marker= (getappdata(himage,'Mark'));
    vidRes=getappdata(himage,'vidRes');
    inversemarker=zeros(vidRes(2),vidRes(1),3,'int16');
    inversemarker(:,:,1)=int16(not(marker(:,:)));
    inversemarker(:,:,2)=int16(not(marker(:,:)));
    inversemarker(:,:,3)=int16(not(marker(:,:)));
    org(:,:,1)=event.Data;
    org(:,:,2)=event.Data;
    org(:,:,3)=event.Data;
    markeddata=org.*inversemarker;
    redmarker=zeros(vidRes(2),vidRes(1),3,'int16');
    redmarker(:,:,1)=marker*255;
    markeddata=markeddata+redmarker;
    set(himage,'CData' ,markeddata);
else
    set(himage,'CData' ,event.Data);
end


function Xmin_Callback(hObject, eventdata, handles)
% hObject    handle to Xmin (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of Xmin as text
%        str2double(get(hObject,'String')) returns contents of Xmin as a double


% --- Executes during object creation, after setting all properties.
function Xmin_CreateFcn(hObject, eventdata, handles)
% hObject    handle to Xmin (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function Xmax_Callback(hObject, eventdata, handles)
% hObject    handle to Xmax (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of Xmax as text
%        str2double(get(hObject,'String')) returns contents of Xmax as a double


% --- Executes during object creation, after setting all properties.
function Xmax_CreateFcn(hObject, eventdata, handles)
% hObject    handle to Xmax (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function Ymin_Callback(hObject, eventdata, handles)
% hObject    handle to Ymin (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of Ymin as text
%        str2double(get(hObject,'String')) returns contents of Ymin as a double


% --- Executes during object creation, after setting all properties.
function Ymin_CreateFcn(hObject, eventdata, handles)
% hObject    handle to Ymin (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function Ymax_Callback(hObject, eventdata, handles)
% hObject    handle to Ymax (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of Ymax as text
%        str2double(get(hObject,'String')) returns contents of Ymax as a double


% --- Executes during object creation, after setting all properties.
function Ymax_CreateFcn(hObject, eventdata, handles)
% hObject    handle to Ymax (see GCBO) 
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in Crop.
function Crop_Callback(hObject, eventdata, handles)
% hObject    handle to Crop (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if get(handles.CropSelect,'Value')
    h=figure;
    d=axes('Parent',h);
    %display the uncroped picture on figure window.
    if get(handles.CMDirect,'Value')
        image(handles.currentimage,'Parent',d,'CDataMapping','direct');
        colormap(d,gray(256));
    end
    if get(handles.CMRescale,'Value')
        image(handles.currentimage,'Parent',d,'CDataMapping','scaled');
        colormap(d,gray(256));
    end
    set(d,'DataAspectRatioMode','manual','DataAspectRatio',[1 1 1]);
    %crop it
    [image_crop,rect]=imcrop(h);
    if ishandle(h)
        close(h);
    end
    handles.currentcrop=image_crop;
    RangeX=size(handles.currentimage,2);
    RangeY=size(handles.currentimage,1);
    X1=max(round(rect(1)),1);
    Y1=max(round(rect(2)),1);
    X2=min(round(rect(3))+X1-1,RangeX);
    Y2=min(round(rect(4))+Y1-1,RangeY);
    set(handles.Xmin,'String',num2str(X1));
    set(handles.Xmax,'String',num2str(X2));
    set(handles.Ymin,'String',num2str(Y1));
    set(handles.Ymax,'String',num2str(Y2));
else
    X1=round(str2num(get(handles.Xmin,'string')));
    X2=round(str2num(get(handles.Xmax,'string')));
    Y1=round(str2num(get(handles.Ymin,'string')));
    Y2=round(str2num(get(handles.Ymax,'string')));
    [RangeY, RangeX]=size(handles.currentimage);
    if (X1<=X2)&&(Y1<=Y2)&&(X1>0)&&(Y1>0)&&(X2<=RangeX)&&(Y2<=RangeY)
        handles.currentcrop=handles.currentimage(Y1:Y2,X1:X2);
    else
        warndlg('Image size not available','Warning');  
        handles.currentcrop=handles.currentimage;
    end
end
guidata(hObject, handles);
updateshow( handles );
if get(handles.SaveROI,'Value')
    vid=handles.currentdevice;
    roi=vid.ROI;
    X0=roi(1);Y0=roi(2);
    roi=[X0+(X1-1)*handles.sfdemag,Y0+(Y1-1)*handles.sfdemag,(X2-X1+1)*handles.sfdemag,(Y2-Y1+1)*handles.sfdemag];
    vid.ROI=roi;
end

guidata(hObject, handles);
setappdata(gcf,   'handles'    , handles);



% --- Executes on button press in Cancelcrop.
function Cancelcrop_Callback(hObject, eventdata, handles)
% hObject    handle to Cancelcrop (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.currentcrop=handles.currentimage;
guidata(hObject,handles);
updateshow( handles );
guidata(hObject,handles);

% --- Executes on key press with focus on ConfirmFld and none of its controls.
function ConfirmFld_KeyPressFcn(hObject, eventdata, handles)
% hObject    handle to ConfirmFld (see GCBO)
% eventdata  structure with the following fields (see UICONTROL)
%	Key: name of the key that was pressed, in lower case
%	Character: character interpretation of the key(s) that was pressed
%	Modifier: name(s) of the modifier key(s) (i.e., control, shift) pressed
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in EndPreview.
function EndPreview_Callback(hObject, eventdata, handles)
% hObject    handle to EndPreview (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
closepreview(handles.currentdevice);
src = getselectedsource(handles.currentdevice);
src.ExposureAuto = 'Off';
guidata(hObject, handles);



function FrameNumber_Callback(hObject, eventdata, handles)
% hObject    handle to FrameNumber (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of FrameNumber as text
%        str2double(get(hObject,'String')) returns contents of FrameNumber as a double
var=round(str2num(get(hObject,'String')));
if ~size(var)
    var=1;
end
var=max(min(var,6),1);
handles.framenum=var;
guidata(hObject,handles);

% --- Executes during object creation, after setting all properties.
function FrameNumber_CreateFcn(hObject, eventdata, handles)
% hObject    handle to FrameNumber (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: delete(hObject) closes the figure
if handles.isdevice
    closepreview(handles.currentdevice);
    src = getselectedsource(handles.currentdevice);
    src.ExposureAuto = 'Off';
    delete(handles.currentdevice);
end
imaqreset;
delete(hObject);


% --- Executes during object creation, after setting all properties.
function figure1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes on button press in Camera_Settings.
function Camera_Settings_Callback(hObject, eventdata, handles)
% hObject    handle to Camera_Settings (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
%closepreview(handles.currentdevice);
vid=handles.currentdevice;
src = getselectedsource(vid);
src.ExposureAuto = 'Off';
if handles.isdevice
    GuppySetting;
else
    errordlg('No device!')
end

guidata(hObject,handles);


% --- Executes on button press in SaveROI.
function SaveROI_Callback(hObject, eventdata, handles)
% hObject    handle to SaveROI (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of SaveROI



function edit9_Callback(hObject, eventdata, handles)
% hObject    handle to edit9 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit9 as text
%        str2double(get(hObject,'String')) returns contents of edit9 as a double
var=round(str2num(get(hObject,'String')));
if ~size(var)
    var=1;
end
var=max(min(var,18),0.5);
handles.sfdemag=var;
guidata(hObject,handles);

% --- Executes during object creation, after setting all properties.
function edit9_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit9 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function Camera_Settings_CreateFcn(hObject, eventdata, handles)
% hObject    handle to Camera_Settings (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes on button press in Mark.
function Mark_Callback(hObject, eventdata, handles)
% hObject    handle to Mark (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
setappdata(gcf,   'CurrentImage'    , handles.currentimage);
setappdata(gcf,   'IfMark'    , 0);
setappdata(gcf,   'Wait'    , 1);
setappdata(gcf,   'Path'    , handles.folder);
a=MarkToolbox();
uiwait(a);
if getappdata(gcf,'IfMark')
    handles.currentmark=getappdata(gcf,'CurrentMark');
    handles.ifmark=1;
end
setappdata(gcf,   'IfMark'    , 0);
guidata(hObject,handles);


% --- Executes on button press in Markinpreview.
function Markinpreview_Callback(hObject, eventdata, handles)
% hObject    handle to Markinpreview (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of Markinpreview


% --- Executes on button press in Markinmain.
function Markinmain_Callback(hObject, eventdata, handles)
% hObject    handle to Markinmain (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of Markinmain


% --- Executes on button press in AutoExp.
function AutoExp_Callback(hObject, eventdata, handles)
% hObject    handle to AutoExp (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of AutoExp


% --- Executes during object deletion, before destroying properties.
function figure1_DeleteFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



function RenameText_Callback(hObject, eventdata, handles)
% hObject    handle to RenameText (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of RenameText as text
%        str2double(get(hObject,'String')) returns contents of RenameText as a double


% --- Executes during object creation, after setting all properties.
function RenameText_CreateFcn(hObject, eventdata, handles)
% hObject    handle to RenameText (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in Rename.
function Rename_Callback(hObject, eventdata, handles)
% hObject    handle to Rename (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
namelist=get(handles.DeviceList,'String');
var=get(handles.DeviceList,'Value');
newname=get(handles.RenameText,'String');
if strcmp(newname,'')
    errordlg('Please enter a name')
else
    namelist{var}=newname;
    set(handles.DeviceList,'String',namelist);
    save('namelist.mat', 'namelist');
end
guidata(hObject,handles);


% --- Executes on button press in Manual.
function Manual_Callback(hObject, eventdata, handles)
% hObject    handle to Manual (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% set the device 
vid = handles.currentdevice;
%Check if the saving folder exist, if not, create the folder
ex=exist(handles.folder,'dir');
if (ex~=7)
    mkdir(handles.folder);
end
%Check if the handle to the camera exist, if so, grab frames
if (vid~=0)
    src = getselectedsource(vid);
    triggerconfig(vid, 'manual');
    vid.TriggerRepeat = 1;
    vid.FramesPerTrigger=1;
    vid.Timeout=1000000;
    src.ExposureAuto = 'Off';
    roi=vid.ROI;
    height=roi(4);
    width=roi(3);
    set(handles.Status,'String','Image taking');
    tempimage=cell(1,1);
    start(vid);
    tempimage{1}=getsnapshot(vid);
    stop(vid);
    set(handles.Status,'String','Stand By');
    % resize the image if indicated
    k=handles.sfdemag;
    if k==1
        imag=zeros(height,width,1,'int16');
        imag(:,:,1)=tempimage{1};
    else
        imag=[];
        imag(:,:,1)=imresize(tempimage{1},1/k);
    end
    handles.lastacquired=imag;
    %save the picture
    if get(handles.SaveChk,'Value')
        time = datestr(now,'yyyy-mm-dd_HH-MM-SS');
        filename=[handles.folder,'\',time,'.fits'];
        fitswrite(handles.lastacquired,filename);
        % assignin('base','imag',handles.lastacquired) %output image to
        % workspace
    end
   % display the image with atom on the main screen
   handles.currentimage=imag(:,:,1);
   handles.currentcrop=updatecrop(handles);
   updateshow(handles);
   %save the picture in roll back.
   if (size(handles.rollback,2)<handles.rollbacksize)
       handles.rollback=[imag,handles.rollback];
       %update roll back list
       str=cell(1,size(handles.rollback,2));
       for i=1:size(handles.rollback,2)
           str{i}=num2str(i);
       end
       set(handles.RollBackList,'String',str);
   else
       handles.rollback=[imag,handles.rollback(1:handles.rollbacksize-1)];
   end
end

guidata(hObject, handles);


% --- Executes on button press in pushbutton19.
function pushbutton19_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton19 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
[FileName,PathName]=uigetfile([handles.folder,'\','*.fits']);
file=[PathName,FileName];
mark=fitsread(file);
handles.currentmark=logical(mark);
guidata(hObject,handles);


% --- Executes during object creation, after setting all properties.
function EndPreview_CreateFcn(hObject, eventdata, handles)
% hObject    handle to EndPreview (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes on button press in RegisterAccess.
function RegisterAccess_Callback(hObject, eventdata, handles)
% hObject    handle to RegisterAccess (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



function CMMin_Callback(hObject, eventdata, handles)
% hObject    handle to CMMin (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of CMMin as text
%        str2double(get(hObject,'String')) returns contents of CMMin as a double


% --- Executes during object creation, after setting all properties.
function CMMin_CreateFcn(hObject, eventdata, handles)
% hObject    handle to CMMin (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function CMMax_Callback(hObject, eventdata, handles)
% hObject    handle to CMMax (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of CMMax as text
%        str2double(get(hObject,'String')) returns contents of CMMax as a double


% --- Executes during object creation, after setting all properties.
function CMMax_CreateFcn(hObject, eventdata, handles)
% hObject    handle to CMMax (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- If Enable == 'on', executes on mouse press in 5 pixel border.
% --- Otherwise, executes on mouse press in 5 pixel border or over AcqOne.
function AcqOne_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to AcqOne (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on key press with focus on AcqOne and none of its controls.
function AcqOne_KeyPressFcn(hObject, eventdata, handles)
% hObject    handle to AcqOne (see GCBO)
% eventdata  structure with the following fields (see MATLAB.UI.CONTROL.UICONTROL)
%	Key: name of the key that was pressed, in lower case
%	Character: character interpretation of the key(s) that was pressed
%	Modifier: name(s) of the modifier key(s) (i.e., control, shift) pressed
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in CMRescale.
function CMRescale_Callback(hObject, eventdata, handles)
% hObject    handle to CMRescale (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of CMRescale
