# Core 1-3 Source Case Structure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reorganize the experiment suite into a compact mainline evidence chain focused on 1-3 source DOA RMSE and spectrum behavior.

**Architecture:** Keep historical cases available, but add a new compact core orchestration path that runs Core 0-4 as the paper-facing mainline. Reuse existing manifold construction, single-source MUSIC evaluation, two-source pairwise backend, and backend ablation code. Add a real three-source covariance-fit backend and a narrow three-source benchmark module.

**Tech Stack:** MATLAB functions/scripts, markdown documentation, traceable result layout under `results/<hash>/`.

---

### Task 1: Add Core Case Configuration

**Files:**
- Modify: `default_config.m`
- Test: `tests/run_sanity_tests.m`

- [ ] **Step 1: Add compact core defaults to `default_config.m`**

Add this block after the existing `cfg.case11` block:

```matlab
cfg.core = struct();
cfg.core.enabledCases = {'manifold_sanity', 'single_source', 'two_source', ...
    'three_source', 'backend_ablation'};
cfg.core.evalSNRDb = 5;
cfg.core.snapshots = 500;
cfg.core.monteCarlo = 20;
cfg.core.methodKeys = {'ideal', 'interp', 'ard', 'proposed_v1', ...
    'proposed_v2', 'proposed_v3', 'oracle'};

cfg.core.singleSourceAnglesDeg = [-42.2 -20.2 0 18.8 42.8];
cfg.core.twoSourcePairsDeg = [-12.2 -4.2; 6.8 16.8; 23.8 31.8];
cfg.core.threeSourceSetsDeg = [-18.2 -7.2 8.8; -10.2 4.8 19.8; 12.8 24.8 36.8];

cfg.core.backendName = 'pairwise_grid_ml';
cfg.core.threeSourceBackendName = 'triplet_grid_ml';
cfg.core.backendCandidateAngleStrideDeg = 1;
cfg.core.backendMinimumSeparationDeg = 2;
cfg.core.backendMaximumSeparationDeg = 35;
cfg.core.topCandidateCount = 8;
```

- [ ] **Step 2: Add sanity test for config presence**

Add this test call near the top of `tests/run_sanity_tests.m`:

```matlab
local_test_core_config_defaults(cfg);
```

Add this helper:

```matlab
function local_test_core_config_defaults(cfg)
local_assert_true(isfield(cfg, 'core'), 'core config exists');
local_assert_equal(cfg.core.backendName, 'pairwise_grid_ml', 'core two-source backend');
local_assert_equal(cfg.core.threeSourceBackendName, 'triplet_grid_ml', 'core three-source backend');
local_assert_equal(size(cfg.core.twoSourcePairsDeg, 2), 2, 'core two-source pair width');
local_assert_equal(size(cfg.core.threeSourceSetsDeg, 2), 3, 'core three-source set width');
local_assert_true(cfg.core.monteCarlo >= 10, 'core diagnostic Monte Carlo is nontrivial');
end
```

- [ ] **Step 3: Run sanity test and confirm failure first**

Run:

```bash
matlab -batch "addpath(genpath(pwd)); run_sanity_tests"
```

Expected before implementation: FAIL because `cfg.core` does not exist.

- [ ] **Step 4: Implement config block**

Edit `default_config.m` with the block from Step 1.

- [ ] **Step 5: Run sanity test and confirm pass**

Run:

```bash
matlab -batch "addpath(genpath(pwd)); run_sanity_tests"
```

Expected: the new core config test passes. Other existing sanity tests still pass.

### Task 2: Add General Multi-Source Backend Utilities

**Files:**
- Modify: `src/doa_backend_utils.m`
- Create: `src/doa_backend_triplet_grid_ml.m`
- Test: `tests/run_sanity_tests.m`

- [ ] **Step 1: Add a failing triplet backend test**

Add this test call:

```matlab
local_test_triplet_grid_ml_backend(ctx);
```

Add this helper:

```matlab
function local_test_triplet_grid_ml_backend(ctx)
rng(9401, 'twister');
trueAngles = [-18.2 -7.2 8.8];
idx = [local_angle_index(ctx.thetaDeg, trueAngles(1)), ...
    local_angle_index(ctx.thetaDeg, trueAngles(2)), ...
    local_angle_index(ctx.thetaDeg, trueAngles(3))];
x = local_simulate_snapshots(ctx.AH(:, idx), 35, 1200);
backendCfg = struct('numSources', 3, 'candidateAnglesDeg', -25:1:15, ...
    'minimumSeparationDeg', 2, 'maximumSeparationDeg', 35, ...
    'topCandidateCount', 6);
result = doa_backend_triplet_grid_ml(x, ctx.AH, ctx.thetaDeg, backendCfg);
local_assert_true(all(abs(sort(result.estAnglesDeg) - trueAngles) <= 1.0), ...
    'triplet grid ML backend recovers high-SNR oracle triplet');
local_assert_true(isfield(result.diagnostics, 'topCandidateSetsDeg'), ...
    'triplet grid ML saves top candidates');
local_assert_true(size(result.diagnostics.topCandidateSetsDeg, 2) == 3, ...
    'triplet grid ML candidate sets have three columns');
end
```

- [ ] **Step 2: Run test to verify failure**

Run:

```bash
matlab -batch "addpath(genpath(pwd)); run_sanity_tests"
```

Expected: FAIL with undefined function `doa_backend_triplet_grid_ml`.

- [ ] **Step 3: Create `src/doa_backend_triplet_grid_ml.m`**

Implement a real three-source covariance-fit backend:

```matlab
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

candidateIdx = local_snap_candidate_indices(scanAnglesDeg, candidateAnglesDeg);
setIdx = local_candidate_triplets(candidateIdx, scanAnglesDeg, ...
    minimumSeparationDeg, maximumSeparationDeg);
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
result.diagnostics.topCandidateSetsDeg = sort(scanAnglesDeg(setIdx(1:topCount, :)), 2);
result.diagnostics.topCandidateScores = sortedScores(1:topCount);
end
```

Add local helpers in the same file:

```matlab
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
coeff = lsqnonneg(real(design' * design), real(design' * target));

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
```

Also add `local_snap_candidate_indices`, `local_angle_tolerance_from_grid`, and `local_optional_field` by following the exact style in `src/doa_backend_pairwise_grid_ml.m`.

- [ ] **Step 4: Run sanity tests**

Run:

```bash
matlab -batch "addpath(genpath(pwd)); run_sanity_tests"
```

Expected: triplet backend test passes.

### Task 3: Add General Core Benchmark Module

**Files:**
- Create: `src/benchmark_core_sources.m`
- Test: `tests/run_sanity_tests.m`

- [ ] **Step 1: Add failing shape test**

Add this test call:

```matlab
local_test_core_source_benchmark_shapes(ctx);
```

Add helper:

```matlab
function local_test_core_source_benchmark_shapes(ctx)
rng(9501, 'twister');
methods = repmat(struct('name', '', 'label', '', 'manifold', []), 1, 2);
methods(1) = struct('name', 'oracle_a', 'label', 'Oracle A', 'manifold', ctx.AH);
methods(2) = struct('name', 'oracle_b', 'label', 'Oracle B', 'manifold', ctx.AH);
evalCfg = struct();
evalCfg.snrDb = 15;
evalCfg.snapshots = 300;
evalCfg.monteCarlo = 2;
evalCfg.toleranceDeg = 0.6;
evalCfg.trueAngleSets = [6.8 16.8; 23.8 31.8];
evalCfg.numSources = 2;
evalCfg.backendName = 'pairwise_grid_ml';
evalCfg.backendCfg = struct('candidateAnglesDeg', 0:1:40, ...
    'minimumSeparationDeg', 2, 'maximumSeparationDeg', 35, ...
    'topCandidateCount', 4);
bench = benchmark_core_sources(ctx, methods, evalCfg);
local_assert_equal(size(bench.perTargetRmse), [2 2], 'core benchmark per-target RMSE shape');
local_assert_equal(numel(bench.summary.meanRmse), 2, 'core benchmark summary method count');
local_assert_equal(bench.snapshotPolicy, 'common_truth_snapshots_across_methods', ...
    'core benchmark common snapshot policy');
end
```

- [ ] **Step 2: Run test to verify failure**

Run:

```bash
matlab -batch "addpath(genpath(pwd)); run_sanity_tests"
```

Expected: FAIL with undefined function `benchmark_core_sources`.

- [ ] **Step 3: Implement `benchmark_core_sources.m`**

Implement this interface:

```matlab
function result = benchmark_core_sources(ctx, methods, evalCfg)
%BENCHMARK_CORE_SOURCES Multi-source DOA benchmark with common snapshots.
```

Behavior:

- `evalCfg.trueAngleSets` is an `N x K` matrix for K sources.
- snapshots are generated from `ctx.AH` and reused across all methods.
- for `K = 1`, use current single-source MUSIC estimate.
- for `K = 2`, dispatch to `doa_backend_pairwise_grid_ml` when requested.
- for `K = 3`, dispatch to `doa_backend_triplet_grid_ml`.
- compute assignment RMSE by sorting estimated and true angles for 1D DOA.
- compute worst-source absolute error.
- compute resolved rate as `all(abs(estAngles - trueAngles) <= evalCfg.toleranceDeg)`.
- save representative spectrum for target 1 / MC 1. If backend spectrum is empty, compute MUSIC spectrum for visualization.

Result fields:

```matlab
result.numSources
result.trueAngleSetsDeg
result.snapshotPolicy
result.methodLabels
result.perTargetRmse
result.perTargetResolvedRate
result.perTargetWorstAbsError
result.summary.meanRmse
result.summary.meanResolvedRate
result.summary.meanWorstAbsError
result.representative(methodIdx).spectrum
result.representative(methodIdx).estAnglesDeg
```

- [ ] **Step 4: Run sanity tests**

Run:

```bash
matlab -batch "addpath(genpath(pwd)); run_sanity_tests"
```

Expected: all benchmark shape tests pass.

### Task 4: Add Core Orchestration Case

**Files:**
- Modify: `run_project.m`
- Test: `tests/run_sanity_tests.m`

- [ ] **Step 1: Add a new selected case id**

Add a new case runner after Case 11:

```matlab
@case12_core_1to3_source_mainline
```

Add folder name:

```matlab
'case12_core_1to3_source_mainline'
```

Update error range from `[1, 11]` to `[1, 12]`.

- [ ] **Step 2: Implement `case12_core_1to3_source_mainline`**

Add a function in `run_project.m`:

```matlab
function caseResult = case12_core_1to3_source_mainline(cfg, ctx)
rng(cfg.randomSeed + 12, 'twister');
outDir = local_case_output_dir(cfg, 'case12_core_1to3_source_mainline');

calIdx = select_calibration_indices(ctx.thetaDeg, cfg.case3.representativeL, 'uniform');
models = build_sparse_models(ctx, calIdx, cfg.model);
methods = local_named_methods(ctx, models, cfg.core.methodKeys);

caseResult = struct();
caseResult.outputDir = outDir;
caseResult.methodLabels = {methods.label};
caseResult.coreConfig = cfg.core;
caseResult.manifoldSanity = local_core_manifold_sanity(ctx, methods);
caseResult.singleSource = local_core_source_run(ctx, methods, cfg, 1, cfg.core.singleSourceAnglesDeg);
caseResult.twoSource = local_core_source_run(ctx, methods, cfg, 2, cfg.core.twoSourcePairsDeg);
caseResult.threeSource = local_core_source_run(ctx, methods, cfg, 3, cfg.core.threeSourceSetsDeg);
caseResult.backendAblation = local_core_backend_ablation(ctx, methods, cfg);

local_plot_core_summary(caseResult, outDir);
save(fullfile(outDir, 'case12_results.mat'), 'caseResult');
end
```

- [ ] **Step 3: Implement helper `local_core_source_run`**

Use `benchmark_core_sources` and construct backend config:

```matlab
function bench = local_core_source_run(ctx, methods, cfg, numSources, trueAngleSets)
evalCfg = struct();
evalCfg.numSources = numSources;
evalCfg.trueAngleSets = trueAngleSets;
evalCfg.snrDb = cfg.core.evalSNRDb;
evalCfg.snapshots = cfg.core.snapshots;
evalCfg.monteCarlo = cfg.core.monteCarlo;
evalCfg.toleranceDeg = cfg.case9.toleranceDeg;
evalCfg.backendName = cfg.core.backendName;
if numSources == 3
    evalCfg.backendName = cfg.core.threeSourceBackendName;
end
evalCfg.backendCfg = local_core_backend_cfg(cfg.core, ctx.thetaDeg, trueAngleSets, numSources);
bench = benchmark_core_sources(ctx, methods, evalCfg);
end
```

- [ ] **Step 4: Implement plotting**

Create one summary figure:

- tile 1: mean RMSE for 1/2/3 sources by method;
- tile 2: resolved rate for 1/2/3 sources by method;
- tile 3: worst-source error for 1/2/3 sources by method;
- tile 4: representative spectra for V3.3 and Oracle for the three-source scene with true DOA xlines.

Save to:

```matlab
fullfile(outDir, 'core_1to3_source_summary.png')
```

- [ ] **Step 5: Add smoke test for Case 12 output shape**

Add a light direct benchmark test rather than running full `run_project(12)` in sanity:

```matlab
local_test_core_triplet_benchmark(ctx);
```

Helper:

```matlab
function local_test_core_triplet_benchmark(ctx)
rng(9502, 'twister');
method = struct('name', 'oracle', 'label', 'HFSS Oracle', 'manifold', ctx.AH);
evalCfg = struct('numSources', 3, 'trueAngleSets', [-18.2 -7.2 8.8], ...
    'snrDb', 25, 'snapshots', 800, 'monteCarlo', 1, ...
    'toleranceDeg', 1.0, 'backendName', 'triplet_grid_ml', ...
    'backendCfg', struct('candidateAnglesDeg', -25:1:15, ...
    'minimumSeparationDeg', 2, 'maximumSeparationDeg', 35, ...
    'topCandidateCount', 4));
bench = benchmark_core_sources(ctx, method, evalCfg);
local_assert_true(bench.summary.meanRmse < 1.5, ...
    'core triplet benchmark high-SNR oracle RMSE');
end
```

### Task 5: Update Documentation and Run Traceable Core Case

**Files:**
- Modify: `README.md`
- Modify: `simulation.md`
- Modify: `docs/research-log.md`
- Create: `results/<hash>/case12_core_1to3_source_mainline/`
- Create: `docs/assets/case12-core-1to3-source-mainline-<hash>.png`

- [ ] **Step 1: Update docs**

Update README and simulation notes to state:

```markdown
The paper-facing mainline is now Core 0-4, centered on 1-3 source RMSE and spectrum behavior. Historical cases remain available as appendix/diagnostic evidence.
```

- [ ] **Step 2: Run validation**

Run:

```bash
matlab -batch "addpath(genpath(pwd)); run_sanity_tests"
matlab -batch "checkcode default_config.m run_project.m src/*.m tests/*.m"
```

Expected: sanity passes; checkcode has no new run-blocking errors.

- [ ] **Step 3: Generate pending local hash**

Run:

```bash
python3 .codex/skills/project-code-change-log/scripts/new_local_hash.py
```

- [ ] **Step 4: Run Case 12 only**

Run:

```bash
matlab -batch "addpath(genpath(pwd)); cfg=default_config(pwd); cfg.run.useTraceableDirs=true; cfg.run.resultRoot=fullfile(pwd,'results'); cfg.run.runId='<hash>'; cfg.run.pendingLocalHash='<hash>'; cfg.run.baseHead='not-a-git-repo'; cfg.run.gitStatusShort='fatal: not a git repository (or any of the parent directories): .git'; cfg.run.command='matlab -batch Case12 core 1to3 source mainline'; cfg.run.notes='Core 1-3 source mainline diagnostic; RMSE and spectrum focus; diagnostic only, not full paper profile.'; run_project(12,cfg);"
```

- [ ] **Step 5: Verify and log**

Run:

```bash
matlab -batch "s=load(fullfile('results','<hash>','case12_core_1to3_source_mainline','case12_results.mat')); cr=s.caseResult; disp(cr.singleSource.summary.meanRmse); disp(cr.twoSource.summary.meanRmse); disp(cr.threeSource.summary.meanRmse);"
```

Copy image:

```bash
cp results/<hash>/case12_core_1to3_source_mainline/core_1to3_source_summary.png docs/assets/case12-core-1to3-source-mainline-<hash>.png
```

Add top `docs/research-log.md` entry with:

- version hash;
- Core 0-4 design summary;
- validation commands;
- Case 12 result path;
- RMSE/resolved/worst-error summary;
- caution that this is a diagnostic mainline, not paper-final.

### Task 6: Keep Historical Cases but Mark as Appendix

**Files:**
- Modify: `README.md`
- Modify: `simulation.md`
- Modify: `run_project.m` comments only if needed

- [ ] **Step 1: Add appendix mapping**

Add this README table:

```markdown
| Role | Cases |
| --- | --- |
| Mainline | Case 12 Core 1-3 Source Mainline |
| Backend ablation | Case 11 |
| Historical/sensitivity appendix | Case 1-10 |
```

- [ ] **Step 2: Do not delete historical cases**

Confirm:

```bash
rg -n "case01_|case10_|case11_|case12_" run_project.m
```

Expected: all historical cases still exist, plus new Case 12.

---

## Self-Review Checklist

- Spec coverage: Core 0-4 are implemented by Task 4 and documented by Task 5/6.
- TDD coverage: config, triplet backend, core benchmark shapes, and triplet high-SNR benchmark all have sanity tests.
- No hidden estimator shortcut: three-source evaluation uses a real triplet covariance-fit backend.
- Traceability: Task 5 creates versioned results and research-log entry.
- Scope control: historical cases are kept as appendix and not deleted.
