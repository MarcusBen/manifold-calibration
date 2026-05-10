function varargout = case09_helpers(action, varargin)
%CASE09_HELPERS Pure helper routines for Case 9 pair selection and summaries.

switch lower(strtrim(action))
    case 'source_pairs'
        [varargout{1:nargout}] = local_source_pairs(varargin{:});
    case 'filter_pairs'
        varargout{1} = local_filter_pairs(varargin{:});
    case 'exclude_task_pairs'
        [varargout{1:nargout}] = local_exclude_task_pairs(varargin{:});
    case 'count_task_eval_overlap'
        varargout{1} = local_count_task_eval_overlap(varargin{:});
    case 'pair_labels'
        varargout{1} = local_pair_labels(varargin{:});
    case 'group_metric'
        [varargout{1:nargout}] = local_group_metric(varargin{:});
    case 'v3_delta_from_ard'
        [varargout{1:nargout}] = local_v3_delta_from_ard(varargin{:});
    case 'subset_summary'
        varargout{1} = local_subset_summary(varargin{:});
    case 'v1_experience_diagnostics'
        varargout{1} = local_v1_experience_diagnostics(varargin{:});
    case 'pair_stratum_hist'
        varargout{1} = local_pair_stratum_hist(varargin{:});
    case 'v3_stable_pair_diagnostics'
        varargout{1} = local_v3_stable_pair_diagnostics(varargin{:});
    case 'select_example_pair'
        [varargout{1:nargout}] = local_select_example_pair(varargin{:});
    case 'optional_field'
        varargout{1} = local_optional_field(varargin{:});
    otherwise
        error('Unsupported Case 9 helper action: %s', action);
end
end

function [sourcePairs, pairSelection] = local_source_pairs(caseCfg, ctx, calAnglesDeg)
thetaGrid = ctx.thetaDeg;
if isfield(caseCfg, 'sourcePairsDeg') && ~isempty(caseCfg.sourcePairsDeg)
    candidatePairs = caseCfg.sourcePairsDeg;
else
    candidatePairs = local_generate_pairs(thetaGrid, caseCfg.separationSweepDeg);
end

sourcePairs = local_filter_pairs(candidatePairs, thetaGrid, calAnglesDeg);
if isempty(sourcePairs)
    sourcePairs = local_filter_pairs(candidatePairs, thetaGrid);
end

sourcePairs = sort(sourcePairs, 2);
sourcePairs = unique(sourcePairs, 'rows', 'stable');
separationDeg = sourcePairs(:, 2) - sourcePairs(:, 1);
pairCenterDeg = mean(sourcePairs, 2);
sourcePairs = sortrows([sourcePairs, separationDeg, pairCenterDeg], [3 4 1 2]);
sourcePairs = sourcePairs(:, 1:2);
preLimitPairs = sourcePairs;

if isfield(caseCfg, 'maxPairsPerSeparation') && ~isempty(caseCfg.maxPairsPerSeparation) && ...
        isfinite(caseCfg.maxPairsPerSeparation) && caseCfg.maxPairsPerSeparation > 0
    selectionMode = local_optional_field(caseCfg, 'pairSelectionMode', 'research_coverage');
    [sourcePairs, selectedIdx] = local_limit_pairs_per_separation( ...
        sourcePairs, caseCfg.maxPairsPerSeparation, ctx, calAnglesDeg, selectionMode);
else
    selectionMode = 'none';
    selectedIdx = 1:size(sourcePairs, 1);
end

pairSelection = local_score_pairs(preLimitPairs, ctx, calAnglesDeg);
pairSelection.mode = selectionMode;
pairSelection.preLimitPairCount = size(preLimitPairs, 1);
pairSelection.selectedOriginalIndex = selectedIdx(:);
pairSelection = local_subset_pair_selection(pairSelection, selectedIdx);
end

function validPairs = local_filter_pairs(candidatePairs, thetaGrid, calAnglesDeg)
tolDeg = local_angle_tolerance_from_grid(thetaGrid);
snappedPairs = zeros(size(candidatePairs));
availableMask = false(size(candidatePairs, 1), 1);

for pairIdx = 1:size(candidatePairs, 1)
    [leftDistance, leftIdx] = min(abs(thetaGrid - candidatePairs(pairIdx, 1)));
    [rightDistance, rightIdx] = min(abs(thetaGrid - candidatePairs(pairIdx, 2)));
    if leftDistance <= tolDeg && rightDistance <= tolDeg
        snappedPairs(pairIdx, :) = [thetaGrid(leftIdx), thetaGrid(rightIdx)];
        availableMask(pairIdx) = true;
    end
end

validPairs = snappedPairs(availableMask, :);

if nargin >= 3 && ~isempty(calAnglesDeg)
    unseenMask = true(size(validPairs, 1), 1);
    for pairIdx = 1:size(validPairs, 1)
        touchesCal = any(abs(calAnglesDeg - validPairs(pairIdx, 1)) <= tolDeg) || ...
            any(abs(calAnglesDeg - validPairs(pairIdx, 2)) <= tolDeg);
        unseenMask(pairIdx) = ~touchesCal;
    end
    if any(unseenMask)
        validPairs = validPairs(unseenMask, :);
    end
end
end

function [sourcePairs, pairSelection, excludedCount] = local_exclude_task_pairs( ...
    sourcePairs, pairSelection, taskPairsDeg)
excludedCount = 0;
if isempty(taskPairsDeg) || isempty(sourcePairs)
    return;
end

taskPairsDeg = sort(round(taskPairsDeg, 10), 2);
sourceRounded = sort(round(sourcePairs, 10), 2);
keepMask = true(size(sourcePairs, 1), 1);
for pairIdx = 1:size(sourceRounded, 1)
    overlaps = all(abs(taskPairsDeg - sourceRounded(pairIdx, :)) < 1e-9, 2);
    if any(overlaps)
        keepMask(pairIdx) = false;
        excludedCount = excludedCount + 1;
    end
end

sourcePairs = sourcePairs(keepMask, :);
pairSelection = local_filter_pair_selection_by_mask(pairSelection, keepMask);
end

function overlapCount = local_count_task_eval_overlap(sourcePairs, taskPairsDeg)
overlapCount = 0;
if isempty(taskPairsDeg) || isempty(sourcePairs)
    return;
end

taskPairsDeg = sort(round(taskPairsDeg, 10), 2);
sourceRounded = sort(round(sourcePairs, 10), 2);
for pairIdx = 1:size(sourceRounded, 1)
    overlaps = all(abs(taskPairsDeg - sourceRounded(pairIdx, :)) < 1e-9, 2);
    if any(overlaps)
        overlapCount = overlapCount + 1;
    end
end
end

function pairSelection = local_filter_pair_selection_by_mask(pairSelection, keepMask)
fieldsToFilter = {'sourcePairsDeg', 'pairMismatchScore', 'edgeScore', ...
    'calDistanceScore', 'combinedScore', 'selectedOriginalIndex'};
for fieldIdx = 1:numel(fieldsToFilter)
    fieldName = fieldsToFilter{fieldIdx};
    if isfield(pairSelection, fieldName)
        values = pairSelection.(fieldName);
        if size(values, 1) == numel(keepMask)
            pairSelection.(fieldName) = values(keepMask, :);
        end
    end
end
pairSelection.taskExcludedCount = sum(~keepMask);
end

function candidatePairs = local_generate_pairs(thetaGrid, separationSweepDeg)
candidatePairs = zeros(0, 2);
tolDeg = local_angle_tolerance_from_grid(thetaGrid);

for sepDeg = reshape(separationSweepDeg, 1, [])
    for angleIdx = 1:numel(thetaGrid)
        partnerAngle = thetaGrid(angleIdx) + sepDeg;
        [distance, partnerIdx] = min(abs(thetaGrid - partnerAngle));
        if distance <= tolDeg
            candidatePairs(end+1, :) = [thetaGrid(angleIdx), thetaGrid(partnerIdx)]; %#ok<AGROW>
        end
    end
end
end

function [limitedPairs, selectedIdx] = local_limit_pairs_per_separation( ...
    sourcePairs, maxPairsPerSeparation, ctx, calAnglesDeg, selectionMode)
separationDeg = sourcePairs(:, 2) - sourcePairs(:, 1);
uniqueSep = unique(round(separationDeg, 10), 'sorted');
limitedPairs = zeros(0, 2);
selectedIdx = zeros(0, 1);
useResearchCoverage = strcmpi(selectionMode, 'research_coverage');
if useResearchCoverage
    scores = local_score_pairs(sourcePairs, ctx, calAnglesDeg);
end

for sepIdx = 1:numel(uniqueSep)
    pairIdx = find(abs(separationDeg - uniqueSep(sepIdx)) < 1e-9);
    if numel(pairIdx) > maxPairsPerSeparation
        if useResearchCoverage
            pairIdx = local_research_coverage_indices(pairIdx, scores, sourcePairs, maxPairsPerSeparation);
        else
            pickLocal = unique(round(linspace(1, numel(pairIdx), maxPairsPerSeparation)));
            pairIdx = pairIdx(pickLocal);
        end
    end
    limitedPairs = [limitedPairs; sourcePairs(pairIdx, :)]; %#ok<AGROW>
    selectedIdx = [selectedIdx; pairIdx(:)]; %#ok<AGROW>
end
end

function pairSelection = local_score_pairs(sourcePairs, ctx, calAnglesDeg)
leftIdx = local_angle_indices(ctx.thetaDeg, sourcePairs(:, 1));
rightIdx = local_angle_indices(ctx.thetaDeg, sourcePairs(:, 2));
leftMetrics = compute_manifold_metrics(ctx.AH(:, leftIdx), ctx.AI(:, leftIdx));
rightMetrics = compute_manifold_metrics(ctx.AH(:, rightIdx), ctx.AI(:, rightIdx));

maxAbsAngle = max(abs(ctx.thetaDeg));
if maxAbsAngle <= 0
    maxAbsAngle = 1;
end

pairMismatchScore = (leftMetrics.relativeError(:) + rightMetrics.relativeError(:)) / 2;
edgeScore = max(abs(sourcePairs), [], 2) / maxAbsAngle;

if nargin < 3 || isempty(calAnglesDeg)
    calDistanceScore = ones(size(pairMismatchScore));
else
    calDistance = zeros(size(pairMismatchScore));
    for pairIdx = 1:size(sourcePairs, 1)
        leftDistance = min(abs(calAnglesDeg(:) - sourcePairs(pairIdx, 1)));
        rightDistance = min(abs(calAnglesDeg(:) - sourcePairs(pairIdx, 2)));
        calDistance(pairIdx) = min(leftDistance, rightDistance);
    end
    calDistanceScore = min(calDistance / maxAbsAngle, 1);
end

combinedScore = 0.55 * pairMismatchScore + 0.30 * edgeScore + 0.15 * calDistanceScore;

pairSelection = struct();
pairSelection.mode = 'research_coverage';
pairSelection.sourcePairsDeg = sourcePairs;
pairSelection.pairMismatchScore = pairMismatchScore;
pairSelection.edgeScore = edgeScore;
pairSelection.calDistanceScore = calDistanceScore;
pairSelection.combinedScore = combinedScore;
pairSelection.weights = [0.55 0.30 0.15];
end

function subsetSelection = local_subset_pair_selection(pairSelection, selectedIdx)
subsetSelection = pairSelection;
fieldsToSubset = {'sourcePairsDeg', 'pairMismatchScore', 'edgeScore', ...
    'calDistanceScore', 'combinedScore'};
for fieldIdx = 1:numel(fieldsToSubset)
    fieldName = fieldsToSubset{fieldIdx};
    values = pairSelection.(fieldName);
    if size(values, 1) == numel(pairSelection.combinedScore)
        subsetSelection.(fieldName) = values(selectedIdx, :);
    end
end
end

function selectedIdx = local_research_coverage_indices(pairIdx, scores, sourcePairs, maxPairsPerSeparation)
selectedIdx = zeros(0, 1);

[~, combinedOrder] = sort(scores.combinedScore(pairIdx), 'descend');
combinedPick = pairIdx(combinedOrder(1:min(9, min(maxPairsPerSeparation, numel(combinedOrder)))));
selectedIdx = local_append_unique_indices(selectedIdx, combinedPick);

remainingSlots = maxPairsPerSeparation - numel(selectedIdx);
if remainingSlots > 0
    [~, edgeOrder] = sort(scores.edgeScore(pairIdx), 'descend');
    edgePick = pairIdx(edgeOrder(1:min(6, min(remainingSlots, numel(edgeOrder)))));
    selectedIdx = local_append_unique_indices(selectedIdx, edgePick);
end

while numel(selectedIdx) < maxPairsPerSeparation
    remaining = setdiff(pairIdx(:), selectedIdx(:), 'stable');
    if isempty(remaining)
        break;
    end
    nextIdx = local_next_farthest_center_idx(remaining, selectedIdx, sourcePairs, scores);
    selectedIdx = local_append_unique_indices(selectedIdx, nextIdx);
end

selectedIdx = sort(selectedIdx(:));
end

function selectedIdx = local_append_unique_indices(selectedIdx, newIdx)
for idx = reshape(newIdx, 1, [])
    if ~ismember(idx, selectedIdx)
        selectedIdx(end+1, 1) = idx; %#ok<AGROW>
    end
end
end

function nextIdx = local_next_farthest_center_idx(remaining, selectedIdx, sourcePairs, scores)
centers = mean(sourcePairs, 2);
if isempty(selectedIdx)
    [~, localIdx] = max(scores.combinedScore(remaining));
    nextIdx = remaining(localIdx);
    return;
end

selectedCenters = centers(selectedIdx);
minDistance = zeros(numel(remaining), 1);
for idx = 1:numel(remaining)
    minDistance(idx) = min(abs(centers(remaining(idx)) - selectedCenters));
end

tieBreaker = scores.combinedScore(remaining);
rankScore = minDistance + 1e-3 * tieBreaker;
[~, localIdx] = max(rankScore);
nextIdx = remaining(localIdx);
end

function pairLabels = local_pair_labels(sourcePairs)
pairLabels = arrayfun(@(rowIdx) sprintf('[%g,%g]', sourcePairs(rowIdx, 1), sourcePairs(rowIdx, 2)), ...
    1:size(sourcePairs, 1), 'UniformOutput', false);
end

function [uniqueSep, meanMetric, stdMetric] = local_group_metric(separationDeg, metricMatrix)
separationDeg = round(separationDeg, 10);
uniqueSep = unique(separationDeg, 'sorted');
meanMetric = zeros(numel(uniqueSep), size(metricMatrix, 2));
stdMetric = zeros(numel(uniqueSep), size(metricMatrix, 2));

for sepIdx = 1:numel(uniqueSep)
    pairMask = abs(separationDeg - uniqueSep(sepIdx)) < 1e-9;
    meanMetric(sepIdx, :) = mean(metricMatrix(pairMask, :), 1);
    stdMetric(sepIdx, :) = std(metricMatrix(pairMask, :), 0, 1);
end
end

function [deltaResolution, deltaStable] = local_v3_delta_from_ard(methods, resolutionMean, stableMean)
deltaResolution = [];
deltaStable = [];
ardIdx = find(strcmp({methods.name}, 'ard'), 1, 'first');
v3Idx = find(strcmp({methods.name}, 'proposed_v3'), 1, 'first');
if isempty(ardIdx) || isempty(v3Idx)
    return;
end
deltaResolution = resolutionMean(:, v3Idx) - resolutionMean(:, ardIdx);
deltaStable = stableMean(:, v3Idx) - stableMean(:, ardIdx);
end

function summary = local_subset_summary(methods, pairMask, resolutionProb, stableRate, ...
    pairRmse, marginalRate, biasedRate, unresolvedRate)
pairMask = pairMask(:);
summary = struct();
summary.methodLabels = {methods.label};
summary.pairCount = sum(pairMask);
summary.meanResolution = NaN(1, numel(methods));
summary.meanStable = NaN(1, numel(methods));
summary.meanPairRmse = NaN(1, numel(methods));
summary.meanMarginal = NaN(1, numel(methods));
summary.meanBiased = NaN(1, numel(methods));
summary.meanUnresolved = NaN(1, numel(methods));
if ~any(pairMask)
    return;
end
summary.meanResolution = mean(resolutionProb(pairMask, :), 1);
summary.meanStable = mean(stableRate(pairMask, :), 1);
summary.meanPairRmse = mean(pairRmse(pairMask, :), 1);
summary.meanMarginal = mean(marginalRate(pairMask, :), 1);
summary.meanBiased = mean(biasedRate(pairMask, :), 1);
summary.meanUnresolved = mean(unresolvedRate(pairMask, :), 1);
end

function diagnostics = local_v1_experience_diagnostics(methods, overallSummary, ...
    discriminativeSummary, uniqueSep, resolutionMean, stableMean)
diagnostics = struct();
diagnostics.note = ['Proposed V1 remains a useful reference because its low-order global ' ...
    'phase residual can improve two-source peak selection without task-specific leakage.'];
diagnostics.uniqueSeparationDeg = uniqueSep;
diagnostics.v1Idx = find(strcmp({methods.name}, 'proposed_v1'), 1, 'first');
diagnostics.ardIdx = find(strcmp({methods.name}, 'ard'), 1, 'first');
diagnostics.v3Idx = find(strcmp({methods.name}, 'proposed_v3'), 1, 'first');
diagnostics.v1MinusArdStableBySeparation = [];
diagnostics.v3MinusV1StableBySeparation = [];
diagnostics.v1MinusArdResolutionBySeparation = [];
diagnostics.v3MinusV1ResolutionBySeparation = [];
diagnostics.overallV1MinusArdStable = NaN;
diagnostics.discriminativeV1MinusArdStable = NaN;
diagnostics.overallV3MinusV1Stable = NaN;
diagnostics.discriminativeV3MinusV1Stable = NaN;
if isempty(diagnostics.v1Idx) || isempty(diagnostics.ardIdx)
    return;
end

diagnostics.v1MinusArdStableBySeparation = ...
    stableMean(:, diagnostics.v1Idx) - stableMean(:, diagnostics.ardIdx);
diagnostics.v1MinusArdResolutionBySeparation = ...
    resolutionMean(:, diagnostics.v1Idx) - resolutionMean(:, diagnostics.ardIdx);
diagnostics.overallV1MinusArdStable = ...
    overallSummary.meanStable(diagnostics.v1Idx) - overallSummary.meanStable(diagnostics.ardIdx);
diagnostics.discriminativeV1MinusArdStable = ...
    discriminativeSummary.meanStable(diagnostics.v1Idx) - discriminativeSummary.meanStable(diagnostics.ardIdx);

if isempty(diagnostics.v3Idx)
    return;
end
diagnostics.v3MinusV1StableBySeparation = ...
    stableMean(:, diagnostics.v3Idx) - stableMean(:, diagnostics.v1Idx);
diagnostics.v3MinusV1ResolutionBySeparation = ...
    resolutionMean(:, diagnostics.v3Idx) - resolutionMean(:, diagnostics.v1Idx);
diagnostics.overallV3MinusV1Stable = ...
    overallSummary.meanStable(diagnostics.v3Idx) - overallSummary.meanStable(diagnostics.v1Idx);
diagnostics.discriminativeV3MinusV1Stable = ...
    discriminativeSummary.meanStable(diagnostics.v3Idx) - discriminativeSummary.meanStable(diagnostics.v1Idx);
end

function histInfo = local_pair_stratum_hist(pairAnglesDeg, centerBinDeg)
histInfo = struct();
histInfo.centerBinDeg = centerBinDeg;
histInfo.keys = zeros(0, 2);
histInfo.counts = zeros(0, 1);
if isempty(pairAnglesDeg)
    return;
end
pairAnglesDeg = sort(round(pairAnglesDeg, 10), 2);
separationDeg = round(pairAnglesDeg(:, 2) - pairAnglesDeg(:, 1), 10);
centerBin = round(mean(pairAnglesDeg, 2) / max(centerBinDeg, eps));
[keys, ~, binId] = unique([separationDeg(:), centerBin(:)], 'rows');
histInfo.keys = keys;
histInfo.counts = accumarray(binId, 1, [size(keys, 1), 1], @sum, 0);
histInfo.centerDegApprox = keys(:, 2) * centerBinDeg;
end

function diagnostics = local_v3_stable_pair_diagnostics(models)
diagnostics = struct();
if isfield(models, 'v3Diagnostics') && ...
        isfield(models.v3Diagnostics, 'stablePairDiagnostics')
    diagnostics = models.v3Diagnostics.stablePairDiagnostics;
end
end

function [exampleIdx, reason] = local_select_example_pair( ...
    bench, methods, separationDeg, targetResolutionProb, pairSelection)
primaryIdx = find(strcmp({methods.name}, 'proposed_v3'), 1, 'first');
if isempty(primaryIdx)
    primaryIdx = find(strcmp({methods.name}, 'proposed_v2'), 1, 'first');
end
if isempty(primaryIdx)
    primaryIdx = find(strcmp({methods.name}, 'proposed'), 1, 'first');
end
if isempty(primaryIdx)
    primaryIdx = find(strcmp({methods.name}, 'proposed_v1'), 1, 'first');
end
if isempty(primaryIdx)
    primaryIdx = 1;
end
interpIdx = find(strcmp({methods.name}, 'interp'), 1, 'first');
v1Idx = find(strcmp({methods.name}, 'proposed_v1'), 1, 'first');
v2Idx = find(strcmp({methods.name}, 'proposed_v2'), 1, 'first');

primary = bench.methods(primaryIdx);
primaryLabel = methods(primaryIdx).label;
stateMatrix = [ ...
    primary.perTargetUnresolvedRate(:), ...
    primary.perTargetMarginalRate(:), ...
    primary.perTargetBiasedRate(:), ...
    primary.perTargetStableRate(:)];
stateEntropy = -sum(stateMatrix .* log(max(stateMatrix, eps)), 2);

mixedMask = primary.perTargetResolutionRate > 0.05 & primary.perTargetResolutionRate < 0.98;
mismatchScore = zeros(size(primary.perTargetResolutionRate(:)));
if nargin >= 5 && isfield(pairSelection, 'combinedScore')
    mismatchScore = pairSelection.combinedScore(:);
    mismatchScore = mismatchScore / max(max(mismatchScore), eps);
end

baselineStable = [];
baselineResolution = [];
baselineLabels = {};
if ~isempty(interpIdx)
    baselineStable(:, end+1) = bench.methods(interpIdx).perTargetStableRate(:);
    baselineResolution(:, end+1) = bench.methods(interpIdx).perTargetResolutionRate(:);
    baselineLabels{end+1} = methods(interpIdx).label;
end
if ~isempty(v1Idx) && v1Idx ~= primaryIdx
    baselineStable(:, end+1) = bench.methods(v1Idx).perTargetStableRate(:);
    baselineResolution(:, end+1) = bench.methods(v1Idx).perTargetResolutionRate(:);
    baselineLabels{end+1} = methods(v1Idx).label;
end
if ~isempty(v2Idx) && v2Idx ~= primaryIdx
    baselineStable(:, end+1) = bench.methods(v2Idx).perTargetStableRate(:);
    baselineResolution(:, end+1) = bench.methods(v2Idx).perTargetResolutionRate(:);
    baselineLabels{end+1} = methods(v2Idx).label;
end

if ~isempty(baselineStable)
    bestBaselineStable = max(baselineStable, [], 2);
    bestBaselineResolution = max(baselineResolution, [], 2);
    advantage = primary.perTargetStableRate(:) - bestBaselineStable + ...
        0.5 * (primary.perTargetResolutionRate(:) - bestBaselineResolution);
    candidateMask = mixedMask & advantage > 0.02;
    if any(candidateMask)
        candidateIdx = find(candidateMask);
        score = advantage(candidateIdx) + 0.4 * stateEntropy(candidateIdx) ...
            + 0.15 * mismatchScore(candidateIdx) - 0.02 * separationDeg(candidateIdx);
        [~, bestLocalIdx] = max(score);
        exampleIdx = candidateIdx(bestLocalIdx);
        reason = sprintf(['Selected [%g, %g] deg because %s improves stable/resolution ' ...
            'behavior over %s while remaining a mixed hard pair.'], ...
            bench.trueAngleSetsDeg(exampleIdx, 1), bench.trueAngleSetsDeg(exampleIdx, 2), ...
            primaryLabel, strjoin(baselineLabels, '/'));
        return;
    end
end

candidateMask = mixedMask;
if ~any(candidateMask)
    candidateMask = true(size(primary.perTargetResolutionRate));
end

candidateIdx = find(candidateMask);
score = 0.45 * mismatchScore(candidateIdx) + 0.35 * stateEntropy(candidateIdx) ...
    - abs(primary.perTargetResolutionRate(candidateIdx) - targetResolutionProb) ...
    - 0.02 * separationDeg(candidateIdx);
[~, bestLocalIdx] = max(score);
exampleIdx = candidateIdx(bestLocalIdx);
reason = sprintf(['Selected [%g, %g] deg as the hardest available high-mismatch pair; ' ...
    'no stable %s-over-baseline advantage pair was found in this run.'], ...
    bench.trueAngleSetsDeg(exampleIdx, 1), bench.trueAngleSetsDeg(exampleIdx, 2), primaryLabel);
end

function idx = local_angle_indices(thetaDeg, queryAngles)
idx = zeros(size(queryAngles));
for angleIdx = 1:numel(queryAngles)
    idx(angleIdx) = local_angle_index(thetaDeg, queryAngles(angleIdx));
end
end

function idx = local_angle_index(thetaDeg, queryAngle)
[distance, idx] = min(abs(thetaDeg - queryAngle));
tolDeg = local_angle_tolerance_from_grid(thetaDeg);
if distance > tolDeg
    error('Angle %.6f deg is %.6f deg away from the nearest grid point, exceeding tolerance %.6f deg.', ...
        queryAngle, distance, tolDeg);
end
end

function tolDeg = local_angle_tolerance_from_grid(thetaDeg)
if numel(thetaDeg) > 1
    tolDeg = median(diff(sort(thetaDeg))) / 2 + 1e-9;
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
