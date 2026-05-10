# Case9 Pairwise Backend Mainline Design

## Decision

Case 9 should treat the enhanced backend as part of the main method definition:

```text
Proposed V3.3 manifold calibration + pairwise covariance-fit ML backend
```

The old MUSIC peak-picking backend remains useful as a diagnostic baseline, but it is no longer the primary Case 9 result path.

## Motivation

Recent backend diagnostics showed that the weak Case 9 behavior was dominated by the backend peak-selection step, not only by the calibrated manifold. Plain MUSIC independently selects spectral peaks and can collapse two nearby sources into one dominant peak. The pairwise grid ML backend evaluates joint two-source angle pairs against the sample covariance, which better matches the double-source estimation task.

This is not a metric shortcut. The backend uses the same HFSS-truth snapshots and the same estimator manifolds, but changes the estimator from independent peak picking to joint pair fitting. Case 11 remains the explicit backend ablation that explains this change.

## Scope

- Case 9 defaults use `pairwise_grid_ml`.
- Case 9 default diagnostic pairs are middle, non-extreme, and not too close:
  `[-12.2 -4.2; 6.8 16.8; 23.8 31.8]`.
- Case 9 uses a medium diagnostic Monte Carlo count, currently `20`, for fast but non-trivial validation.
- Case 11 remains the backend diagnostic comparing `music`, `music_pair_rescore`, and `pairwise_grid_ml`.
- Proposed V3.3 manifold calibration objective is unchanged.
- README, simulation notes, algorithm documentation, and research log must state that Case 9 mainline now uses the pairwise backend.

## Non-Goals

- Do not run a full paper-profile `1:10` experiment in this batch.
- Do not change Case 1-8 or Case 10 estimator semantics.
- Do not claim paper-final superiority from the medium Case 9 diagnostic.
- Do not remove old historical log entries; mark them as older MUSIC-backend evidence where needed.

## Required Evidence

The implementation must leave a coherent trace:

- `results/<pending-local-hash>/RUN_NOTES.md`
- `results/<pending-local-hash>/manifest.md`
- `results/<pending-local-hash>/case09_two_source_resolution/case09_results.mat`
- `results/<pending-local-hash>/case09_two_source_resolution/two_source_resolution.png`
- `docs/assets/case09-pairwise-mainline-<pending-local-hash>.png`
- `docs/research-log.md` top entry matching the result folder

## Validation

- Run `matlab -batch "addpath(genpath(pwd)); run_sanity_tests"`.
- Run `matlab -batch "checkcode default_config.m run_project.m src/doa_backend_pairwise_grid_ml.m src/benchmark_music.m tests/run_sanity_tests.m"`.
- Run traceable Case 9 only with default config after the mainline update.
- Confirm `case09_results.mat` contains `backendName = 'pairwise_grid_ml'`, `backendCfg`, source pairs, and summary metrics.

## Interpretation Rules

- New Case 9 numbers are not directly comparable to old MUSIC-backend Case 9 numbers as method-only improvements; the backend changed.
- Case 11 should be used to explain the backend lift.
- The current medium run is a diagnostic mainline result, not a final paper-profile benchmark.
