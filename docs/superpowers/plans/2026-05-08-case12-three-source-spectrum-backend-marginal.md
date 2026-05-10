# Case12 Three-Source Spectrum Backend Marginal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a backend-consistent triplet marginal confidence panel to the Case12 three-source spectrum figure without changing Case12 metrics or estimator behavior.

**Architecture:** `doa_backend_triplet_grid_ml` will expose sorted candidate triplet scores and a per-angle marginal confidence diagnostic. `benchmark_core_sources` already stores representative diagnostics, so the plot layer in `run_project.m` can render a two-panel three-source figure from existing result data. Tests will lock the new diagnostic fields and basic marginal semantics.

**Tech Stack:** MATLAB scripts/functions, existing project helpers, `tests/run_sanity_tests.m`, traceable result folders under `results/<pending-local-hash>/`.

---

## File Structure

- Modify `src/doa_backend_triplet_grid_ml.m`
  - Add all-candidate sorted diagnostics.
  - Add marginal confidence calculation from the same sorted triplet scores.
- Modify `tests/run_sanity_tests.m`
  - Extend `local_test_triplet_grid_ml_backend` to assert the new diagnostic fields and finite true-angle marginal responses.
- Modify `run_project.m`
  - Keep two-source spectrum unchanged.
  - Replace three-source plotting with a two-panel MUSIC plus triplet marginal confidence figure.
  - Add small local helpers for plotting true/estimated DOA markers.
- No expected changes to `src/benchmark_core_sources.m`
  - It already stores representative diagnostics from the backend.
- After implementation only, update `docs/research-log.md`, `README.md` if needed, `results/<hash>/RUN_NOTES.md`, and copy new figures to `docs/assets/`.

## Task 1: Triplet Backend Diagnostics

**Files:**
- Modify: `src/doa_backend_triplet_grid_ml.m`
- Test later in: `tests/run_sanity_tests.m`

- [ ] **Step 1: Locate sorted candidate block**

Read this block in `src/doa_backend_triplet_grid_ml.m`:

```matlab
[sortedScores, order] = sort(scores, 'ascend');
setIdx = setIdx(order, :);
fits = fits(order);
bestSetIdx = setIdx(1, :);
topCount = min(topCandidateCount, numSets);
```

- [ ] **Step 2: Add marginal confidence helper call**

Immediately after `topCount = min(topCandidateCount, numSets);`, add:

```matlab
[marginalAnglesDeg, marginalConfidence, marginalBestScores] = ...
    local_triplet_marginal_confidence(scanAnglesDeg, setIdx, sortedScores);
```

- [ ] **Step 3: Add new diagnostics fields**

In the `result.diagnostics` block, keep existing fields and add:

```matlab
result.diagnostics.candidateSetIndex = setIdx;
result.diagnostics.candidateSetScores = sortedScores;
result.diagnostics.candidateSetAnglesDeg = sort(scanAnglesDeg(setIdx), 2);
result.diagnostics.marginalAnglesDeg = marginalAnglesDeg;
result.diagnostics.marginalConfidence = marginalConfidence;
result.diagnostics.marginalBestScores = marginalBestScores;
```

Do not remove these existing compatibility fields:

```matlab
result.diagnostics.topCandidateSetsDeg = sort(scanAnglesDeg(setIdx(1:topCount, :)), 2);
result.diagnostics.topCandidateScores = sortedScores(1:topCount);
```

- [ ] **Step 4: Add the marginal helper**

Add this local function before `local_snap_candidate_indices`:

```matlab
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
```

- [ ] **Step 5: Sanity-check syntax quickly**

Run:

```bash
matlab -batch "checkcode('src/doa_backend_triplet_grid_ml.m')"
```

Expected: no syntax or parse errors. Style warnings are acceptable only if non-blocking.

## Task 2: Diagnostic Sanity Test

**Files:**
- Modify: `tests/run_sanity_tests.m`

- [ ] **Step 1: Extend the existing triplet test**

In `local_test_triplet_grid_ml_backend`, after the existing `topCandidateSetsDeg` assertions, add:

```matlab
local_assert_true(isfield(result.diagnostics, 'candidateSetIndex'), ...
    'triplet grid ML saves all candidate set indices');
local_assert_true(isfield(result.diagnostics, 'candidateSetScores'), ...
    'triplet grid ML saves all candidate scores');
local_assert_true(isfield(result.diagnostics, 'candidateSetAnglesDeg'), ...
    'triplet grid ML saves all candidate set angles');
local_assert_true(isfield(result.diagnostics, 'marginalAnglesDeg'), ...
    'triplet grid ML saves marginal angles');
local_assert_true(isfield(result.diagnostics, 'marginalConfidence'), ...
    'triplet grid ML saves marginal confidence');
local_assert_equal(numel(result.diagnostics.marginalConfidence), ...
    numel(result.diagnostics.marginalAnglesDeg), ...
    'triplet grid ML marginal confidence length');
local_assert_true(all(diff(result.diagnostics.candidateSetScores) >= -eps), ...
    'triplet grid ML candidate scores sorted');
for trueAngle = [-18 -6 12]
    [distance, marginalIdx] = min(abs(result.diagnostics.marginalAnglesDeg - trueAngle));
    local_assert_true(distance <= 1e-9 && ...
        isfinite(result.diagnostics.marginalConfidence(marginalIdx)), ...
        sprintf('triplet grid ML finite marginal confidence at %.1f deg', trueAngle));
end
```

- [ ] **Step 2: Run the focused sanity suite**

Run:

```bash
matlab -batch "addpath(genpath(pwd)); run('tests/run_sanity_tests.m')"
```

Expected: `All sanity tests PASS.`

If the test fails because a true angle is not on `marginalAnglesDeg`, inspect `candidateAnglesDeg` in the test. It should include `-18`, `-6`, and `12` because the test uses `-24:2:18`.

## Task 3: Case12 Three-Source Two-Panel Plot

**Files:**
- Modify: `run_project.m`

- [ ] **Step 1: Split two-source and three-source plotting**

Replace `local_plot_case12_representative_spectra` with:

```matlab
function local_plot_case12_representative_spectra(caseResult, outDir)
local_plot_case12_spectrum(caseResult.twoSource, 'Case 12: two-source representative spectrum', ...
    fullfile(outDir, 'core_two_source_spectrum.png'));
local_plot_case12_three_source_spectrum(caseResult.threeSource, ...
    fullfile(outDir, 'core_three_source_spectrum.png'));
end
```

- [ ] **Step 2: Add three-source plotting function**

Add this function after `local_plot_case12_spectrum`:

```matlab
function local_plot_case12_three_source_spectrum(sourceResult, filePath)
fig = figure('Visible', 'off', 'Position', [120 120 1180 720]);
layout = tiledlayout(2, 1, 'Padding', 'compact', 'TileSpacing', 'compact');
trueAngles = sort(sourceResult.trueAngleSetsDeg(1, :));
colors = lines(numel(sourceResult.methodLabels));

nexttile;
hold on;
for methodIdx = 1:numel(sourceResult.methodLabels)
    spectrum = sourceResult.representative(methodIdx).spectrum;
    if isempty(spectrum)
        continue;
    end
    spectrumDb = 10 * log10(real(spectrum) ./ max(real(spectrum)));
    plot(sourceResult.backendCfg.scanAnglesDeg, spectrumDb, 'LineWidth', 1.5, ...
        'Color', colors(methodIdx, :));
    local_plot_case12_estimated_markers(sourceResult.representative(methodIdx).estAnglesDeg, ...
        colors(methodIdx, :), -38, methodIdx);
end
local_plot_case12_truth_lines(trueAngles);
grid on;
xlabel('Angle (deg)');
ylabel('Normalized MUSIC spectrum (dB)');
ylim([-40 1]);
title('MUSIC pseudo-spectrum', 'FontWeight', 'bold');

nexttile;
hold on;
for methodIdx = 1:numel(sourceResult.methodLabels)
    diagnostics = sourceResult.representative(methodIdx).diagnostics;
    if ~isfield(diagnostics, 'marginalAnglesDeg') || ...
            ~isfield(diagnostics, 'marginalConfidence')
        continue;
    end
    plot(diagnostics.marginalAnglesDeg, diagnostics.marginalConfidence, ...
        'o-', 'LineWidth', 1.5, 'MarkerSize', 4, 'Color', colors(methodIdx, :));
    local_plot_case12_estimated_markers(sourceResult.representative(methodIdx).estAnglesDeg, ...
        colors(methodIdx, :), min(diagnostics.marginalConfidence(:), [], 'omitnan'), methodIdx);
end
local_plot_case12_truth_lines(trueAngles);
grid on;
xlabel('Angle (deg)');
ylabel('Triplet marginal confidence');
title('Triplet-grid backend marginal confidence', 'FontWeight', 'bold');

legend(local_case11_display_labels(sourceResult.methodLabels), ...
    'Location', 'bestoutside', 'Interpreter', 'none');
title(layout, 'Case 12: three-source MUSIC spectrum + triplet-grid backend marginal score', ...
    'FontWeight', 'bold');
save_figure(fig, filePath);
end
```

- [ ] **Step 3: Add true/estimated marker helpers**

Add these helpers after `local_plot_case12_three_source_spectrum`:

```matlab
function local_plot_case12_truth_lines(trueAngles)
for angleIdx = 1:numel(trueAngles)
    xline(trueAngles(angleIdx), '--k', 'LineWidth', 1.0, 'HandleVisibility', 'off');
end
end

function local_plot_case12_estimated_markers(estAnglesDeg, colorValue, yValue, methodIdx)
if isempty(estAnglesDeg) || ~isfinite(yValue)
    return;
end
estAnglesDeg = sort(estAnglesDeg(:).');
yOffset = 0.03 * methodIdx;
for angleIdx = 1:numel(estAnglesDeg)
    plot(estAnglesDeg(angleIdx), yValue + yOffset, 'v', ...
        'Color', colorValue, 'MarkerFaceColor', colorValue, ...
        'MarkerSize', 5, 'HandleVisibility', 'off');
end
end
```

- [ ] **Step 4: Ensure two-source plot still has truth lines**

In `local_plot_case12_spectrum`, keep the existing `xline` loop or replace it with:

```matlab
local_plot_case12_truth_lines(trueAngles);
```

Expected behavior: `core_two_source_spectrum.png` remains one panel. `core_three_source_spectrum.png` becomes two panels.

- [ ] **Step 5: Run syntax check**

Run:

```bash
matlab -batch "checkcode('run_project.m')"
```

Expected: no syntax or parse errors. Existing `datestr/now/STRCMPI` warnings are acceptable.

## Task 4: Full Validation And Traceable Run

**Files:**
- Read/produce: `results/<pending-local-hash>/...`
- Modify after run: `docs/research-log.md`, optionally `README.md`
- Copy images to: `docs/assets/`

- [ ] **Step 1: Run full sanity tests**

Run:

```bash
matlab -batch "addpath(genpath(pwd)); run('tests/run_sanity_tests.m')"
```

Expected: `All sanity tests PASS.`

- [ ] **Step 2: Run static checks**

Run:

```bash
matlab -batch "checkcode('default_config.m','run_project.m','src/doa_backend_triplet_grid_ml.m','tests/run_sanity_tests.m')"
```

Expected: no run-blocking errors. Existing style warnings are acceptable.

- [ ] **Step 3: Generate pending local hash**

Run:

```bash
python3 .codex/skills/project-code-change-log/scripts/new_local_hash.py
```

Expected: output matching `local-[0-9a-f]{8}`. Use this same value for the run folder, `RUN_NOTES.md`, `manifest.md`, and research log entry.

- [ ] **Step 4: Run default Case12 traceably**

Replace `local-xxxxxxxx` with the generated hash and run:

```bash
matlab -batch "addpath(genpath(pwd)); cfg=default_config(pwd); cfg.run.useTraceableDirs=true; cfg.run.resultRoot=fullfile(pwd,'results'); cfg.run.runId='local-xxxxxxxx'; cfg.run.pendingLocalHash='local-xxxxxxxx'; cfg.run.baseHead='unavailable-not-a-git-repo'; cfg.run.gitStatusShort='fatal: not a git repository'; cfg.run.command='matlab -batch addpath/genpath; cfg=default_config(pwd); run_project([],cfg)'; cfg.run.notes='Case12 three-source spectrum now includes triplet-grid backend marginal confidence.'; run_project([],cfg);"
```

Expected outputs:

```text
results/local-xxxxxxxx/RUN_NOTES.md
results/local-xxxxxxxx/manifest.md
results/local-xxxxxxxx/case12_core_1to3_source_mainline/case12_results.mat
results/local-xxxxxxxx/case12_core_1to3_source_mainline/core_three_source_spectrum.png
```

- [ ] **Step 5: Inspect result summary**

Run:

```bash
matlab -batch "load('results/local-xxxxxxxx/case12_core_1to3_source_mainline/case12_results.mat'); disp(caseResult.threeSource.representative(1).diagnostics);"
```

Expected: diagnostics include `marginalAnglesDeg`, `marginalConfidence`, `candidateSetScores`, and `candidateSetIndex`.

- [ ] **Step 6: Copy documentation images**

Run:

```bash
cp results/local-xxxxxxxx/case12_core_1to3_source_mainline/core_three_source_spectrum.png docs/assets/case12-three-source-backend-marginal-local-xxxxxxxx.png
cp results/local-xxxxxxxx/case12_core_1to3_source_mainline/core_rmse_summary.png docs/assets/case12-core-rmse-summary-local-xxxxxxxx.png
cp results/local-xxxxxxxx/case12_core_1to3_source_mainline/core_resolved_summary.png docs/assets/case12-core-resolved-summary-local-xxxxxxxx.png
```

- [ ] **Step 7: Update research log**

Add a new dated entry near the top of `docs/research-log.md` containing:

```markdown
### 2026-05-08：`local-xxxxxxxx` Case12 three-source backend-marginal spectrum

- Version hash: `local-xxxxxxxx`
- Base HEAD: `unavailable-not-a-git-repo`
- Worktree state: uncommitted code and documentation changes; this local directory did not expose a `.git` repository.
- Change: added backend-consistent triplet marginal confidence diagnostics to `triplet_grid_ml`.
- Change: changed Case12 three-source spectrum output to a two-panel MUSIC plus triplet-grid marginal confidence figure.
- Affected cases: Case12 figure/diagnostics only. RMSE, resolved-rate, source sets, and snapshot policy are unchanged.
- Validation: sanity tests, checkcode, traceable default `run_project([],cfg)`.
- Result path: `results/local-xxxxxxxx/`
- Case outputs: `case12_core_1to3_source_mainline/`
- Interpretation: this improves the three-source evidence display, but `triplet_grid_ml` remains a coarse-grid diagnostic backend.

![case12 three-source backend marginal](assets/case12-three-source-backend-marginal-local-xxxxxxxx.png)
```

- [ ] **Step 8: Final verification**

Run:

```bash
find results/local-xxxxxxxx -maxdepth 2 -type f | sort
rg -n "local-xxxxxxxx|backend marginal|marginal confidence" docs/research-log.md README.md
```

Expected: result files exist; research log references the new hash and copied image.

## Self-Review

- Spec coverage: Task 1 adds diagnostics, Task 2 tests them, Task 3 implements two-panel plotting, Task 4 performs traceable validation and logging.
- Placeholder scan: no TBD/TODO placeholders remain.
- Type consistency: diagnostic names match the spec exactly: `candidateSetIndex`, `candidateSetScores`, `candidateSetAnglesDeg`, `marginalAnglesDeg`, `marginalConfidence`.
- Scope: no Case9/Case11 metrics or behavior are changed.
