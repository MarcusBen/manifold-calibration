function result = benchmark_music(ctx, methods, evalCfg)
%BENCHMARK_MUSIC Run single-source or two-source MUSIC experiments.

modeName = lower(strtrim(evalCfg.mode));
collectSpectrum = isfield(evalCfg, 'collectRepresentativeSpectrum') && evalCfg.collectRepresentativeSpectrum;
doubleStateCfg = local_double_state_config(evalCfg);

switch modeName
    case 'single'
        trueAngleSets = evalCfg.trueAngles(:);
        numSources = 1;
    case 'double'
        trueAngleSets = evalCfg.trueAngles;
        numSources = size(trueAngleSets, 2);
    otherwise
        error('Unsupported benchmark mode: %s', evalCfg.mode);
end

requestedAngleSets = trueAngleSets;
[trueAngleSets, trueIdxSets] = local_snap_angle_sets(ctx.thetaDeg, trueAngleSets, local_angle_tolerance(ctx));
numTargets = size(trueAngleSets, 1);
numMethods = numel(methods);
toleranceDeg = evalCfg.toleranceDeg;

result = struct();
result.mode = modeName;
result.requestedAngleSetsDeg = requestedAngleSets;
result.trueAngleSetsDeg = trueAngleSets;
result.methods = repmat(struct(), 1, numMethods);

for methodIdx = 1:numMethods
    result.methods(methodIdx).name = methods(methodIdx).name;
    result.methods(methodIdx).label = methods(methodIdx).label;
    result.methods(methodIdx).successRate = NaN;
    result.methods(methodIdx).rmse = NaN;
    result.methods(methodIdx).perTargetRmse = NaN(numTargets, 1);
    result.methods(methodIdx).perTargetMeanError = NaN(numTargets, 1);
    result.methods(methodIdx).perTargetAbsBias = NaN(numTargets, 1);
    result.methods(methodIdx).trialErrorStd = NaN(numTargets, 1);
    result.methods(methodIdx).p90AbsError = NaN;
    result.methods(methodIdx).perTargetP90AbsError = NaN(numTargets, 1);
    result.methods(methodIdx).perTargetSuccess = NaN(numTargets, 1);
    result.methods(methodIdx).resolutionRate = NaN;
    result.methods(methodIdx).marginalRate = NaN;
    result.methods(methodIdx).biasedRate = NaN;
    result.methods(methodIdx).stableRate = NaN;
    result.methods(methodIdx).perTargetResolutionRate = NaN(numTargets, 1);
    result.methods(methodIdx).perTargetMarginalRate = NaN(numTargets, 1);
    result.methods(methodIdx).perTargetBiasedRate = NaN(numTargets, 1);
    result.methods(methodIdx).perTargetStableRate = NaN(numTargets, 1);
    result.methods(methodIdx).perTargetUnresolvedRate = NaN(numTargets, 1);
    result.methods(methodIdx).representativeSpectrum = [];
    result.methods(methodIdx).representativeEstAnglesDeg = [];
    result.methods(methodIdx).representativeResolutionState = '';
end

for methodIdx = 1:numMethods
    switch modeName
        case 'single'
            trialErrors = zeros(numTargets, evalCfg.monteCarlo);
        case 'double'
            trialErrors = zeros(numTargets, evalCfg.monteCarlo);
    end
    trialSuccess = false(numTargets, evalCfg.monteCarlo);
    trialResolution = false(numTargets, evalCfg.monteCarlo);
    trialMarginal = false(numTargets, evalCfg.monteCarlo);
    trialBiased = false(numTargets, evalCfg.monteCarlo);
    trialStable = false(numTargets, evalCfg.monteCarlo);

    for targetIdx = 1:numTargets
        trueAngles = trueAngleSets(targetIdx, :);
        trueIdx = trueIdxSets(targetIdx, :);
        aTrue = ctx.AH(:, trueIdx);

        for mcIdx = 1:evalCfg.monteCarlo
            x = local_simulate_snapshots(aTrue, evalCfg.snrDb, evalCfg.snapshots);
            [estAngles, spectrum] = local_estimate_music(x, methods(methodIdx).manifold, ctx.thetaDeg, numSources);

            if strcmp(modeName, 'single')
                trialErrors(targetIdx, mcIdx) = estAngles(1) - trueAngles(1);
                trialSuccess(targetIdx, mcIdx) = abs(trialErrors(targetIdx, mcIdx)) <= toleranceDeg;
            else
                estAngles = sort(estAngles(:).');
                trueAngles = sort(trueAngles(:).');
                trialErrors(targetIdx, mcIdx) = sqrt(mean((estAngles - trueAngles) .^ 2));
                state = local_classify_double_resolution(estAngles, trueAngles, doubleStateCfg);
                trialSuccess(targetIdx, mcIdx) = state.isStable;
                trialResolution(targetIdx, mcIdx) = state.isResolved;
                trialMarginal(targetIdx, mcIdx) = state.isMarginal;
                trialBiased(targetIdx, mcIdx) = state.isBiased;
                trialStable(targetIdx, mcIdx) = state.isStable;
            end

            if collectSpectrum && targetIdx == 1 && mcIdx == 1
                result.methods(methodIdx).representativeSpectrum = spectrum;
                result.methods(methodIdx).representativeEstAnglesDeg = estAngles;
                if strcmp(modeName, 'double')
                    result.methods(methodIdx).representativeResolutionState = state.name;
                end
            end
        end
    end

    if strcmp(modeName, 'single')
        result.methods(methodIdx).rmse = sqrt(mean(trialErrors(:) .^ 2));
        result.methods(methodIdx).perTargetRmse = sqrt(mean(trialErrors .^ 2, 2));
        result.methods(methodIdx).perTargetMeanError = mean(trialErrors, 2);
        result.methods(methodIdx).perTargetAbsBias = abs(result.methods(methodIdx).perTargetMeanError);
        result.methods(methodIdx).trialErrorStd = std(trialErrors, 0, 2);
        result.methods(methodIdx).p90AbsError = local_percentile(abs(trialErrors(:)), 90);
        result.methods(methodIdx).perTargetP90AbsError = local_row_percentile(abs(trialErrors), 90);
    else
        result.methods(methodIdx).rmse = mean(trialErrors(:));
        result.methods(methodIdx).perTargetRmse = mean(trialErrors, 2);
        result.methods(methodIdx).resolutionRate = mean(trialResolution(:));
        result.methods(methodIdx).marginalRate = mean(trialMarginal(:));
        result.methods(methodIdx).biasedRate = mean(trialBiased(:));
        result.methods(methodIdx).stableRate = mean(trialStable(:));
        result.methods(methodIdx).perTargetResolutionRate = mean(trialResolution, 2);
        result.methods(methodIdx).perTargetMarginalRate = mean(trialMarginal, 2);
        result.methods(methodIdx).perTargetBiasedRate = mean(trialBiased, 2);
        result.methods(methodIdx).perTargetStableRate = mean(trialStable, 2);
        result.methods(methodIdx).perTargetUnresolvedRate = 1 - mean(trialResolution, 2);
    end

    result.methods(methodIdx).successRate = mean(trialSuccess(:));
    result.methods(methodIdx).perTargetSuccess = mean(trialSuccess, 2);
end
end

function value = local_percentile(values, percentile)
values = sort(values(:), 'ascend');
if isempty(values)
    value = NaN;
    return;
end

rank = 1 + (numel(values) - 1) * percentile / 100;
lowerIdx = floor(rank);
upperIdx = ceil(rank);
if lowerIdx == upperIdx
    value = values(lowerIdx);
else
    fraction = rank - lowerIdx;
    value = (1 - fraction) * values(lowerIdx) + fraction * values(upperIdx);
end
end

function values = local_row_percentile(dataMatrix, percentile)
values = NaN(size(dataMatrix, 1), 1);
for rowIdx = 1:size(dataMatrix, 1)
    values(rowIdx) = local_percentile(dataMatrix(rowIdx, :), percentile);
end
end

function tolDeg = local_angle_tolerance(ctx)
if isfield(ctx, 'gridStepDeg') && isfinite(ctx.gridStepDeg) && ctx.gridStepDeg > 0
    tolDeg = ctx.gridStepDeg / 2 + 1e-9;
else
    tolDeg = 1e-9;
end
end

function [snappedAngles, idxSets] = local_snap_angle_sets(thetaGrid, queryAngleSets, tolDeg)
snappedAngles = zeros(size(queryAngleSets));
idxSets = zeros(size(queryAngleSets));

for rowIdx = 1:size(queryAngleSets, 1)
    for colIdx = 1:size(queryAngleSets, 2)
        [distance, nearestIdx] = min(abs(thetaGrid - queryAngleSets(rowIdx, colIdx)));
        if distance > tolDeg
            error('Angle %.6f deg is %.6f deg away from the nearest HFSS grid angle, exceeding tolerance %.6f deg.', ...
                queryAngleSets(rowIdx, colIdx), distance, tolDeg);
        end
        idxSets(rowIdx, colIdx) = nearestIdx;
        snappedAngles(rowIdx, colIdx) = thetaGrid(nearestIdx);
    end
end
end

function x = local_simulate_snapshots(aTrue, snrDb, snapshots)
numSources = size(aTrue, 2);
sourceSignals = (randn(numSources, snapshots) + 1i * randn(numSources, snapshots)) / sqrt(2);
signalOnly = aTrue * sourceSignals;
signalPower = mean(abs(signalOnly(:)) .^ 2);
noisePower = signalPower / (10 ^ (snrDb / 10));
noise = sqrt(noisePower / 2) * ...
    (randn(size(signalOnly)) + 1i * randn(size(signalOnly)));
x = signalOnly + noise;
end

function [estAngles, spectrum] = local_estimate_music(x, scanManifold, scanAngles, numSources)
covariance = (x * x') / size(x, 2);
spectrum = local_music_spectrum(covariance, scanManifold, numSources);
estAngles = local_pick_top_k_peaks(spectrum, scanAngles, numSources);
end

function spectrum = local_music_spectrum(covariance, scanManifold, numSources)
[eigVec, eigVal] = eig(covariance, 'vector');
[~, order] = sort(real(eigVal), 'descend');
eigVec = eigVec(:, order);
noiseSubspace = eigVec(:, numSources+1:end);
projection = noiseSubspace' * scanManifold;
denominator = sum(abs(projection) .^ 2, 1);
denominator(denominator < eps) = eps;
spectrum = real(1 ./ denominator);
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
    peakIdx = local_reduce_plateau_peaks(peakIdx, spectrum);
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

function peakIdx = local_reduce_plateau_peaks(peakIdx, spectrum)
if isempty(peakIdx)
    return;
end

groupStart = [1, find(diff(peakIdx) > 1) + 1];
groupEnd = [groupStart(2:end) - 1, numel(peakIdx)];
reduced = zeros(1, numel(groupStart));

for groupIdx = 1:numel(groupStart)
    block = peakIdx(groupStart(groupIdx):groupEnd(groupIdx));
    blockValues = spectrum(block);
    maxValue = max(blockValues);
    tied = block(blockValues == maxValue);
    reduced(groupIdx) = tied(ceil(numel(tied) / 2));
end

peakIdx = reduced;
end

function stateCfg = local_double_state_config(evalCfg)
stateCfg = struct();
stateCfg.stableToleranceDeg = evalCfg.toleranceDeg;
stateCfg.biasedToleranceDeg = local_optional_field(evalCfg, ...
    'biasedToleranceDeg', 2 * evalCfg.toleranceDeg);
stateCfg.marginalToleranceDeg = local_optional_field(evalCfg, ...
    'marginalToleranceDeg', 4 * evalCfg.toleranceDeg);
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

function value = local_optional_field(inputStruct, fieldName, defaultValue)
if isfield(inputStruct, fieldName) && ~isempty(inputStruct.(fieldName))
    value = inputStruct.(fieldName);
else
    value = defaultValue;
end
end
