# Case12 Paper-Readable Plots Design

## Context

Case12 now runs as the default mainline evidence path with `monteCarlo = 50`, `snapshots = 1000`, and 1/2/3-source metrics. The three-source spectrum figure was improved to show both MUSIC pseudo-spectrum and triplet-grid backend marginal confidence.

The remaining presentation problem is readability:

- In three-source plots, full-method overlays are visually crowded.
- Several calibrated methods have similar RMSE or resolved-rate values, so grouped bars look nearly identical.
- Overlapping curves and equal-height bars make the result harder to inspect even when the numeric metrics are reasonable.

The goal is to improve figure readability without changing the estimator, metrics, source sets, Monte Carlo settings, backend logic, or snapshot policy.

## Goal

Add paper-readable Case12 figures alongside the full diagnostic figures:

- keep existing complete diagnostic figures for traceability;
- add focused paper figures with fewer methods, clearer styles, and better visibility for near-overlapping values;
- make three-source visual evidence easier to understand without overstating the quality of the coarse triplet-grid backend.

## Chosen Approach

Use Scheme C: separate diagnostic and paper-readable figures.

Existing figures remain:

- `core_rmse_summary.png`
- `core_resolved_summary.png`
- `core_two_source_spectrum.png`
- `core_three_source_spectrum.png`

Add new paper-readable figures:

- `paper_core_rmse_ranked.png`
- `paper_core_resolved_ranked.png`
- `paper_three_source_spectrum.png`

## Paper Three-Source Spectrum

`paper_three_source_spectrum.png` should be a cleaner companion to the full `core_three_source_spectrum.png`.

It should:

- show only key methods:
  - `ARD`
  - `Proposed V3.3`
  - `HFSS Oracle`
  - `Ideal`
- use a two-panel layout:
  - top: smoothed normalized MUSIC pseudo-spectrum;
  - bottom: triplet-grid marginal confidence;
- use a local x-window around the first three-source test set:
  - from `min(true DOA) - 10 deg` to `max(true DOA) + 10 deg`, clipped to available grid;
- show true DOAs as black dashed vertical lines;
- show estimated DOAs as method-colored markers;
- use distinct line styles and markers so curves remain distinguishable if colors are close.

Smoothing is display-only. It must not modify stored spectrum data or estimator output. A simple moving average over 3 to 5 samples is sufficient because the grid is dense.

## Paper RMSE And Resolved-Rate Figures

Grouped bars are retained for full diagnostics, but paper-readable summaries should use point/line plots because they handle near-equal values better.

`paper_core_rmse_ranked.png`:

- plot method on x-axis and mean RMSE on y-axis;
- include three series for `1 source`, `2 sources`, and `3 sources`;
- use line + marker style, with small x-offsets per source count to avoid overlap;
- annotate values for:
  - `Proposed V3.3`
  - `HFSS Oracle`
  - best non-oracle calibrated method for each source count;
- keep the y-axis honest, starting at zero unless the range becomes unreadable; if a zoom is needed later, use a separate delta figure rather than truncating this one.

`paper_core_resolved_ranked.png`:

- plot method on x-axis and resolved rate on y-axis;
- include three series for `1 source`, `2 sources`, and `3 sources`;
- use small x-offsets and distinct markers;
- annotate values for `Proposed V3.3`, `HFSS Oracle`, and best non-oracle calibrated method;
- y-axis should be `[0 1]`.

The method order should remain fixed for comparability:

```text
Ideal / Interpolation / ARD / Proposed V1 / Proposed V2 / Proposed V3.3 / HFSS Oracle
```

The filename says `ranked` because the visual emphasis is performance comparison, but the initial implementation should keep fixed method order to avoid changing interpretation across figures. A later revision can add sorted variants if needed.

## Code Boundaries

Modify only plotting and documentation paths:

- `run_project.m`
  - add paper figure generation from existing `caseResult`;
  - add local plotting helpers for method selection, moving-average display smoothing, x-offset marker plots, and value annotations.
- `tests/run_sanity_tests.m`
  - add lightweight checks only if a helper is moved to a testable function; otherwise keep validation through Case12 run outputs.
- `docs/research-log.md`, `README.md`, and copied `docs/assets/*` after implementation/run.

Do not change:

- `benchmark_core_sources`
- `doa_backend_triplet_grid_ml`
- backend objectives
- source sets
- Monte Carlo settings
- RMSE/resolved-rate definitions
- common snapshot policy

## Validation

Run static checks:

```matlab
checkcode default_config.m run_project.m
```

Run sanity tests:

```matlab
addpath(genpath(pwd));
run('tests/run_sanity_tests.m')
```

Run the default Case12 path traceably:

```matlab
cfg = default_config(pwd);
run_project([], cfg);
```

Expected new outputs:

- `paper_core_rmse_ranked.png`
- `paper_core_resolved_ranked.png`
- `paper_three_source_spectrum.png`

Copy the new paper figures to `docs/assets/` and update `docs/research-log.md`.

## Risks And Constraints

- Paper-readable figures must not replace full diagnostic figures; both should be generated.
- Smoothing can improve visual readability but must be clearly limited to display-only spectrum curves.
- Annotating too many points will reduce readability. Limit annotations to V3.3, Oracle, and the best non-oracle calibrated method per source count.
- If the best non-oracle calibrated method is V3.3, avoid duplicate labels.

## Self-Review

- No placeholders remain.
- The design only changes figure generation and documentation.
- The design preserves metric definitions and backend behavior.
- The design explicitly handles overlapping curves and near-equal bars without misleading axis truncation.
