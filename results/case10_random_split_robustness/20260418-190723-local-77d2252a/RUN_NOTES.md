# Run Notes

- Case: `case10_random_split_robustness`
- Timestamp: `2026-04-18 19:14:35`
- Pending local hash: `local-77d2252a`
- Base HEAD: `bd11394`
- Run id: `20260418-190723-local-77d2252a`
- Command: `run_project(1:10, cfg) with default_config(pwd, 'paper')`
- Notes: `Archive closeout paper-profile candidate from uncommitted local-77d2252a; tracked historical results intentionally deleted per user confirmation.`

## Important Config

- Data: `D:\Codex\manifold calibration\data\hfss\step0.2deg.csv`
- Frequency Hz: `2500000000`
- Element spacing lambda: `0.25`
- Case 1 high SNR dB: `40`
- Case 9 Monte Carlo: `300`
- Case 9 separation sweep: `[1 2 3 4 5 6 8 10]`

## Git Status Short

```text
M default_config.m
 M docs/comments.md
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
?? tmp_run_paper_local_77d2252a.m
```
