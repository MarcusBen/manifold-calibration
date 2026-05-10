# Case11 Enhanced Backend Diagnostic Design

Date: 2026-05-08

Status: design approved in conversation; pending implementation plan.

Repository note: this local directory does not expose a `.git` repository, so the design document could not be committed here. `git status --short` returns `fatal: not a git repository (or any of the parent directories): .git`.

## Purpose

Add a separate Case 9 enhanced-backend diagnostic to answer one question:

```text
Is the weak Case 9 two-source result mainly caused by the MUSIC backend ceiling?
```

This diagnostic must not replace the current MUSIC-based main benchmark. Existing V3.3 claims remain tied to `benchmark_music` and the common-snapshot Case 9 rerun. The new backend path is an upper-bound diagnostic that compares stronger two-source estimators under the same snapshots, source pairs, and manifolds.

## Scope

In scope:

- Add an enhanced backend benchmark for two-source Case 9 diagnostics.
- Keep common HFSS-truth snapshots across all methods and backends.
- Compare current MUSIC, MUSIC pair-rescoring, and pairwise grid ML / covariance fitting.
- Run a small Case 9 subset first, then decide whether a full Case 9 diagnostic is worth running.
- Save diagnostic outputs under a new traceable case folder.

Out of scope:

- Replacing `benchmark_music` as the main paper benchmark.
- Changing V3.3 manifold construction, objective, or training pairs.
- Adding CVX, SDP solvers, or external SBL dependencies.
- Treating enhanced-backend results as direct Proposed V3.3 performance claims.

## Recommended Strategy

Use a dual-track evaluation:

1. Keep Case 9 MUSIC as the official baseline.
2. Add `case11_backend_diagnostic` as a separate upper-bound diagnostic.

Case11 answers:

- If `HFSS Oracle + pairwise_grid_ml` is much better than `HFSS Oracle + MUSIC`, then MUSIC is a material bottleneck.
- If `HFSS Oracle + pairwise_grid_ml` is still weak, then the Case 9 SNR/snapshot/separation condition is intrinsically hard.
- If Oracle improves but V3.3 does not, then V3.3's manifold or surrogate still loses information that a stronger backend could otherwise use.
- If Proposed V1 remains better than V3.3 under pairwise ML, then V1's two-peak structure remains useful evidence for future V3 design.

## Architecture

Add a backend-agnostic benchmark entry point:

```text
src/benchmark_doa_backends.m
```

Responsibilities:

- Snap requested source pairs to the HFSS grid.
- Generate one common HFSS-truth snapshot matrix per `(target, Monte Carlo)` trial.
- Evaluate each backend for each method manifold.
- Classify estimates using the current stable / biased / marginal / unresolved rules.
- Record RMSE, resolution rate, stable rate, marginal rate, biased rate, unresolved rate, and separation-collapse rate.

Add backend implementations:

```text
src/doa_backend_music_pair_rescore.m
src/doa_backend_pairwise_grid_ml.m
```

The existing MUSIC behavior can be reused directly or wrapped as the baseline backend.

## Backend 1: MUSIC Pair Rescoring

Purpose:

Determine whether the current MUSIC spectrum contains useful information but the top-k peak picker is too weak.

Flow:

1. Compute the same MUSIC pseudo-spectrum as `benchmark_music`.
2. Collect the top `N` local peaks, for example `N = 8` or `N = 12`.
3. Enumerate candidate peak pairs with a minimum separation constraint.
4. For each candidate pair, fit the covariance model:

```text
Rxx ~= A_pair * S_pair * A_pair' + sigma^2 I
```

5. Score the pair by covariance residual or negative likelihood proxy.
6. Return the lowest-residual pair.

Interpretation:

- If this improves strongly over MUSIC, the original peak picker is a bottleneck.
- If it does not improve, MUSIC's spectrum itself may be losing the useful pair information.

## Backend 2: Pairwise Grid ML / Covariance Fitting

Purpose:

Provide a stronger two-source upper-bound diagnostic by jointly estimating the angle pair instead of selecting independent spectrum peaks.

Core objective:

```text
min over theta1, theta2, p1, p2, sigma2:
|| Rxx - A(theta1,theta2) * diag([p1,p2]) * A(theta1,theta2)' - sigma2 I ||_F

subject to:
p1 >= 0, p2 >= 0, sigma2 >= 0
```

First implementation should be grid-only:

- Enumerate candidate angle pairs on the HFSS grid.
- Restrict to valid Case 9-like separations where useful.
- Fit nonnegative source powers and noise floor for each pair.
- Choose the pair with the lowest covariance residual.

Optimization Toolbox can be used later for optional local refinement if available. The baseline implementation must not require it.

Diagnostics to save:

- Best pair.
- Best score.
- Top candidate pairs and score gaps.
- Whether optional refinement ran.
- Runtime per backend/method if easy to record.

## Case11 Output

Add a separate case folder:

```text
results/<version-hash>/case11_backend_diagnostic/
```

Expected files:

```text
case11_results.mat
backend_resolution_summary.png
backend_stable_summary.png
backend_oracle_ceiling.png
representative_backend_spectra_or_scores.png
```

Core `case11_results.mat` fields:

```text
sourcePairsDeg
backendNames
methodLabels
snapshotPolicy
rmse
resolutionRate
stableRate
marginalRate
biasedRate
unresolvedRate
collapseRate
oracleCeilingDelta
backendDiagnostics
```

Recommended dimensions:

```text
metric(backend, pair, method)
```

Default smoke configuration:

```text
sourcePairsDeg = [23.8 31.8; 35.8 45.8]
monteCarlo = 20
methods = ARD / Proposed V1 / Proposed V3.3 / HFSS Oracle
backends = music / music_pair_rescore / pairwise_grid_ml
```

## Summary Metrics

For each backend, report:

```text
HFSS Oracle resolution / stable / RMSE
Proposed V3.3 resolution / stable / RMSE
Proposed V1 resolution / stable / RMSE
ARD resolution / stable / RMSE
```

Derived diagnostics:

```text
oracleGainOverMusic
v3GainOverMusic
v1GainOverMusic
v3ToOracleGap
v1ToOracleGap
```

Interpretation rules:

- Large `oracleGainOverMusic`: MUSIC is a backend bottleneck.
- Small `oracleGainOverMusic`: backend choice is not the main bottleneck.
- Large `oracleGainOverMusic` plus small `v3GainOverMusic`: V3.3's manifold/surrogate still loses usable information.
- V1 outperforming V3.3 under pairwise ML: V1's two-peak behavior remains valuable design evidence.

## Testing

Add tests before running Case11:

1. High-SNR oracle sanity:
   - Two-source HFSS Oracle manifold.
   - High SNR and large snapshots.
   - `pairwise_grid_ml` should recover the true grid angles within one grid step.

2. Common-snapshot regression:
   - Two identical methods must produce identical metrics under each backend.

3. Rescore isolation:
   - `music_pair_rescore` must use the same snapshots and MUSIC spectrum as baseline MUSIC.
   - It may change only pair selection / rescoring.

4. Result shape sanity:
   - Metric arrays must have dimensions `(backend, pair, method)`.
   - `snapshotPolicy` must remain `common_truth_snapshots_across_methods`.

## Risks

- Pairwise grid ML can be slow. First implementation must use small Case 9 subsets and optionally restrict candidate pairs by separation.
- Covariance fitting can confidently choose a ghost pair. Save top candidates and score gaps to detect this.
- Optional Optimization Toolbox refinement may improve accuracy but must not be required for reproducibility.
- Enhanced-backend results can be overinterpreted. Logs and README updates must label Case11 as diagnostic / upper-bound evidence only.

## Implementation Order

1. Add backend framework and two backend functions.
2. Add backend sanity tests.
3. Add `case11_backend_diagnostic` orchestration without changing Case9.
4. Run Case11 smoke with two pairs and `monteCarlo = 20`.
5. Update `docs/research-log.md` and traceable result metadata.
6. Decide whether a full Case9 enhanced-backend diagnostic is warranted.

## Approval State

The user approved:

- Dual-track strategy.
- Upper-bound diagnostic positioning.
- MATLAB built-in toolbox allowance, without external CVX/SDP dependency.
- Pairwise grid ML as the main enhanced backend.
- MUSIC pair-rescoring as an auxiliary diagnostic.
- Separate Case11 output and interpretation rules.
