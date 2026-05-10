# Case12 Paper-Readable Plots Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add paper-readable Case12 figures that improve readability for overlapping curves and near-equal metric values while preserving existing diagnostics and all metric/backend behavior.

**Architecture:** Keep full diagnostic figures unchanged and generate additional paper figures from the already assembled `caseResult`. All changes stay inside `run_project.m` plotting helpers plus documentation/log updates after validation. No estimator, backend, or benchmark data path changes.

**Tech Stack:** MATLAB plotting, existing project helpers, traceable result folders under `results/<pending-local-hash>/`.

---

## File Structure

- Modify `run_project.m`
  - Add `local_plot_case12_paper_figures`.
  - Add `local_plot_case12_paper_metric`.
  - Add `local_plot_case12_paper_three_source_spectrum`.
  - Add small helpers for method selection, fixed style, smoothing, x-window clipping, and annotations.
- Do not modify `benchmark_core_sources.m` or backend code.
- After validation, update `README.md`, `docs/research-log.md`, and copy new figures to `docs/assets/`.

## Task 1: Wire Paper Figure Generation

**Files:**
- Modify: `run_project.m`

- [ ] **Step 1: Add paper plotting call**

In `case12_core_1to3_source_mainline`, after:

```matlab
local_plot_case12_core_summary(caseResult, outDir);
local_plot_case12_representative_spectra(caseResult, outDir);
```

add:

```matlab
local_plot_case12_paper_figures(caseResult, outDir);
```

- [ ] **Step 2: Add wrapper function**

After `local_plot_case12_representative_spectra`, add:

```matlab
function local_plot_case12_paper_figures(caseResult, outDir)
methodLabels = local_case11_display_labels(caseResult.methodLabels);
rmseValues = [caseResult.singleSource.summary.meanRmse(:), ...
    caseResult.twoSource.summary.meanRmse(:), ...
    caseResult.threeSource.summary.meanRmse(:)];
resolvedValues = [caseResult.singleSource.summary.meanResolvedRate(:), ...
    caseResult.twoSource.summary.meanResolvedRate(:), ...
    caseResult.threeSource.summary.meanResolvedRate(:)];

local_plot_case12_paper_metric(methodLabels, caseResult.methodNames, rmseValues, ...
    'Mean RMSE (deg)', 'Case 12: core RMSE by source count', ...
    fullfile(outDir, 'paper_core_rmse_ranked.png'), []);
local_plot_case12_paper_metric(methodLabels, caseResult.methodNames, resolvedValues, ...
    'Resolved rate', 'Case 12: core resolved rate by source count', ...
    fullfile(outDir, 'paper_core_resolved_ranked.png'), [0 1]);
local_plot_case12_paper_three_source_spectrum(caseResult.threeSource, ...
    fullfile(outDir, 'paper_three_source_spectrum.png'));
end
```

## Task 2: Add Paper Metric Plot

**Files:**
- Modify: `run_project.m`

- [ ] **Step 1: Add metric plotting helper**

Add after `local_plot_case12_paper_figures`:

```matlab
function local_plot_case12_paper_metric(methodLabels, methodNames, values, ylabelText, titleText, filePath, yLimits)
fig = figure('Visible', 'off', 'Position', [120 120 1180 560]);
hold on;
sourceLabels = {'1 source', '2 sources', '3 sources'};
markers = {'o', 's', '^'};
lineStyles = {'-', '--', '-.'};
xBase = 1:numel(methodLabels);
xOffsets = [-0.12, 0, 0.12];
colors = lines(3);
for sourceIdx = 1:3
    plot(xBase + xOffsets(sourceIdx), values(:, sourceIdx), ...
        'LineStyle', lineStyles{sourceIdx}, 'Marker', markers{sourceIdx}, ...
        'LineWidth', 1.8, 'MarkerSize', 7, 'Color', colors(sourceIdx, :));
end
grid on;
xlim([0.5, numel(methodLabels) + 0.5]);
if ~isempty(yLimits)
    ylim(yLimits);
else
    ylim([0, max(values(:)) * 1.08]);
end
set(gca, 'XTick', xBase, 'XTickLabel', methodLabels, 'TickLabelInterpreter', 'none');
xtickangle(25);
ylabel(ylabelText);
title(titleText, 'FontWeight', 'bold');
legend(sourceLabels, 'Location', 'bestoutside');
local_annotate_case12_metric_values(xBase, xOffsets, values, methodNames);
save_figure(fig, filePath);
end
```

- [ ] **Step 2: Add annotation helper**

Add after `local_plot_case12_paper_metric`:

```matlab
function local_annotate_case12_metric_values(xBase, xOffsets, values, methodNames)
v3Idx = find(strcmp(methodNames, 'proposed_v3'), 1, 'first');
oracleIdx = find(strcmp(methodNames, 'oracle'), 1, 'first');
excluded = strcmp(methodNames, 'ideal') | strcmp(methodNames, 'oracle');
for sourceIdx = 1:size(values, 2)
    candidates = values(:, sourceIdx);
    candidates(excluded(:)) = NaN;
    [~, bestIdx] = min(candidates);
    if all(values(:, sourceIdx) <= 1) && max(values(:, sourceIdx)) <= 1
        [~, bestIdx] = max(candidates);
    end
    annotateIdx = unique([v3Idx, oracleIdx, bestIdx], 'stable');
    annotateIdx = annotateIdx(~isnan(annotateIdx) & annotateIdx > 0);
    for idx = reshape(annotateIdx, 1, [])
        value = values(idx, sourceIdx);
        if ~isfinite(value)
            continue;
        end
        text(xBase(idx) + xOffsets(sourceIdx), value, sprintf(' %.3g', value), ...
            'FontSize', 8, 'Rotation', 35, 'VerticalAlignment', 'bottom', ...
            'HorizontalAlignment', 'left');
    end
end
end
```

Note: the helper detects resolved-rate plots by `max(values) <= 1`, so it chooses the best non-oracle calibrated method by max for resolved rate and min for RMSE.

## Task 3: Add Paper Three-Source Spectrum

**Files:**
- Modify: `run_project.m`

- [ ] **Step 1: Add paper three-source spectrum function**

Add after the existing `local_plot_case12_three_source_spectrum`:

```matlab
function local_plot_case12_paper_three_source_spectrum(sourceResult, filePath)
selectedNames = {'ard', 'proposed_v3', 'oracle', 'ideal'};
selectedIdx = local_case12_method_indices(sourceResult.methodNames, selectedNames);
fig = figure('Visible', 'off', 'Position', [120 120 1180 720]);
layout = tiledlayout(2, 1, 'Padding', 'compact', 'TileSpacing', 'compact');
trueAngles = sort(sourceResult.trueAngleSetsDeg(1, :));
xWindow = [max(min(sourceResult.backendCfg.scanAnglesDeg), min(trueAngles) - 10), ...
    min(max(sourceResult.backendCfg.scanAnglesDeg), max(trueAngles) + 10)];
[colors, lineStyles, markers] = local_case12_paper_styles(numel(selectedIdx));

nexttile;
hold on;
for plotIdx = 1:numel(selectedIdx)
    methodIdx = selectedIdx(plotIdx);
    spectrum = sourceResult.representative(methodIdx).spectrum;
    if isempty(spectrum)
        continue;
    end
    spectrumDb = 10 * log10(real(spectrum) ./ max(real(spectrum)));
    spectrumDb = local_case12_smooth_vector(spectrumDb, 5);
    plot(sourceResult.backendCfg.scanAnglesDeg, spectrumDb, ...
        'LineStyle', lineStyles{plotIdx}, 'Marker', 'none', 'LineWidth', 2.0, ...
        'Color', colors(plotIdx, :));
    local_plot_case12_estimated_markers(sourceResult.representative(methodIdx).estAnglesDeg, ...
        colors(plotIdx, :), -34, plotIdx);
end
local_plot_case12_truth_lines(trueAngles);
grid on;
xlim(xWindow);
ylim([-36 1]);
xlabel('Angle (deg)');
ylabel('Smoothed MUSIC spectrum (dB)');
title('Display-smoothed MUSIC pseudo-spectrum', 'FontWeight', 'bold');

nexttile;
hold on;
for plotIdx = 1:numel(selectedIdx)
    methodIdx = selectedIdx(plotIdx);
    diagnostics = sourceResult.representative(methodIdx).diagnostics;
    if ~isfield(diagnostics, 'marginalAnglesDeg') || ...
            ~isfield(diagnostics, 'marginalConfidence')
        continue;
    end
    marginalConfidence = diagnostics.marginalConfidence(:).';
    plot(diagnostics.marginalAnglesDeg, marginalConfidence, ...
        'LineStyle', lineStyles{plotIdx}, 'Marker', markers{plotIdx}, ...
        'LineWidth', 2.0, 'MarkerSize', 5, 'Color', colors(plotIdx, :));
    finiteConfidence = marginalConfidence(isfinite(marginalConfidence));
    if isempty(finiteConfidence)
        markerY = NaN;
    else
        markerY = min(finiteConfidence);
    end
    local_plot_case12_estimated_markers(sourceResult.representative(methodIdx).estAnglesDeg, ...
        colors(plotIdx, :), markerY, plotIdx);
end
local_plot_case12_truth_lines(trueAngles);
grid on;
xlim(xWindow);
xlabel('Angle (deg)');
ylabel('Triplet marginal confidence');
title('Backend-consistent triplet marginal confidence', 'FontWeight', 'bold');

legend(local_case11_display_labels(sourceResult.methodLabels(selectedIdx)), ...
    'Location', 'bestoutside', 'Interpreter', 'none');
title(layout, 'Case 12: paper-readable three-source spectrum diagnostic', ...
    'FontWeight', 'bold');
save_figure(fig, filePath);
end
```

- [ ] **Step 2: Add method-selection helper**

Add after the paper spectrum function:

```matlab
function selectedIdx = local_case12_method_indices(methodNames, selectedNames)
selectedIdx = zeros(1, 0);
for nameIdx = 1:numel(selectedNames)
    matchIdx = find(strcmp(methodNames, selectedNames{nameIdx}), 1, 'first');
    if ~isempty(matchIdx)
        selectedIdx(end+1) = matchIdx; %#ok<AGROW>
    end
end
end
```

- [ ] **Step 3: Add styles helper**

Add:

```matlab
function [colors, lineStyles, markers] = local_case12_paper_styles(numSeries)
baseColors = [ ...
    0.0000 0.4470 0.7410; ...
    0.8500 0.3250 0.0980; ...
    0.4660 0.6740 0.1880; ...
    0.4940 0.1840 0.5560];
colors = baseColors(1:numSeries, :);
lineStyles = {'-', '--', '-.', ':'};
markers = {'o', 's', '^', 'd'};
end
```

- [ ] **Step 4: Add smoothing helper**

Add:

```matlab
function smoothed = local_case12_smooth_vector(values, windowLength)
values = values(:).';
if windowLength <= 1 || numel(values) < windowLength
    smoothed = values;
    return;
end
kernel = ones(1, windowLength) / windowLength;
smoothed = conv(values, kernel, 'same');
end
```

## Task 4: Validate And Run

**Files:**
- Read/produce: `results/<pending-local-hash>/...`
- Modify after run: `README.md`, `docs/research-log.md`
- Copy images to: `docs/assets/`

- [ ] **Step 1: Run static check**

Run:

```bash
matlab -batch "checkcode('default_config.m','run_project.m')"
```

Expected: no parse errors. Existing `datestr/now/STRCMPI` warnings are acceptable.

- [ ] **Step 2: Run sanity tests**

Run:

```bash
matlab -batch "addpath(genpath(pwd)); run('tests/run_sanity_tests.m')"
```

Expected: `All sanity tests PASS.`

- [ ] **Step 3: Generate pending local hash**

Run:

```bash
python3 .codex/skills/project-code-change-log/scripts/new_local_hash.py
```

Expected: output matching `local-[0-9a-f]{8}`.

- [ ] **Step 4: Run default Case12 traceably**

Replace `local-xxxxxxxx` with the generated hash:

```bash
matlab -batch "addpath(genpath(pwd)); cfg=default_config(pwd); cfg.run.useTraceableDirs=true; cfg.run.resultRoot=fullfile(pwd,'results'); cfg.run.runId='local-xxxxxxxx'; cfg.run.pendingLocalHash='local-xxxxxxxx'; cfg.run.baseHead='unavailable-not-a-git-repo'; cfg.run.gitStatusShort='fatal: not a git repository'; cfg.run.command='matlab -batch addpath/genpath; cfg=default_config(pwd); run_project([],cfg)'; cfg.run.notes='Case12 adds paper-readable metric and three-source spectrum figures.'; run_project([],cfg);"
```

Expected new files:

```text
results/local-xxxxxxxx/case12_core_1to3_source_mainline/paper_core_rmse_ranked.png
results/local-xxxxxxxx/case12_core_1to3_source_mainline/paper_core_resolved_ranked.png
results/local-xxxxxxxx/case12_core_1to3_source_mainline/paper_three_source_spectrum.png
```

- [ ] **Step 5: Copy paper figures to docs assets**

Run:

```bash
cp results/local-xxxxxxxx/case12_core_1to3_source_mainline/paper_core_rmse_ranked.png docs/assets/case12-paper-core-rmse-local-xxxxxxxx.png
cp results/local-xxxxxxxx/case12_core_1to3_source_mainline/paper_core_resolved_ranked.png docs/assets/case12-paper-core-resolved-local-xxxxxxxx.png
cp results/local-xxxxxxxx/case12_core_1to3_source_mainline/paper_three_source_spectrum.png docs/assets/case12-paper-three-source-spectrum-local-xxxxxxxx.png
```

- [ ] **Step 6: Update README**

Update latest Case12 line to mention the new paper-readable figures:

```markdown
- Latest local Case 12 core diagnostic: `results/local-xxxxxxxx/`, with `monteCarlo = 50`, `snapshots = 1000`, 1/2/3-source mean RMSE, full diagnostics, and paper-readable metric/spectrum figures in `case12_core_1to3_source_mainline/`.
```

- [ ] **Step 7: Update research log**

Add a new entry near the top of `docs/research-log.md`:

```markdown
### 2026-05-08：`local-xxxxxxxx` Case12 paper-readable plot set

- Version hash: `local-xxxxxxxx`
- Base HEAD: `unavailable-not-a-git-repo`
- Worktree state: uncommitted code and documentation changes; this local directory did not expose a `.git` repository.
- Change: added paper-readable Case12 metric plots and a focused three-source spectrum diagnostic.
- Change: kept full diagnostic figures unchanged while adding cleaner figures for overlapping curves and near-equal metric values.
- Affected cases: Case12 plotting only. Metrics, backend behavior, source sets, and snapshot policy are unchanged.
- Validation: sanity tests, checkcode, traceable default `run_project([],cfg)`.
- Result path: `results/local-xxxxxxxx/`
- Case outputs: `case12_core_1to3_source_mainline/`
- Interpretation: use the paper figures for presentation readability and the full figures for complete diagnostics.

![case12 paper three-source spectrum](assets/case12-paper-three-source-spectrum-local-xxxxxxxx.png)

![case12 paper rmse](assets/case12-paper-core-rmse-local-xxxxxxxx.png)
```

- [ ] **Step 8: Final artifact check**

Run:

```bash
find results/local-xxxxxxxx/case12_core_1to3_source_mainline -maxdepth 1 -type f | sort
rg -n "local-xxxxxxxx|paper-readable|paper_three_source" README.md docs/research-log.md
```

Expected: the three new paper PNGs exist, and README/research log reference the new hash.

## Self-Review

- Spec coverage: Task 1 wires generation, Task 2 handles near-equal metric values, Task 3 handles crowded spectrum curves, Task 4 validates and logs outputs.
- Placeholder scan: no TBD/TODO placeholders remain.
- Type consistency: helper names and filenames are consistent across tasks.
- Scope: only `run_project.m` plotting and docs are changed; no backend or metric behavior changes.
