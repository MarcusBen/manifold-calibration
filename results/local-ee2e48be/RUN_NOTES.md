# Run Notes

- Timestamp: `2026-05-09 12:35:58`
- Pending local hash: `local-ee2e48be`
- Base HEAD: `unavailable-not-a-git-repo`
- Run id: `local-ee2e48be`
- Command: `matlab -batch addpath/genpath; cfg=default_config(pwd); cfg.case13.profile=auditSmoke; run_project(13,cfg)`
- Notes: `Case13 backend-switched advantage audit smoke.`

## Important Config

- Data: `/Users/bbb/Documents/Codex/manifold_calibration/data/hfss/step0.2deg.csv`
- Frequency Hz: `2500000000`
- Element spacing lambda: `0.25`
- Case 1 high SNR dB: `40`
- Case 9 Monte Carlo: `20`
- Case 9 separation sweep: `[1 2 3 4 5 6 8 10]`

- Case 9 discriminative minimum separation deg: `6`

- MUSIC snapshot policy: `common_truth_snapshots_across_methods`

## Case 12 Core 1/2/3-Source Mainline

- Enabled blocks: `manifold_sanity, single_source, two_source, three_source, backend_ablation`
- Monte Carlo: `50`
- Snapshots: `1000`
- Evaluation SNR dB: `5`
- Two-source backend: `pairwise_grid_ml`
- Three-source backend: `triplet_grid_ml`
- Candidate angle stride deg: `1`
- Three-source candidate angle stride deg: `2`
- Caveat: `Case 12 is a compact structure diagnostic for RMSE and spectra, not a full paper-profile run.`

## Case 11 Backend Diagnostic

- Source pairs deg: `[23.8 31.8;35.8 45.8]`
- Monte Carlo: `20`
- Backend names: `music, music_pair_rescore, pairwise_grid_ml`
- Method keys: `ard, proposed_v1, proposed_v3, oracle`
- Candidate peak count: `12`
- Candidate angle stride deg: `1`
- Minimum separation deg: `2`
- Maximum separation deg: `30`
- Top candidate count: `8`
- Caveat: `Case 11 is diagnostic-only backend screening evidence, not final paper-profile evidence unless stated.`

## Case 13 Backend-Switched Advantage Audit

- Profile: `auditSmoke`
- Calibration counts: `[5 7 9 13]`
- SNR dB: `[0 5 10 20]`
- Snapshots: `800`
- Smoke Monte Carlo: `3`
- Smoke calibration counts: `[5 9]`
- Smoke SNR dB: `[0 10]`
- Full Monte Carlo: `50`
- Two-source backend: `pairwise_grid_ml`
- Three-source backend: `triplet_grid_ml`
- Caveat: `Case 13 auditSmoke is evidence discovery, not final paper-profile evidence.`

- ARD enabled: `1`
- ARD method: `complex_correction_vector`
- ARD note: `Method 2 complex correction-vector interpolation; no unknown coupling matrix C is estimated.`

- Proposed V2 enabled: `1`
- Proposed V2 stage: `full`
- Proposed V2 pair task enabled: `1`

- Proposed V2 task data mode: `heldout_hfss`
- Proposed V2 SPSA iterations: `18`
- Proposed V2 note: `heldout_hfss uses extra task-supervised HFSS truth and is not same-budget with V1/Interpolation.`

- Proposed V3 enabled: `1`
- Proposed V3 label: `Proposed V3.3`
- Proposed V3 stage: `case9_aligned_global_stable_refinement`
- Proposed V3 base: `ard`
- Proposed V3 task data mode: `heldout_hfss`
- Proposed V3 pair objective: `stable_neighborhood`
- Proposed V3 pair selection: `distribution_matched`
- Proposed V3 SPSA iterations: `8`
- Proposed V3 anchor weight: `50`
- Proposed V3 guard weight: `10`
- Proposed V3 trust radius rad: `0.04`
- Proposed V3 task SNR dB: `5`
- Proposed V3 stable score mode: `peak`
- Proposed V3 stable background mode: `global_competitor`
- Proposed V3 note: `V3.3 case9-aligned global stable-pair residual; screening result, not final full paper-profile evidence unless stated.`

## Git Status Short

```text
fatal: not a git repository
```
