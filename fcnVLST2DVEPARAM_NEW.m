function [ vecDVEHVSPN, vecDVEHVCRD, ...
    vecDVEROLL, vecDVEPITCH, vecDVEYAW,...
    vecDVELESWP, vecDVEMCSWP, vecDVETESWP, ...
    vecDVEAREA, matDVENORM, matVLST, matDVE, matCENTER, matNEWWAKE ] = fcnVLST2DVEPARAM_NEW( matNPDVE, matNPVLST, matNEWWAKE, vecDVETE )

%FCNVLST2DVEPARAMS Summary of this function goes here
%   Detailed explanation goes here

P1 = matNPVLST(matNPDVE(:,1),:);
P2 = matNPVLST(matNPDVE(:,2),:);
P3 = matNPVLST(matNPDVE(:,3),:);
P4 = matNPVLST(matNPDVE(:,4),:);

matCENTER = (P1+P2+P3+P4)/4;


[ vecDVEHVSPN, vecDVEHVCRD, ...
    vecDVEROLL, vecDVEPITCH, vecDVEYAW,...
    vecDVELESWP, vecDVEMCSWP, vecDVETESWP, ...
    vecDVEAREA, matDVENORM, ...
    matVLST, matDVE, ~, ~] = fcnDVECORNER2PARAM( matCENTER, P1, P2, P3, P4 );

% New trailing edge vertices
matNEWWAKE(:,:,1) = matVLST(matDVE(vecDVETE>0,4),:);
matNEWWAKE(:,:,2) = matVLST(matDVE(vecDVETE>0,3),:);


end

