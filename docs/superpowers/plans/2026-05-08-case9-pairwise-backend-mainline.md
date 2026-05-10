# Case9 Pairwise Backend Mainline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Promote pairwise covariance-fit ML to the Case 9 mainline backend and produce one coherent traceable Case 9 diagnostic run.

**Architecture:** Keep Proposed V3.3 manifold calibration unchanged. Use `benchmark_music` backend dispatch to run Case 9 through `pairwise_grid_ml`, and keep Case 11 as the backend ablation. Synchronize documentation and traceable results so logs, README, and outputs agree.

**Tech Stack:** MATLAB scripts/functions, markdown docs, project traceable result layout under `results/<hash>/`.

---

### Task 1: Verify Mainline Config

**Files:**
- Modify: `default_config.m`

- [ ] **Step 1: Confirm Case 9 backend defaults**

Ensure this block is present:

```matlab
cfg.case9.monteCarlo = 20;
cfg.case9.sourcePairsDeg = [-12.2 -4.2; 6.8 16.8; 23.8 31.8];
cfg.case9.backendName = 'pairwise_grid_ml';
cfg.case9.backendCandidateAngleStrideDeg = 1;
cfg.case9.backendMinimumSeparationDeg = 2;
cfg.case9.backendMaximumSeparationDeg = 30;
```

- [ ] **Step 2: Run a size probe**

Run:

```bash
matlab -batch "addpath(genpath(pwd)); cfg=default_config(pwd); ctx=build_project_context(cfg); calIdx=select_calibration_indices(ctx.thetaDeg,cfg.case3.representativeL,'uniform'); models=build_sparse_models(ctx,calIdx,cfg.model); [pairs,~]=case09_helpers('source_pairs',cfg.case9,ctx,models.calAnglesDeg); fprintf('case9_pairs=%d methods=7 mc=%d raw_trials=%d backend=%s sourcePairs=%s\n',size(pairs,1),cfg.case9.monteCarlo,size(pairs,1)*7*cfg.case9.monteCarlo,cfg.case9.backendName,mat2str(cfg.case9.sourcePairsDeg));"
```

Expected: 3 source pairs, backend `pairwise_grid_ml`, and 420 raw method/trial estimates.

### Task 2: Synchronize Documentation

**Files:**
- Modify: `README.md`
- Modify: `simulation.md`
- Modify: `algorithms/proposed_algorithm_v3_3.md`
- Modify: `docs/research-log.md`

- [ ] **Step 1: Update README summary**

Replace the stale `fadea59`-only summary with a current local mainline summary:

```markdown
当前本地研究主线已切换为 `Proposed V3.3 manifold calibration + pairwise covariance-fit ML backend` for Case 9. MUSIC peak picking is retained as a backend diagnostic/baseline, not the primary Case 9 result path.
```

- [ ] **Step 2: Update algorithm notes**

Add a short section to `algorithms/proposed_algorithm_v3_3.md`:

```markdown
## Case 9 Backend Mainline

For two-source Case 9 evaluation, the current mainline uses the calibrated manifold with a pairwise covariance-fit ML backend. MUSIC peak picking is retained as a backend ablation and visualization spectrum, but it is no longer the primary Case 9 estimator.
```

- [ ] **Step 3: Update simulation notes**

In the Case 9 section of `simulation.md`, state that Case 9's current mainline backend is pairwise covariance-fit ML and that Case 11 provides backend ablation.

### Task 3: Validate Code

**Files:**
- Test: `tests/run_sanity_tests.m`
- Test: `src/doa_backend_pairwise_grid_ml.m`

- [ ] **Step 1: Run sanity tests**

Run:

```bash
matlab -batch "addpath(genpath(pwd)); run_sanity_tests"
```

Expected: `All sanity tests PASS.`

- [ ] **Step 2: Run static check**

Run:

```bash
matlab -batch "checkcode default_config.m run_project.m src/doa_backend_pairwise_grid_ml.m src/benchmark_music.m tests/run_sanity_tests.m"
```

Expected: no run-blocking errors. Existing `datestr/now/STRCMPI` warnings are acceptable.

### Task 4: Run Traceable Case 9

**Files:**
- Create: `results/<hash>/RUN_NOTES.md`
- Create: `results/<hash>/manifest.md`
- Create: `results/<hash>/case09_two_source_resolution/case09_results.mat`
- Create: `results/<hash>/case09_two_source_resolution/two_source_resolution.png`

- [ ] **Step 1: Generate pending local hash**

Run:

```bash
python3 .codex/skills/project-code-change-log/scripts/new_local_hash.py
```

Use the returned hash consistently.

- [ ] **Step 2: Run Case 9 only**

Run:

```bash
matlab -batch "addpath(genpath(pwd)); cfg=default_config(pwd); cfg.run.useTraceableDirs=true; cfg.run.resultRoot=fullfile(pwd,'results'); cfg.run.runId='<hash>'; cfg.run.pendingLocalHash='<hash>'; cfg.run.baseHead='not-a-git-repo'; cfg.run.gitStatusShort='fatal: not a git repository (or any of the parent directories): .git'; cfg.run.command='matlab -batch Case9 pairwise backend mainline diagnostic'; cfg.run.notes='Case9 mainline pairwise covariance-fit ML backend diagnostic; sourcePairs=[-12.2 -4.2; 6.8 16.8; 23.8 31.8], monteCarlo=20; diagnostic, not full paper profile.'; run_project(9,cfg);"
```

Expected: `results/<hash>/case09_two_source_resolution/` contains `.mat` and `.png` outputs.

- [ ] **Step 3: Verify result fields**

Run:

```bash
matlab -batch "s=load(fullfile('results','<hash>','case09_two_source_resolution','case09_results.mat')); cr=s.caseResult; assert(strcmp(cr.backendName,'pairwise_grid_ml')); assert(isfield(cr,'backendCfg')); disp(cr.overallSummary.meanResolution); disp(cr.overallSummary.meanStable); disp(cr.overallSummary.meanPairRmse);"
```

Expected: backend assertion passes and metrics print.

### Task 5: Finalize Log Assets

**Files:**
- Create: `docs/assets/case09-pairwise-mainline-<hash>.png`
- Modify: `docs/research-log.md`

- [ ] **Step 1: Copy result image**

Run:

```bash
cp results/<hash>/case09_two_source_resolution/two_source_resolution.png docs/assets/case09-pairwise-mainline-<hash>.png
```

- [ ] **Step 2: Add research-log entry**

Add a top entry with:

```markdown
### 2026-05-08：`<hash>` Case9 pairwise backend mainline diagnostic

- Version hash: `<hash>`
- Change: promoted pairwise covariance-fit ML backend to Case9 mainline and synchronized docs.
- Validation: sanity tests, checkcode, traceable Case9 run.
- Result path: `results/<hash>/`
- Case outputs: `case09_two_source_resolution/`
- Remaining risk: diagnostic Case9 only; not full paper profile.
```

- [ ] **Step 3: Confirm traceability**

Run:

```bash
ls -lh results/<hash>/RUN_NOTES.md results/<hash>/manifest.md results/<hash>/case09_two_source_resolution/case09_results.mat docs/assets/case09-pairwise-mainline-<hash>.png
```

Expected: all files exist.
