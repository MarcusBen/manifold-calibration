# Parallel DOA Backends Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add MUSIC, SPICE/SPICE+, and Grid ML as parallel DOA backend families for fair 1/2/3-source diagnostics.

**Architecture:** Import the SPICE spectral estimator into tracked `src/` code behind a normal backend contract, then route all backend names through one dispatcher. Extend the core 1/2/3-source benchmark to evaluate multiple backends on shared snapshots while preserving existing single-backend behavior for callers that still expect it.

**Tech Stack:** MATLAB project code, existing `tests/run_sanity_tests.m`, existing `benchmark_music`, `benchmark_doa_backends`, `benchmark_core_sources`, and project result logging conventions.

---

## File Structure

- Create `src/doa_backend_spice.m`: SPICE/SPICE+ backend wrapper with the same output contract as existing DOA backends.
- Create `src/doa_backend_dispatch.m`: single backend dispatcher for `music`, `spice`, `spice_plus`, `pairwise_grid_ml`, and `triplet_grid_ml`.
- Modify `src/doa_backend_utils.m`: add `spice_spectrum` and `spice_plus_spectrum` utility actions adapted from `algorithms/SPICE/src/alg`.
- Modify `src/benchmark_doa_backends.m`: replace local dispatcher with `doa_backend_dispatch` and accept SPICE backends.
- Modify `src/benchmark_music.m`: accept SPICE backends for double-source runs and keep MUSIC default behavior.
- Modify `src/benchmark_core_sources.m`: support `evalCfg.backendNames` for parallel backend evaluation while preserving existing `evalCfg.backendName` / `threeSourceBackendName` behavior.
- Modify `default_config.m`: add backend-family defaults for Case12/Case13-style core runs.
- Modify `tests/run_sanity_tests.m`: add SPICE backend tests, dispatcher tests, and parallel core benchmark shape/common-snapshot tests.
- Modify `docs/research-log.md`: record code behavior change and validation after implementation.
- Create `results/<pending-local-hash>/RUN_NOTES.md` and `results/<pending-local-hash>/manifest.md` after code changes and before any smoke run.

---

### Task 1: Add SPICE Utility Tests First

**Files:**
- Modify: `tests/run_sanity_tests.m`
- Later implementation target: `src/doa_backend_utils.m`

- [ ] **Step 1: Add test calls near existing backend utility tests**

Add these calls after `local_test_backend_utils_covariance_fit(ctx);`:

```matlab
local_test_backend_utils_spice_spectra(ctx);
```

- [ ] **Step 2: Add the failing test function**

Place this function near the other backend utility tests:

```matlab
function local_test_backend_utils_spice_spectra(ctx)
rng(93011, 'twister');
idx = [local_angle_index(ctx.thetaDeg, -18), local_angle_index(ctx.thetaDeg, 14)];
x = local_simulate_snapshots(ctx.AH(:, idx), 35, 1200);
covariance = (x * x') / size(x, 2);
alg = struct('maxIterations', 60, 'tolerance', 1e-5, 'diagonalLoading', 1e-8);
[spiceSpectrum, spiceInfo] = doa_backend_utils('spice_spectrum', covariance, ctx.AH, alg);
[spicePlusSpectrum, spicePlusInfo] = doa_backend_utils('spice_plus_spectrum', covariance, ctx.AH, alg);
local_assert_equal(numel(spiceSpectrum), numel(ctx.thetaDeg), ...
    'SPICE spectrum length');
local_assert_equal(numel(spicePlusSpectrum), numel(ctx.thetaDeg), ...
    'SPICE+ spectrum length');
local_assert_true(all(isfinite(spiceSpectrum)) && all(spiceSpectrum >= 0), ...
    'SPICE spectrum finite nonnegative');
local_assert_true(all(isfinite(spicePlusSpectrum)) && all(spicePlusSpectrum >= 0), ...
    'SPICE+ spectrum finite nonnegative');
local_assert_true(isfield(spiceInfo, 'iterations') && spiceInfo.iterations > 0, ...
    'SPICE iteration diagnostics');
local_assert_true(isfield(spicePlusInfo, 'sigmaHat') && isfinite(spicePlusInfo.sigmaHat), ...
    'SPICE+ sigma diagnostics');
end
```

- [ ] **Step 3: Run the focused sanity test and verify it fails**

Run:

```bash
matlab -batch "addpath(genpath(pwd)); tests/run_sanity_tests"
```

Expected: FAIL with an unsupported `doa_backend_utils` action for `spice_spectrum`.

---

### Task 2: Implement SPICE Spectrum Utilities

**Files:**
- Modify: `src/doa_backend_utils.m`

- [ ] **Step 1: Add utility actions**

At the top `switch` in `doa_backend_utils`, add:

```matlab
    case 'spice_spectrum'
        [varargout{1:nargout}] = local_spice_spectrum(varargin{:});
    case 'spice_plus_spectrum'
        [varargout{1:nargout}] = local_spice_plus_spectrum(varargin{:});
```

- [ ] **Step 2: Add SPICE utility implementations**

Append these local functions to `src/doa_backend_utils.m`. Keep names local to avoid path collisions with `algorithms/SPICE`.

```matlab
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
if opts.diagonalLoading < 0 || ~isfinite(opts.diagonalLoading)
    error('spice_spectrum:InvalidOptions', 'diagonalLoading must be nonnegative and finite.');
end
end
```

- [ ] **Step 3: Run sanity tests**

Run:

```bash
matlab -batch "addpath(genpath(pwd)); tests/run_sanity_tests"
```

Expected: the new SPICE utility test passes; unrelated later tests may still fail until subsequent tasks add backend wrappers.

- [ ] **Step 4: Commit**

```bash
git add src/doa_backend_utils.m tests/run_sanity_tests.m
git commit -m "feat: add spice spectrum utilities"
```

---

### Task 3: Add SPICE Backend Wrapper

**Files:**
- Create: `src/doa_backend_spice.m`
- Modify: `tests/run_sanity_tests.m`

- [ ] **Step 1: Add failing backend tests**

Add calls after `local_test_music_pair_rescore_backend(ctx);`:

```matlab
local_test_spice_backend(ctx);
local_test_spice_plus_backend(ctx);
```

Add test functions:

```matlab
function local_test_spice_backend(ctx)
rng(93021, 'twister');
idx = [local_angle_index(ctx.thetaDeg, -18), local_angle_index(ctx.thetaDeg, 14)];
x = local_simulate_snapshots(ctx.AH(:, idx), 35, 1200);
backendCfg = struct('numSources', 2, 'variant', 'spice', ...
    'maxIterations', 60, 'tolerance', 1e-5, 'diagonalLoading', 1e-8, ...
    'minimumSeparationDeg', 3);
result = doa_backend_spice(x, ctx.AH, ctx.thetaDeg, backendCfg);
local_assert_true(all(abs(result.estAnglesDeg - [-18 14]) <= 0.8), ...
    'SPICE backend recovers high-SNR oracle pair');
local_assert_equal(result.name, 'spice', 'SPICE backend name');
local_assert_equal(numel(result.spectrum), numel(ctx.thetaDeg), ...
    'SPICE backend spectrum length');
local_assert_true(isfield(result.diagnostics, 'iterations'), ...
    'SPICE backend iteration diagnostics');
end

function local_test_spice_plus_backend(ctx)
rng(93022, 'twister');
idx = [local_angle_index(ctx.thetaDeg, -18), local_angle_index(ctx.thetaDeg, 14)];
x = local_simulate_snapshots(ctx.AH(:, idx), 35, 1200);
backendCfg = struct('numSources', 2, 'variant', 'spice_plus', ...
    'maxIterations', 60, 'tolerance', 1e-5, 'diagonalLoading', 1e-8, ...
    'minimumSeparationDeg', 3);
result = doa_backend_spice(x, ctx.AH, ctx.thetaDeg, backendCfg);
local_assert_true(all(abs(result.estAnglesDeg - [-18 14]) <= 0.8), ...
    'SPICE+ backend recovers high-SNR oracle pair');
local_assert_equal(result.name, 'spice_plus', 'SPICE+ backend name');
local_assert_true(isfield(result.diagnostics, 'sigmaHat'), ...
    'SPICE+ backend sigma diagnostics');
end
```

- [ ] **Step 2: Run focused test and verify it fails**

Run:

```bash
matlab -batch "addpath(genpath(pwd)); tests/run_sanity_tests"
```

Expected: FAIL because `doa_backend_spice` is undefined.

- [ ] **Step 3: Implement `src/doa_backend_spice.m`**

Create the file:

```matlab
function result = doa_backend_spice(x, scanManifold, scanAnglesDeg, backendCfg)
%DOA_BACKEND_SPICE Sparse covariance-spectrum DOA backend using SPICE/SPICE+.

if nargin < 4 || isempty(backendCfg)
    backendCfg = struct();
end

numSources = local_optional_field(backendCfg, 'numSources', 2);
variant = lower(strtrim(local_optional_field(backendCfg, 'variant', 'spice_plus')));
minimumSeparationDeg = local_optional_field(backendCfg, 'minimumSeparationDeg', 0);
candidatePeakCount = local_optional_field(backendCfg, 'candidatePeakCount', ...
    max(numSources + 8, 12));

covariance = (x * x') / size(x, 2);
alg = struct();
alg.maxIterations = local_optional_field(backendCfg, 'maxIterations', 100);
alg.tolerance = local_optional_field(backendCfg, 'tolerance', 1e-4);
alg.diagonalLoading = local_optional_field(backendCfg, 'diagonalLoading', 1e-8);

switch variant
    case 'spice'
        [spectrum, spiceInfo] = doa_backend_utils('spice_spectrum', ...
            covariance, scanManifold, alg);
    case 'spice_plus'
        [spectrum, spiceInfo] = doa_backend_utils('spice_plus_spectrum', ...
            covariance, scanManifold, alg);
    otherwise
        error('Unsupported SPICE backend variant: %s', variant);
end

peakIdx = doa_backend_utils('pick_local_peaks', spectrum, candidatePeakCount);
selectedIdx = local_select_separated_peaks(peakIdx, spectrum, scanAnglesDeg, ...
    numSources, minimumSeparationDeg);

result = struct();
result.name = variant;
result.estAnglesDeg = sort(scanAnglesDeg(selectedIdx));
result.spectrum = spectrum;
result.covariance = covariance;
result.diagnostics = spiceInfo;
result.diagnostics.selectedGridIndex = selectedIdx;
result.diagnostics.selectedSpectrumValue = spectrum(selectedIdx);
result.diagnostics.minimumSeparationDeg = minimumSeparationDeg;
end

function selectedIdx = local_select_separated_peaks(peakIdx, spectrum, scanAnglesDeg, ...
    numSources, minimumSeparationDeg)
selectedIdx = zeros(1, 0);
for candidate = reshape(peakIdx, 1, [])
    if isempty(selectedIdx) || ...
            all(abs(scanAnglesDeg(candidate) - scanAnglesDeg(selectedIdx)) >= minimumSeparationDeg)
        selectedIdx(end+1) = candidate; %#ok<AGROW>
    end
    if numel(selectedIdx) == numSources
        break;
    end
end
if numel(selectedIdx) < numSources
    [~, order] = sort(spectrum, 'descend');
    for candidate = reshape(order, 1, [])
        if ~ismember(candidate, selectedIdx) && ...
                (isempty(selectedIdx) || all(abs(scanAnglesDeg(candidate) - ...
                scanAnglesDeg(selectedIdx)) >= minimumSeparationDeg))
            selectedIdx(end+1) = candidate; %#ok<AGROW>
        end
        if numel(selectedIdx) == numSources
            break;
        end
    end
end
if numel(selectedIdx) < numSources
    [~, order] = maxk(spectrum, min(numSources, numel(spectrum)));
    selectedIdx = order(:).';
end
selectedIdx = selectedIdx(1:numSources);
end

function value = local_optional_field(inputStruct, fieldName, defaultValue)
if isfield(inputStruct, fieldName) && ~isempty(inputStruct.(fieldName))
    value = inputStruct.(fieldName);
else
    value = defaultValue;
end
end
```

- [ ] **Step 4: Run sanity tests**

Run:

```bash
matlab -batch "addpath(genpath(pwd)); tests/run_sanity_tests"
```

Expected: SPICE backend tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/doa_backend_spice.m tests/run_sanity_tests.m
git commit -m "feat: add spice doa backend"
```

---

### Task 4: Add Unified Backend Dispatcher

**Files:**
- Create: `src/doa_backend_dispatch.m`
- Modify: `src/benchmark_doa_backends.m`
- Modify: `src/benchmark_music.m`
- Modify: `tests/run_sanity_tests.m`

- [ ] **Step 1: Add dispatcher tests**

Add calls after SPICE backend tests:

```matlab
local_test_doa_backend_dispatch_spice(ctx);
local_test_backend_benchmark_accepts_spice(ctx);
```

Add test functions:

```matlab
function local_test_doa_backend_dispatch_spice(ctx)
rng(93023, 'twister');
idx = [local_angle_index(ctx.thetaDeg, -18), local_angle_index(ctx.thetaDeg, 14)];
x = local_simulate_snapshots(ctx.AH(:, idx), 35, 1200);
backendCfg = struct('numSources', 2, 'minimumSeparationDeg', 3, ...
    'maxIterations', 60, 'tolerance', 1e-5);
result = doa_backend_dispatch('spice_plus', x, ctx.AH, ctx.thetaDeg, backendCfg);
local_assert_equal(result.name, 'spice_plus', 'dispatcher SPICE+ backend name');
local_assert_true(all(abs(result.estAnglesDeg - [-18 14]) <= 0.8), ...
    'dispatcher SPICE+ recovers high-SNR oracle pair');
end

function local_test_backend_benchmark_accepts_spice(ctx)
rng(93024, 'twister');
methods = struct('name', 'oracle', 'label', 'HFSS Oracle', 'manifold', ctx.AH);
evalCfg = local_backend_test_eval_cfg();
evalCfg.trueAngles = [-18 14];
evalCfg.monteCarlo = 1;
backendCfg = local_backend_test_backend_cfg(ctx);
backendCfg.backendNames = {'music', 'spice_plus', 'pairwise_grid_ml'};
backendCfg.maxIterations = 40;
backendCfg.tolerance = 1e-5;
backendCfg.minimumSeparationDeg = 3;
bench = benchmark_doa_backends(ctx, methods, evalCfg, backendCfg);
local_assert_equal(bench.backendNames, backendCfg.backendNames, ...
    'backend benchmark preserves SPICE backend names');
local_assert_equal(size(bench.rmse, 1), 3, ...
    'backend benchmark has three backend rows');
end
```

- [ ] **Step 2: Run tests and verify dispatcher failure**

Run:

```bash
matlab -batch "addpath(genpath(pwd)); tests/run_sanity_tests"
```

Expected: FAIL because `doa_backend_dispatch` is undefined.

- [ ] **Step 3: Implement `src/doa_backend_dispatch.m`**

Create:

```matlab
function backendResult = doa_backend_dispatch(backendName, x, scanManifold, scanAnglesDeg, backendCfg)
%DOA_BACKEND_DISPATCH Run a named DOA backend through the common contract.

if nargin < 5 || isempty(backendCfg)
    backendCfg = struct();
end

switch lower(strtrim(backendName))
    case 'music'
        backendResult = doa_backend_music_baseline(x, scanManifold, scanAnglesDeg, backendCfg);
    case 'music_pair_rescore'
        backendResult = doa_backend_music_pair_rescore(x, scanManifold, scanAnglesDeg, backendCfg);
    case 'spice'
        backendCfg.variant = 'spice';
        backendResult = doa_backend_spice(x, scanManifold, scanAnglesDeg, backendCfg);
    case 'spice_plus'
        backendCfg.variant = 'spice_plus';
        backendResult = doa_backend_spice(x, scanManifold, scanAnglesDeg, backendCfg);
    case 'pairwise_grid_ml'
        backendResult = doa_backend_pairwise_grid_ml(x, scanManifold, scanAnglesDeg, backendCfg);
    case 'triplet_grid_ml'
        backendResult = doa_backend_triplet_grid_ml(x, scanManifold, scanAnglesDeg, backendCfg);
    otherwise
        error('Unknown DOA backend: %s', backendName);
end
end
```

- [ ] **Step 4: Replace local dispatch in `benchmark_doa_backends`**

Change `local_run_backend` to:

```matlab
function backendResult = local_run_backend(backendName, x, scanManifold, scanAnglesDeg, backendCfg)
backendResult = doa_backend_dispatch(backendName, x, scanManifold, scanAnglesDeg, backendCfg);
end
```

- [ ] **Step 5: Extend `benchmark_music` dispatch**

In `local_estimate_doa`, replace the switch with:

```matlab
switch lower(strtrim(backendName))
    case {'music_pair_rescore', 'pairwise_grid_ml', 'spice', 'spice_plus'}
        backendResult = doa_backend_dispatch(backendName, x, scanManifold, scanAngles, backendCfg);
    otherwise
        error('Unsupported benchmark backend: %s', backendName);
end
```

Keep the existing single-source guard unchanged for this task.

- [ ] **Step 6: Run sanity tests**

Run:

```bash
matlab -batch "addpath(genpath(pwd)); tests/run_sanity_tests"
```

Expected: dispatcher and backend benchmark SPICE tests pass.

- [ ] **Step 7: Commit**

```bash
git add src/doa_backend_dispatch.m src/benchmark_doa_backends.m src/benchmark_music.m tests/run_sanity_tests.m
git commit -m "feat: route doa backends through dispatcher"
```

---

### Task 5: Extend Core Benchmark To Parallel Backends

**Files:**
- Modify: `src/benchmark_core_sources.m`
- Modify: `tests/run_sanity_tests.m`

- [ ] **Step 1: Add failing parallel core benchmark test**

Add a call after `local_test_core_source_benchmark_common_snapshots(ctx);`:

```matlab
local_test_core_source_benchmark_parallel_backends(ctx);
```

Add test:

```matlab
function local_test_core_source_benchmark_parallel_backends(ctx)
rng(93042, 'twister');
methods = struct('name', 'oracle', 'label', 'HFSS Oracle', 'manifold', ctx.AH);
evalCfg = struct('numSources', 2, 'trueAngles', [-18 14], 'snrDb', 35, ...
    'snapshots', 1000, 'monteCarlo', 1, 'toleranceDeg', 1.0, ...
    'backendNames', {{'music', 'spice_plus', 'pairwise_grid_ml'}});
backendCfg = struct('candidateAnglesDeg', -30:1:30, ...
    'minimumSeparationDeg', 3, 'maximumSeparationDeg', 60, ...
    'topCandidateCount', 6, 'maxIterations', 40, 'tolerance', 1e-5);
bench = benchmark_core_sources(ctx, methods, evalCfg, backendCfg);
local_assert_equal(bench.backendNames, evalCfg.backendNames, ...
    'core benchmark preserves backend names');
local_assert_equal(size(bench.perTargetRmse), [1 1 3], ...
    'core benchmark RMSE dimensions target-method-backend');
local_assert_equal(size(bench.summary.meanRmse), [1 3], ...
    'core benchmark summary dimensions method-backend');
local_assert_equal(bench.snapshotPolicy, ...
    'common_truth_snapshots_across_backends_and_methods', ...
    'core benchmark parallel backend snapshot policy');
end
```

- [ ] **Step 2: Run tests and verify shape failure**

Run:

```bash
matlab -batch "addpath(genpath(pwd)); tests/run_sanity_tests"
```

Expected: FAIL because `benchmark_core_sources` does not support `backendNames`.

- [ ] **Step 3: Update core benchmark loop dimensions**

In `benchmark_core_sources`, compute backend list before allocation:

```matlab
backendNames = local_backend_names(numSources, evalCfg);
numBackends = numel(backendNames);
```

Change arrays to include backend dimension:

```matlab
trialRmse = zeros(numTargets, numMethods, numBackends, numMonteCarlo);
trialResolved = false(numTargets, numMethods, numBackends, numMonteCarlo);
trialWorstAbsError = zeros(numTargets, numMethods, numBackends, numMonteCarlo);
backendDiagnostics = cell(numTargets, numMethods, numBackends, numMonteCarlo);
representative = repmat(struct('estAnglesDeg', [], 'spectrum', [], ...
    'diagnostics', []), numBackends, numMethods);
```

- [ ] **Step 4: Add backend loop around each trial**

Inside method/target/MC loops, run:

```matlab
for backendIdx = 1:numBackends
    backendName = backendNames{backendIdx};
    backendResult = local_run_core_backend(backendName, x, methods(methodIdx).manifold, ...
        ctx.thetaDeg, numSources, evalCfg, backendCfg);
    estAngles = sort(backendResult.estAnglesDeg(:).');
    if numel(estAngles) == numSources
        absError = abs(estAngles - trueAngles);
        trialRmse(targetIdx, methodIdx, backendIdx, mcIdx) = sqrt(mean(absError .^ 2));
        trialWorstAbsError(targetIdx, methodIdx, backendIdx, mcIdx) = max(absError);
        trialResolved(targetIdx, methodIdx, backendIdx, mcIdx) = ...
            all(absError <= evalCfg.toleranceDeg);
    else
        trialRmse(targetIdx, methodIdx, backendIdx, mcIdx) = Inf;
        trialWorstAbsError(targetIdx, methodIdx, backendIdx, mcIdx) = Inf;
        trialResolved(targetIdx, methodIdx, backendIdx, mcIdx) = false;
    end
    backendDiagnostics{targetIdx, methodIdx, backendIdx, mcIdx} = backendResult.diagnostics;
    if targetIdx == 1 && mcIdx == 1
        representative(backendIdx, methodIdx).estAnglesDeg = estAngles;
        representative(backendIdx, methodIdx).spectrum = backendResult.spectrum;
        representative(backendIdx, methodIdx).diagnostics = backendResult.diagnostics;
    end
end
```

- [ ] **Step 5: Update result fields**

Set:

```matlab
result.snapshotPolicy = 'common_truth_snapshots_across_backends_and_methods';
result.backendNames = backendNames;
result.backendName = backendNames{1};
result.perTargetRmse = mean(trialRmse, 4);
result.perTargetResolvedRate = mean(trialResolved, 4);
result.perTargetWorstAbsError = mean(trialWorstAbsError, 4);
result.summary.meanRmse = squeeze(mean(result.perTargetRmse, 1));
result.summary.meanResolvedRate = squeeze(mean(result.perTargetResolvedRate, 1));
result.summary.meanWorstAbsError = squeeze(mean(result.perTargetWorstAbsError, 1));
if numMethods == 1
    result.summary.meanRmse = reshape(result.summary.meanRmse, 1, []);
    result.summary.meanResolvedRate = reshape(result.summary.meanResolvedRate, 1, []);
    result.summary.meanWorstAbsError = reshape(result.summary.meanWorstAbsError, 1, []);
end
```

- [ ] **Step 6: Replace core backend runner**

Use a backend name argument:

```matlab
function backendResult = local_run_core_backend(backendName, x, scanManifold, scanAnglesDeg, ...
    numSources, evalCfg, backendCfg)
backendCfg.numSources = numSources;
backendCfg.scanAnglesDeg = scanAnglesDeg;
if ~isfield(backendCfg, 'candidateAnglesDeg') || isempty(backendCfg.candidateAnglesDeg)
    backendCfg.candidateAnglesDeg = scanAnglesDeg;
end
backendResult = doa_backend_dispatch(backendName, x, scanManifold, scanAnglesDeg, backendCfg);
if isempty(backendResult.spectrum)
    covariance = (x * x') / size(x, 2);
    backendResult.spectrum = doa_backend_utils('music_spectrum', covariance, scanManifold, numSources);
end
backendResult.diagnostics.backendName = backendName;
backendResult.diagnostics.reportedBackendName = local_backend_name(numSources, evalCfg);
end
```

- [ ] **Step 7: Add backend-name helper**

Add:

```matlab
function backendNames = local_backend_names(numSources, evalCfg)
if isfield(evalCfg, 'backendNames') && ~isempty(evalCfg.backendNames)
    backendNames = evalCfg.backendNames;
    return;
end
switch numSources
    case 1
        backendNames = {'music'};
    case 2
        backendNames = {evalCfg.backendName};
    case 3
        backendNames = {evalCfg.threeSourceBackendName};
    otherwise
        error('Unsupported numSources=%d.', numSources);
end
end
```

- [ ] **Step 8: Run sanity tests**

Run:

```bash
matlab -batch "addpath(genpath(pwd)); tests/run_sanity_tests"
```

Expected: core parallel backend test passes and older core tests still pass.

- [ ] **Step 9: Commit**

```bash
git add src/benchmark_core_sources.m tests/run_sanity_tests.m
git commit -m "feat: benchmark core sources across backends"
```

---

### Task 6: Update Defaults And Plot Labels

**Files:**
- Modify: `default_config.m`
- Modify: `run_project.m`
- Modify: `tests/run_sanity_tests.m`

- [ ] **Step 1: Add config defaults**

In `default_config.m`, add backend-family defaults near existing core/case13 backend fields:

```matlab
cfg.core.backendNamesBySource = struct();
cfg.core.backendNamesBySource.single = {'music', 'spice_plus'};
cfg.core.backendNamesBySource.double = {'music', 'spice_plus', 'pairwise_grid_ml'};
cfg.core.backendNamesBySource.triple = {'music', 'spice_plus', 'triplet_grid_ml'};
cfg.core.spice = struct('maxIterations', 80, 'tolerance', 1e-5, ...
    'diagonalLoading', 1e-8, 'minimumSeparationDeg', 2);
cfg.case13.backendNamesBySource = cfg.core.backendNamesBySource;
```

- [ ] **Step 2: Update config sanity test**

Extend `local_test_core_config_defaults`:

```matlab
local_assert_true(isfield(cfg.core, 'backendNamesBySource'), ...
    'core backend family defaults exist');
local_assert_true(any(strcmp(cfg.core.backendNamesBySource.double, 'spice_plus')), ...
    'core double-source backend family includes SPICE+');
local_assert_true(any(strcmp(cfg.core.backendNamesBySource.triple, 'triplet_grid_ml')), ...
    'core triple-source backend family includes triplet Grid ML');
```

- [ ] **Step 3: Thread defaults into Case12/Case13 callers**

Where `run_project.m` builds core source eval configs, set:

```matlab
evalCfg.backendNames = local_backend_names_for_source_count(cfg.core, numSources);
backendCfg.maxIterations = cfg.core.spice.maxIterations;
backendCfg.tolerance = cfg.core.spice.tolerance;
backendCfg.diagonalLoading = cfg.core.spice.diagonalLoading;
backendCfg.minimumSeparationDeg = max(backendCfg.minimumSeparationDeg, ...
    cfg.core.spice.minimumSeparationDeg);
```

Add local helper:

```matlab
function backendNames = local_backend_names_for_source_count(coreCfg, numSources)
if ~isfield(coreCfg, 'backendNamesBySource')
    switch numSources
        case 1
            backendNames = {'music'};
        case 2
            backendNames = {coreCfg.backendName};
        case 3
            backendNames = {coreCfg.threeSourceBackendName};
    end
    return;
end
switch numSources
    case 1
        backendNames = coreCfg.backendNamesBySource.single;
    case 2
        backendNames = coreCfg.backendNamesBySource.double;
    case 3
        backendNames = coreCfg.backendNamesBySource.triple;
    otherwise
        error('Unsupported source count: %d', numSources);
end
end
```

- [ ] **Step 4: Rename plot labels away from unconditional MUSIC**

Search:

```bash
rg -n "MUSIC spectrum|music spectrum|example_music_spectrum" run_project.m src default_config.m
```

Replace labels that refer to generic backend plots with `backend spectrum`. Keep `MUSIC` only when the curve is truly the MUSIC backend.

- [ ] **Step 5: Run static checks and sanity tests**

Run:

```bash
checkcode default_config.m run_project.m src/*.m tests/*.m
matlab -batch "addpath(genpath(pwd)); tests/run_sanity_tests"
```

Expected: no run-blocking MATLAB errors; existing style warnings may remain.

- [ ] **Step 6: Commit**

```bash
git add default_config.m run_project.m tests/run_sanity_tests.m
git commit -m "feat: default core diagnostics to parallel backends"
```

---

### Task 7: Traceable Smoke Run And Research Log

**Files:**
- Modify: `docs/research-log.md`
- Create: `results/<pending-local-hash>/RUN_NOTES.md`
- Create: `results/<pending-local-hash>/manifest.md`

- [ ] **Step 1: Generate pending local hash**

Run:

```bash
py -X utf8 .codex/skills/project-code-change-log/scripts/new_local_hash.py
```

Expected: prints a value matching `local-[0-9a-f]{8}`. Use the same value for all remaining steps in this task.

- [ ] **Step 2: Capture base HEAD and worktree status**

Run:

```bash
git rev-parse --short HEAD
git status --short
```

Expected: record current committed base and uncommitted changes if any. `algorithms/SPICE/` may remain untracked unless the implementation intentionally imports it.

- [ ] **Step 3: Run validation**

Run:

```bash
checkcode default_config.m run_project.m src/*.m tests/*.m
matlab -batch "addpath(genpath(pwd)); tests/run_sanity_tests"
```

Expected: sanity tests pass. Record any allowed `checkcode` warnings in notes.

- [ ] **Step 4: Run a small backend smoke if runtime is reasonable**

Run a small Case13/core backend smoke, using the project’s existing entrypoint or a one-off MATLAB command that sets:

```matlab
cfg = default_config(pwd);
cfg.run.cases = 13;
cfg.case13.monteCarlo = 2;
cfg.case13.sourceCounts = [1 2 3];
cfg.case13.backendNamesBySource = cfg.core.backendNamesBySource;
run_project(cfg);
```

Expected: outputs are written under `results/<pending-local-hash>/...` if the entrypoint supports configured result root. If the existing entrypoint still controls result directory internally, record the actual output path and do not move old results.

- [ ] **Step 5: Write `RUN_NOTES.md`**

Create:

```markdown
# Run notes

- Timestamp: `<YYYY-MM-DD HH:MM Asia/Shanghai>`
- Version hash: `<pending-local-hash>`
- Base HEAD: `<short-hash>`
- Worktree state: `<git status --short output or clean>`

## Commands

- `checkcode default_config.m run_project.m src/*.m tests/*.m`
- `matlab -batch "addpath(genpath(pwd)); tests/run_sanity_tests"`
- `<smoke command if run>`

## Config overrides

- Backend families: MUSIC, SPICE+, Grid ML
- Smoke Monte Carlo: 2
- Source counts: 1, 2, 3

## Notes

- This validates parallel backend plumbing and smoke behavior.
- This is not a final benchmark performance conclusion.
```

- [ ] **Step 6: Write `manifest.md`**

Create:

```markdown
# Results manifest

- Version hash: `<pending-local-hash>`
- Base HEAD: `<short-hash>`
- Worktree state: `<clean or uncommitted code changes>`

## Cases

- `<case folder>`: parallel backend smoke for 1/2/3-source diagnostics

## Not run

- Full Case12/Case13 benchmark: skipped until smoke validation is accepted.
```

- [ ] **Step 7: Update `docs/research-log.md`**

Add a latest entry:

```markdown
### 2026-05-13: Parallel DOA backend family plumbing

- Version hash: `<pending-local-hash>`
- Base HEAD: `<short-hash>`
- Worktree state: `<clean or uncommitted code changes>`
- Change:
  - Added SPICE/SPICE+ as tracked backend options.
  - Added common backend dispatch for MUSIC, SPICE+, and Grid ML.
  - Extended core 1/2/3-source diagnostics to compare backend families on common snapshots.
- Affected cases:
  - Case12/Case13-style source-count diagnostics.
  - Backend diagnostic paths using `benchmark_doa_backends`.
- Validation:
  - `checkcode default_config.m run_project.m src/*.m tests/*.m`
  - `matlab -batch "addpath(genpath(pwd)); tests/run_sanity_tests"`
  - `<smoke command/result if run>`
- Result path: `results/<pending-local-hash>/`
- Case outputs:
  - `<case folder if produced>`
- Remaining risk:
  - Smoke validation does not establish final performance ranking.
  - SPICE+ may improve spectrum readability without improving RMSE in every condition.
```

- [ ] **Step 8: Commit logs/results metadata**

```bash
git add docs/research-log.md results/<pending-local-hash>/RUN_NOTES.md results/<pending-local-hash>/manifest.md
git commit -m "docs: log parallel backend validation"
```

---

## Self-Review Checklist

- Spec coverage: SPICE backend, common dispatcher, parallel Case12/Case13-style source diagnostics, shared snapshots, backend metadata, and neutral spectrum labels are each covered by a task.
- Scope control: hybrid `spice_grid_rescore` is intentionally excluded from implementation and remains a follow-up.
- TDD coverage: each behavioral change starts with a sanity test that should fail before implementation.
- Traceability: project result/log requirements are covered in Task 7.
- Risk statement: smoke runs are explicitly not final benchmark conclusions.
