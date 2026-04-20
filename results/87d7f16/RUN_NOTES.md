# Run Notes

- Version hash: `87d7f16`
- Timestamp: `2026-04-20 13:42:08`
- Base HEAD: `489efb6`
- Branch: `codex/proposed_v3`
- Worktree state: uncommitted code changes in `default_config.m`, `run_project.m`, and `src/build_sparse_models.m`; result layout migration in progress.
- Command: `run_project([3 7 9 10], default_config(pwd, 'paper'))`
- Run scope: screening only for Case 3/7/9/10; not a full paper-profile run.
- Case list: see `manifest.md`.
- Important config: Proposed V3 uses ARD as coarse model plus anchored task-aware phase residual refinement.
- Decision: screening failed; do not promote this batch to a full 1:10 paper run.

## Git Status Short At Run Time

```text
M default_config.m
M run_project.m
M src/build_sparse_models.m
```
