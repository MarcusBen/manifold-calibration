# Case11 Enhanced Backend Diagnostic Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a separate Case11 enhanced-backend diagnostic that compares MUSIC, MUSIC pair-rescoring, and pairwise grid ML under common HFSS-truth snapshots to determine whether MUSIC is the Case9 bottleneck.

**Architecture:** Keep `benchmark_music` and Case9 unchanged as the official baseline. Add a backend-agnostic two-source benchmark in `src/benchmark_doa_backends.m`, two backend functions in focused files, and a new `case11_backend_diagnostic` runner in `run_project.m`. Use the existing traceable result layout, existing method construction, and current stable/biased/marginal/unresolved classification semantics.

**Tech Stack:** MATLAB R2024b-compatible code, base MATLAB only for the required path, existing project helpers (`setup_paths`, `default_config`, `build_project_context`, `build_sparse_models`, `save_figure`, `case09_helpers`), optional local `git` commands when a `.git` directory exists.

---

## File Structure

- Create `src/doa_backend_music_baseline.m`
  - One responsibility: current grid MUSIC estimator as a callable backend.
  - Returns estimated angles, score spectrum, covariance, and diagnostics.

- Create `src/doa_backend_music_pair_rescore.m`
  - One responsibility: compute MUSIC spectrum, collect candidate peaks, enumerate peak pairs, and choose the covariance-fitting best pair.
  - No random generation inside this file.

- Create `src/doa_backend_pairwise_grid_ml.m`
  - One responsibility: enumerate candidate angle pairs and choose the covariance-fitting best pair.
  - Base MATLAB only; no CVX or external solver.

- Create `src/doa_backend_utils.m`
  - One responsibility: shared backend utilities through a dispatcher.
  - Shared functions: covariance model scoring, peak picking, angle snapping, pair classification, snapshot simulation, result struct helpers.

- Create `src/benchmark_doa_backends.m`
  - One responsibility: common snapshot benchmark across backends and methods.
  - Mirrors the common-snapshot policy from `benchmark_music` but supports multiple backend functions and metric arrays with dimensions `(backend, pair, method)`.

- Modify `tests/run_sanity_tests.m`
  - Add backend sanity tests.
  - Keep existing tests intact.

- Modify `default_config.m`
  - Add `cfg.case11` defaults for the backend diagnostic smoke.

- Modify `run_project.m`
  - Add Case11 to `caseRunners` and `caseFolderNames`.
  - Change valid case range from `[1, 10]` to `[1, 11]`.
  - Add `case11_backend_diagnostic`.
  - Reuse existing `local_named_methods` with `cfg.case11.methodKeys`.

- Update `docs/research-log.md` after validation and Case11 smoke.

## Task 1: Backend Utility Dispatcher

**Files:**
- Create: `src/doa_backend_utils.m`
- Test: `tests/run_sanity_tests.m`

- [ ] **Step 1: Write the failing tests**

Append these calls after `local_test_common_snapshot_policy(ctx);` in `tests/run_sanity_tests.m`:

```matlab
local_test_backend_utils_covariance_fit(ctx);
local_test_backend_utils_classification();
```

Append these local test functions before `local_simulate_snapshots`:

```matlab
function local_test_backend_utils_covariance_fit(ctx)
idx = [local_angle_index(ctx.thetaDeg, -20), local_angle_index(ctx.thetaDeg, 15)];
aPair = ctx.AH(:, idx);
sourcePower = [1.5; 0.7];
noisePower = 0.05;
covariance = aPair * diag(sourcePower) * aPair' + noisePower * eye(ctx.numElements);
[score, fit] = doa_backend_utils('covariance_score', covariance, aPair);
local_assert_true(score < 1e-10, sprintf('backend covariance fit score=%g', score));
local_assert_close(fit.sourcePower(:), sourcePower, 1e-8, 'backend covariance source powers');
local_assert_close(fit.noisePower, noisePower, 1e-8, 'backend covariance noise power');
end

function local_test_backend_utils_classification()
stateCfg = struct('stableToleranceDeg', 0.6, 'biasedToleranceDeg', 2, 'marginalToleranceDeg', 5);
stable = doa_backend_utils('classify_double', [23.8 31.8], [23.8 31.8], stateCfg);
biased = doa_backend_utils('classify_double', [24.8 32.6], [23.8 31.8], stateCfg);
collapsed = doa_backend_utils('separation_collapsed', [27.0 28.0], [23.8 31.8]);
local_assert_true(stable.isStable && stable.isResolved, 'backend stable classification');
local_assert_true(biased.isBiased && biased.isResolved, 'backend biased classification');
local_assert_true(collapsed, 'backend separation collapse diagnostic');
end
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
matlab -batch "addpath(genpath(pwd)); run_sanity_tests"
```

Expected: FAIL with `Undefined function 'doa_backend_utils'`.

- [ ] **Step 3: Write minimal implementation**

Create `src/doa_backend_utils.m`:

```matlab
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
    [~, peakIdx] = maxk(spectrum, min(maxPeaks, numPoints));
else
    peakIdx = local_reduce_plateau_peaks(peakIdx, spectrum);
    [~, order] = sort(spectrum(peakIdx), 'descend');
    peakIdx = peakIdx(order);
    peakIdx = peakIdx(1:min(maxPeaks, numel(peakIdx)));
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

function isCollapsed = local_is_separation_collapsed(estAngles, trueAngles)
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
matlab -batch "addpath(genpath(pwd)); run_sanity_tests"
```

Expected: PASS for all existing tests plus:

```text
PASS: backend covariance fit score=...
PASS: backend covariance source powers
PASS: backend covariance noise power
PASS: backend stable classification
PASS: backend biased classification
PASS: backend separation collapse diagnostic
```

- [ ] **Step 5: Commit or record no-git state**

Run:

```bash
git status --short
```

Expected in this local directory:

```text
fatal: not a git repository (or any of the parent directories): .git
```

Record this in the final implementation notes instead of committing.

## Task 2: Baseline MUSIC Backend Function

**Files:**
- Create: `src/doa_backend_music_baseline.m`
- Test: `tests/run_sanity_tests.m`

- [ ] **Step 1: Write the failing test**

Append this call after `local_test_backend_utils_classification();`:

```matlab
local_test_music_backend_baseline(ctx);
```

Append this local test before `local_simulate_snapshots`:

```matlab
function local_test_music_backend_baseline(ctx)
rng(9301, 'twister');
idx = [local_angle_index(ctx.thetaDeg, -20), local_angle_index(ctx.thetaDeg, 15)];
x = local_simulate_snapshots(ctx.AH(:, idx), 40, 1200);
backendCfg = struct('numSources', 2);
result = doa_backend_music_baseline(x, ctx.AH, ctx.thetaDeg, backendCfg);
local_assert_true(all(abs(result.estAnglesDeg - [-20 15]) <= 0.4), ...
    'baseline backend MUSIC recovers high-SNR oracle pair');
local_assert_equal(numel(result.spectrum), numel(ctx.thetaDeg), ...
    'baseline backend MUSIC spectrum length');
end
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
matlab -batch "addpath(genpath(pwd)); run_sanity_tests"
```

Expected: FAIL with `Undefined function 'doa_backend_music_baseline'`.

- [ ] **Step 3: Write implementation**

Create `src/doa_backend_music_baseline.m`:

```matlab
function result = doa_backend_music_baseline(x, scanManifold, scanAnglesDeg, backendCfg)
%DOA_BACKEND_MUSIC_BASELINE Current grid MUSIC estimator as a backend.

numSources = local_optional_field(backendCfg, 'numSources', 2);
covariance = (x * x') / size(x, 2);
spectrum = doa_backend_utils('music_spectrum', covariance, scanManifold, numSources);
peakIdx = doa_backend_utils('pick_local_peaks', spectrum, max(numSources + 8, 12));

if numel(peakIdx) < numSources
    [~, fallbackIdx] = maxk(spectrum, min(numSources + 8, numel(spectrum)));
    peakIdx = unique([peakIdx(:); fallbackIdx(:)], 'stable');
end

selectedIdx = zeros(1, 0);
for candidate = reshape(peakIdx, 1, [])
    if ~ismember(candidate, selectedIdx)
        selectedIdx(end+1) = candidate; %#ok<AGROW>
    end
    if numel(selectedIdx) == numSources
        break;
    end
end

if numel(selectedIdx) < numSources
    [~, allOrder] = maxk(spectrum, min(numSources, numel(spectrum)));
    selectedIdx = allOrder(:).';
end

result = struct();
result.name = 'music';
result.estAnglesDeg = sort(scanAnglesDeg(selectedIdx(1:numSources)));
result.spectrum = spectrum;
result.covariance = covariance;
result.diagnostics = struct();
result.diagnostics.selectedGridIndex = selectedIdx(1:numSources);
result.diagnostics.selectedSpectrumValue = spectrum(selectedIdx(1:numSources));
end

function value = local_optional_field(inputStruct, fieldName, defaultValue)
if isfield(inputStruct, fieldName) && ~isempty(inputStruct.(fieldName))
    value = inputStruct.(fieldName);
else
    value = defaultValue;
end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
matlab -batch "addpath(genpath(pwd)); run_sanity_tests"
```

Expected: PASS, including `PASS: baseline backend MUSIC recovers high-SNR oracle pair`.

- [ ] **Step 5: Commit or record no-git state**

Run:

```bash
git status --short
```

Expected in this local directory: fatal not-a-git-repo message. Record no commit was possible.

## Task 3: MUSIC Pair-Rescore Backend

**Files:**
- Create: `src/doa_backend_music_pair_rescore.m`
- Test: `tests/run_sanity_tests.m`

- [ ] **Step 1: Write the failing test**

Append this call after `local_test_music_backend_baseline(ctx);`:

```matlab
local_test_music_pair_rescore_backend(ctx);
```

Append this local test before `local_simulate_snapshots`:

```matlab
function local_test_music_pair_rescore_backend(ctx)
rng(9302, 'twister');
idx = [local_angle_index(ctx.thetaDeg, -20), local_angle_index(ctx.thetaDeg, 15)];
x = local_simulate_snapshots(ctx.AH(:, idx), 35, 1200);
backendCfg = struct('numSources', 2, 'candidatePeakCount', 10, 'minimumSeparationDeg', 2);
result = doa_backend_music_pair_rescore(x, ctx.AH, ctx.thetaDeg, backendCfg);
local_assert_true(all(abs(result.estAnglesDeg - [-20 15]) <= 0.6), ...
    'pair-rescore backend recovers high-SNR oracle pair');
local_assert_true(isfield(result.diagnostics, 'topCandidatePairsDeg'), ...
    'pair-rescore backend saves top candidates');
local_assert_true(size(result.diagnostics.topCandidatePairsDeg, 2) == 2, ...
    'pair-rescore candidate pairs have two columns');
end
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
matlab -batch "addpath(genpath(pwd)); run_sanity_tests"
```

Expected: FAIL with `Undefined function 'doa_backend_music_pair_rescore'`.

- [ ] **Step 3: Write implementation**

Create `src/doa_backend_music_pair_rescore.m`:

```matlab
function result = doa_backend_music_pair_rescore(x, scanManifold, scanAnglesDeg, backendCfg)
%DOA_BACKEND_MUSIC_PAIR_RESCORE Rescore MUSIC peak pairs by covariance fit.

numSources = local_optional_field(backendCfg, 'numSources', 2);
if numSources ~= 2
    error('MUSIC pair-rescore backend supports exactly two sources.');
end
candidatePeakCount = local_optional_field(backendCfg, 'candidatePeakCount', 12);
minimumSeparationDeg = local_optional_field(backendCfg, 'minimumSeparationDeg', 0);
topCandidateCount = local_optional_field(backendCfg, 'topCandidateCount', 8);

covariance = (x * x') / size(x, 2);
spectrum = doa_backend_utils('music_spectrum', covariance, scanManifold, numSources);
peakIdx = doa_backend_utils('pick_local_peaks', spectrum, candidatePeakCount);
if numel(peakIdx) < 2
    [~, peakIdx] = maxk(spectrum, min(candidatePeakCount, numel(spectrum)));
end

[pairIdx, pairAnglesDeg] = local_candidate_pairs(peakIdx, scanAnglesDeg, minimumSeparationDeg);
if isempty(pairIdx)
    [~, fallbackIdx] = maxk(spectrum, 2);
    pairIdx = sort(fallbackIdx(:).');
    pairAnglesDeg = sort(scanAnglesDeg(pairIdx));
end

scores = zeros(size(pairIdx, 1), 1);
fits = cell(size(pairIdx, 1), 1);
for pairRow = 1:size(pairIdx, 1)
    [scores(pairRow), fits{pairRow}] = doa_backend_utils( ...
        'covariance_score', covariance, scanManifold(:, pairIdx(pairRow, :)));
end

[bestScore, bestRow] = min(scores);
[sortedScores, order] = sort(scores, 'ascend');
topRows = order(1:min(topCandidateCount, numel(order)));

result = struct();
result.name = 'music_pair_rescore';
result.estAnglesDeg = sort(pairAnglesDeg(bestRow, :));
result.spectrum = spectrum;
result.covariance = covariance;
result.diagnostics = struct();
result.diagnostics.peakIdx = peakIdx(:);
result.diagnostics.peakAnglesDeg = scanAnglesDeg(peakIdx(:));
result.diagnostics.bestScore = bestScore;
result.diagnostics.bestFit = fits{bestRow};
result.diagnostics.topCandidatePairsDeg = pairAnglesDeg(topRows, :);
result.diagnostics.topCandidateScores = sortedScores(1:numel(topRows));
end

function [pairIdx, pairAnglesDeg] = local_candidate_pairs(peakIdx, scanAnglesDeg, minimumSeparationDeg)
pairIdx = zeros(0, 2);
pairAnglesDeg = zeros(0, 2);
for left = 1:numel(peakIdx)-1
    for right = left+1:numel(peakIdx)
        candidateIdx = sort([peakIdx(left), peakIdx(right)]);
        candidateAngles = sort(scanAnglesDeg(candidateIdx));
        if abs(diff(candidateAngles)) >= minimumSeparationDeg
            pairIdx(end+1, :) = candidateIdx; %#ok<AGROW>
            pairAnglesDeg(end+1, :) = candidateAngles; %#ok<AGROW>
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
matlab -batch "addpath(genpath(pwd)); run_sanity_tests"
```

Expected: PASS, including pair-rescore candidate diagnostics.

- [ ] **Step 5: Commit or record no-git state**

Run `git status --short`; record not-a-git-repo if it remains fatal.

## Task 4: Pairwise Grid ML Backend

**Files:**
- Create: `src/doa_backend_pairwise_grid_ml.m`
- Test: `tests/run_sanity_tests.m`

- [ ] **Step 1: Write the failing test**

Append this call after `local_test_music_pair_rescore_backend(ctx);`:

```matlab
local_test_pairwise_grid_ml_backend(ctx);
```

Append this local test before `local_simulate_snapshots`:

```matlab
function local_test_pairwise_grid_ml_backend(ctx)
rng(9303, 'twister');
idx = [local_angle_index(ctx.thetaDeg, -20), local_angle_index(ctx.thetaDeg, 15)];
x = local_simulate_snapshots(ctx.AH(:, idx), 35, 1200);
backendCfg = struct('numSources', 2, 'candidateAnglesDeg', -30:1:30, ...
    'minimumSeparationDeg', 2, 'maximumSeparationDeg', 50, 'topCandidateCount', 8);
result = doa_backend_pairwise_grid_ml(x, ctx.AH, ctx.thetaDeg, backendCfg);
local_assert_true(all(abs(result.estAnglesDeg - [-20 15]) <= 1.0), ...
    'pairwise grid ML backend recovers high-SNR oracle pair');
local_assert_true(isfield(result.diagnostics, 'topCandidatePairsDeg'), ...
    'pairwise grid ML saves top candidates');
local_assert_true(result.diagnostics.bestScore <= result.diagnostics.topCandidateScores(end), ...
    'pairwise grid ML top scores sorted');
end
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
matlab -batch "addpath(genpath(pwd)); run_sanity_tests"
```

Expected: FAIL with `Undefined function 'doa_backend_pairwise_grid_ml'`.

- [ ] **Step 3: Write implementation**

Create `src/doa_backend_pairwise_grid_ml.m`:

```matlab
function result = doa_backend_pairwise_grid_ml(x, scanManifold, scanAnglesDeg, backendCfg)
%DOA_BACKEND_PAIRWISE_GRID_ML Two-source covariance-fitting grid search.

numSources = local_optional_field(backendCfg, 'numSources', 2);
if numSources ~= 2
    error('Pairwise grid ML backend supports exactly two sources.');
end

minimumSeparationDeg = local_optional_field(backendCfg, 'minimumSeparationDeg', 0);
maximumSeparationDeg = local_optional_field(backendCfg, 'maximumSeparationDeg', Inf);
topCandidateCount = local_optional_field(backendCfg, 'topCandidateCount', 10);
candidateAnglesDeg = local_optional_field(backendCfg, 'candidateAnglesDeg', scanAnglesDeg);
candidateIdx = local_candidate_indices(scanAnglesDeg, candidateAnglesDeg);

covariance = (x * x') / size(x, 2);
pairIdx = local_pair_indices(scanAnglesDeg, candidateIdx, minimumSeparationDeg, maximumSeparationDeg);
if isempty(pairIdx)
    error('Pairwise grid ML found no candidate pairs under the configured separation constraints.');
end

scores = zeros(size(pairIdx, 1), 1);
fits = cell(size(pairIdx, 1), 1);
for pairRow = 1:size(pairIdx, 1)
    [scores(pairRow), fits{pairRow}] = doa_backend_utils( ...
        'covariance_score', covariance, scanManifold(:, pairIdx(pairRow, :)));
end

[bestScore, bestRow] = min(scores);
[sortedScores, order] = sort(scores, 'ascend');
topRows = order(1:min(topCandidateCount, numel(order)));
pairAnglesDeg = sort(scanAnglesDeg(pairIdx), 2);

result = struct();
result.name = 'pairwise_grid_ml';
result.estAnglesDeg = pairAnglesDeg(bestRow, :);
result.spectrum = [];
result.covariance = covariance;
result.diagnostics = struct();
result.diagnostics.bestScore = bestScore;
result.diagnostics.bestFit = fits{bestRow};
result.diagnostics.bestGridIndex = pairIdx(bestRow, :);
result.diagnostics.candidatePairCount = size(pairIdx, 1);
result.diagnostics.topCandidatePairsDeg = pairAnglesDeg(topRows, :);
result.diagnostics.topCandidateScores = sortedScores(1:numel(topRows));
result.diagnostics.refinementUsed = false;
end

function candidateIdx = local_candidate_indices(scanAnglesDeg, candidateAnglesDeg)
candidateIdx = zeros(numel(candidateAnglesDeg), 1);
tolDeg = local_angle_tolerance_from_grid(scanAnglesDeg);
for idx = 1:numel(candidateAnglesDeg)
    [distance, nearestIdx] = min(abs(scanAnglesDeg - candidateAnglesDeg(idx)));
    if distance <= tolDeg
        candidateIdx(idx) = nearestIdx;
    end
end
candidateIdx = unique(candidateIdx(candidateIdx > 0), 'stable');
end

function pairIdx = local_pair_indices(scanAnglesDeg, candidateIdx, minimumSeparationDeg, maximumSeparationDeg)
pairIdx = zeros(0, 2);
for left = 1:numel(candidateIdx)-1
    for right = left+1:numel(candidateIdx)
        idxPair = sort([candidateIdx(left), candidateIdx(right)]);
        sepDeg = abs(diff(scanAnglesDeg(idxPair)));
        if sepDeg >= minimumSeparationDeg && sepDeg <= maximumSeparationDeg
            pairIdx(end+1, :) = idxPair; %#ok<AGROW>
        end
    end
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
matlab -batch "addpath(genpath(pwd)); run_sanity_tests"
```

Expected: PASS, including `PASS: pairwise grid ML backend recovers high-SNR oracle pair`.

- [ ] **Step 5: Commit or record no-git state**

Run `git status --short`; record not-a-git-repo if it remains fatal.

## Task 5: Backend Benchmark Framework

**Files:**
- Create: `src/benchmark_doa_backends.m`
- Test: `tests/run_sanity_tests.m`

- [ ] **Step 1: Write the failing tests**

Append these calls after `local_test_pairwise_grid_ml_backend(ctx);`:

```matlab
local_test_backend_benchmark_common_snapshots(ctx);
local_test_backend_benchmark_shapes(ctx);
```

Append these local tests before `local_simulate_snapshots`:

```matlab
function local_test_backend_benchmark_common_snapshots(ctx)
rng(9304, 'twister');
methods = repmat(struct('name', '', 'label', '', 'manifold', []), 1, 2);
methods(1) = struct('name', 'oracle_a', 'label', 'Oracle A', 'manifold', ctx.AH);
methods(2) = struct('name', 'oracle_b', 'label', 'Oracle B', 'manifold', ctx.AH);
evalCfg = local_backend_test_eval_cfg();
backendCfg = local_backend_test_backend_cfg(ctx);
bench = benchmark_doa_backends(ctx, methods, evalCfg, backendCfg);
local_assert_equal(bench.snapshotPolicy, 'common_truth_snapshots_across_backends_and_methods', ...
    'backend benchmark common snapshot policy');
local_assert_true(isequaln(bench.rmse(:, :, 1), bench.rmse(:, :, 2)), ...
    'backend benchmark identical methods share RMSE');
local_assert_true(isequaln(bench.stableRate(:, :, 1), bench.stableRate(:, :, 2)), ...
    'backend benchmark identical methods share stable rates');
end

function local_test_backend_benchmark_shapes(ctx)
rng(9305, 'twister');
methods = struct('name', 'oracle', 'label', 'HFSS Oracle', 'manifold', ctx.AH);
evalCfg = local_backend_test_eval_cfg();
backendCfg = local_backend_test_backend_cfg(ctx);
bench = benchmark_doa_backends(ctx, methods, evalCfg, backendCfg);
local_assert_equal(size(bench.rmse), [numel(backendCfg.backendNames), size(evalCfg.trueAngles, 1), 1], ...
    'backend benchmark metric dimensions');
local_assert_true(isfield(bench, 'backendDiagnostics'), 'backend benchmark diagnostics field');
end

function evalCfg = local_backend_test_eval_cfg()
evalCfg = struct('mode', 'double', 'trueAngles', [23.8 31.8; 35.8 45.8], ...
    'snrDb', 15, 'snapshots', 300, 'monteCarlo', 2, 'toleranceDeg', 0.6, ...
    'biasedToleranceDeg', 2, 'marginalToleranceDeg', 5, ...
    'collectRepresentative', true);
end

function backendCfg = local_backend_test_backend_cfg(ctx)
backendCfg = struct();
backendCfg.backendNames = {'music', 'music_pair_rescore', 'pairwise_grid_ml'};
backendCfg.candidatePeakCount = 8;
backendCfg.minimumSeparationDeg = 2;
backendCfg.maximumSeparationDeg = 30;
backendCfg.candidateAnglesDeg = unique([23.8 31.8 35.8 45.8 -30:2:50]);
backendCfg.topCandidateCount = 5;
backendCfg.numSources = 2;
backendCfg.scanAnglesDeg = ctx.thetaDeg;
end
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
matlab -batch "addpath(genpath(pwd)); run_sanity_tests"
```

Expected: FAIL with `Undefined function 'benchmark_doa_backends'`.

- [ ] **Step 3: Write implementation**

Create `src/benchmark_doa_backends.m`:

```matlab
function result = benchmark_doa_backends(ctx, methods, evalCfg, backendCfg)
%BENCHMARK_DOA_BACKENDS Compare two-source DOA backends with common snapshots.

modeName = lower(strtrim(evalCfg.mode));
if ~strcmp(modeName, 'double')
    error('benchmark_doa_backends currently supports double-source mode only.');
end

numSources = size(evalCfg.trueAngles, 2);
if numSources ~= 2
    error('benchmark_doa_backends expects exactly two sources.');
end

[trueAngleSets, trueIdxSets] = doa_backend_utils('snap_angle_sets', ctx.thetaDeg, evalCfg.trueAngles);
backendNames = backendCfg.backendNames;
numBackends = numel(backendNames);
numTargets = size(trueAngleSets, 1);
numMethods = numel(methods);
stateCfg = struct('stableToleranceDeg', evalCfg.toleranceDeg, ...
    'biasedToleranceDeg', evalCfg.biasedToleranceDeg, ...
    'marginalToleranceDeg', evalCfg.marginalToleranceDeg);

snapshotsByTarget = cell(numTargets, evalCfg.monteCarlo);
for targetIdx = 1:numTargets
    aTrue = ctx.AH(:, trueIdxSets(targetIdx, :));
    for mcIdx = 1:evalCfg.monteCarlo
        snapshotsByTarget{targetIdx, mcIdx} = doa_backend_utils( ...
            'simulate_snapshots', aTrue, evalCfg.snrDb, evalCfg.snapshots);
    end
end

trialRmse = zeros(numBackends, numTargets, numMethods, evalCfg.monteCarlo);
trialResolution = false(numBackends, numTargets, numMethods, evalCfg.monteCarlo);
trialMarginal = false(numBackends, numTargets, numMethods, evalCfg.monteCarlo);
trialBiased = false(numBackends, numTargets, numMethods, evalCfg.monteCarlo);
trialStable = false(numBackends, numTargets, numMethods, evalCfg.monteCarlo);
trialCollapse = false(numBackends, numTargets, numMethods, evalCfg.monteCarlo);
backendDiagnostics = cell(numBackends, numTargets, numMethods, evalCfg.monteCarlo);
representative = repmat(struct('estAnglesDeg', [], 'diagnostics', []), numBackends, numMethods);

for backendIdx = 1:numBackends
    for methodIdx = 1:numMethods
        for targetIdx = 1:numTargets
            trueAngles = sort(trueAngleSets(targetIdx, :));
            for mcIdx = 1:evalCfg.monteCarlo
                x = snapshotsByTarget{targetIdx, mcIdx};
                backendResult = local_run_backend(backendNames{backendIdx}, x, ...
                    methods(methodIdx).manifold, ctx.thetaDeg, backendCfg);
                estAngles = sort(backendResult.estAnglesDeg(:).');
                trialRmse(backendIdx, targetIdx, methodIdx, mcIdx) = ...
                    sqrt(mean((estAngles - trueAngles) .^ 2));
                state = doa_backend_utils('classify_double', estAngles, trueAngles, stateCfg);
                trialResolution(backendIdx, targetIdx, methodIdx, mcIdx) = state.isResolved;
                trialMarginal(backendIdx, targetIdx, methodIdx, mcIdx) = state.isMarginal;
                trialBiased(backendIdx, targetIdx, methodIdx, mcIdx) = state.isBiased;
                trialStable(backendIdx, targetIdx, methodIdx, mcIdx) = state.isStable;
                trialCollapse(backendIdx, targetIdx, methodIdx, mcIdx) = ...
                    doa_backend_utils('separation_collapsed', estAngles, trueAngles);
                backendDiagnostics{backendIdx, targetIdx, methodIdx, mcIdx} = backendResult.diagnostics;
                if local_collect_representative(evalCfg) && targetIdx == 1 && mcIdx == 1
                    representative(backendIdx, methodIdx).estAnglesDeg = estAngles;
                    representative(backendIdx, methodIdx).diagnostics = backendResult.diagnostics;
                end
            end
        end
    end
end

result = struct();
result.mode = modeName;
result.snapshotPolicy = 'common_truth_snapshots_across_backends_and_methods';
result.backendNames = backendNames;
result.methodLabels = {methods.label};
result.methodNames = {methods.name};
result.requestedAngleSetsDeg = evalCfg.trueAngles;
result.trueAngleSetsDeg = trueAngleSets;
result.rmse = mean(trialRmse, 4);
result.resolutionRate = mean(trialResolution, 4);
result.marginalRate = mean(trialMarginal, 4);
result.biasedRate = mean(trialBiased, 4);
result.stableRate = mean(trialStable, 4);
result.unresolvedRate = 1 - result.resolutionRate;
result.collapseRate = mean(trialCollapse, 4);
result.backendDiagnostics = backendDiagnostics;
result.representative = representative;
result.summary = local_summary(result);
end

function backendResult = local_run_backend(backendName, x, scanManifold, scanAnglesDeg, backendCfg)
switch lower(strtrim(backendName))
    case 'music'
        backendResult = doa_backend_music_baseline(x, scanManifold, scanAnglesDeg, backendCfg);
    case 'music_pair_rescore'
        backendResult = doa_backend_music_pair_rescore(x, scanManifold, scanAnglesDeg, backendCfg);
    case 'pairwise_grid_ml'
        backendResult = doa_backend_pairwise_grid_ml(x, scanManifold, scanAnglesDeg, backendCfg);
    otherwise
        error('Unknown DOA backend: %s', backendName);
end
end

function collect = local_collect_representative(evalCfg)
collect = isfield(evalCfg, 'collectRepresentative') && evalCfg.collectRepresentative;
end

function summary = local_summary(result)
musicIdx = find(strcmp(result.backendNames, 'music'), 1, 'first');
oracleIdx = find(strcmp(result.methodNames, 'oracle'), 1, 'first');
v3Idx = find(strcmp(result.methodNames, 'proposed_v3'), 1, 'first');
v1Idx = find(strcmp(result.methodNames, 'proposed_v1'), 1, 'first');

summary = struct();
summary.meanRmse = squeeze(mean(result.rmse, 2));
summary.meanResolution = squeeze(mean(result.resolutionRate, 2));
summary.meanStable = squeeze(mean(result.stableRate, 2));
summary.meanCollapse = squeeze(mean(result.collapseRate, 2));
summary.oracleGainOverMusic = NaN(numel(result.backendNames), 1);
summary.v3GainOverMusic = NaN(numel(result.backendNames), 1);
summary.v1GainOverMusic = NaN(numel(result.backendNames), 1);
summary.v3ToOracleGap = NaN(numel(result.backendNames), 1);
summary.v1ToOracleGap = NaN(numel(result.backendNames), 1);

if ~isempty(musicIdx) && ~isempty(oracleIdx)
    oracleMusic = summary.meanResolution(musicIdx, oracleIdx);
    summary.oracleGainOverMusic = summary.meanResolution(:, oracleIdx) - oracleMusic;
end
if ~isempty(musicIdx) && ~isempty(v3Idx)
    v3Music = summary.meanResolution(musicIdx, v3Idx);
    summary.v3GainOverMusic = summary.meanResolution(:, v3Idx) - v3Music;
end
if ~isempty(musicIdx) && ~isempty(v1Idx)
    v1Music = summary.meanResolution(musicIdx, v1Idx);
    summary.v1GainOverMusic = summary.meanResolution(:, v1Idx) - v1Music;
end
if ~isempty(oracleIdx) && ~isempty(v3Idx)
    summary.v3ToOracleGap = summary.meanResolution(:, oracleIdx) - summary.meanResolution(:, v3Idx);
end
if ~isempty(oracleIdx) && ~isempty(v1Idx)
    summary.v1ToOracleGap = summary.meanResolution(:, oracleIdx) - summary.meanResolution(:, v1Idx);
end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
matlab -batch "addpath(genpath(pwd)); run_sanity_tests"
```

Expected: PASS, including backend benchmark common-snapshot and shape tests.

- [ ] **Step 5: Run static check for new backend files**

Run:

```bash
matlab -batch "checkcode src/doa_backend_utils.m src/doa_backend_music_baseline.m src/doa_backend_music_pair_rescore.m src/doa_backend_pairwise_grid_ml.m src/benchmark_doa_backends.m tests/run_sanity_tests.m"
```

Expected: no run-blocking syntax errors.

- [ ] **Step 6: Commit or record no-git state**

Run `git status --short`; record not-a-git-repo if it remains fatal.

## Task 6: Default Case11 Configuration

**Files:**
- Modify: `default_config.m`
- Test: MATLAB config smoke command

- [ ] **Step 1: Write the failing config smoke**

Run:

```bash
matlab -batch "cfg=default_config(pwd); assert(isfield(cfg,'case11')); assert(isequal(cfg.case11.sourcePairsDeg,[23.8 31.8; 35.8 45.8])); fprintf('PASS: case11 config\\n');"
```

Expected: FAIL because `cfg.case11` does not exist.

- [ ] **Step 2: Add Case11 config**

Add this block after the existing `cfg.case10` block in `default_config.m`:

```matlab
cfg.case11 = struct();
cfg.case11.sourcePairsDeg = [23.8 31.8; 35.8 45.8];
cfg.case11.evalSNRDb = cfg.case9.evalSNRDb;
cfg.case11.snapshots = cfg.case9.snapshots;
cfg.case11.monteCarlo = 20;
cfg.case11.toleranceDeg = cfg.case9.toleranceDeg;
cfg.case11.biasedToleranceDeg = cfg.case9.biasedToleranceDeg;
cfg.case11.marginalToleranceDeg = cfg.case9.marginalToleranceDeg;
cfg.case11.methodKeys = {'ard', 'proposed_v1', 'proposed_v3', 'oracle'};
cfg.case11.backendNames = {'music', 'music_pair_rescore', 'pairwise_grid_ml'};
cfg.case11.candidatePeakCount = 12;
cfg.case11.minimumSeparationDeg = 2;
cfg.case11.maximumSeparationDeg = 30;
cfg.case11.candidateAngleStrideDeg = 1;
cfg.case11.topCandidateCount = 8;
```

Add this line inside the `'paper'` profile branch after `cfg.case9.monteCarlo = 300;`:

```matlab
        cfg.case11.monteCarlo = 80;
```

- [ ] **Step 3: Run config smoke to verify it passes**

Run:

```bash
matlab -batch "cfg=default_config(pwd); assert(isfield(cfg,'case11')); assert(isequal(cfg.case11.sourcePairsDeg,[23.8 31.8; 35.8 45.8])); fprintf('PASS: case11 config\\n');"
```

Expected:

```text
PASS: case11 config
```

- [ ] **Step 4: Commit or record no-git state**

Run `git status --short`; record not-a-git-repo if it remains fatal.

## Task 7: Run Project Case11 Orchestration

**Files:**
- Modify: `run_project.m`
- Test: Case11 smoke with `monteCarlo = 1`

- [ ] **Step 1: Write the failing orchestration smoke**

Run:

```bash
matlab -batch "addpath(genpath(pwd)); cfg=default_config(pwd); cfg.outputDir=fullfile(pwd,'tmp_case11_smoke'); cfg.case11.monteCarlo=1; run_project(11,cfg); assert(exist(fullfile(cfg.outputDir,'case11_backend_diagnostic','case11_results.mat'),'file')==2); fprintf('PASS: case11 run_project smoke\\n');"
```

Expected: FAIL with `Case id must be an integer in [1, 10]`.

- [ ] **Step 2: Extend case lists**

In `run_project.m`, extend `caseRunners`:

```matlab
    @case09_two_source_resolution, ...
    @case10_random_split_robustness, ...
    @case11_backend_diagnostic};
```

Extend `caseFolderNames`:

```matlab
    'case09_two_source_resolution', ...
    'case10_random_split_robustness', ...
    'case11_backend_diagnostic'};
```

Change this validation:

```matlab
    if caseId < 1 || caseId > numel(caseRunners)
        error('Case id must be an integer in [1, 11].');
    end
```

- [ ] **Step 3: Add Case11 runner**

Insert this function after `case10_random_split_robustness` and before `local_case_output_dir`:

```matlab
function caseResult = case11_backend_diagnostic(cfg, ctx)
rng(cfg.randomSeed + 11, 'twister');
outDir = local_case_output_dir(cfg, 'case11_backend_diagnostic');

calIdx = select_calibration_indices(ctx.thetaDeg, cfg.case3.representativeL, 'uniform');
models = build_sparse_models(ctx, calIdx, cfg.model);
methods = local_named_methods(ctx, models, cfg.case11.methodKeys);

evalCfg = struct();
evalCfg.mode = 'double';
evalCfg.trueAngles = cfg.case11.sourcePairsDeg;
evalCfg.snrDb = cfg.case11.evalSNRDb;
evalCfg.snapshots = cfg.case11.snapshots;
evalCfg.monteCarlo = cfg.case11.monteCarlo;
evalCfg.toleranceDeg = cfg.case11.toleranceDeg;
evalCfg.biasedToleranceDeg = cfg.case11.biasedToleranceDeg;
evalCfg.marginalToleranceDeg = cfg.case11.marginalToleranceDeg;
evalCfg.collectRepresentative = true;

backendCfg = struct();
backendCfg.backendNames = cfg.case11.backendNames;
backendCfg.numSources = 2;
backendCfg.candidatePeakCount = cfg.case11.candidatePeakCount;
backendCfg.minimumSeparationDeg = cfg.case11.minimumSeparationDeg;
backendCfg.maximumSeparationDeg = cfg.case11.maximumSeparationDeg;
backendCfg.topCandidateCount = cfg.case11.topCandidateCount;
backendCfg.candidateAnglesDeg = local_case11_candidate_angles(ctx.thetaDeg, cfg.case11);

bench = benchmark_doa_backends(ctx, methods, evalCfg, backendCfg);

caseResult = struct();
caseResult.outputDir = outDir;
caseResult.sourcePairsDeg = bench.trueAngleSetsDeg;
caseResult.backendNames = bench.backendNames;
caseResult.methodLabels = bench.methodLabels;
caseResult.methodNames = bench.methodNames;
caseResult.snapshotPolicy = bench.snapshotPolicy;
caseResult.rmse = bench.rmse;
caseResult.resolutionRate = bench.resolutionRate;
caseResult.stableRate = bench.stableRate;
caseResult.marginalRate = bench.marginalRate;
caseResult.biasedRate = bench.biasedRate;
caseResult.unresolvedRate = bench.unresolvedRate;
caseResult.collapseRate = bench.collapseRate;
caseResult.oracleCeilingDelta = bench.summary.oracleGainOverMusic;
caseResult.backendDiagnostics = bench.backendDiagnostics;
caseResult.representative = bench.representative;
caseResult.summary = bench.summary;

local_plot_case11_backend_summary(caseResult, outDir);
save(fullfile(outDir, 'case11_results.mat'), 'caseResult');
end

function candidateAnglesDeg = local_case11_candidate_angles(thetaDeg, case11Cfg)
strideDeg = case11Cfg.candidateAngleStrideDeg;
if isempty(strideDeg) || strideDeg <= 0
    strideDeg = 1;
end
minAngle = max(min(thetaDeg), min(case11Cfg.sourcePairsDeg(:)) - 20);
maxAngle = min(max(thetaDeg), max(case11Cfg.sourcePairsDeg(:)) + 20);
candidateAnglesDeg = minAngle:strideDeg:maxAngle;
candidateAnglesDeg = unique([candidateAnglesDeg(:); case11Cfg.sourcePairsDeg(:)], 'stable').';
end
```

- [ ] **Step 4: Add Case11 plotting helper**

Insert this function after `local_case11_candidate_angles`:

```matlab
function local_plot_case11_backend_summary(caseResult, outDir)
backendLabels = caseResult.backendNames;
methodLabels = caseResult.methodLabels;
meanResolution = squeeze(mean(caseResult.resolutionRate, 2));
meanStable = squeeze(mean(caseResult.stableRate, 2));
meanRmse = squeeze(mean(caseResult.rmse, 2));

fig = figure('Visible', 'off', 'Position', [120 120 1280 760]);
tiledlayout(1, 3, 'Padding', 'compact', 'TileSpacing', 'compact');

nexttile;
bar(categorical(backendLabels), meanResolution);
grid on;
ylim([0 1]);
ylabel('Resolution rate');
title('Case 11: backend resolution');
legend(methodLabels, 'Location', 'bestoutside');

nexttile;
bar(categorical(backendLabels), meanStable);
grid on;
ylim([0 1]);
ylabel('Stable rate');
title('Case 11: backend stable');

nexttile;
bar(categorical(backendLabels), meanRmse);
grid on;
ylabel('Pair RMSE (deg)');
title('Case 11: backend RMSE');

local_add_truth_scan_sgtitle('Case 11: enhanced backend diagnostic');
save_figure(fig, fullfile(outDir, 'backend_resolution_summary.png'));
save_figure(fig, fullfile(outDir, 'backend_stable_summary.png'));
save_figure(fig, fullfile(outDir, 'backend_oracle_ceiling.png'));
end
```

- [ ] **Step 5: Run orchestration smoke**

Run:

```bash
matlab -batch "addpath(genpath(pwd)); cfg=default_config(pwd); cfg.outputDir=fullfile(pwd,'tmp_case11_smoke'); cfg.case11.monteCarlo=1; run_project(11,cfg); assert(exist(fullfile(cfg.outputDir,'case11_backend_diagnostic','case11_results.mat'),'file')==2); fprintf('PASS: case11 run_project smoke\\n');"
```

Expected:

```text
=== Running Case 11 ===
PASS: case11 run_project smoke
```

- [ ] **Step 6: Remove temporary smoke output**

Run:

```bash
rm -rf tmp_case11_smoke
```

Expected: directory no longer exists.

- [ ] **Step 7: Commit or record no-git state**

Run `git status --short`; record not-a-git-repo if it remains fatal.

## Task 8: Case11 Static Check and Full Sanity Tests

**Files:**
- Modify only if checks fail: files from previous tasks

- [ ] **Step 1: Run static check**

Run:

```bash
matlab -batch "checkcode default_config.m run_project.m src/*.m tests/*.m"
```

Expected: no run-blocking errors. Existing `datestr/now`, `STRCMPI`, and stale suppression warnings may remain.

- [ ] **Step 2: Run sanity tests**

Run:

```bash
matlab -batch "addpath(genpath(pwd)); run_sanity_tests"
```

Expected:

```text
All sanity tests PASS.
```

- [ ] **Step 3: Run a direct backend benchmark smoke**

Run:

```bash
matlab -batch "addpath(genpath(pwd)); cfg=default_config(pwd); ctx=build_project_context(cfg); methods=struct('name','oracle','label','HFSS Oracle','manifold',ctx.AH); evalCfg=struct('mode','double','trueAngles',[23.8 31.8],'snrDb',15,'snapshots',300,'monteCarlo',1,'toleranceDeg',0.6,'biasedToleranceDeg',2,'marginalToleranceDeg',5,'collectRepresentative',true); backendCfg=cfg.case11; backendCfg.numSources=2; backendCfg.candidateAnglesDeg=unique([23.8:1:31.8 31.8]); bench=benchmark_doa_backends(ctx,methods,evalCfg,backendCfg); assert(strcmp(bench.snapshotPolicy,'common_truth_snapshots_across_backends_and_methods')); fprintf('PASS: direct backend benchmark smoke\\n');"
```

Expected:

```text
PASS: direct backend benchmark smoke
```

- [ ] **Step 4: Commit or record no-git state**

Run `git status --short`; record not-a-git-repo if it remains fatal.

## Task 9: Traceable Case11 Smoke Run

**Files:**
- Result output: `results/<pending-local-hash>/case11_backend_diagnostic/`
- Update: `docs/research-log.md`
- Documentation image: `docs/assets/case11-enhanced-backend-smoke-<pending-local-hash>.png`

- [ ] **Step 1: Generate pending local hash**

Run:

```bash
HASH=$(python3 .codex/skills/project-code-change-log/scripts/new_local_hash.py)
printf '%s\n' "$HASH"
case "$HASH" in local-[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) true ;; *) exit 1 ;; esac
```

Expected: one printed value matching `local-[0-9a-f]{8}` and shell variable `$HASH` set for the remaining commands in this task.

- [ ] **Step 2: Run traceable Case11 smoke**

Run:

```bash
matlab -batch "addpath(genpath(pwd)); cfg=default_config(pwd); cfg.run.useTraceableDirs=true; cfg.run.resultRoot=fullfile(pwd,'results'); cfg.run.runId='${HASH}'; cfg.run.pendingLocalHash='${HASH}'; cfg.run.baseHead='not-a-git-repo'; cfg.run.gitStatusShort='fatal: not a git repository (or any of the parent directories): .git'; cfg.run.command='matlab -batch Case11 enhanced backend diagnostic smoke'; cfg.run.notes='Case11 enhanced backend diagnostic smoke; sourcePairs=[23.8 31.8; 35.8 45.8], monteCarlo=20; diagnostic only, not a main Case9 performance claim.'; run_project(11,cfg);"
```

Expected:

```text
=== Running Case 11 ===
```

Expected files:

```text
results/$HASH/RUN_NOTES.md
results/$HASH/manifest.md
results/$HASH/case11_backend_diagnostic/case11_results.mat
results/$HASH/case11_backend_diagnostic/backend_resolution_summary.png
```

- [ ] **Step 3: Verify Case11 result fields**

Run:

```bash
matlab -batch "s=load(fullfile('results','${HASH}','case11_backend_diagnostic','case11_results.mat')); cr=s.caseResult; assert(strcmp(cr.snapshotPolicy,'common_truth_snapshots_across_backends_and_methods')); assert(isequal(size(cr.rmse),[numel(cr.backendNames), size(cr.sourcePairsDeg,1), numel(cr.methodLabels)])); assert(isfield(cr,'oracleCeilingDelta')); fprintf('PASS: case11 result fields\\n'); disp(cr.backendNames'); disp(cr.methodLabels'); disp(squeeze(mean(cr.resolutionRate,2)));"
```

Expected:

```text
PASS: case11 result fields
```

- [ ] **Step 4: Copy documentation image**

Run:

```bash
cp "results/${HASH}/case11_backend_diagnostic/backend_resolution_summary.png" "docs/assets/case11-enhanced-backend-smoke-${HASH}.png"
```

Expected:

```bash
test -f "docs/assets/case11-enhanced-backend-smoke-${HASH}.png"
```

returns exit code `0`.

- [ ] **Step 5: Update research log**

Add a new top entry in `docs/research-log.md` under `## 最新整理`:

```markdown
### 2026-05-08：`${HASH}` Case11 enhanced backend diagnostic smoke

- Version hash: `${HASH}`
- Base HEAD: `not-a-git-repo`
- Worktree state: uncommitted code changes; this local directory did not expose a `.git` repository, so `git status --short` returned `fatal: not a git repository`.
- Change: added a separate Case11 enhanced-backend diagnostic with common HFSS-truth snapshots across backends and methods. The diagnostic compares MUSIC, MUSIC pair-rescoring, and pairwise grid ML without replacing the main MUSIC Case9 benchmark.
- Affected cases: Case11 only; Case9 main benchmark remains unchanged.
- Validation: `checkcode default_config.m run_project.m src/*.m tests/*.m`; `matlab -batch "addpath(genpath(pwd)); run_sanity_tests"`; traceable Case11 smoke with `[23.8 31.8; 35.8 45.8]` and `monteCarlo = 20`.
- Result path: `results/${HASH}/`
- Case outputs: `case11_backend_diagnostic/`
- Remaining risk: diagnostic smoke only; do not treat enhanced-backend numbers as main Proposed V3.3 performance claims.

#### Case11 interpretation

- `HFSS Oracle + pairwise_grid_ml` versus `HFSS Oracle + MUSIC` is the primary backend-ceiling comparison.
- If Oracle improves but V3.3 does not, the likely bottleneck remains the calibrated manifold or V3 surrogate.
- If Oracle does not improve, the two-source condition itself is likely too hard under the current SNR/snapshot setting.

![case11 enhanced backend smoke](assets/case11-enhanced-backend-smoke-${HASH}.png)
```

Replace `${HASH}` in the Markdown entry with the actual generated hash string before saving `docs/research-log.md`.

- [ ] **Step 6: Confirm manifest and notes**

Run:

```bash
sed -n '1,180p' "results/${HASH}/RUN_NOTES.md"
sed -n '1,120p' "results/${HASH}/manifest.md"
```

Expected: `RUN_NOTES.md` records Case11 smoke command and `manifest.md` lists only `case11_backend_diagnostic`.

- [ ] **Step 7: Commit or record no-git state**

Run `git status --short`; record not-a-git-repo if it remains fatal.

## Task 10: Final Verification Summary

**Files:**
- No file changes unless a verification failure is found.

- [ ] **Step 1: Check active files for forbidden external dependencies**

Run:

```bash
rg -n "cvx|sdpt3|sedumi|mosek|yalmip|sdpvar|optimoptions|fmincon" src default_config.m run_project.m tests || true
```

Expected: no required external solver dependency. `optimoptions` / `fmincon` should not appear in the first implementation.

- [ ] **Step 2: Check Case9 remains present and unchanged in purpose**

Run:

```bash
rg -n "case09_two_source_resolution|benchmark_music\\(|case11_backend_diagnostic|benchmark_doa_backends" run_project.m src
```

Expected:

```text
run_project.m contains both case09_two_source_resolution and case11_backend_diagnostic.
case09_two_source_resolution still calls benchmark_music.
case11_backend_diagnostic calls benchmark_doa_backends.
```

- [ ] **Step 3: Check result folder completeness**

Run:

```bash
find "results/${HASH}" -maxdepth 3 -type f | sort
```

Expected includes:

```text
results/$HASH/RUN_NOTES.md
results/$HASH/manifest.md
results/$HASH/case11_backend_diagnostic/case11_results.mat
results/$HASH/case11_backend_diagnostic/backend_resolution_summary.png
```

- [ ] **Step 4: Final response content**

Report these items to the user:

```text
- Case11 backend diagnostic implemented.
- Main Case9 MUSIC benchmark left unchanged.
- Static check and sanity tests status.
- Case11 smoke result path.
- Whether HFSS Oracle improved under pairwise_grid_ml compared with MUSIC.
- Reminder that Case11 is diagnostic only.
- Any command that could not run.
```

Do not claim a full Case9 performance conclusion from the two-pair Case11 smoke.
