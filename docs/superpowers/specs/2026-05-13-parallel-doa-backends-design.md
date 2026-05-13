# Parallel DOA Backend Family Design

Date: 2026-05-13

## Goal

Turn MUSIC, SPICE/SPICE+, and covariance-fit Grid ML into parallel backend families for the main DOA experiments. The goal is not to replace MUSIC blindly, but to make backend choice explicit and comparable under identical snapshots, source sets, calibration methods, and evaluation metrics.

## Scope

This change covers the main project backend interface and Case12/Case13-style 1/2/3-source diagnostics. It does not change the V3.3 calibration objective, calibration weights, source-pair/source-triplet selection rules, or the existing stable/unresolved metric definitions.

The existing `algorithms/SPICE/` folder is treated as research reference material. Production code should import or adapt the required SPICE logic into `src/` so the main project does not depend on an untracked experimental path.

## Backend Families

### MUSIC

Keep MUSIC as the conventional baseline. It remains useful because it is simple, widely understood, and exposes when the downstream estimator is limited by subspace peak separation.

Backend names:

- `music`
- existing `music_pair_rescore` can remain as a legacy diagnostic, but should not be the main comparison line.

### SPICE

Add sparse covariance-spectrum backends:

- `spice`
- `spice_plus`

Both backends estimate a spectrum over the scan grid and extract the requested number of separated local peaks. Diagnostics should record iteration count, convergence history, selected grid indices, selected spectrum values, and noise estimates where available.

Default preference for new comparisons should be `spice_plus`, because it uses a shared noise estimate and is the cleaner candidate for a general backend line.

### Grid ML

Keep covariance-fit grid search as the strong estimator line:

- one source: add a lightweight single-source grid covariance-fit backend if needed for symmetry
- two sources: `pairwise_grid_ml`
- three sources: `triplet_grid_ml`

Grid ML remains the primary high-ceiling backend for RMSE and success-rate comparisons. It does not naturally produce a spectrum, so plots should either show an associated diagnostic spectrum or label it as an estimator-only backend.

## Data Flow

All backend families receive the same input contract:

- snapshots `x`
- scan manifold
- scan angles
- source count
- backend configuration

All backend families return the same output contract:

- backend name
- estimated DOAs in degrees
- representative spectrum when available
- sample covariance
- diagnostics struct

Benchmark runners must generate snapshots once per target and Monte Carlo trial, then reuse those snapshots across every backend and calibration method. This preserves the existing common-snapshot fairness policy.

## Case12/Case13 Behavior

Case12/Case13 should run backend families in parallel for 1/2/3-source settings:

- single source: `music`, `spice_plus`, optional single-source Grid ML
- double source: `music`, `spice_plus`, `pairwise_grid_ml`
- triple source: `music`, `spice_plus`, `triplet_grid_ml`

Outputs should include:

- RMSE by backend, method, source count, SNR or difficulty stratum
- success/unresolved rates by backend
- representative spectra for spectrum-producing backends
- estimator-only markers for Grid ML when no spectrum is available
- backend metadata in result `.mat` files and manifests

Plot titles and labels should avoid saying "MUSIC spectrum" unless the plotted curve is actually MUSIC. Use neutral labels such as "backend spectrum" or the concrete backend name.

## Hybrid Follow-Up

Do not enable a hybrid backend by default in this first pass. Keep it as a follow-up candidate:

- `spice_grid_rescore`
- SPICE/SPICE+ generates candidate peaks or local neighborhoods
- Grid ML rescoring chooses the final pair or triplet

This may improve speed and preserve the covariance-fit ceiling, but it should be evaluated after the clean parallel-backend comparison is working.

## Testing

Add focused sanity coverage:

- SPICE and SPICE+ return finite spectra and the requested number of peaks.
- High-SNR single-source oracle manifold resolves near the true angle.
- High-SNR double-source oracle manifold resolves separated sources.
- `benchmark_doa_backends` accepts `music`, `spice_plus`, and `pairwise_grid_ml`.
- Case12/Case13 backend metadata records the backend family and common snapshot policy.

Existing sanity tests should keep passing.

## Validation

Use small smoke runs first:

- run MATLAB sanity tests
- run a backend diagnostic with common snapshots and 1/2/3 source settings
- inspect representative spectra for MUSIC vs SPICE+
- verify result files contain backend names, metrics, and snapshot policy

Only after smoke validation should larger Case12/Case13 runs be used for conclusions.

## Risks

SPICE may improve spectrum shape without improving final RMSE in all regimes. That is acceptable; the result should be reported as backend-dependent behavior, not as a universal improvement.

Grid ML may still dominate RMSE while having less visually useful spectra. Plots should separate estimator performance from spectrum interpretability.

Adding too many backend variants can dilute the story. The default comparison should stay to three families: MUSIC, SPICE+, and Grid ML.
