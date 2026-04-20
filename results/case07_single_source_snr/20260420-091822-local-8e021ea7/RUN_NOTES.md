# Run Notes

- Case: `case07_single_source_snr`
- Timestamp: `2026-04-20 09:28:01`
- Pending local hash: `local-8e021ea7`
- Base HEAD: `588318c`
- Run id: `20260420-091822-local-8e021ea7`
- Command: `run_project(1:10, default_config(pwd, 'paper'))`
- Notes: `Full paper-profile run for Full V2 C-route against Proposed V1 baseline; dirty worktree recorded. Previous local-aa29a0fd run succeeded but had Case 9 overlap metadata semantics fixed before this run.`

## Important Config

- Data: `C:\WorkSpace\Codex\manifold calibration\data\hfss\step0.2deg.csv`
- Frequency Hz: `2500000000`
- Element spacing lambda: `0.25`
- Case 1 high SNR dB: `40`
- Case 9 Monte Carlo: `300`
- Case 9 separation sweep: `[1 2 3 4 5 6 8 10]`

- Proposed V2 enabled: `1`
- Proposed V2 stage: `full`
- Proposed V2 pair task enabled: `1`

- Proposed V2 task data mode: `heldout_hfss`
- Proposed V2 SPSA iterations: `24`
- Proposed V2 note: `heldout_hfss uses extra task-supervised HFSS truth and is not same-budget with V1/Interpolation.`

## Git Status Short

```text
M default_config.m
 M run_project.m
 M src/build_sparse_models.m
?? C_route_full_v2_improvement_plan.md
?? results/case01_problem_validation/20260419-135127-local-aa29a0fd/
?? results/case02_dominant_mismatch/20260419-135127-local-aa29a0fd/
?? results/case03_unseen_generalization/20260419-135127-local-aa29a0fd/
?? results/case04_calibration_count_sensitivity/20260419-135127-local-aa29a0fd/
?? results/case05_sampling_strategy_sensitivity/20260419-135127-local-aa29a0fd/
?? results/case06_model_sensitivity/20260419-135127-local-aa29a0fd/
?? results/case07_single_source_snr/20260419-135127-local-aa29a0fd/
?? results/case08_single_source_snapshots/20260419-135127-local-aa29a0fd/
?? results/case09_two_source_resolution/20260419-135127-local-aa29a0fd/
?? results/case10_random_split_robustness/20260419-135127-local-aa29a0fd/
```
