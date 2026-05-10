function result = doa_backend_triplet_grid_ml(x, scanManifold, scanAnglesDeg, backendCfg)
%DOA_BACKEND_TRIPLET_GRID_ML Exhaustive three-source covariance-fit grid backend.

if nargin < 4 || isempty(backendCfg)
    backendCfg = struct();
end

numSources = local_optional_field(backendCfg, 'numSources', 3);
if numSources ~= 3
    error('Triplet grid ML backend supports exactly numSources=3.');
end

candidateAnglesDeg = local_optional_field(backendCfg, 'candidateAnglesDeg', scanAnglesDeg);
minimumSeparationDeg = local_optional_field(backendCfg, 'minimumSeparationDeg', 0);
maximumSeparationDeg = local_optional_field(backendCfg, 'maximumSeparationDeg', Inf);
topCandidateCount = local_optional_field(backendCfg, 'topCandidateCount', 8);
setIdx = local_optional_field(backendCfg, 'setIndex', []);

if isempty(setIdx)
    candidateIdx = local_snap_candidate_indices(scanAnglesDeg, candidateAnglesDeg);
    setIdx = local_candidate_triplets(candidateIdx, scanAnglesDeg, ...
        minimumSeparationDeg, maximumSeparationDeg);
end
if isempty(setIdx)
    error('Triplet grid ML backend found no candidate angle triplets.');
end

covariance = (x * x') / size(x, 2);
numSets = size(setIdx, 1);
scores = zeros(numSets, 1);
fits = repmat(struct('sourcePower', [], 'noisePower', [], 'modelCovariance', [], ...
    'residualNorm', [], 'relativeResidual', []), numSets, 1);
for rowIdx = 1:numSets
    [scores(rowIdx), fits(rowIdx)] = local_covariance_score_nsource( ...
        covariance, scanManifold(:, setIdx(rowIdx, :)));
end

[sortedScores, order] = sort(scores, 'ascend');
setIdx = setIdx(order, :);
fits = fits(order);
bestSetIdx = setIdx(1, :);
topCount = min(topCandidateCount, numSets);
[marginalAnglesDeg, marginalConfidence, marginalBestScores] = ...
    local_triplet_marginal_confidence(scanAnglesDeg, setIdx, sortedScores);

result = struct();
result.name = 'triplet_grid_ml';
result.estAnglesDeg = sort(scanAnglesDeg(bestSetIdx));
result.spectrum = [];
result.covariance = covariance;
result.diagnostics = struct();
result.diagnostics.bestScore = sortedScores(1);
result.diagnostics.bestFit = fits(1);
result.diagnostics.bestGridIndex = bestSetIdx;
result.diagnostics.candidateSetCount = numSets;
result.diagnostics.candidateSetIndex = setIdx;
result.diagnostics.candidateSetScores = sortedScores;
result.diagnostics.candidateSetAnglesDeg = sort(scanAnglesDeg(setIdx), 2);
result.diagnostics.marginalAnglesDeg = marginalAnglesDeg;
result.diagnostics.marginalConfidence = marginalConfidence;
result.diagnostics.marginalBestScores = marginalBestScores;
result.diagnostics.topCandidateSetsDeg = sort(scanAnglesDeg(setIdx(1:topCount, :)), 2);
result.diagnostics.topCandidateScores = sortedScores(1:topCount);
end

function [score, fit] = local_covariance_score_nsource(covariance, steeringSet)
numElements = size(covariance, 1);
numSources = size(steeringSet, 2);
bases = zeros(numElements, numElements, numSources + 1);
for sourceIdx = 1:numSources
    bases(:, :, sourceIdx) = steeringSet(:, sourceIdx) * steeringSet(:, sourceIdx)';
end
bases(:, :, end) = eye(numElements);

design = zeros(numElements * numElements, numSources + 1);
for basisIdx = 1:size(bases, 3)
    basis = bases(:, :, basisIdx);
    design(:, basisIdx) = basis(:);
end
target = covariance(:);
gram = real(design' * design);
rhs = real(design' * target);
coeff = local_nonnegative_solve(gram, rhs);

modelCovariance = zeros(numElements, numElements);
for basisIdx = 1:size(bases, 3)
    modelCovariance = modelCovariance + coeff(basisIdx) * bases(:, :, basisIdx);
end
residual = covariance - modelCovariance;
score = norm(residual, 'fro') / max(norm(covariance, 'fro'), eps);

fit = struct();
fit.sourcePower = coeff(1:numSources);
fit.noisePower = coeff(end);
fit.modelCovariance = modelCovariance;
fit.residualNorm = norm(residual, 'fro');
fit.relativeResidual = score;
end

function coeff = local_nonnegative_solve(gram, rhs)
numCoeff = numel(rhs);
bestObjective = Inf;
coeff = zeros(numCoeff, 1);
for mask = 1:(2 ^ numCoeff - 1)
    active = logical(bitget(mask, 1:numCoeff)).';
    candidate = zeros(numCoeff, 1);
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

function [marginalAnglesDeg, marginalConfidence, marginalBestScores] = ...
    local_triplet_marginal_confidence(scanAnglesDeg, sortedSetIdx, sortedScores)
marginalGridIdx = unique(sortedSetIdx(:), 'stable');
marginalAnglesDeg = scanAnglesDeg(marginalGridIdx);
marginalBestScores = NaN(size(marginalAnglesDeg));
for angleIdx = 1:numel(marginalGridIdx)
    containsAngle = any(sortedSetIdx == marginalGridIdx(angleIdx), 2);
    if any(containsAngle)
        marginalBestScores(angleIdx) = min(sortedScores(containsAngle));
    end
end
rawConfidence = -marginalBestScores;
finiteMask = isfinite(rawConfidence);
marginalConfidence = NaN(size(rawConfidence));
if any(finiteMask)
    marginalConfidence(finiteMask) = rawConfidence(finiteMask) - max(rawConfidence(finiteMask));
end
end

function candidateIdx = local_snap_candidate_indices(scanAnglesDeg, candidateAnglesDeg)
scanAnglesDeg = scanAnglesDeg(:).';
candidateAnglesDeg = candidateAnglesDeg(:).';
tolDeg = local_angle_tolerance_from_grid(scanAnglesDeg);
candidateIdx = zeros(1, 0);
for queryIdx = 1:numel(candidateAnglesDeg)
    [distance, nearestIdx] = min(abs(scanAnglesDeg - candidateAnglesDeg(queryIdx)));
    if distance <= tolDeg
        candidateIdx(end+1) = nearestIdx; %#ok<AGROW>
    end
end
candidateIdx = unique(candidateIdx, 'stable');
end

function tripletIdx = local_candidate_triplets(candidateIdx, scanAnglesDeg, ...
    minimumSeparationDeg, maximumSeparationDeg)
candidateIdx = candidateIdx(:).';
tripletIdx = zeros(0, 3);
for firstIdx = 1:numel(candidateIdx)-2
    for secondIdx = firstIdx+1:numel(candidateIdx)-1
        for thirdIdx = secondIdx+1:numel(candidateIdx)
            candidate = [candidateIdx(firstIdx), candidateIdx(secondIdx), candidateIdx(thirdIdx)];
            separations = diff(sort(scanAnglesDeg(candidate)));
            aperture = max(scanAnglesDeg(candidate)) - min(scanAnglesDeg(candidate));
            if min(separations) >= minimumSeparationDeg && aperture <= maximumSeparationDeg
                tripletIdx(end+1, :) = candidate; %#ok<AGROW>
            end
        end
    end
end
end

function value = local_optional_field(inputStruct, fieldName, defaultValue)
if isfield(inputStruct, fieldName) && ~isempty(inputStruct.(fieldName))
    value = inputStruct.(fieldName);
else
    value = defaultValue;
end
end

function tolDeg = local_angle_tolerance_from_grid(thetaDeg)
if numel(thetaDeg) > 1
    tolDeg = median(diff(sort(thetaDeg))) / 2 + 1e-9;
else
    tolDeg = 1e-9;
end
end
