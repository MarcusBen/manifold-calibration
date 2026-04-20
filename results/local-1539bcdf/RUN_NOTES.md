# Run Notes

- Timestamp: `2026-04-20 15:12:48`
- Pending local hash: `local-1539bcdf`
- Base HEAD: `7a31dd1`
- Run id: `local-1539bcdf`
- Command: `run_project([3 7 9 10], default_config(pwd, 'paper'))`
- Notes: `Screening run for Proposed V3-Revised calibration-guarded ARD-anchored task residual; not a full paper-profile result.`

## Important Config

- Data: `C:\WorkSpace\Codex\manifold calibration\data\hfss\step0.2deg.csv`
- Frequency Hz: `2500000000`
- Element spacing lambda: `0.25`
- Case 1 high SNR dB: `40`
- Case 9 Monte Carlo: `300`
- Case 9 separation sweep: `[1 2 3 4 5 6 8 10]`

- ARD enabled: `1`
- ARD method: `complex_correction_vector`
- ARD note: `Method 2 complex correction-vector interpolation; no unknown coupling matrix C is estimated.`

- Proposed V2 enabled: `1`
- Proposed V2 stage: `full`
- Proposed V2 pair task enabled: `1`

- Proposed V2 task data mode: `heldout_hfss`
- Proposed V2 SPSA iterations: `24`
- Proposed V2 note: `heldout_hfss uses extra task-supervised HFSS truth and is not same-budget with V1/Interpolation.`

- Proposed V3 enabled: `1`
- Proposed V3 stage: `calibration_guarded_ard_anchored_task_refinement`
- Proposed V3 base: `ard`
- Proposed V3 task data mode: `heldout_hfss`
- Proposed V3 SPSA iterations: `12`
- Proposed V3 anchor weight: `50`
- Proposed V3 guard weight: `10`
- Proposed V3 trust radius rad: `0.04`
- Proposed V3 note: `Calibration-guarded ARD-anchored task-aware residual; screening result, not final full paper-profile evidence unless stated.`

## Git Status Short

```text
M default_config.m
 M docs/comments.md
 M run_project.m
 M src/build_sparse_models.m
?? proposed_algorithm_v3.md
?? proposed_algorithm_v3_initial_screening.md
?? results/87d7f16.zip
```
