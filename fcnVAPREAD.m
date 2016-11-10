function [flagRELAX, flagSTEADY, valAREA, valSPAN, valCMAC, valWEIGHT, ...
    seqALPHA, seqBETA, valKINV, valDENSITY, valPANELS, matGEOM, vecSYM, ...
    vecAIRFOIL, vecN, vecM, valVSPANELS, matVSGEOM, valFPANELS, matFGEOM, ...
    valFTURB, valFPWIDTH, valDELTAE, valAZnum, valMAXTIME, valMINTIME, ...
    valINTERF] = fcnVAPREAD(strFILE)

% INPUT:
%   strFILE - file name of input text file in the local directory (or if not, with the appropriate path in the name)
% OUTPUT:
%   flagRELAX - 0 if fixed wake, 1 if relaxed
%   flagSTEADY - 0 if unsteady, 1 if steady

%   valAREA - projected wing area (m^2)
%   valSPAN - tip-to-tip span (m)
%   valCMAC - mean aerodynamic chord
%   valWEIGHT - aircraft weight (N)

%   seqALPHA - sequence of alphas to analyze
%   seqBETA - sequence of betas to analyze
%   valKINV - kinematic viscosity (1.46e-05 as standard)
%   valDENSITY - fluid density, kg/m^3

%   valPANELS - number of wing panels
%   matGEOM - 2 x 5 x valPANELS matrix, with (x,y,z) coords of edge points, and chord and twist at each edge
%   vecSYM - valPANELS x 1 vector of 0, 1, or 2 which denotes the panels with symmetry condition (1 or 2 being local edge number)
%   vecAIRFOIL - valPANELS x 1 vector of airfoil numbers for the panels

%   vecN - valPANELS x 1 vector of spanwise elements per DVE
%   vecM - valPANELS x 1 vector of chordwise elements per DVE

%   valVSPANELS - number of vertical stabilizer panels
%   matVSGEOM - matrix with vertical tail geometry, if used

%   valFPANELS - number of fuselage panels
%   matFGEOM - matrix of fuselage geometry, if used
%   valFTURB - fuselage panel number where turbulence occurs
%   valFPWIDTH - width of fuselage panels

%   valDELTAE - convergence criteria of change in span efficiency between timesteps
%   valDELTIME - size of timestep (m)
%   valMAXTIME - maximum number of timesteps
%   valMINTIME - minimum number of timesteps

%   valINTERF - interference drag value (%)

fp = fopen(strFILE);

%% Reading header flags
% Reading relaxed wake flag
ch = fscanf(fp,'%c',1);
while(ch~='=');
    ch = fscanf(fp,'%c',1);
end
flagRELAX = fscanf(fp,'%d');

% Reading steady or unsteady flag
ch = fscanf(fp,'%c',1);
while(ch~='=');
    ch = fscanf(fp,'%c',1);
end
flagSTEADY = fscanf(fp,'%d');

%% Reading time step information
% Reading maximum number of time steps
ch = fscanf(fp,'%c',1);
while(ch~='=');
    ch = fscanf(fp,'%c',1);
end
valMAXTIME = fscanf(fp,'%d');

% Reading minimum number of time steps
ch = fscanf(fp,'%c',1);
while(ch~='=');
    ch = fscanf(fp,'%c',1);
end
valMINTIME = fscanf(fp,'%d');

% Reading time step width
ch = fscanf(fp,'%c',1);
while(ch~='=');
    ch = fscanf(fp,'%c',1);
end
valDELTIME = fscanf(fp,'%lf');

% Reading deltae
ch = fscanf(fp,'%c',1);
while(ch~='=');
    ch = fscanf(fp,'%c',1);
end
valDELTAE = fscanf(fp,'%lf');

%% Reading flow conditions

% Reading sequence of alphas to analyze
ch = fscanf(fp,'%c',1);
while(ch~='=');
    ch = fscanf(fp,'%c',1);
end
seqALPHA = fscanf(fp,'%lf');

% Reading sequence of sideslip angles to be analyzed
ch = fscanf(fp,'%c',1);
while(ch~='=');
    ch = fscanf(fp,'%c',1);
end
seqBETA = fscanf(fp,'%lf');

% Reading density
ch = fscanf(fp,'%c',1);
while(ch~='=');
    ch = fscanf(fp,'%c',1);
end
valDENSITY = fscanf(fp,'%lf');

% Reading density
ch = fscanf(fp,'%c',1);
while(ch~='=');
    ch = fscanf(fp,'%c',1);
end
valKINV = fscanf(fp,'%lf');
%% Reading Aircraft Reference Values
% Reading wing area
ch = fscanf(fp,'%c',1);
while(ch~='=');
    ch = fscanf(fp,'%c',1);
end
valAREA = fscanf(fp,'%lf');

% Reading wing span
ch = fscanf(fp,'%c',1);
while(ch~='=');
    ch = fscanf(fp,'%c',1);
end
valSPAN = fscanf(fp,'%lf');

% Reading mean aerodynamic chord
ch = fscanf(fp,'%c',1);
while(ch~='=');
    ch = fscanf(fp,'%c',1);
end
valCMAC = fscanf(fp,'%lf');

% Reading aircraft weight
ch = fscanf(fp,'%c',1);
while(ch~='=');
    ch = fscanf(fp,'%c',1);
end
valWEIGHT = fscanf(fp,'%lf');

%% Reading panel/wing/lifting line information
% Reading No. of panels
ch = fscanf(fp,'%c',1);
while(ch~='=');
    ch = fscanf(fp,'%c',1);
end
valPANELS = fscanf(fp,'%lf');

%% Reading panel information and geometry

vecN = zeros(valPANELS,1);
vecM = zeros(valPANELS,1);
vecAIRFOIL = zeros(valPANELS,1);
vecSYM = zeros(valPANELS,1);

for i = 1:valPANELS
    % Reading spanwise 'n'
    ch = fscanf(fp,'%c',1);
    while(ch~='=');
        ch = fscanf(fp,'%c',1);
    end
    vecN(i) = fscanf(fp,'%lf',1);
    
    % Reading chordwise 'm'
    ch = fscanf(fp,'%c',1);
    while(ch~='=');
        ch = fscanf(fp,'%c',1);
    end
    vecM(i) = fscanf(fp,'%lf',1);
    
    % Reading airfoil number
    ch = fscanf(fp,'%c',1);
    while(ch~='=');
        ch = fscanf(fp,'%c',1);
    end
    vecAIRFOIL(i) = fscanf(fp,'%lf',1);
    
    % Reading symmetry information
    ch = fscanf(fp,'%c',1);
    while(ch~='=');
        ch = fscanf(fp,'%c',1);
    end
    vecSYM(i) = fscanf(fp,'%lf',1);
    
    % Skipping geometry column header
    fgets(fp);
    fgets(fp);
    
    % Reading geometry
    % Explanation below:
    %{
        info_geometry(x,y,z)
            x is for the left or right point
                1 left
                2 right
            y is for the values
                1 x
                2 y
                3 z
                4 chord
                5 epsilon
                6 boundary condition
            z is panel number
    %}
    
    matGEOM(1,:,i) = fscanf(fp,'%lf',5);
    matGEOM(2,:,i) = fscanf(fp,'%lf');
    
end

%% Reading vertical tail information
% Reading number of panels
ch = fscanf(fp,'%c',1);
while(ch~='=');
    ch = fscanf(fp,'%c',1);
end
valVSPANELS = fscanf(fp,'%lf',1);

% Skipping vtail geometry column headers
fgets(fp);
fgets(fp);

matVSGEOM = zeros(valVSPANELS,4);

% Reading v-stab geometry
% Explanation below:
%{
    info_vgeometry(x,y)
        x is the panel number
        y is for the values
            1 panel number
            2 panel chord
            3 panel area
            4 panel airfoil
%}

for j = 1:valVSPANELS
    matVSGEOM(j,:) = fscanf(fp,'%lf');
end

%% Reading fuselage information
% Reading number of sections
ch = fscanf(fp,'%c',1);
while(ch~='=');
    ch = fscanf(fp,'%c',1);
end
valFPANELS = fscanf(fp,'%lf',1);

% Reading width of sections
ch = fscanf(fp,'%c',1);
while(ch~='=');
    ch = fscanf(fp,'%c',1);
end
valFPWIDTH = fscanf(fp,'%lf',1);

% Reading turbulence transition point
ch = fscanf(fp,'%c',1);
while(ch~='=');
    ch = fscanf(fp,'%c',1);
end
valFTURB = fscanf(fp,'%lf',1);

% Skipping fuselage geometry column headers (I don't know why I need 3)
fgetl(fp);
fgetl(fp);
% fgets(fp);

matFGEOM = zeros(valFPANELS,2);

for j = 1:valFPANELS
    matFGEOM(j,:) = fscanf(fp,'%lf',2);
    % I have no idea why I need these:
    %     fgetl(fp);
    %     fgetl(fp);
    % Without them, fscanf returns an extra section number which isn't in
    % the text file
end

% Reading intereference drag
ch = fscanf(fp,'%c',1);
while(ch~='=');
    ch = fscanf(fp,'%c',1);
end

valINTERF = fscanf(fp,'%lf',1);

fclose(fp);

clear ans ch i j fp idx1





















