function result = doa_backend_pairwise_grid_ml(x, scanManifold, scanAnglesDeg, backendCfg)
%DOA_BACKEND_PAIRWISE_GRID_ML Exhaustive two-source covariance-fit grid backend.

if nargin < 4 || isempty(backendCfg)
    backendCfg = struct();
end

numSources = local_optional_field(backendCfg, 'numSources', 2);
if numSources ~= 2
    error('Pairwise grid ML backend supports exactly numSources=2.');
end

minimumSeparationDeg = local_optional_field(backendCfg, 'minimumSeparationDeg', 0);
maximumSeparationDeg = local_optional_field(backendCfg, 'maximumSeparationDeg', Inf);
topCandidateCount = local_optional_field(backendCfg, 'topCandidateCount', 10);
candidateAnglesDeg = local_optional_field(backendCfg, 'candidateAnglesDeg', scanAnglesDeg);

pairIdx = local_optional_field(backendCfg, 'pairIndex', []);
if isempty(pairIdx)
    candidateIdx = local_snap_candidate_indices(scanAnglesDeg, candidateAnglesDeg);
    pairIdx = local_candidate_pairs(candidateIdx, scanAnglesDeg, ...
        minimumSeparationDeg, maximumSeparationDeg);
end
if isempty(pairIdx)
    error('Pairwise grid ML backend found no candidate angle pairs.');
end

covariance = (x * x') / size(x, 2);
numPairs = size(pairIdx, 1);
[scores, coeffs] = local_pairwise_covariance_scores(covariance, scanManifold, pairIdx);
[sortedScores, scoreOrder] = sort(scores, 'ascend');
pairIdx = pairIdx(scoreOrder, :);
coeffs = coeffs(scoreOrder, :);

bestPairIdx = pairIdx(1, :);
topCount = min(topCandidateCount, numPairs);
bestFit = local_pair_fit(covariance, scanManifold(:, bestPairIdx), coeffs(1, :), sortedScores(1));

result = struct();
result.name = 'pairwise_grid_ml';
result.estAnglesDeg = sort(scanAnglesDeg(bestPairIdx));
result.spectrum = [];
result.covariance = covariance;
result.diagnostics = struct();
result.diagnostics.bestScore = sortedScores(1);
result.diagnostics.bestFit = bestFit;
result.diagnostics.bestGridIndex = bestPairIdx;
result.diagnostics.candidatePairCount = numPairs;
result.diagnostics.topCandidatePairsDeg = sort(scanAnglesDeg(pairIdx(1:topCount, :)), 2);
result.diagnostics.topCandidateScores = sortedScores(1:topCount);
result.diagnostics.refinementUsed = false;
end

function [scores, coeffs] = local_pairwise_covariance_scores(covariance, scanManifold, pairIdx)
numElements = size(covariance, 1);
numPairs = size(pairIdx, 1);
normCov = max(norm(covariance, 'fro'), eps);
covFroSq = norm(covariance, 'fro') ^ 2;
traceCov = real(trace(covariance));
identityNormSq = numElements;

firstIdx = pairIdx(:, 1);
secondIdx = pairIdx(:, 2);
aFirst = scanManifold(:, firstIdx);
aSecond = scanManifold(:, secondIdx);
covTimesFirst = covariance * aFirst;
covTimesSecond = covariance * aSecond;

rhs = zeros(numPairs, 3);
rhs(:, 1) = real(sum(conj(aFirst) .* covTimesFirst, 1)).';
rhs(:, 2) = real(sum(conj(aSecond) .* covTimesSecond, 1)).';
rhs(:, 3) = traceCov;

crossTerm = abs(sum(conj(aFirst) .* aSecond, 1)).' .^ 2;
basisNorm1 = sum(abs(aFirst) .^ 2, 1).' .^ 2;
basisNorm2 = sum(abs(aSecond) .^ 2, 1).' .^ 2;
noiseCross1 = sum(abs(aFirst) .^ 2, 1).';
noiseCross2 = sum(abs(aSecond) .^ 2, 1).';

bestObjective = Inf(numPairs, 1);
coeffs = zeros(numPairs, 3);
for mask = 1:7
    active = logical(bitget(mask, 1:3));
    candidate = zeros(numPairs, 3);
    candidate(:, active) = local_solve_active_coefficients(active, ...
        basisNorm1, basisNorm2, crossTerm, noiseCross1, noiseCross2, ...
        identityNormSq, rhs);
    valid = all(candidate(:, active) >= -1e-10, 2);
    candidate(candidate < 0) = 0;
    objective = local_pair_objective(candidate, basisNorm1, basisNorm2, ...
        crossTerm, noiseCross1, noiseCross2, identityNormSq, rhs);
    replace = valid & objective < bestObjective;
    bestObjective(replace) = objective(replace);
    coeffs(replace, :) = candidate(replace, :);
end

residualSq = local_pair_residual_squared(coeffs, basisNorm1, basisNorm2, ...
    crossTerm, noiseCross1, noiseCross2, identityNormSq, rhs, covFroSq);
scores = sqrt(max(residualSq, 0)) / normCov;
end

function activeCoeff = local_solve_active_coefficients(active, basisNorm1, basisNorm2, ...
    crossTerm, noiseCross1, noiseCross2, identityNormSq, rhs)
numPairs = numel(crossTerm);
activeIdx = find(active);
activeCoeff = zeros(numPairs, numel(activeIdx));
switch numel(activeIdx)
    case 1
        diagTerm = local_gram_value(activeIdx, activeIdx, basisNorm1, basisNorm2, ...
            crossTerm, noiseCross1, noiseCross2, identityNormSq);
        activeCoeff(:, 1) = rhs(:, activeIdx) ./ max(diagTerm, eps);
    case 2
        g11 = local_gram_value(activeIdx(1), activeIdx(1), basisNorm1, basisNorm2, ...
            crossTerm, noiseCross1, noiseCross2, identityNormSq);
        g22 = local_gram_value(activeIdx(2), activeIdx(2), basisNorm1, basisNorm2, ...
            crossTerm, noiseCross1, noiseCross2, identityNormSq);
        g12 = local_gram_value(activeIdx(1), activeIdx(2), basisNorm1, basisNorm2, ...
            crossTerm, noiseCross1, noiseCross2, identityNormSq);
        detGram = g11 .* g22 - g12 .^ 2;
        singular = abs(detGram) < 1e-12;
        detGram(singular) = NaN;
        activeCoeff(:, 1) = (rhs(:, activeIdx(1)) .* g22 - rhs(:, activeIdx(2)) .* g12) ./ detGram;
        activeCoeff(:, 2) = (rhs(:, activeIdx(2)) .* g11 - rhs(:, activeIdx(1)) .* g12) ./ detGram;
        activeCoeff(singular, :) = -Inf;
    case 3
        for pairIdx = 1:numPairs
            gram = [basisNorm1(pairIdx), crossTerm(pairIdx), noiseCross1(pairIdx); ...
                crossTerm(pairIdx), basisNorm2(pairIdx), noiseCross2(pairIdx); ...
                noiseCross1(pairIdx), noiseCross2(pairIdx), identityNormSq];
            if rcond(gram) < 1e-12
                activeCoeff(pairIdx, :) = (pinv(gram) * rhs(pairIdx, :).').';
            else
                activeCoeff(pairIdx, :) = (gram \ rhs(pairIdx, :).').';
            end
        end
end
end

function value = local_gram_value(rowIdx, colIdx, basisNorm1, basisNorm2, ...
    crossTerm, noiseCross1, noiseCross2, identityNormSq)
key = sprintf('%d%d', min(rowIdx, colIdx), max(rowIdx, colIdx));
switch key
    case '11'
        value = basisNorm1;
    case '12'
        value = crossTerm;
    case '13'
        value = noiseCross1;
    case '22'
        value = basisNorm2;
    case '23'
        value = noiseCross2;
    case '33'
        value = identityNormSq;
    otherwise
        error('Unsupported Gram index pair.');
end
end

function objective = local_pair_objective(coeffs, basisNorm1, basisNorm2, ...
    crossTerm, noiseCross1, noiseCross2, identityNormSq, rhs)
quadratic = local_pair_quadratic(coeffs, basisNorm1, basisNorm2, ...
    crossTerm, noiseCross1, noiseCross2, identityNormSq);
linear = sum(rhs .* coeffs, 2);
objective = 0.5 * quadratic - linear;
end

function residualSq = local_pair_residual_squared(coeffs, basisNorm1, basisNorm2, ...
    crossTerm, noiseCross1, noiseCross2, identityNormSq, rhs, covFroSq)
quadratic = local_pair_quadratic(coeffs, basisNorm1, basisNorm2, ...
    crossTerm, noiseCross1, noiseCross2, identityNormSq);
linear = sum(rhs .* coeffs, 2);
residualSq = covFroSq + quadratic - 2 * linear;
end

function quadratic = local_pair_quadratic(coeffs, basisNorm1, basisNorm2, ...
    crossTerm, noiseCross1, noiseCross2, identityNormSq)
c1 = coeffs(:, 1);
c2 = coeffs(:, 2);
c3 = coeffs(:, 3);
quadratic = c1 .^ 2 .* basisNorm1 + c2 .^ 2 .* basisNorm2 + c3 .^ 2 .* identityNormSq + ...
    2 * c1 .* c2 .* crossTerm + 2 * c1 .* c3 .* noiseCross1 + 2 * c2 .* c3 .* noiseCross2;
end

function fit = local_pair_fit(covariance, aPair, coeff, score)
modelCovariance = coeff(1) * (aPair(:, 1) * aPair(:, 1)') + ...
    coeff(2) * (aPair(:, 2) * aPair(:, 2)') + coeff(3) * eye(size(covariance, 1));
residual = covariance - modelCovariance;
fit = struct();
fit.sourcePower = coeff(1:2).';
fit.noisePower = coeff(3);
fit.modelCovariance = modelCovariance;
fit.residualNorm = norm(residual, 'fro');
fit.relativeResidual = score;
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

function pairIdx = local_candidate_pairs(candidateIdx, scanAnglesDeg, ...
    minimumSeparationDeg, maximumSeparationDeg)
candidateIdx = candidateIdx(:).';
pairIdx = zeros(0, 2);
for firstIdx = 1:numel(candidateIdx)-1
    for secondIdx = firstIdx+1:numel(candidateIdx)
        candidate = [candidateIdx(firstIdx), candidateIdx(secondIdx)];
        separationDeg = abs(diff(scanAnglesDeg(candidate)));
        if separationDeg >= minimumSeparationDeg && separationDeg <= maximumSeparationDeg
            pairIdx(end+1, :) = candidate; %#ok<AGROW>
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
