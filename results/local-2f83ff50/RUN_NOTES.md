# Run Notes

- Timestamp: `2026-05-06 12:29:26`
- Pending local hash: `local-2f83ff50`
- Base HEAD: `not-a-git-repo`
- Run id: `local-2f83ff50`
- Command: `matlab -batch GP-ANM fallback Case 9 smoke, sourcePairsDeg=[23.8 31.8], monteCarlo=2`
- Notes: `Case 9 GP-ANM fallback smoke: one representative pair [23.8 31.8], default snapshots/SNR, MC=2; GP Diag Proxy enabled; CVX-gated GP-ANM SDP probe enabled.`

## Important Config

- Data: `/Users/bbb/Documents/Codex/manifold_calibration/data/hfss/step0.2deg.csv`
- Frequency Hz: `2500000000`
- Element spacing lambda: `0.25`
- Case 1 high SNR dB: `40`
- Case 9 Monte Carlo: `2`
- Case 9 separation sweep: `[1 2 3 4 5 6 8 10]`

- Case 9 discriminative minimum separation deg: `6`

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

- Case 9 GP-ANM fallback enabled: `1`
- Case 9 GP diagonal proxy enabled: `1`
- Case 9 GP-ANM fallback max pairs: `1`
- Case 9 GP-ANM fallback Monte Carlo: `1`
- Case 9 GP-ANM error radius: `0.5`
- Case 9 GP-ANM tau eta: `1`

## Git Status Short

```text
fatal: not a git repository (or any of the parent directories): .git
fatal: not a git repository (or any of the parent directories): .git
```
