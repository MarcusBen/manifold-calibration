# Backend-Switched Advantage Audit Design

## Context

The project has moved from plain MUSIC peak picking toward stronger source-count-aware backends:

- one source: MUSIC remains acceptable;
- two sources: `pairwise_grid_ml`;
- three sources: coarse `triplet_grid_ml`.

After this switch, Case12 shows that most calibrated frontends are lifted by the stronger backend. The V3.3 frontend no longer has an obvious advantage over ARD, Interpolation, V1, or V2. In some current Case12 metrics V3.3 is close to or worse than those baselines.

The next question is therefore not whether the backend helps. It is:

> Once the backend is fixed to a stronger source-count-aware estimator, does V3.3 still have a stable frontend advantage, and under which conditions?

## Goal

Add a focused audit case that maps V3.3's remaining advantage or failure conditions under the backend-switched evaluation stack.

The audit must answer:

- where V3.3 beats ARD;
- where V3.3 beats the best non-oracle baseline;
- where V3.3 loses clearly;
- whether any V3.3 advantage is broad enough to support a paper claim;
- whether the project should next optimize V3.3, roll back toward ARD/V1, or narrow the claim.

## Non-Goals

This audit does not:

- change V3.3 training or objective;
- change Case12 metrics;
- change source-count backends;
- tune hyperparameters to make V3.3 win;
- replace Case12 as the main compact demonstration.

It is an evidence-generation case, not an algorithm change.

## Proposed Case

Add a new case:

```text
case13_backend_switched_advantage_audit
```

Case13 should be callable explicitly:

```matlab
run_project(13, cfg)
```

The default `run_project()` behavior should remain Case12 only unless the user later decides Case13 should become default.

## Evaluation Stack

Fixed backend by source count:

- 1 source: MUSIC peak estimate from the scan manifold.
- 2 sources: `pairwise_grid_ml`.
- 3 sources: `triplet_grid_ml`.

Compared frontends:

- `Interpolation`
- `ARD`
- `Proposed V1`
- `Proposed V2`
- `Proposed V3.3`
- `HFSS Oracle`
- `Ideal`

`Ideal` is retained as a mismatch stress reference, not as the main competitor.

Main competitors:

- ARD
- best non-oracle calibrated baseline among Interpolation, ARD, V1, V2
- Oracle as ceiling

## Audit Conditions

The audit should scan a controlled matrix:

Calibration count:

```text
5 / 7 / 9 / 13
```

SNR:

```text
0 / 5 / 10 / 20 dB
```

Source count:

```text
1 / 2 / 3
```

Angle strata:

- center
- mid
- edge or high-mismatch

Difficulty:

- medium
- hard

For one source, difficulty can be represented by angle stratum only.

For two and three sources, difficulty should be represented by source spacing and region:

- medium: separated enough that the backend should have a fair chance;
- hard: closer or more mismatched, but not pathological or physically uninformative.

The selected pairs/triplets should be deterministic and traceable. They should avoid calibration angles for the current calibration count where possible.

## Run Profiles

Case13 should support two profiles:

### auditSmoke

Purpose: fast trend and code validation.

- Monte Carlo: `3`
- practical subset of calibration counts, SNRs, and strata;
- one target per retained stratum;
- enough to expose obvious win/loss structure;
- should be the first run after implementation.

Default practical smoke subset:

```text
calibration counts: 5 / 9
SNR: 0 / 10 dB
strata: center / edge
```

The full matrix remains reserved for `auditFull`, because the three-source `triplet_grid_ml` backend is the runtime bottleneck.

### auditFull

Purpose: stronger evidence after smoke confirms the audit is useful.

- Monte Carlo: `50`
- same snapshot scale as Case12 unless runtime is too high;
- can reduce target count rather than changing the backend objective if runtime becomes excessive.

The default config should use `auditSmoke`. Full should require an explicit config/profile change.

## Metrics

For each condition, source count, method, and target set:

- mean RMSE;
- resolved rate;
- worst absolute error;
- oracle gap;
- V3.3 minus ARD delta RMSE;
- V3.3 minus best non-oracle baseline delta RMSE;
- V3.3 resolved-rate delta against ARD;
- V3.3 resolved-rate delta against best non-oracle baseline.

Sign convention:

- `deltaRmse = V3.3 RMSE - baseline RMSE`
- negative delta RMSE means V3.3 is better;
- positive delta RMSE means V3.3 is worse.

For resolved-rate delta:

- positive means V3.3 is better;
- negative means V3.3 is worse.

Win condition:

- V3.3 wins RMSE if `deltaRmse < -winToleranceDeg`.
- V3.3 loses RMSE if `deltaRmse > winToleranceDeg`.
- default `winToleranceDeg = 0.05` to avoid treating numerical noise as a claim.

Resolved-rate win tolerance:

- default `winToleranceRate = 0.05`.

## Outputs

Case13 should save:

```text
case13_results.mat
audit_summary.csv
audit_failure_table.csv
audit_v33_vs_ard_delta_rmse.png
audit_v33_vs_best_baseline_delta_rmse.png
audit_v33_win_rate_by_condition.png
audit_oracle_gap.png
```

`audit_summary.csv` should include one row per condition summary with:

- calibration count;
- SNR;
- source count;
- stratum;
- difficulty;
- method metrics;
- V3.3 deltas;
- win/loss/neutral labels.

`audit_failure_table.csv` should list the clearest V3.3 failures:

- condition metadata;
- V3.3 RMSE/resolved rate;
- best baseline name and metrics;
- ARD metrics;
- oracle metrics;
- delta values.

## Figures

### `audit_v33_vs_ard_delta_rmse.png`

Heatmap or faceted heatmap:

- x-axis: SNR;
- y-axis: calibration count;
- panels or grouped rows: source count and difficulty/stratum;
- color: V3.3 - ARD RMSE.

Negative color should visually mean V3.3 wins.

### `audit_v33_vs_best_baseline_delta_rmse.png`

Same structure, but baseline is the best non-oracle calibrated method for that condition.

This is the stricter and more important figure.

### `audit_v33_win_rate_by_condition.png`

Bar or dot summary:

- by source count;
- by stratum/difficulty;
- value: fraction of conditions where V3.3 wins, loses, or is neutral.

### `audit_oracle_gap.png`

Shows whether failures are frontend-specific or backend/physics-limited:

- V3.3 RMSE minus Oracle RMSE;
- best baseline RMSE minus Oracle RMSE.

If both are close to Oracle, the frontend distinction may be too small to claim.

## Interpretation Rules

After running the audit:

### Strong V3.3 advantage

If V3.3 beats ARD and best baseline across multiple calibration counts, SNRs, and source counts, then continue optimizing V3.3 and use those conditions as the main claim region.

### Narrow V3.3 advantage

If V3.3 wins only in specific strata, make the claim conditional:

```text
V3.3 helps in [identified condition], but is not a universal improvement.
```

### No stable V3.3 advantage

If V3.3 is mostly neutral or worse:

- stop trying to present V3.3 as the main performance winner;
- consider rolling back toward ARD/V1;
- reposition pairwise/triplet backend as the main source of DOA improvement;
- narrow the paper claim to calibrated manifold reconstruction plus backend-aware multi-source estimation.

## Code Boundaries

Expected implementation files:

- `default_config.m`
  - add `cfg.case13` defaults and profile settings.
- `run_project.m`
  - register Case13;
  - implement orchestration and plotting.
- `src/benchmark_advantage_audit.m` or equivalent
  - build and run condition matrix;
  - compute summaries and deltas.
- `src/case13_helpers.m` or equivalent
  - deterministic target selection, labels, table helpers.
- `tests/run_sanity_tests.m`
  - add a small smoke test for condition construction and delta sign convention.

Do not modify:

- V3.3 objective;
- existing Case12 behavior;
- existing Case9 or Case11 behavior;
- backend scoring objectives.

## Validation

Static:

```matlab
checkcode default_config.m run_project.m src/*.m tests/*.m
```

Sanity:

```matlab
addpath(genpath(pwd));
run('tests/run_sanity_tests.m')
```

Traceable smoke:

```matlab
cfg = default_config(pwd);
cfg.case13.profile = 'auditSmoke';
run_project(13, cfg);
```

Do not run `auditFull` until smoke results are inspected.

## Documentation

After implementation and smoke run:

- write `results/<hash>/RUN_NOTES.md`;
- write `results/<hash>/manifest.md`;
- update `docs/research-log.md`;
- copy key audit figures to `docs/assets/`;
- state clearly that smoke evidence is not final full benchmark evidence.

## Risks

- Runtime can grow quickly because the matrix includes source count, SNR, calibration count, and multiple strata.
- Three-source triplet backend is the likely bottleneck.
- A large audit may find no V3.3 advantage. That is a valid and important result.
- If targets are chosen too conveniently, the audit becomes biased. Target selection must be deterministic and documented.

## Self-Review

- No placeholders remain.
- The audit is scoped to evidence generation and does not change algorithms.
- The default run remains Case12 only.
- The design explicitly distinguishes smoke from full evidence.
- The interpretation rules include the possibility that V3.3 has no stable advantage.
