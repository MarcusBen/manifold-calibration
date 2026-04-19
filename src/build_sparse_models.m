function models = build_sparse_models(ctx, calIdx, modelCfg)
%BUILD_SPARSE_MODELS Fit sparse-calibration baselines and proposed models.

calIdx = sort(unique(calIdx(:).'));
testIdx = setdiff(1:ctx.numAngles, calIdx);
calAngles = ctx.thetaDeg(calIdx);

phaseTruthFull = unwrap(angle(ctx.AH .* conj(ctx.AI)), [], 2);
phaseCal = phaseTruthFull(:, calIdx);

phaseModel = local_fit_scalar_residual_model(calAngles, phaseCal, modelCfg);
phaseFitFull = local_predict_scalar_residual_model(phaseModel, ctx.thetaDeg);

interpMethod = modelCfg.interpMethod;
if strcmpi(interpMethod, 'spline') && numel(calAngles) < 4
    interpMethod = 'linear';
end
interpModel = local_fit_phase_interpolant(calAngles, phaseCal, interpMethod);
phaseInterpFull = local_apply_phase_interpolant(interpModel, ctx.thetaDeg);

aProposed = local_normalize_columns(exp(1i * phaseFitFull) .* ctx.AI);
aInterp = local_normalize_columns(exp(1i * phaseInterpFull) .* ctx.AI);

v2Cfg = local_complete_v2_config(modelCfg, ctx);
if v2Cfg.enabled
    [phaseModelV2, phaseFitV2Full, v2Diagnostics] = local_fit_v2_lite_model( ...
        ctx, calIdx, calAngles, phaseCal, v2Cfg);
    aProposedV2 = local_normalize_columns(exp(1i * phaseFitV2Full) .* ctx.AI);
else
    phaseModelV2 = struct('enabled', false, 'stage', 'disabled');
    phaseFitV2Full = phaseFitFull;
    aProposedV2 = aProposed;
    v2Diagnostics = struct('enabled', false, ...
        'selectionReason', 'V2 disabled; copied Proposed V1 manifold.');
end

models = struct();
models.calIdx = calIdx;
models.testIdx = testIdx;
models.calAnglesDeg = calAngles;
models.testAnglesDeg = ctx.thetaDeg(testIdx);
models.phaseTruthFull = phaseTruthFull;
models.phaseFitFull = phaseFitFull;
models.phaseInterpFull = phaseInterpFull;
models.phaseModel = phaseModel;
models.interpModel = interpModel;
models.AProposed = aProposed;
models.AInterp = aInterp;
models.phaseFitV1Full = phaseFitFull;
models.phaseFitV2Full = phaseFitV2Full;
models.phaseModelV1 = phaseModel;
models.phaseModelV2 = phaseModelV2;
models.AProposedV1 = aProposed;
models.AProposedV2 = aProposedV2;
models.v2Diagnostics = v2Diagnostics;
end

function model = local_fit_scalar_residual_model(thetaCalDeg, residualCal, modelCfg)
[thetaCalDeg, orderIdx] = sort(thetaCalDeg, 'ascend');
residualCal = residualCal(:, orderIdx);

uCal = sind(thetaCalDeg);
psi = local_build_basis_matrix(uCal, modelCfg.basisType, modelCfg.order);
dMat = local_build_regularization_matrix(modelCfg.order, modelCfg.regularization);

systemMatrix = psi * psi.' + modelCfg.lambda * (dMat.' * dMat);
if rcond(systemMatrix) < 1e-12
    systemMatrix = systemMatrix + 1e-9 * eye(size(systemMatrix));
end

coeff = (residualCal * psi.') / systemMatrix;

model = struct();
model.thetaCalDeg = thetaCalDeg;
model.uCal = uCal;
model.coeff = coeff;
model.basisType = modelCfg.basisType;
model.order = modelCfg.order;
model.lambda = modelCfg.lambda;
model.regularization = modelCfg.regularization;
end

function residualPred = local_predict_scalar_residual_model(model, thetaQueryDeg)
psi = local_build_basis_matrix(sind(thetaQueryDeg), model.basisType, model.order);
residualPred = model.coeff * psi;
end

function v2Cfg = local_complete_v2_config(modelCfg, ctx)
v2Cfg = struct();
if isfield(modelCfg, 'v2') && ~isempty(modelCfg.v2)
    v2Cfg = modelCfg.v2;
end

v2Cfg = local_set_default_field(v2Cfg, 'enabled', true);
v2Cfg = local_set_default_field(v2Cfg, 'label', 'Proposed V2');
v2Cfg = local_set_default_field(v2Cfg, 'stage', 'lite');
v2Cfg = local_set_default_field(v2Cfg, 'segmentCentersDeg', [-50 0 50]);
v2Cfg = local_set_default_field(v2Cfg, 'order', 2);
v2Cfg = local_set_default_field(v2Cfg, 'lambda', 1e-3);
v2Cfg = local_set_default_field(v2Cfg, 'regularization', 'order-weighted');
v2Cfg = local_set_default_field(v2Cfg, 'candidateMismatchWeights', [1 2 4]);
v2Cfg = local_set_default_field(v2Cfg, 'candidateEdgeWeights', [0.5 1 2]);
v2Cfg = local_set_default_field(v2Cfg, 'taskWeight', 0.25);
v2Cfg = local_set_default_field(v2Cfg, 'taskNeighborhoodDeg', 0.4);
v2Cfg = local_set_default_field(v2Cfg, 'pairTaskEnabled', false);
v2Cfg = local_set_default_field(v2Cfg, 'basisType', modelCfg.basisType);

if ~isfield(v2Cfg, 'segmentWidthU') || isempty(v2Cfg.segmentWidthU)
    centersU = sort(sind(v2Cfg.segmentCentersDeg(:).'));
    if numel(centersU) > 1
        v2Cfg.segmentWidthU = max(median(diff(centersU)) * 0.70, 0.15);
    else
        uGrid = sind(ctx.thetaDeg);
        v2Cfg.segmentWidthU = max((max(uGrid) - min(uGrid)) / 3, 0.15);
    end
end
end

function [bestModel, bestPhaseFull, diagnostics] = local_fit_v2_lite_model( ...
    ctx, calIdx, calAngles, phaseCal, v2Cfg)
candidateMismatchWeights = reshape(v2Cfg.candidateMismatchWeights, 1, []);
candidateEdgeWeights = reshape(v2Cfg.candidateEdgeWeights, 1, []);
numCandidates = numel(candidateMismatchWeights) * numel(candidateEdgeWeights);

candidateRecords = repmat(struct( ...
    'alphaMismatch', NaN, ...
    'alphaEdge', NaN, ...
    'calibrationRmseRad', NaN, ...
    'taskLoss', NaN, ...
    'selectionScore', NaN), numCandidates, 1);
models = cell(numCandidates, 1);
phasePredictions = cell(numCandidates, 1);

candidateIdx = 0;
for mismatchIdx = 1:numel(candidateMismatchWeights)
    for edgeIdx = 1:numel(candidateEdgeWeights)
        candidateIdx = candidateIdx + 1;
        candidateCfg = v2Cfg;
        candidateCfg.alphaMismatch = candidateMismatchWeights(mismatchIdx);
        candidateCfg.alphaEdge = candidateEdgeWeights(edgeIdx);

        model = local_fit_piecewise_residual_model(ctx, calIdx, calAngles, phaseCal, candidateCfg);
        phaseFull = local_predict_piecewise_residual_model(model, ctx.thetaDeg);
        phaseCalPred = phaseFull(:, calIdx);
        calibrationRmse = sqrt(mean(local_phase_difference(phaseCalPred, phaseCal) .^ 2, 'all'));

        candidateManifold = local_normalize_columns(exp(1i * phaseFull) .* ctx.AI);
        taskLoss = local_single_source_task_surrogate(ctx, candidateManifold, calIdx, v2Cfg);
        selectionScore = calibrationRmse + v2Cfg.taskWeight * taskLoss;

        candidateRecords(candidateIdx).alphaMismatch = candidateCfg.alphaMismatch;
        candidateRecords(candidateIdx).alphaEdge = candidateCfg.alphaEdge;
        candidateRecords(candidateIdx).calibrationRmseRad = calibrationRmse;
        candidateRecords(candidateIdx).taskLoss = taskLoss;
        candidateRecords(candidateIdx).selectionScore = selectionScore;
        models{candidateIdx} = model;
        phasePredictions{candidateIdx} = phaseFull;
    end
end

[~, bestIdx] = min([candidateRecords.selectionScore]);
bestModel = models{bestIdx};
bestPhaseFull = phasePredictions{bestIdx};

diagnostics = struct();
diagnostics.enabled = true;
diagnostics.stage = v2Cfg.stage;
diagnostics.label = v2Cfg.label;
diagnostics.pairTaskEnabled = v2Cfg.pairTaskEnabled;
diagnostics.candidates = candidateRecords;
diagnostics.selectedCandidateIndex = bestIdx;
diagnostics.selectedAlphaMismatch = candidateRecords(bestIdx).alphaMismatch;
diagnostics.selectedAlphaEdge = candidateRecords(bestIdx).alphaEdge;
diagnostics.selectedCalibrationRmseRad = candidateRecords(bestIdx).calibrationRmseRad;
diagnostics.selectedTaskLoss = candidateRecords(bestIdx).taskLoss;
diagnostics.selectedScore = candidateRecords(bestIdx).selectionScore;
diagnostics.selectionReason = sprintf(['V2-lite selected alphaMismatch=%g and alphaEdge=%g ' ...
    'by calibration phase RMSE plus deterministic single-source MUSIC surrogate.'], ...
    diagnostics.selectedAlphaMismatch, diagnostics.selectedAlphaEdge);
end

function model = local_fit_piecewise_residual_model(ctx, calIdx, thetaCalDeg, phaseCal, v2Cfg)
[thetaCalDeg, orderIdx] = sort(thetaCalDeg, 'ascend');
calIdx = calIdx(orderIdx);
phaseCal = phaseCal(:, orderIdx);
uCal = sind(thetaCalDeg);

mismatchMetrics = compute_manifold_metrics(ctx.AH(:, calIdx), ctx.AI(:, calIdx));
mismatchScore = mismatchMetrics.relativeError(:).';
maxAbsU = max(abs(sind(ctx.thetaDeg)));
if maxAbsU <= 0
    maxAbsU = 1;
end
edgeScore = abs(uCal) / maxAbsU;
sampleWeights = 1 + v2Cfg.alphaMismatch * mismatchScore + v2Cfg.alphaEdge * edgeScore;
sampleWeights = sampleWeights / mean(sampleWeights);

psi = local_build_piecewise_basis_matrix(uCal, v2Cfg);
sqrtWeights = sqrt(sampleWeights);
psiWeighted = psi .* sqrtWeights;
phaseWeighted = phaseCal .* sqrtWeights;
dMat = local_build_piecewise_regularization_matrix(v2Cfg);

systemMatrix = psiWeighted * psiWeighted.' + v2Cfg.lambda * (dMat.' * dMat);
if rcond(systemMatrix) < 1e-12
    systemMatrix = systemMatrix + 1e-9 * eye(size(systemMatrix));
end

model = struct();
model.type = 'v2_lite_piecewise';
model.enabled = true;
model.stage = v2Cfg.stage;
model.thetaCalDeg = thetaCalDeg;
model.uCal = uCal;
model.calIdx = calIdx;
model.coeff = (phaseWeighted * psiWeighted.') / systemMatrix;
model.basisType = v2Cfg.basisType;
model.order = v2Cfg.order;
model.lambda = v2Cfg.lambda;
model.regularization = v2Cfg.regularization;
model.segmentCentersDeg = v2Cfg.segmentCentersDeg;
model.segmentCentersU = sind(v2Cfg.segmentCentersDeg);
model.segmentWidthU = v2Cfg.segmentWidthU;
model.alphaMismatch = v2Cfg.alphaMismatch;
model.alphaEdge = v2Cfg.alphaEdge;
model.sampleWeights = sampleWeights;
model.mismatchScore = mismatchScore;
model.edgeScore = edgeScore;
end

function residualPred = local_predict_piecewise_residual_model(model, thetaQueryDeg)
cfg = struct();
cfg.basisType = model.basisType;
cfg.order = model.order;
cfg.segmentCentersDeg = model.segmentCentersDeg;
cfg.segmentWidthU = model.segmentWidthU;
psi = local_build_piecewise_basis_matrix(sind(thetaQueryDeg), cfg);
residualPred = model.coeff * psi;
end

function psi = local_build_piecewise_basis_matrix(u, v2Cfg)
u = reshape(u, 1, []);
centersU = reshape(sind(v2Cfg.segmentCentersDeg), [], 1);
numSegments = numel(centersU);
order = v2Cfg.order;
widthU = max(v2Cfg.segmentWidthU, eps);

gates = exp(-0.5 * ((u - centersU) / widthU) .^ 2);
gateSum = sum(gates, 1);
gateSum(gateSum < eps) = 1;
gates = gates ./ gateSum;

psi = zeros(numSegments * (order + 1), numel(u));
for segmentIdx = 1:numSegments
    localU = max(min((u - centersU(segmentIdx)) / widthU, 1.5), -1.5);
    localBasis = local_build_basis_matrix(localU, v2Cfg.basisType, order);
    rowRange = (segmentIdx - 1) * (order + 1) + (1:(order + 1));
    psi(rowRange, :) = localBasis .* gates(segmentIdx, :);
end
end

function dMat = local_build_piecewise_regularization_matrix(v2Cfg)
numSegments = numel(v2Cfg.segmentCentersDeg);
baseReg = local_build_regularization_matrix(v2Cfg.order, v2Cfg.regularization);
dMat = kron(eye(numSegments), baseReg);
end

function taskLoss = local_single_source_task_surrogate(ctx, scanManifold, calIdx, v2Cfg)
taskLoss = 0;
numTasks = numel(calIdx);
if numTasks == 0
    return;
end

for taskIdx = 1:numTasks
    targetIdx = calIdx(taskIdx);
    aTrue = ctx.AH(:, targetIdx);
    covariance = aTrue * aTrue';
    spectrum = local_music_spectrum_from_covariance(covariance, scanManifold, 1);

    targetValue = max(spectrum(targetIdx), eps);
    outsideMask = abs(ctx.thetaDeg - ctx.thetaDeg(targetIdx)) > v2Cfg.taskNeighborhoodDeg;
    if any(outsideMask)
        competitorValue = max(spectrum(outsideMask));
    else
        competitorValue = max(spectrum);
    end
    [~, peakIdx] = max(spectrum);
    angleLoss = abs(ctx.thetaDeg(peakIdx) - ctx.thetaDeg(targetIdx)) / ...
        max(max(abs(ctx.thetaDeg)), eps);
    peakLoss = max(0, log(max(competitorValue, eps) / targetValue));
    taskLoss = taskLoss + peakLoss + 0.10 * angleLoss;
end

taskLoss = taskLoss / numTasks;
end

function spectrum = local_music_spectrum_from_covariance(covariance, scanManifold, numSources)
[eigVec, eigVal] = eig(covariance, 'vector');
[~, order] = sort(real(eigVal), 'descend');
eigVec = eigVec(:, order);
noiseSubspace = eigVec(:, numSources+1:end);
projection = noiseSubspace' * scanManifold;
denominator = sum(abs(projection) .^ 2, 1);
denominator(denominator < eps) = eps;
spectrum = real(1 ./ denominator);
end

function phaseDiff = local_phase_difference(estimatePhase, referencePhase)
phaseDiff = angle(exp(1i * (estimatePhase - referencePhase)));
end

function inputStruct = local_set_default_field(inputStruct, fieldName, defaultValue)
if ~isfield(inputStruct, fieldName) || isempty(inputStruct.(fieldName))
    inputStruct.(fieldName) = defaultValue;
end
end

function interpModel = local_fit_phase_interpolant(thetaCalDeg, phaseCal, method)
[thetaCalDeg, orderIdx] = sort(thetaCalDeg, 'ascend');
interpModel = struct();
interpModel.thetaCalDeg = thetaCalDeg;
interpModel.uCal = sind(thetaCalDeg);
interpModel.phaseCal = phaseCal(:, orderIdx);
interpModel.method = method;
end

function phasePred = local_apply_phase_interpolant(interpModel, thetaQueryDeg)
uQuery = sind(thetaQueryDeg);
phasePred = zeros(size(interpModel.phaseCal, 1), numel(thetaQueryDeg));

for rowIdx = 1:size(interpModel.phaseCal, 1)
    phasePred(rowIdx, :) = interp1( ...
        interpModel.uCal, ...
        interpModel.phaseCal(rowIdx, :), ...
        uQuery, ...
        interpModel.method, ...
        'extrap');
end
end

function psi = local_build_basis_matrix(u, basisType, order)
u = reshape(u, 1, []);
psi = zeros(order + 1, numel(u));

switch lower(strtrim(basisType))
    case 'polynomial'
        for powerIdx = 0:order
            psi(powerIdx + 1, :) = u .^ powerIdx;
        end
    case 'chebyshev'
        psi(1, :) = 1;
        if order >= 1
            psi(2, :) = u;
        end
        for orderIdx = 2:order
            psi(orderIdx + 1, :) = 2 * u .* psi(orderIdx, :) - psi(orderIdx - 1, :);
        end
    otherwise
        error('Unsupported basis type: %s', basisType);
end
end

function dMat = local_build_regularization_matrix(order, regularizationType)
switch lower(strtrim(regularizationType))
    case 'identity'
        dMat = eye(order + 1);
        dMat(1, 1) = 0;
    case 'order-weighted'
        dMat = diag([0, 1:order]);
    otherwise
        error('Unsupported regularization type: %s', regularizationType);
end
end

function manifold = local_normalize_columns(manifold)
refPhase = exp(-1i * angle(manifold(1, :)));
manifold = manifold .* refPhase;
colNorm = vecnorm(manifold, 2, 1);
colNorm(colNorm < eps) = 1;
manifold = manifold ./ colNorm;
end
