# Results manifest

- Version hash: `aa42472`
- Former pending local hash: `local-12e2cc40`
- Base HEAD: `unavailable-not-a-git-repo`
- Worktree state: uncommitted code changes recorded in `RUN_NOTES.md`
- Command: `matlab -batch addpath/genpath; cfg=default_config(pwd); run_project([],cfg)`

## Cases

- `case12_core_1to3_source_mainline`: outputs in `case12_core_1to3_source_mainline/`

## Large artifact note

- `case12_core_1to3_source_mainline/case12_results.mat` is retained locally. The GitHub REST sync path cannot upload this large MATLAB artifact as a blob; the published branch carries the run notes, manifest, code/docs, and PNG figures.
