function varargout = doa_backend_utils(action, varargin)
%DOA_BACKEND_UTILS Shared utilities for enhanced DOA backends.

switch lower(strtrim(action))
    case 'covariance_score'
        [varargout{1:nargout}] = local_covariance_score(varargin{:});
    case 'music_spectrum'
        varargout{1} = local_music_spectrum(varargin{:});
    case 'pick_local_peaks'
        varargout{1} = local_pick_local_peaks(varargin{:});
    case 'snap_angle_sets'
        [varargout{1:nargout}] = local_snap_angle_sets(varargin{:});
    case 'simulate_snapshots'
        varargout{1} = local_simulate_snapshots(varargin{:});
    case 'classify_double'
        varargout{1} = local_classify_double_resolution(varargin{:});
    case 'separation_collapsed'
        varargout{1} = local_is_separation_collapsed(varargin{:});
    case 'row_percentile'
        varargout{1} = local_row_percentile(varargin{:});
    case 'percentile'
        varargout{1} = local_percentile(varargin{:});
    otherwise
        error('Unsupported DOA backend utility action: %s', action);
end
end

function [score, fit] = local_covariance_score(covariance, aPair)
numElements = size(covariance, 1);
if size(aPair, 2) ~= 2
    error('Pair covariance scoring expects exactly two steering vectors.');
end

basis1 = aPair(:, 1) * aPair(:, 1)';
basis2 = aPair(:, 2) * aPair(:, 2)';
basisNoise = eye(numElements);
design = [basis1(:), basis2(:), basisNoise(:)];
target = covariance(:);

gram = real(design' * design);
rhs = real(design' * target);
coeff = local_nonnegative_three_variable_solve(gram, rhs);

modelCovariance = coeff(1) * basis1 + coeff(2) * basis2 + coeff(3) * basisNoise;
residual = covariance - modelCovariance;
score = norm(residual, 'fro') / max(norm(covariance, 'fro'), eps);

fit = struct();
fit.sourcePower = coeff(1:2);
fit.noisePower = coeff(3);
fit.modelCovariance = modelCovariance;
fit.residualNorm = norm(residual, 'fro');
fit.relativeResidual = score;
end

function coeff = local_nonnegative_three_variable_solve(gram, rhs)
bestObjective = Inf;
coeff = zeros(3, 1);
for mask = 1:7
    active = logical(bitget(mask, 1:3)).';
    candidate = zeros(3, 1);
    activeGram = gram(active, active);
    activeRhs = rhs(active);
    if rcond(activeGram) < 1e-12
        activeCoeff = pinv(activeGram) * activeRhs;
    else
        activeCoeff = activeGram \ activeRhs;
    end
    if any(activeCoeff < -1e-10)
        continue;
    end
    candidate(active) = max(activeCoeff, 0);
    objective = 0.5 * candidate' * gram * candidate - rhs' * candidate;
    if objective < bestObjective
        bestObjective = objective;
        coeff = candidate;
    end
end
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

function peakIdx = local_pick_local_peaks(spectrum, maxPeaks)
spectrum = spectrum(:).';
numPoints = numel(spectrum);
targetCount = min(maxPeaks, numPoints);
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
    [~, peakIdx] = maxk(spectrum, targetCount);
else
    peakIdx = local_reduce_plateau_peaks(peakIdx, spectrum);
    [~, order] = sort(spectrum(peakIdx), 'descend');
    peakIdx = peakIdx(order);
    if numel(peakIdx) < targetCount
        [~, globalOrder] = sort(spectrum, 'descend');
        backfillIdx = globalOrder(~ismember(globalOrder, peakIdx));
        peakIdx = [peakIdx, backfillIdx(1:(targetCount - numel(peakIdx)))];
    else
        peakIdx = peakIdx(1:targetCount);
    end
end
end

function peakIdx = local_reduce_plateau_peaks(peakIdx, spectrum)
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

function [snappedAngles, idxSets] = local_snap_angle_sets(thetaGrid, queryAngleSets)
tolDeg = local_angle_tolerance_from_grid(thetaGrid);
snappedAngles = zeros(size(queryAngleSets));
idxSets = zeros(size(queryAngleSets));
for rowIdx = 1:size(queryAngleSets, 1)
    for colIdx = 1:size(queryAngleSets, 2)
        [distance, nearestIdx] = min(abs(thetaGrid - queryAngleSets(rowIdx, colIdx)));
        if distance > tolDeg
            error('Angle %.6f deg is %.6f deg away from the nearest grid angle.', ...
                queryAngleSets(rowIdx, colIdx), distance);
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
noise = sqrt(noisePower / 2) * (randn(size(signalOnly)) + 1i * randn(size(signalOnly)));
x = signalOnly + noise;
end

function state = local_classify_double_resolution(estAngles, trueAngles, stateCfg)
estAngles = sort(estAngles(:).');
trueAngles = sort(trueAngles(:).');
state = struct();
state.name = 'unresolved';
state.isResolved = false;
state.isMarginal = false;
state.isBiased = false;
state.isStable = false;
if numel(estAngles) ~= 2 || numel(trueAngles) ~= 2
    return;
end

pairRmse = sqrt(mean((estAngles - trueAngles) .^ 2));
absError = abs(estAngles - trueAngles);
midpoint = mean(trueAngles);
straddlesMidpoint = estAngles(1) < midpoint && estAngles(2) > midpoint;
maxAbsError = max(absError);
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

function isCollapsed = local_is_separation_collapsed(estAngles, trueAngles)
if numel(estAngles) ~= 2 || numel(trueAngles) ~= 2
    isCollapsed = false;
    return;
end
trueSeparation = abs(diff(sort(trueAngles(:).')));
estimatedSeparation = abs(diff(sort(estAngles(:).')));
isCollapsed = estimatedSeparation < 0.5 * trueSeparation;
end

function values = local_row_percentile(dataMatrix, percentile)
values = NaN(size(dataMatrix, 1), 1);
for rowIdx = 1:size(dataMatrix, 1)
    values(rowIdx) = local_percentile(dataMatrix(rowIdx, :), percentile);
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

function tolDeg = local_angle_tolerance_from_grid(thetaDeg)
if numel(thetaDeg) > 1
    tolDeg = median(diff(sort(thetaDeg))) / 2 + 1e-9;
else
    tolDeg = 1e-9;
end
end
