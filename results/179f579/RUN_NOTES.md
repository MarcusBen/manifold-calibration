# Run Notes

- Timestamp: `2026-04-20 16:51:00`
- Git code commit hash: `179f579`
- Former pending local hash: `local-fc4e69f9`
- Base HEAD: `6bb1a19`
- Run id: `179f579`
- Command: `run_project([3 7 9 10], cfg)`
- Notes: `Screening run for Proposed V3.2 distribution-matched stable-pair residual with separation-balanced non-edge task selection; not a full paper-profile result.`

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
- Proposed V3 label: `Proposed V3.2`
- Proposed V3 stage: `distribution_matched_stable_pair_refinement`
- Proposed V3 base: `ard`
- Proposed V3 task data mode: `heldout_hfss`
- Proposed V3 pair objective: `stable_neighborhood`
- Proposed V3 pair selection: `distribution_matched`
- Proposed V3 SPSA iterations: `12`
- Proposed V3 anchor weight: `50`
- Proposed V3 guard weight: `10`
- Proposed V3 trust radius rad: `0.04`
- Proposed V3 note: `V3.2 distribution-matched stable-pair residual; screening result, not final full paper-profile evidence unless stated.`

## Git Status Short

```text
 M default_config.m
 D results/2962bc3/RUN_NOTES.md
 D results/2962bc3/case01_problem_validation/RUN_NOTES.md
 D results/2962bc3/case01_problem_validation/case01_results.mat
 D results/2962bc3/case01_problem_validation/example_music_spectrum.png
 D results/2962bc3/case01_problem_validation/high_snr_angle_bias.png
 D results/2962bc3/case01_problem_validation/residual_components.png
 D results/2962bc3/case01_problem_validation/similarity_curves.png
 D results/2962bc3/case02_dominant_mismatch/RUN_NOTES.md
 D results/2962bc3/case02_dominant_mismatch/case02_results.mat
 D results/2962bc3/case02_dominant_mismatch/mismatch_dominance.png
 D results/2962bc3/case03_unseen_generalization/RUN_NOTES.md
 D results/2962bc3/case03_unseen_generalization/case03_results.mat
 D results/2962bc3/case03_unseen_generalization/phase_reconstruction.png
 D results/2962bc3/case03_unseen_generalization/steering_vector_comparison.png
 D results/2962bc3/case03_unseen_generalization/unseen_error_vs_L.png
 D results/2962bc3/case04_calibration_count_sensitivity/RUN_NOTES.md
 D results/2962bc3/case04_calibration_count_sensitivity/calibration_count_sensitivity.png
 D results/2962bc3/case04_calibration_count_sensitivity/case04_results.mat
 D results/2962bc3/case05_sampling_strategy_sensitivity/RUN_NOTES.md
 D results/2962bc3/case05_sampling_strategy_sensitivity/case05_results.mat
 D results/2962bc3/case05_sampling_strategy_sensitivity/sampling_strategy_sensitivity.png
 D results/2962bc3/case06_model_sensitivity/RUN_NOTES.md
 D results/2962bc3/case06_model_sensitivity/case06_results.mat
 D results/2962bc3/case06_model_sensitivity/model_sensitivity.png
 D results/2962bc3/case07_single_source_snr/RUN_NOTES.md
 D results/2962bc3/case07_single_source_snr/case07_results.mat
 D results/2962bc3/case07_single_source_snr/representative_spectra.png
 D results/2962bc3/case07_single_source_snr/rmse_and_success_vs_snr.png
 D results/2962bc3/case08_single_source_snapshots/RUN_NOTES.md
 D results/2962bc3/case08_single_source_snapshots/case08_results.mat
 D results/2962bc3/case08_single_source_snapshots/rmse_vs_snapshots.png
 D results/2962bc3/case09_two_source_resolution/RUN_NOTES.md
 D results/2962bc3/case09_two_source_resolution/case09_results.mat
 D results/2962bc3/case09_two_source_resolution/two_source_resolution.png
 D results/2962bc3/case10_random_split_robustness/RUN_NOTES.md
 D results/2962bc3/case10_random_split_robustness/case10_results.mat
 D results/2962bc3/case10_random_split_robustness/random_split_robustness.png
 D results/2962bc3/manifest.md
 D results/71650f7/RUN_NOTES.md
 D results/71650f7/case01_problem_validation/RUN_NOTES.md
 D results/71650f7/case01_problem_validation/case01_results.mat
 D results/71650f7/case01_problem_validation/example_music_spectrum.png
 D results/71650f7/case01_problem_validation/high_snr_angle_bias.png
 D results/71650f7/case01_problem_validation/residual_components.png
 D results/71650f7/case01_problem_validation/similarity_curves.png
 D results/71650f7/case02_dominant_mismatch/RUN_NOTES.md
 D results/71650f7/case02_dominant_mismatch/case02_results.mat
 D results/71650f7/case02_dominant_mismatch/mismatch_dominance.png
 D results/71650f7/case03_unseen_generalization/RUN_NOTES.md
 D results/71650f7/case03_unseen_generalization/case03_results.mat
 D results/71650f7/case03_unseen_generalization/edge_and_hard_unseen_error.png
 D results/71650f7/case03_unseen_generalization/phase_reconstruction.png
 D results/71650f7/case03_unseen_generalization/steering_vector_comparison.png
 D results/71650f7/case03_unseen_generalization/unseen_error_vs_L.png
 D results/71650f7/case04_calibration_count_sensitivity/RUN_NOTES.md
 D results/71650f7/case04_calibration_count_sensitivity/calibration_count_sensitivity.png
 D results/71650f7/case04_calibration_count_sensitivity/case04_results.mat
 D results/71650f7/case05_sampling_strategy_sensitivity/RUN_NOTES.md
 D results/71650f7/case05_sampling_strategy_sensitivity/case05_results.mat
 D results/71650f7/case05_sampling_strategy_sensitivity/sampling_strategy_sensitivity.png
 D results/71650f7/case06_model_sensitivity/RUN_NOTES.md
 D results/71650f7/case06_model_sensitivity/case06_results.mat
 D results/71650f7/case06_model_sensitivity/model_sensitivity.png
 D results/71650f7/case07_single_source_snr/RUN_NOTES.md
 D results/71650f7/case07_single_source_snr/case07_results.mat
 D results/71650f7/case07_single_source_snr/edge_hard_metrics_vs_snr.png
 D results/71650f7/case07_single_source_snr/representative_spectra.png
 D results/71650f7/case07_single_source_snr/rmse_and_success_vs_snr.png
 D results/71650f7/case08_single_source_snapshots/RUN_NOTES.md
 D results/71650f7/case08_single_source_snapshots/case08_results.mat
 D results/71650f7/case08_single_source_snapshots/edge_hard_metrics_vs_snapshots.png
 D results/71650f7/case08_single_source_snapshots/rmse_vs_snapshots.png
 D results/71650f7/case09_two_source_resolution/RUN_NOTES.md
 D results/71650f7/case09_two_source_resolution/case09_results.mat
 D results/71650f7/case09_two_source_resolution/two_source_resolution.png
 D results/71650f7/case10_random_split_robustness/RUN_NOTES.md
 D results/71650f7/case10_random_split_robustness/case10_results.mat
 D results/71650f7/case10_random_split_robustness/random_split_robustness.png
 D results/71650f7/manifest.md
 D results/87d7f16/RUN_NOTES.md
 D results/87d7f16/case03_unseen_generalization/RUN_NOTES.md
 D results/87d7f16/case03_unseen_generalization/case03_results.mat
 D results/87d7f16/case03_unseen_generalization/edge_and_hard_unseen_error.png
 D results/87d7f16/case03_unseen_generalization/phase_reconstruction.png
 D results/87d7f16/case03_unseen_generalization/steering_vector_comparison.png
 D results/87d7f16/case03_unseen_generalization/unseen_error_vs_L.png
 D results/87d7f16/case07_single_source_snr/RUN_NOTES.md
 D results/87d7f16/case07_single_source_snr/case07_results.mat
 D results/87d7f16/case07_single_source_snr/edge_hard_metrics_vs_snr.png
 D results/87d7f16/case07_single_source_snr/representative_spectra.png
 D results/87d7f16/case07_single_source_snr/rmse_and_success_vs_snr.png
 D results/87d7f16/case09_two_source_resolution/RUN_NOTES.md
 D results/87d7f16/case09_two_source_resolution/case09_results.mat
 D results/87d7f16/case09_two_source_resolution/two_source_resolution.png
 D results/87d7f16/case10_random_split_robustness/RUN_NOTES.md
 D results/87d7f16/case10_random_split_robustness/case10_results.mat
 D results/87d7f16/case10_random_split_robustness/random_split_robustness.png
 D results/87d7f16/manifest.md
 D results/a5a22d2/RUN_NOTES.md
 D results/a5a22d2/case03_unseen_generalization/case03_results.mat
 D results/a5a22d2/case03_unseen_generalization/edge_and_hard_unseen_error.png
 D results/a5a22d2/case03_unseen_generalization/phase_reconstruction.png
 D results/a5a22d2/case03_unseen_generalization/steering_vector_comparison.png
 D results/a5a22d2/case03_unseen_generalization/unseen_error_vs_L.png
 D results/a5a22d2/case07_single_source_snr/case07_results.mat
 D results/a5a22d2/case07_single_source_snr/edge_hard_metrics_vs_snr.png
 D results/a5a22d2/case07_single_source_snr/representative_spectra.png
 D results/a5a22d2/case07_single_source_snr/rmse_and_success_vs_snr.png
 D results/a5a22d2/case09_two_source_resolution/case09_results.mat
 D results/a5a22d2/case09_two_source_resolution/two_source_resolution.png
 D results/a5a22d2/case10_random_split_robustness/case10_results.mat
 D results/a5a22d2/case10_random_split_robustness/random_split_robustness.png
 D results/a5a22d2/manifest.md
 D results/local-8e021ea7/RUN_NOTES.md
 D results/local-8e021ea7/case01_problem_validation/RUN_NOTES.md
 D results/local-8e021ea7/case01_problem_validation/case01_results.mat
 D results/local-8e021ea7/case01_problem_validation/example_music_spectrum.png
 D results/local-8e021ea7/case01_problem_validation/high_snr_angle_bias.png
 D results/local-8e021ea7/case01_problem_validation/residual_components.png
 D results/local-8e021ea7/case01_problem_validation/similarity_curves.png
 D results/local-8e021ea7/case02_dominant_mismatch/RUN_NOTES.md
 D results/local-8e021ea7/case02_dominant_mismatch/case02_results.mat
 D results/local-8e021ea7/case02_dominant_mismatch/mismatch_dominance.png
 D results/local-8e021ea7/case03_unseen_generalization/RUN_NOTES.md
 D results/local-8e021ea7/case03_unseen_generalization/case03_results.mat
 D results/local-8e021ea7/case03_unseen_generalization/edge_and_hard_unseen_error.png
 D results/local-8e021ea7/case03_unseen_generalization/phase_reconstruction.png
 D results/local-8e021ea7/case03_unseen_generalization/steering_vector_comparison.png
 D results/local-8e021ea7/case03_unseen_generalization/unseen_error_vs_L.png
 D results/local-8e021ea7/case04_calibration_count_sensitivity/RUN_NOTES.md
 D results/local-8e021ea7/case04_calibration_count_sensitivity/calibration_count_sensitivity.png
 D results/local-8e021ea7/case04_calibration_count_sensitivity/case04_results.mat
 D results/local-8e021ea7/case05_sampling_strategy_sensitivity/RUN_NOTES.md
 D results/local-8e021ea7/case05_sampling_strategy_sensitivity/case05_results.mat
 D results/local-8e021ea7/case05_sampling_strategy_sensitivity/sampling_strategy_sensitivity.png
 D results/local-8e021ea7/case06_model_sensitivity/RUN_NOTES.md
 D results/local-8e021ea7/case06_model_sensitivity/case06_results.mat
 D results/local-8e021ea7/case06_model_sensitivity/model_sensitivity.png
 D results/local-8e021ea7/case07_single_source_snr/RUN_NOTES.md
 D results/local-8e021ea7/case07_single_source_snr/case07_results.mat
 D results/local-8e021ea7/case07_single_source_snr/edge_hard_metrics_vs_snr.png
 D results/local-8e021ea7/case07_single_source_snr/representative_spectra.png
 D results/local-8e021ea7/case07_single_source_snr/rmse_and_success_vs_snr.png
 D results/local-8e021ea7/case08_single_source_snapshots/RUN_NOTES.md
 D results/local-8e021ea7/case08_single_source_snapshots/case08_results.mat
 D results/local-8e021ea7/case08_single_source_snapshots/edge_hard_metrics_vs_snapshots.png
 D results/local-8e021ea7/case08_single_source_snapshots/rmse_vs_snapshots.png
 D results/local-8e021ea7/case09_two_source_resolution/RUN_NOTES.md
 D results/local-8e021ea7/case09_two_source_resolution/case09_results.mat
 D results/local-8e021ea7/case09_two_source_resolution/two_source_resolution.png
 D results/local-8e021ea7/case10_random_split_robustness/RUN_NOTES.md
 D results/local-8e021ea7/case10_random_split_robustness/case10_results.mat
 D results/local-8e021ea7/case10_random_split_robustness/random_split_robustness.png
 D results/local-8e021ea7/manifest.md
 D results/local-aa29a0fd/RUN_NOTES.md
 D results/local-aa29a0fd/manifest.md
 M run_project.m
 M src/build_sparse_models.m
?? algorithms/proposed_algorithm_v3_2.md
?? results/local-08a63f32/
?? results/local-ab47a634/

```
