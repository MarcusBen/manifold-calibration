# Core 1-3 Source Case Structure Design

## Decision

The project should stop treating all existing cases as equal mainline evidence. The mainline should be reorganized around a compact 1-3 source DOA evidence chain:

```text
Core 0: manifold sanity
Core 1: single-source DOA RMSE and spectrum
Core 2: two-source DOA RMSE and spectrum
Core 3: three-source DOA RMSE and spectrum
Core 4: backend ablation
```

Older sensitivity and robustness cases remain useful, but they should be appendix/diagnostic evidence instead of driving the paper narrative.

## Motivation

The current project has accumulated many cases from several research phases. This helped debugging, but it now makes the evidence chain look redundant and unfocused. The current scientific question is narrower:

> Does the calibrated manifold improve practical DOA estimation for 1-3 sources, as measured by RMSE and spectrum quality?

The case structure should therefore emphasize:

- 1-source localization accuracy and model-error floor;
- 2-source pair recovery with the current pairwise covariance-fit ML backend;
- 3-source stress behavior;
- representative spectra that explain why errors happen;
- backend ablation that justifies replacing plain MUSIC peak picking in the two-source mainline.

## Mainline Cases

### Core 0: Manifold Sanity

Purpose: confirm that the calibrated manifolds are geometrically plausible before DOA evaluation.

Recommended content:

- calibration reconstruction check;
- unseen-angle manifold relative error;
- edge/high-mismatch subset error;
- compact figure or table, not a large multi-case sweep.

Current sources to reuse:

- existing Case 1 / Case 3 logic;
- `compute_manifold_metrics`;
- ARD / V1 / V2 / V3.3 / HFSS Oracle method construction.

### Core 1: Single-Source DOA

Purpose: show how manifold quality affects one-source localization.

Primary metrics:

- RMSE;
- mean bias;
- P90 absolute error;
- representative MUSIC spectrum with true DOA marker.

Recommended design:

- use a moderate set of angles covering center, edge, and high-mismatch areas;
- use common HFSS-truth snapshots across methods;
- report RMSE and spectrum quality together;
- avoid splitting SNR and snapshot sweeps into separate mainline cases unless needed for appendix.

Current sources to reuse:

- Case 7 SNR logic;
- Case 8 snapshot logic;
- existing representative spectrum plotting.

### Core 2: Two-Source DOA

Purpose: evaluate pair recovery using the current mainline backend.

Primary backend:

```text
pairwise_grid_ml
```

Primary metrics:

- pair RMSE;
- resolution rate;
- stable / biased / marginal / unresolved state distribution;
- separation-collapse rate;
- representative MUSIC spectrum for visual manifold interpretation.

Recommended design:

- use middle, non-extreme source pairs as the default diagnostic set;
- include separation values around 6-10 deg;
- keep Case 11 as backend ablation, not as a competing mainline result;
- clearly state that older MUSIC-backend Case 9 numbers are historical ablation evidence.

Current sources to reuse:

- current Case 9 pairwise-backend path;
- `benchmark_music` backend dispatch;
- `doa_backend_pairwise_grid_ml`;
- `case09_helpers`.

### Core 3: Three-Source DOA

Purpose: add a moderate stress case that checks whether the calibrated manifold remains useful beyond two sources.

Primary metrics:

- assignment RMSE after optimal matching between estimated and true angles;
- per-trial resolved count;
- worst-source absolute error;
- representative spectrum with three true DOA markers.

Recommended design:

- use a small fixed set of non-extreme three-source scenes;
- avoid very close or edge-only triples in the default diagnostic;
- start with 2-3 source triples and moderate Monte Carlo;
- use the same backend philosophy as Core 2 where practical: joint candidate-set scoring rather than independent peak picking.

Implementation choice:

- extend the covariance-fit backend to real three-source candidate tuples. Do not silently reuse the two-source backend for three-source evaluation. If runtime becomes too high, restrict the default three-source candidate set and Monte Carlo count rather than changing the estimator semantics.

### Core 4: Backend Ablation

Purpose: explain why the project no longer treats plain MUSIC peak picking as the two-source mainline backend.

Backends:

- `music`;
- `music_pair_rescore`;
- `pairwise_grid_ml`;
- future three-source backend if added.

Primary metrics:

- resolution rate;
- stable rate;
- RMSE;
- collapse rate;
- representative spectrum / candidate diagnostics.

Current sources to reuse:

- current Case 11.

## Appendix / Diagnostic Cases

The following should be kept but removed from the mainline narrative:

- calibration count sensitivity;
- sampling strategy sensitivity;
- model sensitivity;
- random split robustness;
- historical V2/V3 screening comparisons;
- GP-ANM fallback/offline diagnostic;
- full separation sweeps used only to stress-test settings.

These are still useful for review defense and engineering confidence, but should not distract from the 1-3 source RMSE/spectrum story.

## Documentation Impact

README, simulation notes, and algorithm documents should describe the new structure explicitly:

- mainline evidence is 1-3 source DOA RMSE plus spectrum;
- two-source mainline backend is pairwise covariance-fit ML;
- MUSIC peak picking is backend ablation / spectrum diagnostic;
- old case numbers are preserved as historical implementation details but no longer define the paper story.

## Validation Strategy

The first implementation should not rewrite everything at once. It should:

1. Create a new compact orchestration path or profile for the core cases.
2. Reuse existing single-source and two-source code where possible.
3. Add three-source support in a narrow, testable backend module.
4. Run sanity tests.
5. Run a traceable medium diagnostic for the new core set.
6. Update research log and README with cautious wording.

## Success Criteria

- A reader can understand the paper evidence chain without reading 11 historical cases.
- Core 1, Core 2, and Core 3 all report RMSE and representative spectrum behavior.
- Core 2 uses `pairwise_grid_ml` as the mainline backend.
- Core 4 explains the backend choice.
- Appendix cases remain accessible but are not presented as equal-weight mainline evidence.
- The result/log/documentation trace is consistent.

## Non-Goals

- Do not delete historical cases or results.
- Do not claim final paper-profile performance from the first compact run.
- Do not silently compare new pairwise-backend numbers against old MUSIC-backend numbers as if only the manifold changed.
- Do not introduce a three-source shortcut without labeling it clearly.
