clc
clear

warning off
tic
% profile -memory on

disp('===========================================================================');
disp('+---------------+');
disp('| RYERSON       |       WinDySIM (Based on FreeWake 2015)');
disp('| APPLIED       |       Running Version 2017.03');
disp('| AERODYNAMICS  |       Includes stall model');
disp('| LABORATORY OF |       No trim solution');
disp('| FLIGHT        |       o                         o');
disp('+---------------+        \                       /');
disp('                          \                     /');
disp('                           \                   /');
disp('                            \       -^-       /');
disp('                             \    _([|])_    /');
disp('                             _\__/ \   / \__/_');
disp('   +X+````````\\\\\\RCAF\\\\\___/\  \ /  /\___/////RCAF//////''''''''+X+');
disp('              /             ||  \ \_(o)_/ /  ||             \');
disp('            +X+     "```````\\__//\__^__/\\__//```````"     +X+');
disp('                              |H|   |H|   |H|');
disp('   ___________________________/______Y______\___________________________');
disp('                            {}+      |      +{}');
disp('                                   {}+{}');
disp('===========================================================================');
disp(' ');

%% Best Practices
% 1. Define wing from one wingtip to another in one direction
% 2. When using symmetry, define from symmetry plane outward

%% Reading in geometry

strFILE = 'inputs/WinDySIM_Gust_AIAA.txt';
strSTRUCT_INPUT = 'inputs/Struct_Input_AIAA.txt';
strOUTPUTFILE = 'AIAA_EA_50c_20171119';
save_interval = 100; % Interval for how often to save time step data

[flagRELAX, flagSTEADY, flagSTIFFWING, flagGUSTMODE, valAREA, valSPAN,...
    valCMAC, valWEIGHT, valCM, seqALPHA, seqBETA, valKINV, valUINF, valGUSTAMP,...
    valGUSTL, valDENSITY, valPANELS, matGEOM, vecSYM, vecAIRFOIL, vecN, vecM,...
    valVSPANELS, matVSGEOM, valFPANELS, matFGEOM, valFTURB, valFPWIDTH, valDELTAE,...
    valDELTIME, valMAXTIME, valMINTIME, valINTERF] = fcnVAPREAD(strFILE);

% Preallocating variables to avoid issues when running only stiff wing case
valSTIFFSTEPS = 0;
matSCLST = [];
vecSPANDIST = [];
matSC = [];
vecMAC = [];
matAEROCNTR = [];

% Read structure input if flexible wing case is selected
if flagSTIFFWING == 2  
    [valSDELTIME, valNSELE, valSTIFFSTEPS, flagSTATIC, vecEIxCOEFF, vecGJtCOEFF, vecEACOEFF, vecCGCOEFF, vecJTCOEFF, vecLMCOEFF] = fcnSTRUCTREAD(strSTRUCT_INPUT);
else % If stiff wing, set number of spanwise elements equal to number of DVEs across span
    valNSELE = sum(vecN,1);
end
 
% [flagRELAX, flagSTEADY, valAREA, valSPAN, valCMAC, valWEIGHT, ...
%     seqALPHA, seqBETA, valKINV, valDENSITY, valPANELS, matGEOM, vecSYM, ...
%     vecAIRFOIL, vecN, vecM, valVSPANELS, matVSGEOM, valFPANELS, matFGEOM, ...
%     valFTURB, valFPWIDTH, valDELTAE, valDELTIME, valMAXTIME, valMINTIME, ...
%     valINTERF] = fcnFWREAD(strFILE);

flagPRINT   = 1;
flagPLOT    = 1;
flagPLOTWAKEVEL = 0;
flagVERBOSE = 0;

save_count = 1; % Initializing counter for incrementing save interval
valGUSTSTART = 20;

%% Discretize geometry into DVEs

[matCENTER0, vecDVEHVSPN, vecDVEHVCRD, vecDVELESWP, vecDVEMCSWP, vecDVETESWP, ...
    vecDVEROLL, vecDVEPITCH, vecDVEYAW, vecDVEAREA, matDVENORM, ...
    matVLST0, matNPVLST0, matNTVLST0, matDVE, valNELE, matADJE, ...
    vecDVESYM, vecDVETIP, vecDVEWING, vecDVELE, vecDVETE, vecDVEPANEL, vecLEDVES] = fcnGENERATEDVES(valPANELS, matGEOM, vecSYM, vecN, vecM);

valWSIZE = length(nonzeros(vecDVETE)); % Amount of wake DVEs shed each timestep

matNPDVE = matDVE;

%% Add boundary conditions to D-Matrix

[matD] = fcnDWING(valNELE, matADJE, vecDVEHVSPN, vecDVESYM, vecDVETIP);

%% Add kinematic conditions to D-Matrix

[vecK] = fcnSINGFCT(valNELE, vecDVEWING, vecDVETIP, vecDVEHVSPN);
[matD] = fcnKINCON(matD, valNELE, matDVE, matCENTER0, matVLST0, matDVENORM, vecK, vecDVEROLL, vecDVEPITCH, vecDVEYAW, vecDVELESWP, vecDVETESWP, vecDVEHVSPN, vecDVEHVCRD,vecSYM);

%% Alpha Loop

% Preallocating for a turbo-boost in performance
vecCL = zeros(valMAXTIME, length(seqALPHA));
vecCDI = zeros(valMAXTIME, length(seqALPHA));
vecE = zeros(valMAXTIME, length(seqALPHA));
vecWRBM = zeros(valMAXTIME,1);

for ai = 1:length(seqALPHA)
    
    valALPHA = deg2rad(seqALPHA(ai));
    
    % This is done for when we are using a parfor loop
    matCENTER = matCENTER0;
    matVLST = matVLST0;
    matNTVLST = matNTVLST0;
    matNPVLST = matNPVLST0;
    
    for bi = 1:length(seqBETA)
        
        fprintf('      ANGLE OF ATTACK = %0.3f DEG\n',seqALPHA(ai));
        fprintf('    ANGLE OF SIDESLIP = %0.3f DEG\n',seqBETA(bi));
        fprintf('\n');
        
        valBETA = deg2rad(seqBETA(bi));
        
        % Determining freestream vector
        vecUINF = fcnUINFWING(valALPHA, valBETA, valUINF);
        
        matUINF = repmat(vecUINF,size(matCENTER,1),1);
        
        % Initializing wake parameters
        matWAKEGEOM = [];
        matNPWAKEGEOM = [];
        vecWDVEHVSPN = [];
        vecWDVEHVCRD = [];
        vecWDVEROLL = [];
        vecWDVEPITCH = [];
        vecWDVEYAW = [];
        vecWDVELESWP = [];
        vecWDVEMCSWP = [];
        vecWDVETESWP = [];
        vecWDVEAREA = [];
        matWDVENORM = [];
        matWVLST = [];
        matWDVE = [];
        valWNELE = 0;
        matWCENTER = [];
        matWCOEFF = [];
        vecWK = [];
        matWADJE = [];
        vecWDVEPANEL = [];
        valLENWADJE = 0;
        vecWKGAM = [];
        vecWDVESYM = [];
        vecWDVETIP = [];
        vecWDVEWING = [];
        
        % Initialize structure and gust parameters
        matDEFGLOB = [];
        matTWISTGLOB = [];
        matDEF = zeros(valSTIFFSTEPS,valNSELE+4);
        matTWIST = zeros(valSTIFFSTEPS,valNSELE+4);
        matCENTER_old = zeros(size(matCENTER,1),size(matCENTER,2));
        matSLOPE = [];
        vecLIFTSTATIC = [];
        vecMOMSTATIC = [];
        valGUSTTIME = 1;
        gust_vel_old = zeros(valNELE,1);
        zvel = zeros(valNELE,1);
        
        % Initialize unsteady aero terms
        gamma_old = [];
        dGammadt = [];
        valDELTIME_old = [];
        
        n = 1;
        
        % Building wing resultant
        [vecR] = fcnRWING(valNELE, 0, matCENTER, matDVENORM, matUINF, valWNELE, matWDVE, ...
            matWVLST, matWCOEFF, vecWK, vecWDVEHVSPN, vecWDVEHVCRD,vecWDVEROLL, vecWDVEPITCH, vecWDVEYAW, vecWDVELESWP, ...
            vecWDVETESWP, vecSYM, valWSIZE);
        
        % Solving for wing coefficients
        [matCOEFF] = fcnSOLVED(matD, vecR, valNELE);
        
        if flagSTIFFWING == 2
            [matEIx, matGJt, vecEA, vecCG, vecJT, vecLM, vecLSM, vecLSAC, matAEROCNTR, matSCLST, vecSPANDIST, matSC, vecMAC] = fcnSTRUCTDIST(vecDVEHVSPN, vecDVELE, vecDVETE, vecEIxCOEFF, vecGJtCOEFF,...
                vecEACOEFF, vecCGCOEFF, vecJTCOEFF, vecLMCOEFF, matNPVLST, matNPDVE, vecDVEPANEL, vecN, vecM, vecDVEWING, vecDVEROLL, vecDVEPITCH, vecDVEYAW);
        end
        
        load('AIAA_EA_50c_20171119.mat');
%         for valTIMESTEP = 1:valMAXTIME

        valMAXTIME = 3000;
            
        while valTIMESTEP < valMAXTIME
                
            valTIMESTEP = valTIMESTEP + 1;
            %% Timestep to solution
            %   Move wing
            %   Generate new wake elements
            %   Create and solve WD-Matrix for new elements
            %   Solve wing D-Matrix with wake-induced velocities
            %   Solve entire WD-Matrix
            %   Relaxation procedure (Relax, create W-Matrix and W-Resultant, solve W-Matrix)
            %   Calculate surface normal forces
            %   Calculate DVE normal forces
            %   Calculate induced drag
            %   Calculate cn, cl, cy, cdi
            %   Calculate viscous effects
            
            %% Moving the wing and structure
            
            % First "valSTIFFSTEPS" timesteps do not deflect the wing
            if valTIMESTEP <= valSTIFFSTEPS || flagSTIFFWING == 1

                [matVLST, matCENTER, matNEWWAKE, matNPNEWWAKE, matNTVLST, matNPVLST, matDEFGLOB, matTWISTGLOB, valUINF, valGUSTTIME, matUINF, flagSTEADY,...
                    gust_vel_old] = fcnSTIFFWING(valALPHA, valBETA, valDELTIME, matVLST, matCENTER, matDVE, vecDVETE, matNTVLST, matNPVLST, vecN,...
                    valTIMESTEP, vecCL, valWEIGHT, valAREA, valDENSITY, valUINF, valGUSTTIME, valGUSTL, valGUSTAMP, flagGUSTMODE, valGUSTSTART,...
                    flagSTEADY, matUINF, gust_vel_old);
                
                % Only update structure position if flex wing case is selected
                if flagSTIFFWING == 2
                
                    [matEIx, matGJt, vecEA, vecCG, vecJT, vecLM, vecLSM, vecLSAC, matAEROCNTR, matSCLST, vecSPANDIST, matSC, vecMAC] = fcnSTRUCTDIST(vecDVEHVSPN, vecDVELE, vecDVETE, vecEIxCOEFF, vecGJtCOEFF,...
                        vecEACOEFF, vecCGCOEFF, vecJTCOEFF, vecLMCOEFF, matNPVLST, matNPDVE, vecDVEPANEL, vecN, vecM, vecDVEWING, vecDVEROLL, vecDVEPITCH, vecDVEYAW);
                    
                end
                              
            % Remaining timesteps compute wing deflection and translate the
            % wing accordingly
            elseif valTIMESTEP == n*valSTIFFSTEPS + 1 || valGUSTTIME > 1

                [valDELTIME, matEIx, matGJt, vecEA, vecCG, vecJT, vecLM, vecLSM, vecLSAC, matAEROCNTR, matSCLST,...
                    vecSPANDIST, matSC, vecMAC, vecDEF, vecTWIST, matDEFGLOB, matTWISTGLOB, matDEF, matTWIST, matSLOPE,...
                    matNPVLST, matNPNEWWAKE, matNEWWAKE, valUINF, vecDVEHVSPN, vecDVEHVCRD, vecDVEROLL, vecDVEPITCH, vecDVEYAW, ...
                    vecDVELESWP, vecDVEMCSWP, vecDVETESWP, vecDVEAREA, matDVENORM, matVLST, matDVE, matCENTER, matUINF, valGUSTTIME, flagSTEADY, gust_vel_old,...
                    zvel, valGUSTSTART, valDELTIME_old] = fcnFLEXWING(vecDVEHVSPN, vecDVELE, vecDVETE, vecEIxCOEFF, vecGJtCOEFF, vecEACOEFF, vecCGCOEFF,...
                    vecJTCOEFF, vecLMCOEFF, matNPVLST, matNPDVE, vecDVEPANEL, vecN, vecM, vecDVEWING, vecDVEROLL, vecDVEPITCH, vecDVEYAW, vecLIFTDIST,...
                    vecMOMDIST, valSPAN, valTIMESTEP, matDEFGLOB, matTWISTGLOB, matSLOPE, valALPHA, valBETA, matVLST, matCENTER, matDVE, vecCL, valWEIGHT,...
                    valAREA, valDENSITY, valUINF, flagSTATIC, valSDELTIME, valDELTIME, valNSELE, matDEF, matTWIST, valSTIFFSTEPS, valGUSTTIME, valGUSTAMP, valGUSTL,...
                    valGUSTSTART, flagGUSTMODE, flagSTEADY, gust_vel_old, matUINF, zvel, valDELTIME_old);
                
                n = n + 1;
                
            else
             
                [matVLST, matCENTER, matNEWWAKE, matNPNEWWAKE, matNTVLST, matNPVLST, matDEFGLOB, matTWISTGLOB, valUINF] = fcnSTIFFWING_STATIC(valALPHA, valBETA,...
                    valDELTIME, matVLST, matCENTER, matDVE, vecDVETE, matNTVLST, matNPVLST, vecN, valTIMESTEP, vecCL, valWEIGHT, valAREA, valDENSITY, valUINF, matNPDVE,...
                    matDEFGLOB, matTWISTGLOB);              
                
            end
            
            % Update structure location after moving wing
            [vecSPNWSECRD, vecSPNWSEAREA, matQTRCRD, vecQTRCRD] = fcnWINGSTRUCTGEOM(vecDVEWING, vecDVELE, vecDVEPANEL, vecM, vecN, vecDVEHVCRD, matDVE, matVLST, vecDVEAREA);
            
            %% Generating new wake elements
            [matWAKEGEOM, matNPWAKEGEOM, vecWDVEHVSPN, vecWDVEHVCRD, vecWDVEROLL, vecWDVEPITCH, vecWDVEYAW, vecWDVELESWP, ...
                vecWDVEMCSWP, vecWDVETESWP, vecWDVEAREA, matWDVENORM, matWVLST, matWDVE, valWNELE, matWCENTER, matWCOEFF, vecWK, matWADJE, matNPVLST, vecWDVEPANEL, valLENWADJE, vecWDVESYM, vecWDVETIP, vecWKGAM, vecWDVEWING] ...
                = fcnCREATEWAKEROW(matNEWWAKE, matNPNEWWAKE, matWAKEGEOM, matNPWAKEGEOM, vecWDVEHVSPN, vecWDVEHVCRD, vecWDVEROLL, vecWDVEPITCH, vecWDVEYAW, vecWDVELESWP, ...
                vecWDVEMCSWP, vecWDVETESWP, vecWDVEAREA, matWDVENORM, matWVLST, matWDVE, valWNELE, matWCENTER, matWCOEFF, vecWK, matCOEFF, vecDVETE, matWADJE, matNPVLST, vecDVEPANEL, ...
                vecWDVEPANEL, vecSYM, valLENWADJE, vecWKGAM, vecWDVESYM, vecWDVETIP, vecK, vecDVEWING, vecWDVEWING, flagSTEADY, valWSIZE);
            
%             if valDELTIME*valTIMESTEP*valUINF >= 1*(valSPAN/2)
%                 wake_chop = valWNELE/valWSIZE - 1;
%             else
                wake_chop = valMAXTIME;
%             end
            % Chop wake elements if wake is larger than specified length
            % (wake_chop)
            if valWNELE/valWSIZE >= (wake_chop+1)
                
                dve_cut = ((valWSIZE)*(wake_chop+1)-valWSIZE+1):valWSIZE*(wake_chop+1);
                
                matWAKEGEOM(1:valWSIZE,:,:) = [];
                matNPWAKEGEOM(1:valWSIZE,:,:) = [];
                vecWDVEHVSPN(1:valWSIZE) = [];
                vecWDVEHVCRD(1:valWSIZE) = [];
                vecWDVEROLL(1:valWSIZE) = [];
                vecWDVEPITCH(1:valWSIZE) = [];
                vecWDVEYAW(1:valWSIZE) = [];
                vecWDVELESWP(1:valWSIZE) = [];
                vecWDVEMCSWP(1:valWSIZE) = [];
                vecWDVETESWP(1:valWSIZE) = [];
                vecWDVEAREA(1:valWSIZE) = [];
                matWDVENORM(1:valWSIZE,:) = [];
                matWVLST(matWDVE(1:valWSIZE,:),:) = [];
                matWDVE(1:valWSIZE,:) = [];
                valWNELE = wake_chop*valWSIZE;
                matWCENTER(1:valWSIZE,:) = [];
                matWCOEFF(1:valWSIZE,:) = [];
                vecWK(1:valWSIZE) = [];
                vecWDVEPANEL(1:valWSIZE) = [];
                vecWDVESYM(1:valWSIZE) = [];
                vecWDVETIP(1:valWSIZE) = [];
                vecWKGAM(1:valWSIZE) = [];
                vecWDVEWING(1:valWSIZE) = [];
                
                [temp1,~,~] = find(matWADJE(:,1) == dve_cut);
                [temp2,~,~] = find(matWADJE(:,3) == dve_cut);
                
                temp3 = unique([temp1; temp2]);
                
                matWADJE(temp3,:) = [];
                
                matWDVE = matWDVE - 4*valWSIZE;
                
                wake_cut = wake_cut + 1;
                
            else
                
                wake_cut = 1;
                
            end
            
            %% Creating and solving WD-Matrix for latest row of wake elements
            % We need to grab from matWADJE only the values we need for this latest row of wake DVEs
            idx = sparse(sum(ismember(matWADJE,[((valWNELE - valWSIZE) + 1):valWNELE]'),2)>0 & (matWADJE(:,2) == 4 | matWADJE(:,2) == 2));
            temp_WADJE = [matWADJE(idx,1) - (valTIMESTEP-wake_cut)*valWSIZE matWADJE(idx,2) matWADJE(idx,3) - (valTIMESTEP-wake_cut)*valWSIZE];
            
            [matWD, vecWR] = fcnWDWAKE([1:valWSIZE]', temp_WADJE, vecWDVEHVSPN(end-valWSIZE+1:end), vecWDVESYM(end-valWSIZE+1:end), vecWDVETIP(end-valWSIZE+1:end), vecWKGAM(end-valWSIZE+1:end));
            [matWCOEFF(end-valWSIZE+1:end,:)] = fcnSOLVEWD(matWD, vecWR, valWSIZE, vecWKGAM(end-valWSIZE+1:end), vecWDVEHVSPN(end-valWSIZE+1:end));
            
            %% Rebuilding and solving wing resultant
            [vecR] = fcnRWING(valNELE, valTIMESTEP, matCENTER, matDVENORM, matUINF, valWNELE, matWDVE, ...
                matWVLST, matWCOEFF, vecWK, vecWDVEHVSPN, vecWDVEHVCRD,vecWDVEROLL, vecWDVEPITCH, vecWDVEYAW, vecWDVELESWP, ...
                vecWDVETESWP, vecSYM, valWSIZE, flagSTEADY);
            
            [matCOEFF] = fcnSOLVED(matD, vecR, valNELE);
            
            %% Creating and solving WD-Matrix
            [matWD, vecWR] = fcnWDWAKE([1:valWNELE]', matWADJE, vecWDVEHVSPN, vecWDVESYM, vecWDVETIP, vecWKGAM);
            [matWCOEFF] = fcnSOLVEWD(matWD, vecWR, valWNELE, vecWKGAM, vecWDVEHVSPN);
            
            %% Relaxing wake
            if valTIMESTEP > 2 && flagRELAX == 1
                
                [vecWDVEHVSPN, vecWDVEHVCRD, vecWDVEROLL, vecWDVEPITCH, vecWDVEYAW,...
                    vecWDVELESWP, vecDVEWMCSWP, vecDVEWTESWP, vecWDVEAREA, matWCENTER, matWDVENORM, ...
                    matWVLST, matWDVE, matWDVEMP, matWDVEMPIND, idxWVLST, vecWK] = fcnRELAXWAKE(vecUINF, matCOEFF, matDVE, matVLST, matWADJE, matWCOEFF, ...
                    matWDVE, matWVLST, valDELTIME, valNELE, valTIMESTEP, valWNELE, valWSIZE, vecDVEHVSPN, vecDVEHVCRD, vecDVELESWP, ...
                    vecDVEPITCH, vecDVEROLL, vecDVETESWP, vecDVEYAW, vecK, vecSYM, vecWDVEHVSPN, vecWDVEHVCRD, vecWDVELESWP, vecWDVEPITCH, ...
                    vecWDVEROLL, vecWDVESYM, vecWDVETESWP, vecWDVETIP, vecWDVEYAW, vecWK, vecWDVEWING);
                
                % Creating and solving WD-Matrix
                [matWD, vecWR] = fcnWDWAKE([1:valWNELE]', matWADJE, vecWDVEHVSPN, vecWDVESYM, vecWDVETIP, vecWKGAM);
                [matWCOEFF] = fcnSOLVEWD(matWD, vecWR, valWNELE, vecWKGAM, vecWDVEHVSPN);
            end
            
            %% Timing
            %             eltime(valTIMESTEP) = toc;
            %             ttime(valTIMESTEP) = sum(eltime);
            
            %% Forces
            
            if wake_cut > 1
                temp = temp + 1;
            else
                temp = 0;
            end
            
            [vecCL(valTIMESTEP,ai), vecCLF(valTIMESTEP,ai),vecCLI(valTIMESTEP,ai),vecCDI(valTIMESTEP,ai), vecE(valTIMESTEP,ai), vecDVENFREE, vecDVENIND, ...
                vecDVELFREE, vecDVELIND, vecDVESFREE, vecDVESIND, vecLIFTDIST, vecMOMDIST, vecCLDIST, gamma_old, dGammadt, vecWRBM] = ...
                fcnFORCES(matCOEFF, vecK, matDVE, valNELE, matCENTER, matVLST, matUINF, vecDVELESWP,...
                vecDVEMCSWP, vecDVEHVSPN, vecDVEHVCRD,vecDVEROLL, vecDVEPITCH, vecDVEYAW, vecDVELE, vecDVETE, matADJE,...
                valWNELE, matWDVE, matWVLST, matWCOEFF, vecWK, vecWDVEHVSPN, vecWDVEHVCRD,vecWDVEROLL, vecWDVEPITCH, vecWDVEYAW, ...
                vecWDVELESWP, vecWDVETESWP, valWSIZE, valTIMESTEP, vecSYM, vecDVETESWP, valAREA, valSPAN, valBETA, ...
                vecDVEWING, vecWDVEWING, vecN, vecM, vecDVEPANEL, vecDVEAREA, vecSPNWSECRD, vecSPNWSEAREA, matQTRCRD, valDENSITY, valWEIGHT,...
                vecLEDVES, vecUINF, matSCLST, vecSPANDIST, matNPVLST, matNPDVE, matSC, vecMAC, valCM, valUINF, matAEROCNTR, flagSTIFFWING, temp,...
                flagSTEADY, gamma_old, dGammadt, valDELTIME, vecWRBM);
            
            if flagPRINT == 1 && valTIMESTEP == 1
                fprintf(' TIMESTEP    CL          CDI      Tip Def. (m)       Twist (deg)\n'); %header
                fprintf('----------------------------------------------------------------\n'); 
            end
            if flagPRINT == 1 && flagSTIFFWING == 2
                fprintf('  %4d     %0.5f     %0.5f         %0.5f          %0.5f\n',valTIMESTEP,vecCL(valTIMESTEP,ai),vecCDI(valTIMESTEP,ai),...
                    matDEFGLOB(valTIMESTEP,end),(180/pi)*matTWISTGLOB(valTIMESTEP,end)); %valTIMESTEP
            else
                fprintf('  %4d     %0.5f     %0.5f\n',valTIMESTEP,vecCL(valTIMESTEP,ai),vecCDI(valTIMESTEP,ai)); %valTIMESTEP               
            end
            
            % Save results every "save_interval" timesteps to output directory
            if valTIMESTEP == save_count*save_interval
                
                save(strcat('outputs/',strOUTPUTFILE,'_Timestep_',num2str(valTIMESTEP),'.mat'));
                
                save_count = save_count + 1;
                
            end
            
%             fprintf('\n\tTimestep = %0.0f', valTIMESTEP);
%             fprintf('\tCL = %0.5f',vecCL(valTIMESTEP,ai));
%             fprintf('\tCDi = %0.5f',vecCDI(valTIMESTEP,ai));

        end
        
        %% Viscous wrapper
        
%         [vecCLv(1,ai), vecCD(1,ai), vecPREQ(1,ai), valVINF(1,ai), valLD(1,ai)] = fcnVISCOUS(vecCL(end,ai), vecCDI(end,ai), ...
%             valWEIGHT, valAREA, valDENSITY, valKINV, vecDVENFREE, vecDVENIND, ...
%             vecDVELFREE, vecDVELIND, vecDVESFREE, vecDVESIND, vecDVEPANEL, vecDVELE, vecDVEWING, vecN, vecM, vecDVEAREA, ...
%             matCENTER, vecDVEHVCRD, vecAIRFOIL, flagVERBOSE, vecSYM, valVSPANELS, matVSGEOM, valFPANELS, matFGEOM, valFTURB, ...
%             valFPWIDTH, valINTERF, vecDVEROLL);
                
    end
end

fprintf('\n');

%% Plotting

if flagPLOT == 1
    [hFig2] = fcnPLOTBODY(flagVERBOSE, valNELE, matDVE, matVLST, matCENTER);
    [hFig2] = fcnPLOTWAKE(flagVERBOSE, hFig2, valWNELE, matWDVE, matWVLST, matWCENTER);
    [hLogo] = fcnPLOTLOGO(0.97,0.03,14,'k','none');
    
    if flagPLOTWAKEVEL == 1
        try
        quiver3(matWDVEMP(:,1),matWDVEMP(:,2),matWDVEMP(:,3),matWDVEMPIND(:,1),matWDVEMPIND(:,2),matWDVEMPIND(:,3));
        end
    end

end

if flagSTIFFWING ~= 1
figure(3)
clf
plot(vecSPANDIST, matDEFGLOB(valTIMESTEP,:));
ylabel('Deflection (m)')
xlabel('Span Location (m)')
hold on
yyaxis right
plot(vecSPANDIST, (180/pi)*matTWISTGLOB(valTIMESTEP,:));
ylabel('Twist (deg)')
hold off

figure(4)
clf
subplot(2,1,1)
plot(valDELTIME*(valGUSTSTART:valTIMESTEP)-valGUSTSTART.*valDELTIME,(180/pi)*matTWISTGLOB(valGUSTSTART:end,end))
ylabel('Tip Twist (deg)')
grid on
box on

subplot(2,1,2)
plot(valDELTIME*(valGUSTSTART:valTIMESTEP)-valGUSTSTART.*valDELTIME,matDEFGLOB(valGUSTSTART:end,end))
xlabel('Time (s)')
ylabel('Tip Deflection (m)')
grid on
box on
  
end

save(strcat(strOUTPUTFILE,'.mat'));

toc
% profreport

%% Viscous wrapper

% whos