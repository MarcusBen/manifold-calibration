# Run Notes

- Timestamp: `2026-05-13 18:46:37 CST`
- Version hash: `4cfa7eb`
- Former pending local hash: `local-1816bb57`
- Base HEAD: `b4e3a32`
- Worktree state before validation metadata: clean (`git status --short` printed no entries)
- Worktree state after smoke before docs edits: `?? results/local-1816bb57/`
- Scope: Task 7 final validation metadata for the parallel backend family plumbing.
- Caveat: this is smoke validation only, not a final performance conclusion.

## Validation Commands

- Pending hash command: `python3 .codex/skills/project-code-change-log/scripts/new_local_hash.py`
  - Result before GitHub-sync finalization: `local-1816bb57`
- Base/status command: `git rev-parse --short HEAD && git status --short`
  - Result: base HEAD `b4e3a32`; no status entries before metadata generation.
- Required static command: `checkcode default_config.m run_project.m src/*.m tests/*.m`
  - Result: unavailable as a standalone shell command (`zsh:1: command not found: checkcode`).
- MATLAB static command: `matlab -batch "files=[{'default_config.m','run_project.m'}, strcat('src/', {dir('src/*.m').name}), strcat('tests/', {dir('tests/*.m').name})]; issues=checkcode(files{:}); ..."`
  - Result: MATLAB `checkcode` completed and reported existing messages only.
- Required sanity command: `matlab -batch "addpath(genpath(pwd)); run('tests/run_sanity_tests.m')"`
  - Result: PASS; `All sanity tests PASS.`
- Smoke command: see `Case12/backend smoke command` below.
  - Result: PASS; `run_project(12,cfg)` exited 0 and wrote `case12_core_1to3_source_mainline/`.

## MATLAB Checkcode Messages

The standalone `checkcode` executable was not available, so the same file set was checked through MATLAB. Messages were pre-existing style/analyzer warnings and were not addressed in this metadata-only task.

```text
run_project.m:2331:37: avoid datestr; use datetime instead
run_project.m:2331:45: avoid now; use datetime("now") instead
run_project.m:2720:4: use STRCMPI(str1,str2) instead of STRCMP with UPPER/LOWER
run_project.m:2742:81: suppressed code analyzer message no longer produced
run_project.m:2749:92: suppressed code analyzer message no longer produced
src/build_sparse_models.m:860:39: suppressed code analyzer message no longer produced
src/build_sparse_models.m:863:110: suppressed code analyzer message no longer produced
src/doa_backend_utils.m:354:32: consider ISMATRIX when checking whether variable is a matrix
src/doa_backend_utils.m:357:30: consider ISMATRIX when checking whether variable is a matrix
src/select_calibration_indices.m:57:82: suppressed code analyzer message no longer produced
TOTAL=10
```

## Case12/backend Smoke Command

```matlab
addpath(genpath(pwd));
cfg = default_config(pwd);
cfg.run.useTraceableDirs = true;
cfg.run.resultRoot = fullfile(pwd, 'results');
cfg.run.runId = '4cfa7eb';
cfg.run.pendingLocalHash = '4cfa7eb';
cfg.run.baseHead = 'b4e3a32';
cfg.run.command = 'matlab -batch addpath(genpath(pwd)); cfg=default_config(pwd); cfg.run.useTraceableDirs=true; cfg.run.runId=4cfa7eb; cfg.core.monteCarlo=1; cfg.core.snapshots=200; cfg.core.methodKeys={ideal,oracle}; cfg.core.singleSourceAnglesDeg=0; cfg.core.twoSourcePairsDeg=[-12.2 -4.2]; cfg.core.threeSourceSetsDeg=[-18.2 -7.2 8.8]; run_project(12,cfg)';
cfg.run.notes = 'Task 7 smoke validation only; not a final performance conclusion.';
cfg.core.monteCarlo = 1;
cfg.core.snapshots = 200;
cfg.core.methodKeys = {'ideal', 'oracle'};
cfg.core.singleSourceAnglesDeg = 0;
cfg.core.twoSourcePairsDeg = [-12.2 -4.2];
cfg.core.threeSourceSetsDeg = [-18.2 -7.2 8.8];
cfg.core.backendCandidateAngleStrideDeg = 4;
cfg.core.threeSourceCandidateAngleStrideDeg = 4;
cfg.core.spice.maxIterations = 20;
run_project(12, cfg);
```

## Config Overrides

- Traceable root: `results/4cfa7eb/`
- Case: `12`
- Methods: `ideal`, `oracle`
- Monte Carlo: `1`
- Snapshots: `200`
- Single-source target: `0`
- Two-source target: `[-12.2 -4.2]`
- Three-source target: `[-18.2 -7.2 8.8]`
- Backend families exercised:
  - Single-source: `music`, `spice_plus`
  - Two-source: `music`, `spice_plus`, `pairwise_grid_ml`
  - Three-source: `music`, `spice_plus`, `triplet_grid_ml`
- Candidate angle stride: `4 deg`
- Three-source candidate angle stride: `4 deg`
- SPICE max iterations: `20`

## Git Status Short

Before validation metadata:

```text
```

After smoke before docs edits:

```text
?? results/local-1816bb57/
```
