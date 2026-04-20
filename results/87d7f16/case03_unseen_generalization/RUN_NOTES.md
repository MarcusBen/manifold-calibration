# Run Notes

- Case: `case03_unseen_generalization`
- Timestamp: `2026-04-20 13:43:28`
- Pending local hash: `87d7f16`
- Base HEAD: `489efb6`
- Run id: `20260420-134208-87d7f16`
- Command: `run_project([3 7 9 10], default_config(pwd, 'paper'))`
- Notes: `Screening run for Proposed V3 ARD-anchored task refinement; not a full paper-profile result.`

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
- Proposed V3 stage: `ard_anchored_task_refinement`
- Proposed V3 base: `ard`
- Proposed V3 task data mode: `heldout_hfss`
- Proposed V3 SPSA iterations: `18`
- Proposed V3 note: `ARD-anchored task-aware phase residual; screening result, not final full paper-profile evidence unless stated.`

## Git Status Short

```text
 M default_config.m
 M run_project.m
 M src/build_sparse_models.m
```
