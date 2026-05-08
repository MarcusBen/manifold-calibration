function result = benchmark_gp_anm_fallback(ctx, evalCfg, gpCfg)
%BENCHMARK_GP_ANM_FALLBACK Prototype GP-ANM backend probe for Case 9.
%
% This is intentionally isolated from the main MUSIC benchmark. It only runs
% when explicitly enabled and requires CVX because the paper backend is an SDP.

gpCfg = local_complete_gp_config(gpCfg);
result = local_empty_result(gpCfg, evalCfg);
if ~gpCfg.enabled
    result.status = 'disabled';
    result.reason = 'cfg.case9.gpAnmFallback.enabled is false.';
    return;
end

if exist('cvx_begin', 'file') ~= 2
    result.status = 'skipped';
    result.reason = 'CVX is not available on the MATLAB path; GP-ANM SDP was not run.';
    return;
end

if ~strcmpi(strtrim(evalCfg.mode), 'double')
    result.status = 'skipped';
    result.reason = 'GP-ANM fallback probe is currently scoped to two-source Case 9.';
    return;
end

trueAngleSets = evalCfg.trueAngles;
numSources = size(trueAngleSets, 2);
if numSources ~= 2
    result.status = 'skipped';
    result.reason = 'GP-ANM fallback probe currently expects exactly two sources.';
    return;
end

[trueAngleSets, trueIdxSets] = local_snap_angle_sets(ctx.thetaDeg, trueAngleSets, local_angle_tolerance(ctx));
numTargets = min(size(trueAngleSets, 1), gpCfg.maxPairs);
numMonteCarlo = gpCfg.monteCarlo;
trialErrors = NaN(numTargets, numMonteCarlo);
trialStable = false(numTargets, numMonteCarlo);
trialResolution = false(numTargets, numMonteCarlo);
estAngles = cell(numTargets, numMonteCarlo);
spectra = cell(numTargets, numMonteCarlo);
solverStatus = strings(numTargets, numMonteCarlo);

stateCfg = struct();
stateCfg.stableToleranceDeg = evalCfg.toleranceDeg;
stateCfg.biasedToleranceDeg = local_optional_field(evalCfg, 'biasedToleranceDeg', 2 * evalCfg.toleranceDeg);
stateCfg.marginalToleranceDeg = local_optional_field(evalCfg, 'marginalToleranceDeg', 4 * evalCfg.toleranceDeg);

for targetIdx = 1:numTargets
    trueAngles = sort(trueAngleSets(targetIdx, :));
    trueIdx = trueIdxSets(targetIdx, :);
    aTrue = ctx.AH(:, trueIdx);

    for mcIdx = 1:numMonteCarlo
        [x, noisePower] = local_simulate_snapshots(aTrue, evalCfg.snrDb, evalCfg.snapshots);
        [estimate, spectrum, solveInfo] = local_estimate_gp_anm(x, ctx.AI, ctx.thetaDeg, ...
            numSources, noisePower, gpCfg);
        estimate = sort(estimate(:).');
        estAngles{targetIdx, mcIdx} = estimate;
        spectra{targetIdx, mcIdx} = spectrum;
        solverStatus(targetIdx, mcIdx) = string(solveInfo.status);

        trialErrors(targetIdx, mcIdx) = sqrt(mean((estimate - trueAngles) .^ 2));
        state = local_classify_double_resolution(estimate, trueAngles, stateCfg);
        trialStable(targetIdx, mcIdx) = state.isStable;
        trialResolution(targetIdx, mcIdx) = state.isResolved;
    end
end

result.status = 'completed';
result.reason = '';
result.trueAngleSetsDeg = trueAngleSets(1:numTargets, :);
result.rmse = mean(trialErrors(:), 'omitnan');
result.stableRate = mean(trialStable(:));
result.resolutionRate = mean(trialResolution(:));
result.perTargetRmse = mean(trialErrors, 2, 'omitnan');
result.perTargetStableRate = mean(trialStable, 2);
result.perTargetResolutionRate = mean(trialResolution, 2);
result.estAnglesDeg = estAngles;
result.spectra = spectra;
result.solverStatus = solverStatus;
end

function gpCfg = local_complete_gp_config(gpCfg)
if nargin < 1 || isempty(gpCfg)
    gpCfg = struct();
end
gpCfg = local_set_default_field(gpCfg, 'enabled', false);
gpCfg = local_set_default_field(gpCfg, 'maxPairs', 4);
gpCfg = local_set_default_field(gpCfg, 'monteCarlo', 1);
gpCfg = local_set_default_field(gpCfg, 'errorRadius', 0.5);
gpCfg = local_set_default_field(gpCfg, 'tauEta', 1);
gpCfg = local_set_default_field(gpCfg, 'label', 'GP-ANM fallback');
gpCfg.maxPairs = max(1, round(gpCfg.maxPairs));
gpCfg.monteCarlo = max(1, round(gpCfg.monteCarlo));
end

function result = local_empty_result(gpCfg, evalCfg)
result = struct();
result.name = 'gp_anm_fallback';
result.label = gpCfg.label;
result.status = 'not_started';
result.reason = '';
result.config = gpCfg;
result.evalSNRDb = evalCfg.snrDb;
result.snapshots = evalCfg.snapshots;
result.requestedMonteCarlo = gpCfg.monteCarlo;
result.trueAngleSetsDeg = zeros(0, 2);
result.rmse = NaN;
result.stableRate = NaN;
result.resolutionRate = NaN;
result.perTargetRmse = [];
result.perTargetStableRate = [];
result.perTargetResolutionRate = [];
result.estAnglesDeg = {};
result.spectra = {};
result.solverStatus = strings(0, 0);
end

function [estAngles, spectrum, solveInfo] = local_estimate_gp_anm(x, scanManifold, scanAngles, numSources, noisePower, gpCfg)
numSensors = size(x, 1);
numSnapshots = size(x, 2);
tau = gpCfg.tauEta * sqrt(noisePower) * sqrt(4 * numSensors * numSnapshots * log(numSensors));

[uHat, solveInfo] = local_solve_gp_anm_dual(x, tau, gpCfg.errorRadius);
spectrum = real(sum(abs(uHat' * scanManifold) .^ 2, 1));
spectrum = spectrum ./ max(max(spectrum), eps);
estAngles = local_pick_top_k_peaks(spectrum, scanAngles, numSources);
end

function [uHat, solveInfo] = local_solve_gp_anm_dual(y, tau, errorRadius)
numSensors = size(y, 1);
numSnapshots = size(y, 2);

cvx_begin sdp quiet
    variable U(numSensors, numSnapshots) complex
    variable Q(numSensors, numSensors) hermitian
    minimize(norm(y - U, 'fro'))
    subject to
        [Q, U; U', (tau ^ 2) * eye(numSnapshots)] >= 0;
        for diagOffset = 1:numSensors-1
            sum(diag(Q, diagOffset)) == 0;
        end
        real(trace(Q)) + (errorRadius + 2 * sqrt(numSensors)) * errorRadius * lambda_max(Q) <= 1;
cvx_end

uHat = U;
solveInfo = struct();
solveInfo.status = cvx_status;
solveInfo.optval = cvx_optval;
end

function [x, noisePower] = local_simulate_snapshots(aTrue, snrDb, snapshots)
numSources = size(aTrue, 2);
sourceSignals = (randn(numSources, snapshots) + 1i * randn(numSources, snapshots)) / sqrt(2);
signalOnly = aTrue * sourceSignals;
signalPower = mean(abs(signalOnly(:)) .^ 2);
noisePower = signalPower / (10 ^ (snrDb / 10));
noise = sqrt(noisePower / 2) * ...
    (randn(size(signalOnly)) + 1i * randn(size(signalOnly)));
x = signalOnly + noise;
end

function estAngles = local_pick_top_k_peaks(spectrum, scanAngles, k)
spectrum = spectrum(:).';
scanAngles = scanAngles(:).';
numPoints = numel(spectrum);
isPeak = false(1, numPoints);
if numPoints == 1
    isPeak(1) = true;
else
    isPeak(1) = spectrum(1) >= spectrum(2);
    isPeak(end) = spectrum(end) >= spectrum(end-1);
    for idx = 2:numPoints-1
        isPeak(idx) = spectrum(idx) >= spectrum(idx-1) && spectrum(idx) >= spectrum(idx+1);
    end
end

peakIdx = find(isPeak);
if isempty(peakIdx)
    [~, peakIdx] = maxk(spectrum, k);
else
    [~, order] = sort(spectrum(peakIdx), 'descend');
    peakIdx = peakIdx(order);
end

selected = zeros(1, 0);
for candidate = peakIdx
    if ~ismember(candidate, selected)
        selected(end+1) = candidate; %#ok<AGROW>
    end
    if numel(selected) == k
        break;
    end
end

if numel(selected) < k
    [~, allOrder] = maxk(spectrum, min(k + 8, numPoints));
    for candidate = allOrder
        if ~ismember(candidate, selected)
            selected(end+1) = candidate; %#ok<AGROW>
        end
        if numel(selected) == k
            break;
        end
    end
end

estAngles = sort(scanAngles(selected(1:k)));
end

function state = local_classify_double_resolution(estAngles, trueAngles, stateCfg)
pairRmse = sqrt(mean((estAngles - trueAngles) .^ 2));
absError = abs(estAngles - trueAngles);
midpoint = mean(trueAngles);
straddlesMidpoint = estAngles(1) < midpoint && estAngles(2) > midpoint;
maxAbsError = max(absError);

state = struct();
state.name = 'unresolved';
state.isResolved = false;
state.isMarginal = false;
state.isBiased = false;
state.isStable = false;

if ~straddlesMidpoint
    return;
end

if maxAbsError <= stateCfg.stableToleranceDeg
    state.name = 'stable';
    state.isResolved = true;
    state.isStable = true;
elseif pairRmse <= stateCfg.biasedToleranceDeg
    state.name = 'biased';
    state.isResolved = true;
    state.isBiased = true;
elseif pairRmse <= stateCfg.marginalToleranceDeg
    state.name = 'marginal';
    state.isResolved = true;
    state.isMarginal = true;
end
end

function [snappedAngles, idxSets] = local_snap_angle_sets(thetaGrid, queryAngleSets, tolDeg)
snappedAngles = zeros(size(queryAngleSets));
idxSets = zeros(size(queryAngleSets));
for rowIdx = 1:size(queryAngleSets, 1)
    for colIdx = 1:size(queryAngleSets, 2)
        [distance, nearestIdx] = min(abs(thetaGrid - queryAngleSets(rowIdx, colIdx)));
        if distance > tolDeg
            error('Angle %.6f deg is %.6f deg from the nearest HFSS grid point.', ...
                queryAngleSets(rowIdx, colIdx), distance);
        end
        idxSets(rowIdx, colIdx) = nearestIdx;
        snappedAngles(rowIdx, colIdx) = thetaGrid(nearestIdx);
    end
end
end

function tolDeg = local_angle_tolerance(ctx)
if isfield(ctx, 'gridStepDeg') && isfinite(ctx.gridStepDeg) && ctx.gridStepDeg > 0
    tolDeg = ctx.gridStepDeg / 2 + 1e-9;
else
    tolDeg = 1e-9;
end
end

function value = local_optional_field(inputStruct, fieldName, defaultValue)
if isfield(inputStruct, fieldName) && ~isempty(inputStruct.(fieldName))
    value = inputStruct.(fieldName);
else
    value = defaultValue;
end
end

function inputStruct = local_set_default_field(inputStruct, fieldName, defaultValue)
if ~isfield(inputStruct, fieldName) || isempty(inputStruct.(fieldName))
    inputStruct.(fieldName) = defaultValue;
end
end
