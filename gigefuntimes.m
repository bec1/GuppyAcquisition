v = videoinput('gige', 1, 'Mono12');
s = v.Source;

% Specify total number of frames to be acquired
% One frame is acquired for each external signal pulse.
numFrames = 30;
v.FramesPerTrigger = 1;
v.TriggerRepeat = numFrames - 1;
% Specify 'hardware' videoinput trigger type 
triggerconfig(v, 'hardware', 'DeviceSpecific', 'DeviceSpecific');

% This requires setting the TriggerSelector first; once a TriggerSelector 
% value is selected, setting a trigger property (for example, 
% TriggerMode to 'on') applies only to the specified trigger mode (FrameStart).
s.TriggerSelector = 'FrameStart';
s.TriggerSource = 'Line1';
s.TriggerActivation = 'RisingEdge';
s.TriggerMode = 'on';
% Specify a constant exposure time for each frame
s.ExposureMode = 'Timed';
s.ExposureTimeAbs = 4000;
% Start hardware-triggered buffered continuous acquisition, and wait for 
% acquisition to complete
start(v)
wait(v, 10)
% Transfer acquired frames and timestamps from acquisition input buffer 
% into workspace
[data2, ts2] = getdata(v, v.FramesAvailable);

figure;
imaqmontage(data2)
figure;
plot(ts2, '.')
xlabel('Frame index');
ylabel('Timestamp (s)');