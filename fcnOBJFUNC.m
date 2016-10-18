function [out] = fcnOBJFUNC(zp)
% clc
% clear
% zp(1) = 1.5; % Distance along the leading edge from the wingtip where we will cut the wing
% zp(2:21) = [...
%     0.310000 7.450000 0.900000 0.130000 0.5 ...
%     0.320000 7.500000 0.610000 0.080000 1 ...
%     0.520000 7.460000 0.420000 0.130000 0 ...
%     0.560000 7.500000 0.610000 0.090000 0 ...
%     ];

z = [...
    zp(2:6); ... % Forward transition panel lower
    zp(7:11); ... % Forward outward panel lower
    zp(12:16); ... % Rear transition panel upper
    zp(17:21); ... % Rear outward panel upper
    ];

load('Standard Cirrus Input.mat');

% valMAXTIME = 15;
% 
% %% Lopping off the end of the wing, to make room for the winglet
% 
% out_len = (sqrt(sum(abs(matGEOM(2,1:3,2)-matGEOM(1,1:3,2)).^2)));
% out_vec = (matGEOM(2,1:3,2) - matGEOM(1,1:3,2))./out_len; % Unit vector of outboard leading edge
% 
% lop_loc = out_vec*zp(1); % Where we will cut the wing
% 
% tr = matGEOM(2,4,2)/matGEOM(1,4,2);
% matGEOM(2,4,2) = matGEOM(1,4,2)*tr*(1+(zp(1)/out_len)); % Finding the chord at the cut
% 
% matGEOM(2,5,2) = matGEOM(2,5,2)*(1-(zp(1)/out_len)); % Finding the twist angle at the cut
% matGEOM(2,1:3,2) = matGEOM(2,1:3,2) - lop_loc; % Making the cut
% 
% %% Adding on split tips
% 
% valPANELS = 7;
% vecAIRFOIL = [1 1 7 6 6 6 6]';
% vecN = [6 8 3 2 2 4 4]';
% vecM = [1 1 1 1 1 1 1]';
% 
% % Forward tip (upper)
% matGEOM(:,:,4) = [matGEOM(2,:,2); z(1,:)];
% matGEOM(:,:,5) = [z(1,:); z(2,:)];
% 
% % Rear tip (lower)
% matGEOM(:,:,6) = [matGEOM(2,:,2); z(3,:)];
% matGEOM(:,:,7) = [z(3,:); z(4,:)];

%% Running VAP2

[vecCLv, vecCD, vecCDi, vecVINF, vecCLDIST, matXYZDIST, vecAREADIST] = fcnVAP_MAIN(flagRELAX, flagSTEADY, valAREA, valSPAN, valCMAC, valWEIGHT, ...
    seqALPHA, seqBETA, valKINV, valDENSITY, valPANELS, matGEOM, vecSYM, ...
    vecAIRFOIL, vecN, vecM, valVSPANELS, matVSGEOM, valFPANELS, matFGEOM, ...
    valFTURB, valFPWIDTH, valDELTAE, valDELTIME, valMAXTIME, valMINTIME, ...
    valINTERF);

%% Root bending
% At alpha = 5 degrees
% section cl * y location * density * 0.5 * section area * V_inf^2
% Includes tail, which is a constant offset

idx = find(seqALPHA == 5);
root_bending = sum(vecCLDIST(idx,:).*matXYZDIST(:,2,idx)'.*valDENSITY.*vecAREADIST(idx,:).*(vecVINF(idx)^2));

%% High speed drag coefficient
% Drag coefficient at 51 m/s

highspeed_cd = interp1(vecVINF,vecCD,51,'linear','extrap');

%% Cross-country speed

[LDfit, ~] = fcnCREATEFIT(seqALPHA, vecCLv./vecCD);
[CLfit, ~] = fcnCREATEFIT(seqALPHA, vecCLv);
[CDfit, ~] = fcnCREATEFIT(seqALPHA, vecCD);
[Vinffit, ~] = fcnCREATEFIT(seqALPHA, vecVINF);
[Cdifit, ~] = fcnCREATEFIT(seqALPHA, vecCDi);

range_vxc = 1.5:0.25:13.5;
CL = CLfit(range_vxc);
CD = CDfit(range_vxc);
LD = LDfit(range_vxc);
Vcruise = Vinffit(range_vxc);
wglide = Vcruise.*(CD./CL);
[~, LDindex] = max(LD);

Rthermal = 150;
Rrecip = 1/Rthermal;
WSroh = 2*valWEIGHT/(valAREA*valDENSITY);

k = 1;

for wmaxth = 2:3:8
    
    j = 1;
    
    for i = LDindex:size(CL)
        wclimb(j,1) = fcnMAXCLIMB(CL(i), CD(i), Rrecip, wmaxth, WSroh);
        j = j + 1;
    end
    
    [wclimbMAX, indexWC] = max(wclimb);
    
    for i = 1:size(CL)
        V(i,1) = (Vcruise(i)*wclimbMAX)/(wglide(i)+wclimbMAX);
    end
    
    [VxcMAX, cruiseIndex] = max(V);
    invVxcMAX(k,1) = 1/VxcMAX;
    Vxc(k,:) = [wmaxth VxcMAX];
    k = k + 1;
    
end

invVxcMAX_low = invVxcMAX(1,1);
invVxcMAX_med = invVxcMAX(ceil(end/2),1);
invVxcMAX_high = invVxcMAX(end,1);

out = [invVxcMAX_low invVxcMAX_med invVxcMAX_high root_bending highspeed_cd];

%% Writing iteration

fp2 = fopen('optihistory2.txt','at');
fprintf(fp2,'%f %f ', out, zp);
fprintf(fp2,'\r\n');
fclose(fp2);

