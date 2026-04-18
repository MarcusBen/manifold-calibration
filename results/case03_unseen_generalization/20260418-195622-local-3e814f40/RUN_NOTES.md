# Run Notes

- Case: `case03_unseen_generalization`
- Timestamp: `2026-04-18 19:57:04`
- Pending local hash: `local-3e814f40`
- Base HEAD: `bd11394`
- Run id: `20260418-195622-local-3e814f40`
- Command: `run_project(1:10, default_config(pwd, 'paper'))`
- Notes: `Full paper-profile run after strict Case 4 update: MC=200, common single-source and two-source test sets across L, and four-state two-source breakdown.`

## Important Config

- Data: `D:\Codex\manifold calibration\data\hfss\step0.2deg.csv`
- Frequency Hz: `2500000000`
- Element spacing lambda: `0.25`
- Case 1 high SNR dB: `40`
- Case 9 Monte Carlo: `300`
- Case 9 separation sweep: `[1 2 3 4 5 6 8 10]`

## Git Status Short

```text
M .codex/skills/project-code-change-log/SKILL.md
 M README.md
 M default_config.m
 M docs/comments.md
 M docs/research-log.md
 D results/case01_problem_validation/case01_results.mat
 D results/case01_problem_validation/example_music_spectrum.png
 D results/case01_problem_validation/high_snr_angle_bias.png
 D results/case01_problem_validation/residual_components.png
 D results/case01_problem_validation/similarity_curves.png
 D results/case02_dominant_mismatch/case02_results.mat
 D results/case02_dominant_mismatch/mismatch_dominance.png
 D results/case03_unseen_generalization/case03_results.mat
 D results/case03_unseen_generalization/phase_reconstruction.png
 D results/case03_unseen_generalization/steering_vector_comparison.png
 D results/case03_unseen_generalization/unseen_error_vs_L.png
 D results/case04_calibration_count_sensitivity/calibration_count_sensitivity.png
 D results/case04_calibration_count_sensitivity/case04_results.mat
 D results/case05_sampling_strategy_sensitivity/case05_results.mat
 D results/case05_sampling_strategy_sensitivity/sampling_strategy_sensitivity.png
 D results/case06_model_sensitivity/case06_results.mat
 D results/case06_model_sensitivity/model_sensitivity.png
 D results/case07_single_source_snr/case07_results.mat
 D results/case07_single_source_snr/representative_spectra.png
 D results/case07_single_source_snr/rmse_and_success_vs_snr.png
 D results/case08_single_source_snapshots/case08_results.mat
 D results/case08_single_source_snapshots/rmse_vs_snapshots.png
 D results/case09_two_source_resolution/case09_results.mat
 D results/case09_two_source_resolution/two_source_resolution.png
 D results/case10_random_split_robustness/case10_results.mat
 D results/case10_random_split_robustness/random_split_robustness.png
 D results_case9_smoke_tmp/case09_two_source_resolution/case09_results.mat
 D results_case9_smoke_tmp/case09_two_source_resolution/two_source_resolution.png
 D results_smoke/case01_problem_validation/case01_results.mat
 D results_smoke/case01_problem_validation/example_music_spectrum.png
 D results_smoke/case01_problem_validation/high_snr_angle_bias.png
 D results_smoke/case01_problem_validation/residual_components.png
 D results_smoke/case01_problem_validation/similarity_curves.png
 D results_smoke/case03_unseen_generalization/case03_results.mat
 D results_smoke/case03_unseen_generalization/phase_reconstruction.png
 D results_smoke/case03_unseen_generalization/steering_vector_comparison.png
 D results_smoke/case03_unseen_generalization/unseen_error_vs_L.png
 D results_smoke/case07_single_source_snr/case07_results.mat
 D results_smoke/case07_single_source_snr/representative_spectra.png
 D results_smoke/case07_single_source_snr/rmse_and_success_vs_snr.png
 D results_smoke2/case02_dominant_mismatch/case02_results.mat
 D results_smoke2/case02_dominant_mismatch/mismatch_dominance.png
 D results_smoke2/case04_calibration_count_sensitivity/calibration_count_sensitivity.png
 D results_smoke2/case04_calibration_count_sensitivity/case04_results.mat
 D results_smoke2/case05_sampling_strategy_sensitivity/case05_results.mat
 D results_smoke2/case05_sampling_strategy_sensitivity/sampling_strategy_sensitivity.png
 D results_smoke2/case06_model_sensitivity/case06_results.mat
 D results_smoke2/case06_model_sensitivity/model_sensitivity.png
 D results_smoke2/case08_single_source_snapshots/case08_results.mat
 D results_smoke2/case08_single_source_snapshots/rmse_vs_snapshots.png
 D results_smoke2/case09_two_source_resolution/case09_results.mat
 D results_smoke2/case09_two_source_resolution/two_source_resolution.png
 D results_smoke2/case10_random_split_robustness/case10_results.mat
 D results_smoke2/case10_random_split_robustness/random_split_robustness.png
 D results_smoke3/case09_two_source_resolution/case09_results.mat
 D results_smoke3/case09_two_source_resolution/two_source_resolution.png
 D results_step0p2_qw/case01_problem_validation/case01_results.mat
 D results_step0p2_qw/case01_problem_validation/example_music_spectrum.png
 D results_step0p2_qw/case01_problem_validation/high_snr_angle_bias.png
 D results_step0p2_qw/case01_problem_validation/residual_components.png
 D results_step0p2_qw/case01_problem_validation/similarity_curves.png
 D results_step0p2_qw/case02_dominant_mismatch/case02_results.mat
 D results_step0p2_qw/case02_dominant_mismatch/mismatch_dominance.png
 D results_step0p2_qw/case03_unseen_generalization/case03_results.mat
 D results_step0p2_qw/case03_unseen_generalization/phase_reconstruction.png
 D results_step0p2_qw/case03_unseen_generalization/steering_vector_comparison.png
 D results_step0p2_qw/case03_unseen_generalization/unseen_error_vs_L.png
 D results_step0p2_qw/case04_calibration_count_sensitivity/calibration_count_sensitivity.png
 D results_step0p2_qw/case04_calibration_count_sensitivity/case04_results.mat
 D results_step0p2_qw/case05_sampling_strategy_sensitivity/case05_results.mat
 D results_step0p2_qw/case05_sampling_strategy_sensitivity/sampling_strategy_sensitivity.png
 D results_step0p2_qw/case06_model_sensitivity/case06_results.mat
 D results_step0p2_qw/case06_model_sensitivity/model_sensitivity.png
 D results_step0p2_qw/case07_single_source_snr/case07_results.mat
 D results_step0p2_qw/case07_single_source_snr/representative_spectra.png
 D results_step0p2_qw/case07_single_source_snr/rmse_and_success_vs_snr.png
 D results_step0p2_qw/case08_single_source_snapshots/case08_results.mat
 D results_step0p2_qw/case08_single_source_snapshots/rmse_vs_snapshots.png
 D results_step0p2_qw/case09_two_source_resolution/case09_results.mat
 D results_step0p2_qw/case09_two_source_resolution/two_source_resolution.png
 D results_step0p2_qw/case10_random_split_robustness/case10_results.mat
 D results_step0p2_qw/case10_random_split_robustness/random_split_robustness.png
 M run_project.m
?? docs/assets/case01-example-spectrum-paper-local-77d2252a.png
?? docs/assets/case01-mismatch-floor-paper-local-77d2252a.png
?? docs/assets/case02-mismatch-dominance-paper-local-77d2252a.png
?? docs/assets/case03-unseen-error-paper-local-77d2252a.png
?? docs/assets/case04-calibration-count-paper-local-77d2252a.png
?? docs/assets/case04-near-threshold-smoke-local-7fa085bd.png
?? docs/assets/case05-sampling-strategy-paper-local-77d2252a.png
?? docs/assets/case06-model-sensitivity-paper-local-77d2252a.png
?? docs/assets/case07-representative-spectra-paper-local-77d2252a.png
?? docs/assets/case07-snr-metrics-paper-local-77d2252a.png
?? docs/assets/case08-snapshot-metrics-paper-local-77d2252a.png
?? docs/assets/case09-resolution-paper-local-77d2252a.png
?? docs/assets/case10-random-split-paper-local-77d2252a.png
?? results/case01_problem_validation/20260418-190723-local-77d2252a/
?? results/case02_dominant_mismatch/20260418-190723-local-77d2252a/
?? results/case03_unseen_generalization/20260418-190723-local-77d2252a/
?? results/case04_calibration_count_sensitivity/20260418-190723-local-77d2252a/
?? results/case04_calibration_count_sensitivity/20260418-193948-local-7fa085bd/
?? results/case04_calibration_count_sensitivity/20260418-195529-local-3e814f40-smoke/
?? results/case05_sampling_strategy_sensitivity/20260418-190723-local-77d2252a/
?? results/case06_model_sensitivity/20260418-190723-local-77d2252a/
?? results/case07_single_source_snr/20260418-190723-local-77d2252a/
?? results/case08_single_source_snapshots/20260418-190723-local-77d2252a/
?? results/case09_two_source_resolution/20260418-190723-local-77d2252a/
?? results/case10_random_split_robustness/20260418-190723-local-77d2252a/
?? tmp_run_full_local_3e814f40.m
```
