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
ardCfg = local_complete_ard_config(modelCfg);
if ardCfg.enabled
    ardModel = local_fit_ard_interpolant(ctx, calIdx, calAngles, interpMethod);
    aARD = local_apply_ard_interpolant(ardModel, ctx);
else
    ardModel = struct('enabled', false, 'method', 'disabled');
    aARD = local_normalize_columns(exp(1i * phaseInterpFull) .* ctx.AI);
end

aProposed = local_normalize_columns(exp(1i * phaseFitFull) .* ctx.AI);
aInterp = local_normalize_columns(exp(1i * phaseInterpFull) .* ctx.AI);

v2Cfg = local_complete_v2_config(modelCfg, ctx);
if v2Cfg.enabled
    [phaseModelV2Init, phaseFitV2InitFull, initDiagnostics] = local_fit_v2_lite_model( ...
        ctx, calIdx, calAngles, phaseCal, v2Cfg);
    aProposedV2Init = local_normalize_columns(exp(1i * phaseFitV2InitFull) .* ctx.AI);
    if strcmpi(v2Cfg.stage, 'full')
        [phaseModelV2, phaseFitV2Full, v2Diagnostics] = local_refine_v2_full_model( ...
            ctx, calIdx, phaseModelV2Init, phaseFitV2InitFull, v2Cfg, initDiagnostics);
    else
        phaseModelV2 = phaseModelV2Init;
        phaseFitV2Full = phaseFitV2InitFull;
        v2Diagnostics = initDiagnostics;
    end
    aProposedV2 = local_normalize_columns(exp(1i * phaseFitV2Full) .* ctx.AI);
else
    phaseModelV2Init = struct('enabled', false, 'stage', 'disabled');
    phaseFitV2InitFull = phaseFitFull;
    aProposedV2Init = aProposed;
    phaseModelV2 = struct('enabled', false, 'stage', 'disabled');
    phaseFitV2Full = phaseFitFull;
    aProposedV2 = aProposed;
    v2Diagnostics = struct('enabled', false, ...
        'selectionReason', 'V2 disabled; copied Proposed V1 manifold.');
end

v3Cfg = local_complete_v3_config(modelCfg, ctx);
if v3Cfg.enabled
    [phaseModelV3, phaseDeltaV3Full, phaseFitV3Full, aProposedV3, v3Diagnostics] = ...
        local_refine_v3_ard_model(ctx, calIdx, aARD, v3Cfg);
else
    phaseModelV3 = struct('enabled', false, 'stage', 'disabled');
    phaseDeltaV3Full = zeros(size(ctx.AH));
    aProposedV3 = aARD;
    phaseFitV3Full = unwrap(angle(aProposedV3 .* conj(ctx.AI)), [], 2);
    v3Diagnostics = struct('enabled', false, ...
        'selectionReason', 'V3 disabled; copied ARD manifold.');
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
models.ardModel = ardModel;
models.AProposed = aProposed;
models.AInterp = aInterp;
models.AARD = aARD;
models.phaseFitV1Full = phaseFitFull;
models.phaseFitV2Full = phaseFitV2Full;
models.phaseFitV2InitFull = phaseFitV2InitFull;
models.phaseFitV3Full = phaseFitV3Full;
models.phaseDeltaV3Full = phaseDeltaV3Full;
models.phaseModelV1 = phaseModel;
models.phaseModelV2 = phaseModelV2;
models.phaseModelV2Init = phaseModelV2Init;
models.phaseModelV3 = phaseModelV3;
models.AProposedV1 = aProposed;
models.AProposedV2 = aProposedV2;
models.AProposedV2Init = aProposedV2Init;
models.AProposedV3 = aProposedV3;
models.v2Diagnostics = v2Diagnostics;
models.v3Diagnostics = v3Diagnostics;
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
v2Cfg = local_set_default_field(v2Cfg, 'stage', 'full');
v2Cfg = local_set_default_field(v2Cfg, 'segmentCentersDeg', [-50 0 50]);
v2Cfg = local_set_default_field(v2Cfg, 'order', 2);
v2Cfg = local_set_default_field(v2Cfg, 'lambda', 1e-3);
v2Cfg = local_set_default_field(v2Cfg, 'regularization', 'order-weighted');
v2Cfg = local_set_default_field(v2Cfg, 'candidateMismatchWeights', [1 2 4]);
v2Cfg = local_set_default_field(v2Cfg, 'candidateEdgeWeights', [0.5 1 2]);
v2Cfg = local_set_default_field(v2Cfg, 'taskWeight', 0.25);
v2Cfg = local_set_default_field(v2Cfg, 'taskNeighborhoodDeg', 0.4);
v2Cfg = local_set_default_field(v2Cfg, 'pairTaskEnabled', true);
v2Cfg = local_set_default_field(v2Cfg, 'taskDataMode', 'heldout_hfss');
v2Cfg = local_set_default_field(v2Cfg, 'taskScanStrideDeg', 1);
v2Cfg = local_set_default_field(v2Cfg, 'taskSingleHeldoutCount', 12);
v2Cfg = local_set_default_field(v2Cfg, 'taskPairSeparationDeg', [4 5 6 8 10]);
v2Cfg = local_set_default_field(v2Cfg, 'taskPairCount', 16);
v2Cfg = local_set_default_field(v2Cfg, 'taskSnrDb', 25);
v2Cfg = local_set_default_field(v2Cfg, 'numSpsaIterations', 18);
v2Cfg = local_set_default_field(v2Cfg, 'learningRate', 0.035);
v2Cfg = local_set_default_field(v2Cfg, 'perturbationScale', 0.025);
v2Cfg = local_set_default_field(v2Cfg, 'lambdaCal', 1);
v2Cfg = local_set_default_field(v2Cfg, 'lambdaSmooth', 1e-3);
v2Cfg = local_set_default_field(v2Cfg, 'lambdaSingle', 0.15);
v2Cfg = local_set_default_field(v2Cfg, 'lambdaPair', 0.20);
v2Cfg = local_set_default_field(v2Cfg, 'lambdaMid', 0.08);
v2Cfg = local_set_default_field(v2Cfg, 'lambdaReg', 1e-4);
v2Cfg = local_set_default_field(v2Cfg, 'softmaxGamma', 8);
v2Cfg = local_set_default_field(v2Cfg, 'midMargin', 0.2);
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

function v3Cfg = local_complete_v3_config(modelCfg, ctx)
v3Cfg = struct();
if isfield(modelCfg, 'v3') && ~isempty(modelCfg.v3)
    v3Cfg = modelCfg.v3;
end

v3Cfg = local_set_default_field(v3Cfg, 'enabled', true);
v3Cfg = local_set_default_field(v3Cfg, 'label', 'Proposed V3.2');
v3Cfg = local_set_default_field(v3Cfg, 'base', 'ard');
v3Cfg = local_set_default_field(v3Cfg, 'stage', 'distribution_matched_stable_pair_refinement');
v3Cfg = local_set_default_field(v3Cfg, 'segmentCentersDeg', [-50 0 50]);
v3Cfg = local_set_default_field(v3Cfg, 'order', 1);
v3Cfg = local_set_default_field(v3Cfg, 'lambda', 1e-3);
v3Cfg = local_set_default_field(v3Cfg, 'regularization', 'order-weighted');
v3Cfg = local_set_default_field(v3Cfg, 'basisType', modelCfg.basisType);
v3Cfg = local_set_default_field(v3Cfg, 'pairTaskEnabled', true);
v3Cfg = local_set_default_field(v3Cfg, 'taskDataMode', 'heldout_hfss');
v3Cfg = local_set_default_field(v3Cfg, 'taskScanStrideDeg', 1);
v3Cfg = local_set_default_field(v3Cfg, 'taskSingleHeldoutCount', 12);
v3Cfg = local_set_default_field(v3Cfg, 'taskPairSeparationDeg', [4 5 6 8 10]);
v3Cfg = local_set_default_field(v3Cfg, 'taskPairCount', 20);
v3Cfg = local_set_default_field(v3Cfg, 'taskSnrDb', 25);
v3Cfg = local_set_default_field(v3Cfg, 'taskPairSelectionMode', 'distribution_matched');
v3Cfg = local_set_default_field(v3Cfg, 'taskPairCenterBinDeg', 10);
v3Cfg = local_set_default_field(v3Cfg, 'guardHeldoutCount', 64);
v3Cfg = local_set_default_field(v3Cfg, 'numSpsaIterations', 8);
v3Cfg = local_set_default_field(v3Cfg, 'learningRate', 0.004);
v3Cfg = local_set_default_field(v3Cfg, 'perturbationScale', 0.004);
v3Cfg = local_set_default_field(v3Cfg, 'maxGradNorm', 5);
v3Cfg = local_set_default_field(v3Cfg, 'lambdaCal', 1);
v3Cfg = local_set_default_field(v3Cfg, 'lambdaSingle', 0.04);
v3Cfg = local_set_default_field(v3Cfg, 'lambdaPair', 0.05);
v3Cfg = local_set_default_field(v3Cfg, 'lambdaMid', 0);
v3Cfg = local_set_default_field(v3Cfg, 'lambdaAnchor', 50);
v3Cfg = local_set_default_field(v3Cfg, 'lambdaGuard', 10);
v3Cfg = local_set_default_field(v3Cfg, 'lambdaCal0', 20);
v3Cfg = local_set_default_field(v3Cfg, 'lambdaSmooth', 1e-3);
v3Cfg = local_set_default_field(v3Cfg, 'lambdaReg', 1e-4);
v3Cfg = local_set_default_field(v3Cfg, 'softmaxGamma', 8);
v3Cfg = local_set_default_field(v3Cfg, 'midMargin', 0.2);
v3Cfg = local_set_default_field(v3Cfg, 'pairObjectiveMode', 'stable_neighborhood');
v3Cfg = local_set_default_field(v3Cfg, 'stableNeighborhoodDeg', 0.6);
v3Cfg = local_set_default_field(v3Cfg, 'stableBackgroundWindowDeg', 4);
v3Cfg = local_set_default_field(v3Cfg, 'stableEndpointFloor', -2.5);
v3Cfg = local_set_default_field(v3Cfg, 'stableMidMargin', 0.15);
v3Cfg = local_set_default_field(v3Cfg, 'stableBackgroundMargin', 0.10);
v3Cfg = local_set_default_field(v3Cfg, 'stableBalanceMargin', 0.15);
v3Cfg = local_set_default_field(v3Cfg, 'stableEtaSub', 1);
v3Cfg = local_set_default_field(v3Cfg, 'stableEtaEnd', 1);
v3Cfg = local_set_default_field(v3Cfg, 'stableEtaMid', 1);
v3Cfg = local_set_default_field(v3Cfg, 'stableEtaBg', 0.5);
v3Cfg = local_set_default_field(v3Cfg, 'stableEtaBalance', 0.5);
v3Cfg = local_set_default_field(v3Cfg, 'trustRadiusRad', 0.04);
v3Cfg = local_set_default_field(v3Cfg, 'calibrationNullSigmaDeg', 0.25);
v3Cfg = local_set_default_field(v3Cfg, 'edgeMaskEnabled', true);
v3Cfg = local_set_default_field(v3Cfg, 'edgeMaskStartDeg', 35);
v3Cfg = local_set_default_field(v3Cfg, 'edgeMaskTransitionDeg', 6);
v3Cfg = local_set_default_field(v3Cfg, 'edgeMaskMinimum', 0.25);
v3Cfg = local_set_default_field(v3Cfg, 'maxCalibrationDrift', 1e-3);
v3Cfg = local_set_default_field(v3Cfg, 'guardRelativeTolerance', 0.003);
v3Cfg = local_set_default_field(v3Cfg, 'maxAnchorRmsDrift', 0.02);

if ~isfield(v3Cfg, 'segmentWidthU') || isempty(v3Cfg.segmentWidthU)
    centersU = sort(sind(v3Cfg.segmentCentersDeg(:).'));
    if numel(centersU) > 1
        v3Cfg.segmentWidthU = max(median(diff(centersU)) * 0.70, 0.15);
    else
        uGrid = sind(ctx.thetaDeg);
        v3Cfg.segmentWidthU = max((max(uGrid) - min(uGrid)) / 3, 0.15);
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

function [fullModel, fullPhaseFull, diagnostics] = local_refine_v2_full_model( ...
    ctx, calIdx, initModel, ~, v2Cfg, initDiagnostics)
tasks = local_build_full_v2_tasks(ctx, calIdx, v2Cfg);
state = local_build_full_v2_objective_state(ctx, initModel, calIdx, tasks, v2Cfg);
x0 = initModel.coeff(:);
initEval = local_evaluate_task_objective(x0, state);

[bestX, bestEval, objectiveHistory] = local_spsa_refine(x0, state, v2Cfg, initEval);
usedInitializer = false;
warningText = '';
if bestEval.total > initEval.total
    bestX = x0;
    bestEval = initEval;
    usedInitializer = true;
    warningText = 'Full V2 refinement did not reduce objective; Stage-I initializer was kept.';
end

fullModel = initModel;
fullModel.type = 'v2_full_task_refined';
fullModel.stage = 'full';
fullModel.coeff = reshape(bestX, size(initModel.coeff));
fullModel.initialCoeff = initModel.coeff;
fullModel.objectiveWeights = local_v2_objective_weights(v2Cfg);
fullModel.taskDataMode = v2Cfg.taskDataMode;
fullModel.pairTaskEnabled = v2Cfg.pairTaskEnabled;
fullModel.numSpsaIterations = v2Cfg.numSpsaIterations;
fullPhaseFull = local_predict_piecewise_residual_model(fullModel, ctx.thetaDeg);

diagnostics = struct();
diagnostics.enabled = true;
diagnostics.stage = 'full';
diagnostics.label = v2Cfg.label;
diagnostics.taskDataMode = v2Cfg.taskDataMode;
diagnostics.pairTaskEnabled = v2Cfg.pairTaskEnabled;
diagnostics.initDiagnostics = initDiagnostics;
diagnostics.initialObjective = initEval.total;
diagnostics.finalObjective = bestEval.total;
diagnostics.initialComponents = initEval.components;
diagnostics.finalComponents = bestEval.components;
diagnostics.objectiveHistory = objectiveHistory;
diagnostics.usedInitializerFallback = usedInitializer;
diagnostics.warning = warningText;
diagnostics.singleTaskAnglesDeg = ctx.thetaDeg(tasks.singleIdx);
diagnostics.heldoutSingleAnglesDeg = ctx.thetaDeg(tasks.heldoutSingleIdx);
diagnostics.taskPairsDeg = tasks.pairAnglesDeg;
diagnostics.taskPairIdx = tasks.pairIdx;
diagnostics.taskScanAnglesDeg = ctx.thetaDeg(tasks.scanIdx);
diagnostics.objectiveWeights = local_v2_objective_weights(v2Cfg);
diagnostics.selectionReason = sprintf(['Full V2 refined Stage-I piecewise coefficients with %d ' ...
    'deterministic SPSA iterations over held-out HFSS single/pair task losses.'], ...
    v2Cfg.numSpsaIterations);
end

function [v3Model, phaseDeltaFull, phaseFitFull, aProposedV3, diagnostics] = ...
    local_refine_v3_ard_model(ctx, calIdx, aARD, v3Cfg)
v3Model = local_build_v3_zero_model(ctx, calIdx, v3Cfg);
tasks = local_build_full_v2_tasks(ctx, calIdx, v3Cfg);
state = local_build_v3_objective_state(ctx, v3Model, calIdx, tasks, v3Cfg, aARD);
x0 = v3Model.coeff(:);
initEval = local_evaluate_task_objective(x0, state);

[bestX, bestEval, objectiveHistory] = local_spsa_refine(x0, state, v3Cfg, initEval);
usedARDFallback = false;
fallbackReason = '';
if bestEval.total > initEval.total
    bestX = x0;
    bestEval = initEval;
    usedARDFallback = true;
    fallbackReason = 'objective_not_reduced';
end

v3Model.coeff = reshape(bestX, size(v3Model.coeff));
v3Model.initialCoeff = zeros(size(v3Model.coeff));
v3Model.objectiveWeights = local_v3_objective_weights(v3Cfg);
v3Model.numSpsaIterations = v3Cfg.numSpsaIterations;
phaseDeltaFull = local_predict_v3_safe_residual_model(v3Model, ctx.thetaDeg);
aProposedV3 = local_normalize_columns(aARD .* exp(1i * phaseDeltaFull));
candidateGuardMetrics = local_v3_guard_metrics(ctx, aProposedV3, aARD, calIdx, tasks.guardIdx, v3Cfg);
if ~usedARDFallback
    [guardPassed, fallbackReason] = local_v3_guard_passed(candidateGuardMetrics, v3Cfg);
    if ~guardPassed
        bestX = x0;
        bestEval = initEval;
        usedARDFallback = true;
        v3Model.coeff = reshape(bestX, size(v3Model.coeff));
        phaseDeltaFull = local_predict_v3_safe_residual_model(v3Model, ctx.thetaDeg);
        aProposedV3 = local_normalize_columns(aARD .* exp(1i * phaseDeltaFull));
    end
end
finalGuardMetrics = local_v3_guard_metrics(ctx, aProposedV3, aARD, calIdx, tasks.guardIdx, v3Cfg);
phaseFitFull = unwrap(angle(aProposedV3 .* conj(ctx.AI)), [], 2);

diagnostics = struct();
diagnostics.enabled = true;
diagnostics.stage = v3Cfg.stage;
diagnostics.label = v3Cfg.label;
diagnostics.base = v3Cfg.base;
diagnostics.taskDataMode = v3Cfg.taskDataMode;
diagnostics.pairTaskEnabled = v3Cfg.pairTaskEnabled;
diagnostics.initialObjective = initEval.total;
diagnostics.finalObjective = bestEval.total;
diagnostics.initialComponents = initEval.components;
diagnostics.finalComponents = bestEval.components;
diagnostics.objectiveHistory = objectiveHistory;
diagnostics.usedARDFallback = usedARDFallback;
diagnostics.fallbackReason = fallbackReason;
diagnostics.warning = local_v3_fallback_warning(usedARDFallback, fallbackReason);
diagnostics.singleTaskAnglesDeg = ctx.thetaDeg(tasks.singleIdx);
diagnostics.heldoutSingleAnglesDeg = ctx.thetaDeg(tasks.heldoutSingleIdx);
diagnostics.taskPairsDeg = tasks.pairAnglesDeg;
diagnostics.taskPairIdx = tasks.pairIdx;
diagnostics.guardAnglesDeg = ctx.thetaDeg(tasks.guardIdx);
diagnostics.taskScanAnglesDeg = ctx.thetaDeg(tasks.scanIdx);
diagnostics.objectiveWeights = local_v3_objective_weights(v3Cfg);
diagnostics.candidateGuardMetrics = candidateGuardMetrics;
diagnostics.guardMetrics = finalGuardMetrics;
diagnostics.trustRadiusRad = v3Cfg.trustRadiusRad;
diagnostics.taskPairSelectionMode = local_optional_v2_field(v3Cfg, 'taskPairSelectionMode', 'top_score');
diagnostics.pairObjectiveMode = local_optional_v2_field(v3Cfg, 'pairObjectiveMode', 'legacy');
diagnostics.pairSelection = tasks.pairSelection;
diagnostics.stablePairDiagnostics = local_stable_pair_diagnostics(aProposedV3, state);
diagnostics.selectionReason = sprintf(['Proposed V3.2 used distribution-matched stable-pair residuals ' ...
    'around ARD with %d deterministic SPSA iterations, anchor %.3g, guard %.3g.'], ...
    v3Cfg.numSpsaIterations, v3Cfg.lambdaAnchor, v3Cfg.lambdaGuard);
end

function model = local_build_v3_zero_model(ctx, calIdx, v3Cfg)
numBasis = numel(v3Cfg.segmentCentersDeg) * (v3Cfg.order + 1);
model = struct();
model.type = 'v3_distribution_matched_stable_pair_refinement';
model.enabled = true;
model.stage = v3Cfg.stage;
model.calIdx = calIdx(:).';
model.calU = sind(ctx.thetaDeg(calIdx));
model.coeff = zeros(ctx.numElements, numBasis);
model.basisType = v3Cfg.basisType;
model.order = v3Cfg.order;
model.lambda = v3Cfg.lambda;
model.regularization = v3Cfg.regularization;
model.segmentCentersDeg = v3Cfg.segmentCentersDeg;
model.segmentCentersU = sind(v3Cfg.segmentCentersDeg);
model.segmentWidthU = v3Cfg.segmentWidthU;
model.trustRadiusRad = v3Cfg.trustRadiusRad;
model.calibrationNullSigmaDeg = v3Cfg.calibrationNullSigmaDeg;
model.edgeMaskEnabled = v3Cfg.edgeMaskEnabled;
model.edgeMaskStartDeg = v3Cfg.edgeMaskStartDeg;
model.edgeMaskTransitionDeg = v3Cfg.edgeMaskTransitionDeg;
model.edgeMaskMinimum = v3Cfg.edgeMaskMinimum;
end

function tasks = local_build_full_v2_tasks(ctx, calIdx, v2Cfg)
calIdx = sort(unique(calIdx(:).'));
candidateIdx = setdiff(1:ctx.numAngles, calIdx);
metrics = compute_manifold_metrics(ctx.AH, ctx.AI);
mismatchScore = metrics.relativeError(:);
mismatchScore = mismatchScore / max(max(mismatchScore), eps);
edgeScore = abs(ctx.thetaDeg(:)) / max(max(abs(ctx.thetaDeg)), eps);
taskScore = 0.65 * mismatchScore + 0.35 * edgeScore;

heldoutCount = min(v2Cfg.taskSingleHeldoutCount, numel(candidateIdx));
[~, heldoutOrder] = sort(taskScore(candidateIdx), 'descend');
heldoutSingleIdx = candidateIdx(heldoutOrder(1:heldoutCount));
singleIdx = sort(unique([calIdx(:); heldoutSingleIdx(:)]));

pairCandidates = local_generate_task_pair_candidates(ctx, v2Cfg.taskPairSeparationDeg, calIdx);
if v2Cfg.pairTaskEnabled && v2Cfg.taskPairCount > 0 && ~isempty(pairCandidates)
    pairScores = local_score_task_pairs(ctx, pairCandidates, taskScore, calIdx);
    [pairIdx, pairSelection] = local_select_task_pairs(ctx, pairCandidates, pairScores, taskScore, v2Cfg);
else
    pairIdx = zeros(0, 2);
    pairSelection = local_empty_pair_selection();
end
pairAnglesDeg = ctx.thetaDeg(pairIdx);
guardIdx = local_select_guard_indices(ctx, calIdx, taskScore, v2Cfg);

scanIdx = local_training_scan_indices(ctx, v2Cfg, singleIdx, pairIdx);

tasks = struct();
tasks.calIdx = calIdx;
tasks.singleIdx = singleIdx(:).';
tasks.heldoutSingleIdx = heldoutSingleIdx(:).';
tasks.pairIdx = pairIdx;
tasks.pairAnglesDeg = pairAnglesDeg;
tasks.pairWeights = pairSelection.pairWeights(:);
tasks.pairSelection = pairSelection;
tasks.guardIdx = guardIdx(:).';
tasks.scanIdx = scanIdx(:).';
tasks.taskScore = taskScore;
tasks.mismatchScore = mismatchScore;
tasks.edgeScore = edgeScore;
end

function [pairIdx, selection] = local_select_task_pairs(ctx, pairCandidates, pairScores, taskScore, v2Cfg)
taskPairCount = min(v2Cfg.taskPairCount, size(pairCandidates, 1));
selectionMode = local_optional_v2_field(v2Cfg, 'taskPairSelectionMode', 'top_score');
if taskPairCount <= 0
    pairIdx = zeros(0, 2);
    selection = local_empty_pair_selection();
    return;
end

if strcmpi(selectionMode, 'distribution_matched')
    [selected, selection] = local_select_distribution_matched_pair_indices( ...
        ctx, pairCandidates, pairScores, v2Cfg, taskPairCount);
    pairIdx = pairCandidates(selected, :);
    return;
end

if ~strcmpi(selectionMode, 'coverage')
    [~, pairOrder] = sort(pairScores, 'descend');
    selected = pairOrder(1:taskPairCount);
    pairIdx = pairCandidates(selected, :);
    selection = local_basic_pair_selection(ctx, pairCandidates, selected, selectionMode, []);
    return;
end

thetaPairs = ctx.thetaDeg(pairCandidates);
pairCenters = mean(thetaPairs, 2);
pairSeparations = round(thetaPairs(:, 2) - thetaPairs(:, 1), 10);
edgeScore = max(abs(thetaPairs), [], 2) / max(max(abs(ctx.thetaDeg)), eps);
centerScore = 1 - abs(pairCenters) / max(max(abs(ctx.thetaDeg)), eps);
pairMismatchScore = mean([taskScore(pairCandidates(:, 1)), taskScore(pairCandidates(:, 2))], 2);

selected = [];
selected = local_append_ranked_pair_indices(selected, pairScores, ceil(0.25 * taskPairCount), taskPairCount);
selected = local_append_ranked_pair_indices(selected, centerScore, ceil(0.25 * taskPairCount), taskPairCount);
selected = local_append_ranked_pair_indices(selected, edgeScore, ceil(0.25 * taskPairCount), taskPairCount);
selected = local_append_separation_coverage(selected, pairSeparations, pairMismatchScore, taskPairCount);

while numel(selected) < taskPairCount
    remaining = setdiff(1:size(pairCandidates, 1), selected, 'stable');
    if isempty(remaining)
        break;
    end
    if isempty(selected)
        [~, localIdx] = max(pairScores(remaining));
    else
        selectedCenters = pairCenters(selected);
        minDistance = zeros(numel(remaining), 1);
        for idx = 1:numel(remaining)
            minDistance(idx) = min(abs(pairCenters(remaining(idx)) - selectedCenters));
        end
        rankScore = minDistance + 1e-3 * pairScores(remaining);
        [~, localIdx] = max(rankScore);
    end
    selected(end+1) = remaining(localIdx); %#ok<AGROW>
end

selected = selected(1:min(taskPairCount, numel(selected)));
pairIdx = pairCandidates(selected, :);
selection = local_basic_pair_selection(ctx, pairCandidates, selected, selectionMode, []);
end

function selection = local_empty_pair_selection()
selection = struct();
selection.mode = 'none';
selection.pairWeights = zeros(0, 1);
selection.stratumKeys = zeros(0, 2);
selection.evalStratumHist = zeros(0, 1);
selection.taskStratumHist = zeros(0, 1);
selection.selectedCandidateIndex = zeros(0, 1);
end

function selection = local_basic_pair_selection(ctx, pairCandidates, selected, modeName, pairWeights)
if nargin < 5 || isempty(pairWeights)
    pairWeights = ones(numel(selected), 1);
end
[stratumKeys, allBinId] = local_pair_strata(ctx.thetaDeg(pairCandidates), 10);
taskBinId = allBinId(selected);
selection = struct();
selection.mode = modeName;
selection.pairWeights = pairWeights(:);
selection.stratumKeys = stratumKeys;
selection.evalStratumHist = accumarray(allBinId, 1, [size(stratumKeys, 1), 1], @sum, 0);
selection.taskStratumHist = accumarray(taskBinId, 1, [size(stratumKeys, 1), 1], @sum, 0);
selection.selectedCandidateIndex = selected(:);
end

function [selected, selection] = local_select_distribution_matched_pair_indices( ...
    ctx, pairCandidates, pairScores, v2Cfg, taskPairCount)
thetaPairs = ctx.thetaDeg(pairCandidates);
centerBinDeg = local_optional_v2_field(v2Cfg, 'taskPairCenterBinDeg', 10);
[stratumKeys, binId] = local_pair_strata(thetaPairs, centerBinDeg);
numBins = size(stratumKeys, 1);
candidateCounts = accumarray(binId, 1, [numBins, 1], @sum, 0);
selected = zeros(0, 1);

separationDeg = round(thetaPairs(:, 2) - thetaPairs(:, 1), 10);
uniqueSep = unique(separationDeg, 'sorted');
sepBinId = zeros(numel(separationDeg), 1);
for sepIdx = 1:numel(uniqueSep)
    sepBinId(abs(separationDeg - uniqueSep(sepIdx)) < 1e-9) = sepIdx;
end
sepCounts = accumarray(sepBinId, 1, [numel(uniqueSep), 1], @sum, 0);
sepTargetCounts = local_allocate_distribution_counts(sepCounts, taskPairCount);

for sepIdx = 1:numel(uniqueSep)
    quota = sepTargetCounts(sepIdx);
    if quota <= 0
        continue;
    end
    sepCandidates = find(sepBinId == sepIdx);
    selected = [selected; local_select_center_covered_candidates( ...
        thetaPairs, pairScores, sepCandidates, quota, centerBinDeg)]; %#ok<AGROW>
end

while numel(selected) < taskPairCount
    remaining = setdiff((1:size(pairCandidates, 1)).', selected, 'stable');
    if isempty(remaining)
        break;
    end
    selectedCounts = accumarray(binId(selected), 1, [numBins, 1], @sum, 0);
    targetProb = candidateCounts / max(sum(candidateCounts), eps);
    selectedProb = selectedCounts / max(numel(selected), 1);
    sepSelectedCounts = accumarray(sepBinId(selected), 1, [numel(uniqueSep), 1], @sum, 0);
    sepTargetProb = sepCounts / max(sum(sepCounts), eps);
    sepSelectedProb = sepSelectedCounts / max(numel(selected), 1);
    underRepresented = targetProb - selectedProb;
    sepUnderRepresented = sepTargetProb - sepSelectedProb;
    fillScore = pairScores(remaining) + 0.05 * underRepresented(binId(remaining)) + ...
        0.10 * sepUnderRepresented(sepBinId(remaining));
    [~, localIdx] = max(fillScore);
    selected(end+1) = remaining(localIdx); %#ok<AGROW>
end
selected = selected(1:min(taskPairCount, numel(selected)));

taskCounts = accumarray(binId(selected), 1, [numBins, 1], @sum, 0);
targetProb = candidateCounts / max(sum(candidateCounts), eps);
taskProb = taskCounts / max(sum(taskCounts), eps);
pairWeights = targetProb(binId(selected)) ./ max(taskProb(binId(selected)), eps);
pairWeights = pairWeights / max(mean(pairWeights), eps);

selection = struct();
selection.mode = 'distribution_matched';
selection.pairWeights = pairWeights(:);
selection.stratumKeys = stratumKeys;
selection.evalStratumHist = candidateCounts;
selection.taskStratumHist = taskCounts;
selection.selectedCandidateIndex = selected(:);
selection.centerBinDeg = centerBinDeg;
end

function selected = local_select_center_covered_candidates(thetaPairs, pairScores, candidateIdx, quota, centerBinDeg)
selected = zeros(0, 1);
if quota <= 0 || isempty(candidateIdx)
    return;
end
pairCenters = mean(thetaPairs(candidateIdx, :), 2);
centerBins = round(pairCenters / max(centerBinDeg, eps));
uniqueCenters = unique(centerBins, 'sorted');
if numel(uniqueCenters) <= quota
    targetCenters = uniqueCenters;
else
    targetPositions = unique(round(linspace(1, numel(uniqueCenters), quota + 2)));
    if numel(targetPositions) > 2
        targetPositions = targetPositions(2:end-1);
    end
    targetCenters = uniqueCenters(targetPositions);
end
for centerIdx = reshape(targetCenters, 1, [])
    if numel(selected) >= quota
        break;
    end
    binCandidates = candidateIdx(centerBins == centerIdx);
    binCandidates = setdiff(binCandidates(:), selected, 'stable');
    if isempty(binCandidates)
        continue;
    end
    [~, localIdx] = max(pairScores(binCandidates));
    selected(end+1, 1) = binCandidates(localIdx); %#ok<AGROW>
end
while numel(selected) < min(quota, numel(candidateIdx))
    remaining = setdiff(candidateIdx(:), selected, 'stable');
    if isempty(remaining)
        break;
    end
    if isempty(selected)
        [~, localIdx] = max(pairScores(remaining));
    else
        selectedCenters = mean(thetaPairs(selected, :), 2);
        remainingCenters = mean(thetaPairs(remaining, :), 2);
        minDistance = zeros(numel(remaining), 1);
        for idx = 1:numel(remaining)
            minDistance(idx) = min(abs(remainingCenters(idx) - selectedCenters));
        end
        rankScore = minDistance + 1e-3 * pairScores(remaining);
        [~, localIdx] = max(rankScore);
    end
    selected(end+1, 1) = remaining(localIdx); %#ok<AGROW>
end
end

function targetCounts = local_allocate_distribution_counts(candidateCounts, totalCount)
candidateCounts = candidateCounts(:);
numBins = numel(candidateCounts);
targetCounts = zeros(numBins, 1);
if totalCount <= 0 || sum(candidateCounts) == 0
    return;
end
rawCounts = totalCount * candidateCounts / sum(candidateCounts);
targetCounts = min(floor(rawCounts), candidateCounts);
while sum(targetCounts) < min(totalCount, sum(candidateCounts))
    remainingCapacity = candidateCounts - targetCounts;
    remainders = rawCounts - targetCounts;
    remainders(remainingCapacity <= 0) = -Inf;
    [~, idx] = max(remainders);
    if ~isfinite(remainders(idx))
        break;
    end
    targetCounts(idx) = targetCounts(idx) + 1;
end
end

function [stratumKeys, binId] = local_pair_strata(thetaPairs, centerBinDeg)
if isempty(thetaPairs)
    stratumKeys = zeros(0, 2);
    binId = zeros(0, 1);
    return;
end
separationDeg = round(thetaPairs(:, 2) - thetaPairs(:, 1), 10);
centerBin = round(mean(thetaPairs, 2) / max(centerBinDeg, eps));
[stratumKeys, ~, binId] = unique([separationDeg(:), centerBin(:)], 'rows');
end

function selected = local_append_ranked_pair_indices(selected, score, quota, taskPairCount)
if quota <= 0 || numel(selected) >= taskPairCount
    return;
end
initialCount = numel(selected);
[~, order] = sort(score, 'descend');
for idx = reshape(order, 1, [])
    if ~ismember(idx, selected)
        selected(end+1) = idx; %#ok<AGROW>
    end
    if numel(selected) >= taskPairCount || numel(selected) - initialCount >= quota
        return;
    end
end
end

function selected = local_append_separation_coverage(selected, pairSeparations, score, taskPairCount)
uniqueSeparations = unique(pairSeparations, 'stable');
for sepIdx = 1:numel(uniqueSeparations)
    if numel(selected) >= taskPairCount
        return;
    end
    candidates = find(pairSeparations == uniqueSeparations(sepIdx));
    candidates = setdiff(candidates, selected, 'stable');
    if isempty(candidates)
        continue;
    end
    [~, localIdx] = max(score(candidates));
    selected(end+1) = candidates(localIdx); %#ok<AGROW>
end
end

function guardIdx = local_select_guard_indices(ctx, calIdx, taskScore, v2Cfg)
candidateIdx = setdiff(1:ctx.numAngles, calIdx);
guardCount = local_optional_v2_field(v2Cfg, 'guardHeldoutCount', 0);
guardCount = min(max(0, round(guardCount)), numel(candidateIdx));
if guardCount == 0
    guardIdx = zeros(1, 0);
    return;
end

hardCount = min(ceil(0.5 * guardCount), guardCount);
[~, hardOrder] = sort(taskScore(candidateIdx), 'descend');
guardIdx = candidateIdx(hardOrder(1:hardCount));

remainingCount = guardCount - numel(guardIdx);
if remainingCount > 0
    uniformPositions = unique(round(linspace(1, numel(candidateIdx), remainingCount * 2)));
    for pos = reshape(uniformPositions, 1, [])
        idx = candidateIdx(pos);
        if ~ismember(idx, guardIdx)
            guardIdx(end+1) = idx; %#ok<AGROW>
        end
        if numel(guardIdx) >= guardCount
            break;
        end
    end
end

if numel(guardIdx) < guardCount
    for idx = reshape(candidateIdx, 1, [])
        if ~ismember(idx, guardIdx)
            guardIdx(end+1) = idx; %#ok<AGROW>
        end
        if numel(guardIdx) >= guardCount
            break;
        end
    end
end

guardIdx = sort(unique(guardIdx), 'ascend');
end

function pairCandidates = local_generate_task_pair_candidates(ctx, separationSweepDeg, calIdx)
thetaGrid = ctx.thetaDeg(:).';
tolDeg = local_angle_tolerance_from_grid(thetaGrid);
pairCandidates = zeros(0, 2);

for sepDeg = reshape(separationSweepDeg, 1, [])
    for leftIdx = 1:numel(thetaGrid)
        [distance, rightIdx] = min(abs(thetaGrid - (thetaGrid(leftIdx) + sepDeg)));
        if distance <= tolDeg && rightIdx > leftIdx
            pairCandidates(end+1, :) = [leftIdx, rightIdx]; %#ok<AGROW>
        end
    end
end

if ~isempty(calIdx) && ~isempty(pairCandidates)
    touchesCal = ismember(pairCandidates(:, 1), calIdx) | ismember(pairCandidates(:, 2), calIdx);
    pairCandidates = pairCandidates(~touchesCal, :);
end
pairCandidates = unique(pairCandidates, 'rows', 'stable');
end

function pairScores = local_score_task_pairs(ctx, pairIdx, taskScore, calIdx)
pairMismatchScore = mean([taskScore(pairIdx(:, 1)), taskScore(pairIdx(:, 2))], 2);
edgeScore = max(abs(ctx.thetaDeg(pairIdx)), [], 2) / max(max(abs(ctx.thetaDeg)), eps);
if isempty(calIdx)
    calDistanceScore = ones(size(pairMismatchScore));
else
    calAngles = ctx.thetaDeg(calIdx);
    calDistance = zeros(size(pairMismatchScore));
    for idx = 1:size(pairIdx, 1)
        leftDistance = min(abs(calAngles(:) - ctx.thetaDeg(pairIdx(idx, 1))));
        rightDistance = min(abs(calAngles(:) - ctx.thetaDeg(pairIdx(idx, 2))));
        calDistance(idx) = min(leftDistance, rightDistance);
    end
    calDistanceScore = min(calDistance / max(max(abs(ctx.thetaDeg)), eps), 1);
end
pairScores = 0.55 * pairMismatchScore + 0.30 * edgeScore + 0.15 * calDistanceScore;
end

function scanIdx = local_training_scan_indices(ctx, v2Cfg, singleIdx, pairIdx)
strideDeg = v2Cfg.taskScanStrideDeg;
if ~isfinite(strideDeg) || strideDeg <= 0
    strideDeg = 1;
end
targetAngles = ctx.thetaDeg(1):strideDeg:ctx.thetaDeg(end);
scanIdx = local_nearest_indices_from_angles(ctx.thetaDeg, targetAngles);
scanIdx = [scanIdx(:); singleIdx(:)]; %#ok<AGROW>
if ~isempty(pairIdx)
    pairMidAngles = mean(ctx.thetaDeg(pairIdx), 2);
    scanIdx = [scanIdx(:); pairIdx(:); local_nearest_indices_from_angles(ctx.thetaDeg, pairMidAngles(:).')]; %#ok<AGROW>
end
scanIdx = unique(scanIdx(:), 'stable');
end

function idx = local_nearest_indices_from_angles(thetaGrid, queryAngles)
idx = zeros(numel(queryAngles), 1);
for queryIdx = 1:numel(queryAngles)
    [~, idx(queryIdx)] = min(abs(thetaGrid - queryAngles(queryIdx)));
end
end

function tolDeg = local_angle_tolerance_from_grid(thetaDeg)
if numel(thetaDeg) > 1
    tolDeg = median(diff(sort(thetaDeg))) / 2 + 1e-9;
else
    tolDeg = 1e-9;
end
end

function state = local_build_full_v2_objective_state(ctx, model, calIdx, tasks, v2Cfg)
state = struct();
state.objectiveType = 'v2_full';
state.ctx = ctx;
state.v2Cfg = v2Cfg;
state.coeffSize = size(model.coeff);
state.psiFull = local_build_piecewise_basis_matrix(sind(ctx.thetaDeg), model);
state.dMat = local_build_piecewise_regularization_matrix(model);
state.calIdx = calIdx(:).';
if isfield(model, 'sampleWeights') && numel(model.sampleWeights) == numel(calIdx)
    state.calWeights = model.sampleWeights(:).';
else
    state.calWeights = ones(1, numel(calIdx));
end
state.tasks = tasks;
state.singleTasks = local_precompute_single_tasks(ctx, tasks.singleIdx, tasks.scanIdx, v2Cfg);
state.pairTasks = local_precompute_pair_tasks(ctx, tasks.pairIdx, tasks.scanIdx, v2Cfg);
end

function state = local_build_v3_objective_state(ctx, model, calIdx, tasks, v3Cfg, baseManifold)
state = struct();
state.objectiveType = 'v3_ard_anchor';
state.ctx = ctx;
state.v2Cfg = v3Cfg;
state.v3Cfg = v3Cfg;
state.baseManifold = baseManifold;
state.coeffSize = size(model.coeff);
state.psiFull = local_build_piecewise_basis_matrix(sind(ctx.thetaDeg), model);
state.dMat = local_build_piecewise_regularization_matrix(model);
state.calIdx = calIdx(:).';
state.calWeights = ones(1, numel(calIdx));
state.tasks = tasks;
state.guardIdx = tasks.guardIdx(:).';
state.singleTasks = local_precompute_single_tasks(ctx, tasks.singleIdx, tasks.scanIdx, v3Cfg);
state.pairTasks = local_precompute_pair_tasks(ctx, tasks.pairIdx, tasks.scanIdx, v3Cfg, tasks.pairWeights);
end

function taskList = local_precompute_single_tasks(ctx, singleIdx, scanIdx, v2Cfg)
taskList = repmat(struct('targetIdx', [], 'targetScanPos', [], 'projector', []), numel(singleIdx), 1);
for idx = 1:numel(singleIdx)
    targetIdx = singleIdx(idx);
    taskList(idx).targetIdx = targetIdx;
    taskList(idx).targetScanPos = find(scanIdx == targetIdx, 1, 'first');
    taskList(idx).projector = local_noise_projector(ctx.AH(:, targetIdx), 1, v2Cfg.taskSnrDb);
end
end

function taskList = local_precompute_pair_tasks(ctx, pairIdx, scanIdx, v2Cfg, pairWeights)
if nargin < 5 || isempty(pairWeights)
    pairWeights = ones(size(pairIdx, 1), 1);
end
taskList = repmat(struct('pairIdx', [], 'targetScanPos', [], 'midScanPos', [], ...
    'leftNeighborhoodPos', [], 'rightNeighborhoodPos', [], 'midNeighborhoodPos', [], ...
    'backgroundScanPos', [], 'projector', [], 'weight', 1), size(pairIdx, 1), 1);
scanAngles = ctx.thetaDeg(scanIdx);
stableNeighborhoodDeg = local_optional_v2_field(v2Cfg, 'stableNeighborhoodDeg', 0.6);
for idx = 1:size(pairIdx, 1)
    targetIdx = pairIdx(idx, :);
    midIdx = local_nearest_indices_from_angles(ctx.thetaDeg, mean(ctx.thetaDeg(targetIdx)));
    targetAngles = ctx.thetaDeg(targetIdx);
    midAngle = mean(targetAngles);
    taskList(idx).pairIdx = targetIdx;
    taskList(idx).targetScanPos = [find(scanIdx == targetIdx(1), 1, 'first'), ...
        find(scanIdx == targetIdx(2), 1, 'first')];
    taskList(idx).midScanPos = find(scanIdx == midIdx, 1, 'first');
    taskList(idx).leftNeighborhoodPos = local_scan_neighborhood_positions( ...
        scanAngles, targetAngles(1), stableNeighborhoodDeg, taskList(idx).targetScanPos(1));
    taskList(idx).rightNeighborhoodPos = local_scan_neighborhood_positions( ...
        scanAngles, targetAngles(2), stableNeighborhoodDeg, taskList(idx).targetScanPos(2));
    taskList(idx).midNeighborhoodPos = local_scan_neighborhood_positions( ...
        scanAngles, midAngle, stableNeighborhoodDeg, taskList(idx).midScanPos);
    taskList(idx).backgroundScanPos = local_stable_background_positions(scanAngles, targetAngles, ...
        taskList(idx), v2Cfg);
    taskList(idx).projector = local_noise_projector(ctx.AH(:, targetIdx), 2, v2Cfg.taskSnrDb);
    taskList(idx).weight = pairWeights(idx);
end
end

function positions = local_scan_neighborhood_positions(scanAngles, centerAngle, radiusDeg, fallbackPos)
positions = find(abs(scanAngles(:) - centerAngle) <= radiusDeg);
if isempty(positions)
    positions = fallbackPos;
end
positions = positions(:).';
end

function positions = local_stable_background_positions(scanAngles, targetAngles, task, v2Cfg)
windowDeg = local_optional_v2_field(v2Cfg, 'stableBackgroundWindowDeg', 4);
lowAngle = min(targetAngles) - windowDeg;
highAngle = max(targetAngles) + windowDeg;
inWindow = scanAngles(:) >= lowAngle & scanAngles(:) <= highAngle;
excluded = false(numel(scanAngles), 1);
excluded(task.leftNeighborhoodPos) = true;
excluded(task.rightNeighborhoodPos) = true;
excluded(task.midNeighborhoodPos) = true;
positions = find(inWindow & ~excluded);
if isempty(positions)
    excluded = false(numel(scanAngles), 1);
    excluded(task.targetScanPos) = true;
    excluded(task.midScanPos) = true;
    positions = find(~excluded);
end
if isempty(positions)
    positions = task.midScanPos;
end
positions = positions(:).';
end

function projector = local_noise_projector(signalManifold, numSources, snrDb)
signalCov = signalManifold * signalManifold';
signalPower = trace(signalCov) / size(signalManifold, 1);
noisePower = signalPower / (10 ^ (snrDb / 10));
covariance = signalCov + noisePower * eye(size(signalManifold, 1));
[eigVec, eigVal] = eig(covariance, 'vector');
[~, order] = sort(real(eigVal), 'descend');
eigVec = eigVec(:, order);
noiseSubspace = eigVec(:, numSources+1:end);
projector = noiseSubspace * noiseSubspace';
end

function [bestX, bestEval, history] = local_spsa_refine(x0, state, v2Cfg, initEval)
numIterations = max(0, round(v2Cfg.numSpsaIterations));
history = repmat(struct('iteration', 0, 'objective', NaN, 'accepted', false), numIterations + 1, 1);
history(1).iteration = 0;
history(1).objective = initEval.total;
history(1).accepted = true;

currentX = x0;
currentEval = initEval;
bestX = x0;
bestEval = initEval;
m = zeros(size(x0));
v = zeros(size(x0));
beta1 = 0.9;
beta2 = 0.999;
maxGradNorm = local_optional_v2_field(v2Cfg, 'maxGradNorm', 10);

for iter = 1:numIterations
    c = v2Cfg.perturbationScale / (iter ^ 0.101);
    delta = local_spsa_delta(numel(x0), iter);
    plusEval = local_evaluate_task_objective(currentX + c * delta, state);
    minusEval = local_evaluate_task_objective(currentX - c * delta, state);
    grad = ((plusEval.total - minusEval.total) / (2 * c)) * delta;
    gradNorm = norm(grad);
    if gradNorm > maxGradNorm
        grad = grad * (maxGradNorm / gradNorm);
    end

    m = beta1 * m + (1 - beta1) * grad;
    v = beta2 * v + (1 - beta2) * (grad .^ 2);
    mHat = m / (1 - beta1 ^ iter);
    vHat = v / (1 - beta2 ^ iter);
    step = (v2Cfg.learningRate / (iter ^ 0.602)) * mHat ./ (sqrt(vHat) + 1e-8);

    candidateX = currentX - step;
    candidateEval = local_evaluate_task_objective(candidateX, state);
    accepted = candidateEval.total <= currentEval.total;
    if ~accepted
        candidateX = currentX - 0.5 * step;
        candidateEval = local_evaluate_task_objective(candidateX, state);
        accepted = candidateEval.total <= currentEval.total;
    end

    if accepted
        currentX = candidateX;
        currentEval = candidateEval;
        if currentEval.total < bestEval.total
            bestX = currentX;
            bestEval = currentEval;
        end
    end

    history(iter + 1).iteration = iter;
    history(iter + 1).objective = currentEval.total;
    history(iter + 1).accepted = accepted;
end
end

function result = local_evaluate_task_objective(x, state)
if isfield(state, 'objectiveType') && strcmpi(state.objectiveType, 'v3_ard_anchor')
    result = local_full_v3_objective(x, state);
else
    result = local_full_v2_objective(x, state);
end
end

function delta = local_spsa_delta(numParams, iteration)
pattern = mod((1:numParams).' * (2 * iteration + 1) + iteration, 4);
delta = ones(numParams, 1);
delta(pattern < 2) = -1;
end

function phaseDeltaFull = local_v3_safe_residual_from_coeff(coeff, state)
rawResidual = coeff * state.psiFull;
phaseDeltaFull = local_apply_v3_residual_guards( ...
    rawResidual, state.ctx.thetaDeg, state.v3Cfg, sind(state.ctx.thetaDeg(state.calIdx)));
end

function phaseDeltaFull = local_predict_v3_safe_residual_model(model, thetaQueryDeg)
rawResidual = local_predict_piecewise_residual_model(model, thetaQueryDeg);
phaseDeltaFull = local_apply_v3_residual_guards(rawResidual, thetaQueryDeg, model, model.calU);
end

function phaseDelta = local_apply_v3_residual_guards(rawResidual, thetaDeg, cfg, calU)
thetaDeg = reshape(thetaDeg, 1, []);
uQuery = sind(thetaDeg);

if isempty(calU)
    calibrationGate = ones(1, numel(thetaDeg));
else
    sigmaU = max(abs(sind(local_optional_v2_field(cfg, 'calibrationNullSigmaDeg', 0.25))), eps);
    distanceU = uQuery - reshape(calU, [], 1);
    calibrationGate = prod(1 - exp(-0.5 * (distanceU / sigmaU) .^ 2), 1);
end

if local_optional_v2_field(cfg, 'edgeMaskEnabled', false)
    startDeg = local_optional_v2_field(cfg, 'edgeMaskStartDeg', 35);
    transitionDeg = max(local_optional_v2_field(cfg, 'edgeMaskTransitionDeg', 6), eps);
    minMask = min(max(local_optional_v2_field(cfg, 'edgeMaskMinimum', 0.25), 0), 1);
    edgeGate = 1 ./ (1 + exp(-(abs(thetaDeg) - startDeg) / transitionDeg));
    edgeGate = minMask + (1 - minMask) * edgeGate;
else
    edgeGate = ones(1, numel(thetaDeg));
end

phaseDelta = rawResidual .* (calibrationGate .* edgeGate);
trustRadius = local_optional_v2_field(cfg, 'trustRadiusRad', Inf);
if isfinite(trustRadius) && trustRadius > 0
    phaseDelta = trustRadius * tanh(phaseDelta / trustRadius);
end
end

function result = local_full_v3_objective(x, state)
coeff = reshape(x, state.coeffSize);
phaseDeltaFull = local_v3_safe_residual_from_coeff(coeff, state);
manifold = local_normalize_columns(state.baseManifold .* exp(1i * phaseDeltaFull));

components = struct();
components.cal = local_complex_calibration_loss(state.ctx, manifold, state.calIdx, state.calWeights);
components.cal0 = local_v3_calibration_anchor_loss(manifold, state.baseManifold, state.calIdx);
components.smooth = mean(abs(coeff * state.dMat') .^ 2, 'all');
components.reg = mean(abs(coeff(:)) .^ 2);
components.anchor = mean(sum(abs(manifold - state.baseManifold) .^ 2, 1));
components.guard = local_v3_guard_loss(state.ctx, manifold, state.guardIdx);
[components.single, components.singleSub, components.singlePeak] = ...
    local_single_task_loss(manifold, state);
[components.pair, components.pairSub, components.pairPeak, components.mid] = ...
    local_pair_task_loss(manifold, state);

weights = local_v3_objective_weights(state.v3Cfg);
total = weights.lambdaCal * components.cal + ...
    weights.lambdaSmooth * components.smooth + ...
    weights.lambdaSingle * components.single + ...
    weights.lambdaPair * components.pair + ...
    weights.lambdaMid * components.mid + ...
    weights.lambdaAnchor * components.anchor + ...
    weights.lambdaGuard * components.guard + ...
    weights.lambdaCal0 * components.cal0 + ...
    weights.lambdaReg * components.reg;

result = struct();
result.total = real(total);
result.components = components;
end

function result = local_full_v2_objective(x, state)
coeff = reshape(x, state.coeffSize);
phaseFull = coeff * state.psiFull;
manifold = local_normalize_columns(exp(1i * phaseFull) .* state.ctx.AI);

components = struct();
components.cal = local_complex_calibration_loss(state.ctx, manifold, state.calIdx, state.calWeights);
components.smooth = mean(abs(coeff * state.dMat') .^ 2, 'all');
components.reg = mean(abs(coeff(:)) .^ 2);
[components.single, components.singleSub, components.singlePeak] = ...
    local_single_task_loss(manifold, state);
[components.pair, components.pairSub, components.pairPeak, components.mid] = ...
    local_pair_task_loss(manifold, state);

weights = local_v2_objective_weights(state.v2Cfg);
total = weights.lambdaCal * components.cal + ...
    weights.lambdaSmooth * components.smooth + ...
    weights.lambdaSingle * components.single + ...
    weights.lambdaPair * components.pair + ...
    weights.lambdaMid * components.mid + ...
    weights.lambdaReg * components.reg;

result = struct();
result.total = real(total);
result.components = components;
end

function loss = local_complex_calibration_loss(ctx, manifold, calIdx, calWeights)
diffCal = manifold(:, calIdx) - ctx.AH(:, calIdx);
perCal = sum(abs(diffCal) .^ 2, 1);
loss = sum(calWeights .* perCal) / max(sum(calWeights), eps);
end

function loss = local_v3_calibration_anchor_loss(manifold, baseManifold, calIdx)
if isempty(calIdx)
    loss = 0;
    return;
end
diffCal = manifold(:, calIdx) - baseManifold(:, calIdx);
loss = mean(sum(abs(diffCal) .^ 2, 1));
end

function loss = local_v3_guard_loss(ctx, manifold, guardIdx)
if isempty(guardIdx)
    loss = 0;
    return;
end
diffGuard = manifold(:, guardIdx) - ctx.AH(:, guardIdx);
loss = mean(sum(abs(diffGuard) .^ 2, 1));
end

function [loss, subLoss, peakLoss] = local_single_task_loss(manifold, state)
if isempty(state.singleTasks)
    loss = 0;
    subLoss = 0;
    peakLoss = 0;
    return;
end

scanManifold = manifold(:, state.tasks.scanIdx);
subValues = zeros(numel(state.singleTasks), 1);
peakValues = zeros(numel(state.singleTasks), 1);
for taskIdx = 1:numel(state.singleTasks)
    task = state.singleTasks(taskIdx);
    targetVector = manifold(:, task.targetIdx);
    subValues(taskIdx) = real(targetVector' * task.projector * targetVector);
    z = local_task_logits(task.projector, scanManifold, state.v2Cfg.softmaxGamma);
    peakValues(taskIdx) = -z(task.targetScanPos) + local_logsumexp(z);
end
subLoss = mean(subValues);
peakLoss = mean(peakValues);
loss = subLoss + peakLoss;
end

function [loss, subLoss, peakLoss, midLoss] = local_pair_task_loss(manifold, state)
if isempty(state.pairTasks)
    loss = 0;
    subLoss = 0;
    peakLoss = 0;
    midLoss = 0;
    return;
end

if strcmpi(local_optional_v2_field(state.v2Cfg, 'pairObjectiveMode', 'legacy'), 'stable_neighborhood')
    [loss, subLoss, peakLoss, midLoss] = local_stable_pair_task_loss(manifold, state);
    return;
end

scanManifold = manifold(:, state.tasks.scanIdx);
subValues = zeros(numel(state.pairTasks), 1);
peakValues = zeros(numel(state.pairTasks), 1);
midValues = zeros(numel(state.pairTasks), 1);
for taskIdx = 1:numel(state.pairTasks)
    task = state.pairTasks(taskIdx);
    leftVector = manifold(:, task.pairIdx(1));
    rightVector = manifold(:, task.pairIdx(2));
    subValues(taskIdx) = real(leftVector' * task.projector * leftVector) + ...
        real(rightVector' * task.projector * rightVector);
    z = local_task_logits(task.projector, scanManifold, state.v2Cfg.softmaxGamma);
    targetZ = z(task.targetScanPos);
    peakValues(taskIdx) = -sum(targetZ) + 2 * local_logsumexp(z);
    midValues(taskIdx) = max(0, z(task.midScanPos) - mean(targetZ) + state.v2Cfg.midMargin) ^ 2;
end
subLoss = mean(subValues);
peakLoss = mean(peakValues);
midLoss = mean(midValues);
loss = subLoss + peakLoss;
end

function [loss, subLoss, peakLoss, midLoss] = local_stable_pair_task_loss(manifold, state)
scanManifold = manifold(:, state.tasks.scanIdx);
subValues = zeros(numel(state.pairTasks), 1);
endValues = zeros(numel(state.pairTasks), 1);
midValues = zeros(numel(state.pairTasks), 1);
bgValues = zeros(numel(state.pairTasks), 1);
balanceValues = zeros(numel(state.pairTasks), 1);
pairWeights = zeros(numel(state.pairTasks), 1);

for taskIdx = 1:numel(state.pairTasks)
    task = state.pairTasks(taskIdx);
    leftVector = manifold(:, task.pairIdx(1));
    rightVector = manifold(:, task.pairIdx(2));
    subValues(taskIdx) = real(leftVector' * task.projector * leftVector) + ...
        real(rightVector' * task.projector * rightVector);

    z = local_task_logits(task.projector, scanManifold, state.v2Cfg.softmaxGamma);
    s1 = local_logmeanexp(z(task.leftNeighborhoodPos));
    s2 = local_logmeanexp(z(task.rightNeighborhoodPos));
    sm = local_logmeanexp(z(task.midNeighborhoodPos));
    sb = local_logmeanexp(z(task.backgroundScanPos));
    minEndpoint = min(s1, s2);

    endFloor = local_optional_v2_field(state.v2Cfg, 'stableEndpointFloor', -2.5);
    midMargin = local_optional_v2_field(state.v2Cfg, 'stableMidMargin', state.v2Cfg.midMargin);
    bgMargin = local_optional_v2_field(state.v2Cfg, 'stableBackgroundMargin', 0.10);
    balanceMargin = local_optional_v2_field(state.v2Cfg, 'stableBalanceMargin', 0.15);

    endValues(taskIdx) = local_softplus(endFloor - s1) + local_softplus(endFloor - s2);
    midValues(taskIdx) = local_softplus(sm - minEndpoint + midMargin);
    bgValues(taskIdx) = local_softplus(sb - minEndpoint + bgMargin);
    balanceValues(taskIdx) = local_softplus(abs(s1 - s2) - balanceMargin);
    pairWeights(taskIdx) = task.weight;
end

etaSub = local_optional_v2_field(state.v2Cfg, 'stableEtaSub', 1);
etaEnd = local_optional_v2_field(state.v2Cfg, 'stableEtaEnd', 1);
etaMid = local_optional_v2_field(state.v2Cfg, 'stableEtaMid', 1);
etaBg = local_optional_v2_field(state.v2Cfg, 'stableEtaBg', 0.5);
etaBalance = local_optional_v2_field(state.v2Cfg, 'stableEtaBalance', 0.5);
pairWeights = pairWeights / max(sum(pairWeights), eps);

subLoss = sum(pairWeights .* subValues);
endLoss = sum(pairWeights .* endValues);
midLoss = sum(pairWeights .* midValues);
bgLoss = sum(pairWeights .* bgValues);
balanceLoss = sum(pairWeights .* balanceValues);
peakLoss = endLoss + bgLoss + balanceLoss;
loss = etaSub * subLoss + etaEnd * endLoss + etaMid * midLoss + ...
    etaBg * bgLoss + etaBalance * balanceLoss;
end

function z = local_task_logits(projector, scanManifold, gamma)
denominator = real(sum(conj(scanManifold) .* (projector * scanManifold), 1));
denominator(denominator < eps) = eps;
logSpectrum = -log(denominator);
z = gamma * (logSpectrum - max(logSpectrum));
end

function value = local_logsumexp(z)
zMax = max(z);
value = zMax + log(sum(exp(z - zMax)));
end

function value = local_logmeanexp(z)
value = local_logsumexp(z) - log(max(numel(z), 1));
end

function value = local_softplus(x)
value = log(1 + exp(-abs(x))) + max(x, 0);
end

function weights = local_v2_objective_weights(v2Cfg)
weights = struct();
weights.lambdaCal = v2Cfg.lambdaCal;
weights.lambdaSmooth = v2Cfg.lambdaSmooth;
weights.lambdaSingle = v2Cfg.lambdaSingle;
weights.lambdaPair = v2Cfg.lambdaPair;
weights.lambdaMid = v2Cfg.lambdaMid;
weights.lambdaReg = v2Cfg.lambdaReg;
end

function weights = local_v3_objective_weights(v3Cfg)
weights = struct();
weights.lambdaCal = v3Cfg.lambdaCal;
weights.lambdaSmooth = v3Cfg.lambdaSmooth;
weights.lambdaSingle = v3Cfg.lambdaSingle;
weights.lambdaPair = v3Cfg.lambdaPair;
weights.lambdaMid = v3Cfg.lambdaMid;
weights.lambdaAnchor = v3Cfg.lambdaAnchor;
weights.lambdaGuard = v3Cfg.lambdaGuard;
weights.lambdaCal0 = v3Cfg.lambdaCal0;
weights.lambdaReg = v3Cfg.lambdaReg;
end

function metrics = local_v3_guard_metrics(ctx, manifold, baseManifold, calIdx, guardIdx, v3Cfg)
metrics = struct();
if isempty(calIdx)
    metrics.maxCalibrationDrift = 0;
else
    metrics.maxCalibrationDrift = max(vecnorm(manifold(:, calIdx) - baseManifold(:, calIdx), 2, 1));
end
anchorColumnDrift = vecnorm(manifold - baseManifold, 2, 1);
metrics.anchorRmsDrift = sqrt(mean(anchorColumnDrift .^ 2));
metrics.maxAnchorDrift = max(anchorColumnDrift);

if isempty(guardIdx)
    metrics.guardMeanRelativeError = 0;
    metrics.ardGuardMeanRelativeError = 0;
else
    candidateMetrics = compute_manifold_metrics(ctx.AH(:, guardIdx), manifold(:, guardIdx));
    ardMetrics = compute_manifold_metrics(ctx.AH(:, guardIdx), baseManifold(:, guardIdx));
    metrics.guardMeanRelativeError = mean(candidateMetrics.relativeError);
    metrics.ardGuardMeanRelativeError = mean(ardMetrics.relativeError);
end
metrics.guardRelativeExcess = metrics.guardMeanRelativeError - metrics.ardGuardMeanRelativeError;
metrics.maxCalibrationDriftLimit = v3Cfg.maxCalibrationDrift;
metrics.guardRelativeTolerance = v3Cfg.guardRelativeTolerance;
metrics.maxAnchorRmsDriftLimit = v3Cfg.maxAnchorRmsDrift;
end

function [passed, reason] = local_v3_guard_passed(metrics, v3Cfg)
passed = true;
reason = '';
if metrics.maxCalibrationDrift > v3Cfg.maxCalibrationDrift
    passed = false;
    reason = 'calibration_drift_guard';
elseif metrics.guardRelativeExcess > v3Cfg.guardRelativeTolerance
    passed = false;
    reason = 'heldout_manifold_guard';
elseif metrics.anchorRmsDrift > v3Cfg.maxAnchorRmsDrift
    passed = false;
    reason = 'anchor_drift_guard';
end
end

function warningText = local_v3_fallback_warning(usedARDFallback, fallbackReason)
if usedARDFallback
    warningText = sprintf('Proposed V3.2 kept the ARD initializer because %s failed.', fallbackReason);
else
    warningText = '';
end
end

function diagnostics = local_stable_pair_diagnostics(manifold, state)
diagnostics = struct();
diagnostics.pairAnglesDeg = zeros(0, 2);
diagnostics.s1 = zeros(0, 1);
diagnostics.s2 = zeros(0, 1);
diagnostics.sm = zeros(0, 1);
diagnostics.sb = zeros(0, 1);
diagnostics.weight = zeros(0, 1);
if isempty(state.pairTasks)
    return;
end

scanManifold = manifold(:, state.tasks.scanIdx);
diagnostics.pairAnglesDeg = state.ctx.thetaDeg(vertcat(state.pairTasks.pairIdx));
diagnostics.s1 = zeros(numel(state.pairTasks), 1);
diagnostics.s2 = zeros(numel(state.pairTasks), 1);
diagnostics.sm = zeros(numel(state.pairTasks), 1);
diagnostics.sb = zeros(numel(state.pairTasks), 1);
diagnostics.weight = zeros(numel(state.pairTasks), 1);
for taskIdx = 1:numel(state.pairTasks)
    task = state.pairTasks(taskIdx);
    z = local_task_logits(task.projector, scanManifold, state.v2Cfg.softmaxGamma);
    diagnostics.s1(taskIdx) = local_logmeanexp(z(task.leftNeighborhoodPos));
    diagnostics.s2(taskIdx) = local_logmeanexp(z(task.rightNeighborhoodPos));
    diagnostics.sm(taskIdx) = local_logmeanexp(z(task.midNeighborhoodPos));
    diagnostics.sb(taskIdx) = local_logmeanexp(z(task.backgroundScanPos));
    diagnostics.weight(taskIdx) = task.weight;
end
diagnostics.minEndpointMinusMid = min(diagnostics.s1, diagnostics.s2) - diagnostics.sm;
diagnostics.minEndpointMinusBackground = min(diagnostics.s1, diagnostics.s2) - diagnostics.sb;
diagnostics.endpointImbalance = abs(diagnostics.s1 - diagnostics.s2);
end

function value = local_optional_v2_field(inputStruct, fieldName, defaultValue)
if isfield(inputStruct, fieldName) && ~isempty(inputStruct.(fieldName))
    value = inputStruct.(fieldName);
else
    value = defaultValue;
end
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

function ardCfg = local_complete_ard_config(modelCfg)
if isfield(modelCfg, 'ard') && ~isempty(modelCfg.ard)
    ardCfg = modelCfg.ard;
else
    ardCfg = struct();
end

ardCfg = local_set_default_field(ardCfg, 'enabled', true);
ardCfg = local_set_default_field(ardCfg, 'label', 'ARD');
ardCfg = local_set_default_field(ardCfg, 'method', 'complex_correction_vector');
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

function ardModel = local_fit_ard_interpolant(ctx, calIdx, thetaCalDeg, method)
[thetaCalDeg, orderIdx] = sort(thetaCalDeg, 'ascend');
calIdx = calIdx(orderIdx);
idealCal = ctx.AI(:, calIdx);
idealCal(abs(idealCal) < eps) = eps;
correctionCal = ctx.AH(:, calIdx) ./ idealCal;

ardModel = struct();
ardModel.enabled = true;
ardModel.type = 'array_response_decomposition_method2';
ardModel.method = method;
ardModel.thetaCalDeg = thetaCalDeg;
ardModel.uCal = sind(thetaCalDeg);
ardModel.correctionCal = correctionCal;
ardModel.normalization = 'columns are phase-referenced and l2-normalized after reconstruction';
ardModel.description = ['ARD Method 2: interpolate complex HFSS/ideal correction vectors ' ...
    'over u = sin(theta), then reconstruct with the ideal steering manifold.'];
end

function aARD = local_apply_ard_interpolant(ardModel, ctx)
uQuery = sind(ctx.thetaDeg);
correctionPred = zeros(size(ardModel.correctionCal, 1), ctx.numAngles);

for rowIdx = 1:size(ardModel.correctionCal, 1)
    correctionPred(rowIdx, :) = interp1( ...
        ardModel.uCal, ...
        ardModel.correctionCal(rowIdx, :), ...
        uQuery, ...
        ardModel.method, ...
        'extrap');
end

aARD = local_normalize_columns(ctx.AI .* correctionPred);
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
