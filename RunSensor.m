% Anser EMT, the worlds first open-source electromagnetic tracking system.
% Copyright (c) 2017, Alex Jaeger, Kilian O'Donoghue
% All rights reserved.
% This code is licensed under the BSD 3-Clause License.

% Run the system for a single sensor.
% Use this script as a starting point for writing applications with the
% tracking system.



% Settings for the tracking system
sensorToTrack = 2;
refreshRate = 100;

% Enable OpenIGTLink connection
igtEnable = 0;
transformName = 'ProbeToTracker';


% Variables for storing sys.positionVectors
sys.positionVector = zeros(1, 5);
igtTranform = zeros(4, 4, 1);


%% Enable OpenIGTLink connection
if(igtEnable == 1)
    slicerConnection = igtlConnect('127.0.0.1', 18944);
    transform.name = transformName;
end

% Initialise the tracking system. Channel 0 is always required.
% Desired channels are passed in a single vector. For only one sensor the
% vector [0, X] is passed, where X is the index of the desired sensor.
sys = fSysSetup(['2'], 'nidaq6212');
pause(3);

%% Main loop.
% This loop is cancelled cleanly using the 3rd party stoploop function.
FS = stoploop();
while (~FS.Stop())
   tic
   
   % Update the tracking system with new sample data from the DAQ.
   % Resolve the position of the chosen sensor denoted by sensorNo
   % Change the initial condition of the solver to the resolved position
   % (this will reduce solving time on each iteration)
   % Print the position vector on the command line. The format of the
   % vector is [x,y,z,theta,phi]
   sys = fSysDAQUpdate(sys);
   sys = fGetSensorPosition(sys, sensorToTrack);
   sys.estimateInit1 = sys.positionVector;
   disp(sys.positionVector);
   
   
   
      
    
   
   % Prepare sys.positionVector for OpenIGTLink transmission
   if(igtEnable == 1)
     
      % Rigid registration matrix.  
      sys.registration = [   0.9996   -0.0169    0.0229   72.3403;...
                      0.0174    0.9996   -0.0220  163.1285;...
                     -0.0225    0.0224    0.9995 -114.8978;...
                      0         0         0    1.0000];     
   
      % Add pi to theta angle. This resolved pointing issues.
      sys.positionVector(4) = sys.positionVector(4) + pi;
      % Convert meters to millimeters. Required for many IGT packages
      sys.positionVector(1:3) = sys.positionVector(1:3) * 1000;
      % Convert from Spherical to Homogenous transformation matrix.
      sys.positionVectorMatrix = fSphericalToMatrix(sys.positionVector); 
      % Applies registration for the IGT coordinate system.      
      transform.matrix = sys.registration * sys.positionVectorMatrix;
      % Generate a timestamp for the data and sent the transform through
      % the OpenIGTLink connection.
      transform.timestamp = igtlTimestampNow();
      igtlSendTransform(slicerConnection, transform);

   end

   toc
   pause(0.001);
   % Clear the screen.
   clc;
end


%% Save and cleanup
FS.Clear(); 
clear FS;
if(igtEnable == 1)
    igtlDisconnect(slicerConnection);
end