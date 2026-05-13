function varargout = doa_backend_utils(action, varargin)
%DOA_BACKEND_UTILS Shared utilities for enhanced DOA backends.

switch lower(strtrim(action))
    case 'covariance_score'
        [varargout{1:nargout}] = local_covariance_score(varargin{:});
    case 'music_spectrum'
        varargout{1} = local_music_spectrum(varargin{:});
    case 'spice_spectrum'
        [varargout{1:nargout}] = local_spice_spectrum(varargin{:});
    case 'spice_plus_spectrum'
        [varargout{1:nargout}] = local_spice_plus_spectrum(varargin{:});
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

function [p, info] = local_spice_spectrum(covariance, scanManifold, alg)
if nargin < 3 || isempty(alg)
    alg = struct();
end
local_validate_spice_inputs(covariance, scanManifold, 'spice_spectrum');
opts = local_spice_options(alg);
[p, ~] = local_periodogram_spectrum(covariance, scanManifold);
p = max(real(p), eps);
numSensors = size(scanManifold, 1);
sigma = max(real(diag(covariance)).' / 10, eps);
dictionary = [scanManifold, eye(numSensors)];
pAll = [p, sigma];
weightedCovariance = covariance + opts.diagonalLoading * eye(numSensors);
weights = real(sum(conj(dictionary) .* (weightedCovariance \ dictionary), 1)) / numSensors;
weights = max(weights, eps);
deltaHistory = zeros(1, opts.maxIterations);
iterations = 0;
for iter = 1:opts.maxIterations
    modelCovariance = (dictionary .* reshape(pAll, 1, [])) * dictionary' + ...
        opts.diagonalLoading * eye(numSensors);
    projectedDictionary = modelCovariance \ dictionary;
    columnNorm = sqrt(max(real(sum(conj(projectedDictionary) .* ...
        (covariance * projectedDictionary), 1)), eps));
    rho = max(sum(sqrt(weights) .* pAll .* columnNorm), eps);
    pNew = pAll .* columnNorm ./ (sqrt(weights) .* rho);
    pNew(~isfinite(pNew)) = eps;
    pNew = max(real(pNew), eps);
    delta = norm(pNew - pAll, 1) / max(norm(pAll, 1), eps);
    deltaHistory(iter) = delta;
    iterations = iter;
    pAll = pNew;
    if delta < opts.tolerance
        break;
    end
end
p = reshape(pAll(1:size(scanManifold, 2)), 1, []);
info = struct();
info.iterations = iterations;
info.deltaHistory = deltaHistory(1:iterations);
info.noisePowers = reshape(pAll(size(scanManifold, 2)+1:end), 1, []);
end

function [p, info] = local_spice_plus_spectrum(covariance, scanManifold, alg)
if nargin < 3 || isempty(alg)
    alg = struct();
end
local_validate_spice_inputs(covariance, scanManifold, 'spice_plus_spectrum');
opts = local_spice_options(alg);
[p, ~] = local_periodogram_spectrum(covariance, scanManifold);
p = max(real(p), eps);
numSensors = size(scanManifold, 1);
numGridPoints = size(scanManifold, 2);
sortedP = sort(p);
numNoiseSeeds = min(numSensors, numel(sortedP));
sigmaHat = max(mean(sortedP(1:numNoiseSeeds)) * numSensors, eps);
dictionary = [scanManifold, eye(numSensors)];
weightedCovariance = covariance + opts.diagonalLoading * eye(numSensors);
wSignal = real(sum(conj(scanManifold) .* (weightedCovariance \ scanManifold), 1)) / numSensors;
wNoise = real(sum(conj(eye(numSensors)) .* ...
    (weightedCovariance \ eye(numSensors)), 1)) / numSensors;
wSignal = max(wSignal, eps);
wNoise = max(wNoise, eps);
gamma = max(sum(wNoise), eps);
deltaHistory = zeros(1, opts.maxIterations);
iterations = 0;
for iter = 1:opts.maxIterations
    pAll = [p, sigmaHat * ones(1, numSensors)];
    modelCovariance = (dictionary .* reshape(pAll, 1, [])) * dictionary' + ...
        opts.diagonalLoading * eye(numSensors);
    projectedSignal = modelCovariance \ scanManifold;
    cSignalNorm = sqrt(max(real(sum(conj(projectedSignal) .* ...
        (covariance * projectedSignal), 1)), eps));
    projectedNoise = modelCovariance \ eye(numSensors);
    cNoiseNorm = sqrt(max(real(trace(projectedNoise' * projectedNoise * covariance)), eps));
    rho = max(sum(sqrt(wSignal) .* p .* cSignalNorm) + ...
        sqrt(gamma) * sigmaHat * cNoiseNorm, eps);
    pNew = p .* cSignalNorm ./ (sqrt(wSignal) .* rho);
    pNew(~isfinite(pNew)) = eps;
    pNew = max(real(pNew), eps);
    sigmaNew = sigmaHat * cNoiseNorm / (sqrt(gamma) * rho);
    if ~isfinite(sigmaNew)
        sigmaNew = eps;
    end
    sigmaNew = max(real(sigmaNew), eps);
    delta = norm([pNew, sigmaNew] - [p, sigmaHat], 1) / ...
        max(norm([p, sigmaHat], 1), eps);
    deltaHistory(iter) = delta;
    iterations = iter;
    p = pNew;
    sigmaHat = sigmaNew;
    if delta < opts.tolerance
        break;
    end
end
p = reshape(p(1:numGridPoints), 1, []);
info = struct();
info.iterations = iterations;
info.deltaHistory = deltaHistory(1:iterations);
info.sigmaHat = sigmaHat;
end

function [spectrum, beamPower] = local_periodogram_spectrum(covariance, scanManifold)
beamPower = real(sum(conj(scanManifold) .* (covariance * scanManifold), 1));
spectrum = max(beamPower, 0);
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

function local_validate_spice_inputs(covariance, scanManifold, callerName)
if ~isnumeric(scanManifold) || ndims(scanManifold) ~= 2 || isempty(scanManifold)
    error('%s:InvalidSteeringMatrix', callerName);
end
if ~isnumeric(covariance) || ndims(covariance) ~= 2 || isempty(covariance) || ...
        size(covariance, 1) ~= size(covariance, 2)
    error('%s:InvalidCovariance', callerName);
end
if size(scanManifold, 1) ~= size(covariance, 1)
    error('%s:DimensionMismatch', callerName);
end
if any(~isfinite(scanManifold(:))) || any(~isfinite(covariance(:)))
    error('%s:InvalidInput', callerName);
end
hermitianTolerance = 1e-10 * max(1, norm(covariance, 'fro'));
if norm(covariance - covariance', 'fro') > hermitianTolerance
    error('%s:NonHermitianCovariance', callerName);
end
end

function opts = local_spice_options(alg)
opts = struct();
opts.maxIterations = local_optional_field(alg, 'maxIterations', 100);
opts.tolerance = local_optional_field(alg, 'tolerance', 1e-4);
opts.diagonalLoading = local_optional_field(alg, 'diagonalLoading', 1e-8);
if opts.maxIterations <= 0 || opts.maxIterations ~= floor(opts.maxIterations)
    error('spice_spectrum:InvalidOptions', 'maxIterations must be a positive integer.');
end
if opts.tolerance <= 0 || ~isfinite(opts.tolerance)
    error('spice_spectrum:InvalidOptions', 'tolerance must be positive and finite.');
end
if opts.diagonalLoading <= 0 || ~isfinite(opts.diagonalLoading)
    error('spice_spectrum:InvalidOptions', 'diagonalLoading must be positive and finite.');
end
end

function value = local_optional_field(inputStruct, fieldName, defaultValue)
if isstruct(inputStruct) && isfield(inputStruct, fieldName) && ~isempty(inputStruct.(fieldName))
    value = inputStruct.(fieldName);
else
    value = defaultValue;
end
end
