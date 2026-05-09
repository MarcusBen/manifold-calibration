function result = doa_backend_music_pair_rescore(x, scanManifold, scanAnglesDeg, backendCfg)
%DOA_BACKEND_MUSIC_PAIR_RESCORE MUSIC candidate peaks rescored by covariance fit.

if nargin < 4 || isempty(backendCfg)
    backendCfg = struct();
end

numSources = local_optional_field(backendCfg, 'numSources', 2);
if numSources ~= 2
    error('MUSIC pair-rescore backend supports exactly numSources=2.');
end

candidatePeakCount = local_optional_field(backendCfg, 'candidatePeakCount', 12);
minimumSeparationDeg = local_optional_field(backendCfg, 'minimumSeparationDeg', 0);
topCandidateCount = local_optional_field(backendCfg, 'topCandidateCount', 8);

covariance = (x * x') / size(x, 2);
spectrum = doa_backend_utils('music_spectrum', covariance, scanManifold, numSources);
peakIdx = doa_backend_utils('pick_local_peaks', spectrum, candidatePeakCount);

if numel(peakIdx) < 2
    [~, fallbackIdx] = maxk(spectrum, min(candidatePeakCount, numel(spectrum)));
    peakIdx = unique([peakIdx(:); fallbackIdx(:)], 'stable').';
end

pairIdx = local_candidate_pairs(peakIdx, scanAnglesDeg, minimumSeparationDeg);
if isempty(pairIdx)
    [~, globalIdx] = maxk(spectrum, min(2, numel(spectrum)));
    pairIdx = globalIdx(:).';
end

numPairs = size(pairIdx, 1);
scores = zeros(numPairs, 1);
fits = repmat(struct('sourcePower', [], 'noisePower', [], 'modelCovariance', [], ...
    'residualNorm', [], 'relativeResidual', []), numPairs, 1);
for rowIdx = 1:numPairs
    [scores(rowIdx), fits(rowIdx)] = doa_backend_utils( ...
        'covariance_score', covariance, scanManifold(:, pairIdx(rowIdx, :)));
end

[sortedScores, scoreOrder] = sort(scores, 'ascend');
pairIdx = pairIdx(scoreOrder, :);
fits = fits(scoreOrder);

bestPairIdx = pairIdx(1, :);
topCount = min(topCandidateCount, numPairs);

result = struct();
result.name = 'music_pair_rescore';
result.estAnglesDeg = sort(scanAnglesDeg(bestPairIdx));
result.spectrum = spectrum;
result.covariance = covariance;
result.diagnostics = struct();
result.diagnostics.peakIdx = peakIdx;
result.diagnostics.peakAnglesDeg = scanAnglesDeg(peakIdx);
result.diagnostics.bestScore = sortedScores(1);
result.diagnostics.bestFit = fits(1);
result.diagnostics.topCandidatePairsDeg = sort(scanAnglesDeg(pairIdx(1:topCount, :)), 2);
result.diagnostics.topCandidateScores = sortedScores(1:topCount);
end

function pairIdx = local_candidate_pairs(peakIdx, scanAnglesDeg, minimumSeparationDeg)
peakIdx = peakIdx(:).';
pairIdx = zeros(0, 2);
for firstIdx = 1:numel(peakIdx)-1
    for secondIdx = firstIdx+1:numel(peakIdx)
        candidate = [peakIdx(firstIdx), peakIdx(secondIdx)];
        separationDeg = abs(diff(scanAnglesDeg(candidate)));
        if separationDeg >= minimumSeparationDeg
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
