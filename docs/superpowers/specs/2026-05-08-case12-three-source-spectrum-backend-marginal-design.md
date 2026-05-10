# Case12 Three-Source Spectrum Backend Marginal Design

## Context

Case12 now presents the main 1/2/3-source evidence path. The three-source result uses a coarse `triplet_grid_ml` covariance-fit backend, but the current `core_three_source_spectrum.png` only plots a standard `K=3` MUSIC pseudo-spectrum. That plot is visually useful, but it does not show the score surface actually used by the three-source estimator.

This mismatch can make the three-source figure look less convincing or confusing: the reported estimated angles come from a joint triplet covariance-fit objective, while the visible spectrum comes from independent single-angle MUSIC scanning.

## Goal

Improve the Case12 three-source figure so it communicates both:

- the familiar single-angle MUSIC peak shape; and
- the backend-consistent triplet-grid decision evidence.

The change is presentational and diagnostic. It must not change RMSE, resolved-rate definitions, source sets, snapshot policy, or the three-source backend objective.

## Chosen Approach

Use a two-panel Case12 three-source figure:

1. Top panel: normalized `K=3` MUSIC pseudo-spectrum.
2. Bottom panel: triplet-grid marginal confidence derived from the same candidate triplet covariance-fit scores used by `triplet_grid_ml`.

True DOAs are shown as black dashed vertical lines in both panels. Estimated DOAs are shown as method-colored markers or short vertical marks so the reader can compare truth, visual spectrum, and backend-selected angles.

## Backend Diagnostics

Extend `doa_backend_triplet_grid_ml` diagnostics without changing its selected estimate:

- `candidateSetIndex`: all candidate triplets as scan-grid indices, after sorting by ascending score.
- `candidateSetScores`: covariance-fit score for each candidate triplet, sorted ascending.
- `candidateSetAnglesDeg`: all candidate triplets as angles, sorted consistently with scores.
- `marginalAnglesDeg`: candidate angle grid used by the triplet backend.
- `marginalConfidence`: one scalar per candidate angle, where higher means better.

The marginal confidence is computed from the best score among all triplets containing each candidate angle. Since the covariance-fit score is lower-is-better, confidence is displayed as a normalized higher-is-better quantity. The exact normalization should be stable and plot-oriented, for example:

```text
bestScoreAtAngle = min(score of triplets containing angle)
rawConfidence = -bestScoreAtAngle
marginalConfidence = rawConfidence - max(rawConfidence)
```

The plotted marginal confidence can then be shown in dB-like or normalized linear units. Angles that never appear in a candidate triplet should be `NaN`, not zero, so the plot does not fabricate evidence outside the backend candidate grid.

## Plotting

`core_three_source_spectrum.png` becomes a two-panel figure:

- Top: `Normalized MUSIC spectrum (dB)`.
- Bottom: `Triplet-grid marginal confidence`.

Each method keeps the same line color across both panels. True DOAs use black dashed `xline`. Estimated DOAs use the corresponding method color. The title should explicitly say that the figure combines MUSIC spectrum and triplet-grid backend marginal score.

The two-source figure can remain as-is for now because the two-source backend already has cleaner pairwise behavior and the immediate ambiguity is in three-source presentation.

## Code Boundaries

Modify only:

- `src/doa_backend_triplet_grid_ml.m`
- `src/benchmark_core_sources.m` if diagnostics need light pass-through support
- `run_project.m` Case12 plotting helpers
- `tests/run_sanity_tests.m`
- docs/log files required by the project change-log workflow after implementation

Do not change:

- Case9 metrics or backend behavior
- Case11 backend diagnostic behavior
- Case12 RMSE or resolved-rate definitions
- source angle sets
- common snapshot policy

## Validation

Add sanity coverage that:

- `triplet_grid_ml` diagnostics include `candidateSetScores`, `candidateSetIndex`, and `marginalConfidence`.
- marginal confidence length matches the backend candidate angle grid.
- at least one true high-SNR source angle has finite marginal confidence in the oracle triplet test.

Then run:

```matlab
addpath(genpath(pwd));
run('tests/run_sanity_tests.m')
```

Run the default Case12 path and save traceable results:

```matlab
cfg = default_config(pwd);
run_project([], cfg);
```

The resulting interpretation should remain conservative: this improves the three-source evidence display, but `triplet_grid_ml` remains a coarse-grid diagnostic backend rather than a final optimized three-source estimator.

## Risks

- If all candidate scores are very close, the marginal curve may look flat. That is a valid diagnostic and should not be hidden.
- If too many methods are plotted, estimated-DOA markers can clutter the panel. Prefer small markers or short stems over full-height colored lines.
- Storing all candidate triplet scores increases `.mat` size, but the current candidate grid is small enough for Case12.

## Self-Review

- No placeholders remain.
- The design is limited to Case12 three-source diagnostics and does not change estimator metrics.
- The backend diagnostic fields are explicit.
- The plot semantics are clear: MUSIC shows single-angle pseudo-spectrum; marginal confidence shows backend-consistent triplet evidence.
