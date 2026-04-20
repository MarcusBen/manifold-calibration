# Run Notes

- Case: `case08_single_source_snapshots`
- Timestamp: `2026-04-20 12:19:26`
- Pending local hash: `local-c72eabab`
- Base HEAD: `588318c`
- Run id: `20260420-120416-local-c72eabab`
- Command: `run_project(1:10, default_config(pwd, 'paper'))`
- Notes: `Full paper-profile rerun with ARD Method-2 included in the official method lists; merged local-e866e3df outputs will be deleted after validation.`

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

## Git Status Short

```text
M default_config.m
 M docs/research-log.md
 M run_project.m
 M src/build_sparse_models.m
?? array_response_decomposition_algorithm.md
?? docs/assets/case03-ard-merged-edge-hard-local-e866e3df.png
?? docs/assets/case03-ard-merged-unseen-local-e866e3df.png
?? docs/assets/case03-edge-hard-full-v2-local-8e021ea7.png
?? docs/assets/case03-unseen-error-full-v2-local-8e021ea7.png
?? docs/assets/case04-ard-merged-calibration-count-local-e866e3df.png
?? docs/assets/case05-ard-merged-sampling-local-e866e3df.png
?? docs/assets/case06-v2-task-sensitivity-local-8e021ea7.png
?? docs/assets/case07-ard-merged-snr-local-e866e3df.png
?? docs/assets/case07-edge-hard-snr-full-v2-local-8e021ea7.png
?? docs/assets/case07-snr-full-v2-local-8e021ea7.png
?? docs/assets/case08-ard-merged-snapshots-local-e866e3df.png
?? docs/assets/case08-edge-hard-snapshots-full-v2-local-8e021ea7.png
?? docs/assets/case08-snapshots-full-v2-local-8e021ea7.png
?? docs/assets/case09-ard-merged-two-source-local-e866e3df.png
?? docs/assets/case09-two-source-full-v2-local-8e021ea7.png
?? docs/assets/case10-ard-merged-random-split-local-e866e3df.png
?? docs/assets/case10-random-split-full-v2-local-8e021ea7.png
?? results/case01_problem_validation/20260420-091822-local-8e021ea7/
?? results/case01_problem_validation/20260420-113929-local-e866e3df/
?? results/case01_problem_validation/20260420-114554-local-e866e3df/
?? results/case02_dominant_mismatch/20260420-091822-local-8e021ea7/
?? results/case02_dominant_mismatch/20260420-113929-local-e866e3df/
?? results/case02_dominant_mismatch/20260420-114554-local-e866e3df/
?? results/case03_unseen_generalization/20260420-091822-local-8e021ea7/
?? results/case03_unseen_generalization/20260420-113929-local-e866e3df/
?? results/case03_unseen_generalization/20260420-114554-local-e866e3df/
?? results/case04_calibration_count_sensitivity/20260420-091822-local-8e021ea7/
?? results/case04_calibration_count_sensitivity/20260420-113929-local-e866e3df/
?? results/case04_calibration_count_sensitivity/20260420-114554-local-e866e3df/
?? results/case05_sampling_strategy_sensitivity/20260420-091822-local-8e021ea7/
?? results/case05_sampling_strategy_sensitivity/20260420-113929-local-e866e3df/
?? results/case05_sampling_strategy_sensitivity/20260420-114554-local-e866e3df/
?? results/case06_model_sensitivity/20260420-091822-local-8e021ea7/
?? results/case06_model_sensitivity/20260420-113929-local-e866e3df/
?? results/case06_model_sensitivity/20260420-114554-local-e866e3df/
?? results/case07_single_source_snr/20260420-091822-local-8e021ea7/
?? results/case07_single_source_snr/20260420-113929-local-e866e3df/
?? results/case07_single_source_snr/20260420-114554-local-e866e3df/
?? results/case08_single_source_snapshots/20260420-091822-local-8e021ea7/
?? results/case08_single_source_snapshots/20260420-113929-local-e866e3df/
?? results/case08_single_source_snapshots/20260420-114554-local-e866e3df/
?? results/case09_two_source_resolution/20260420-091822-local-8e021ea7/
?? results/case09_two_source_resolution/20260420-113929-local-e866e3df/
?? results/case09_two_source_resolution/20260420-114554-local-e866e3df/
?? results/case10_random_split_robustness/20260420-091822-local-8e021ea7/
?? results/case10_random_split_robustness/20260420-113929-local-e866e3df/
?? results/case10_random_split_robustness/20260420-114554-local-e866e3df/
?? run_ard_merge_from_previous.m
```
