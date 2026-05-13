# Results manifest

- Version hash: `4cfa7eb`
- Former pending local hash: `local-1816bb57`
- Base HEAD: `b4e3a32`
- Worktree state: clean before validation metadata; uncommitted validation metadata/results after smoke.
- Validation scope: parallel backend family plumbing smoke only.
- Caveat: smoke validation only, not a final performance conclusion.

## Cases

- `case12_core_1to3_source_mainline`: small Case12/backend smoke outputs in `case12_core_1to3_source_mainline/`.

## Outputs

- `case12_core_1to3_source_mainline/case12_results.mat`
- `case12_core_1to3_source_mainline/core_resolved_summary.png`
- `case12_core_1to3_source_mainline/core_rmse_summary.png`
- `case12_core_1to3_source_mainline/core_three_source_spectrum.png`
- `case12_core_1to3_source_mainline/core_two_source_spectrum.png`
- `case12_core_1to3_source_mainline/paper_core_resolved_ranked.png`
- `case12_core_1to3_source_mainline/paper_core_rmse_ranked.png`
- `case12_core_1to3_source_mainline/paper_three_source_spectrum.png`

## Not run

- Full Case12 benchmark: skipped by design; this task requested a small smoke only.
- Case13 full/audit smoke: skipped to keep Task 7 scoped to final validation metadata for the parallel backend implementation.
- Any paper-profile or full performance benchmark: not run; no performance conclusion should be drawn from this result folder.
