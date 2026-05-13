# manifold calibration

这个仓库保存 MATLAB 实验代码、HFSS 数据、可追溯实验结果和论文证据链记录。当前主线是用少量校准角重构未见方向流形，并在双源 Case 9 中使用 pairwise covariance-fit ML backend 进行联合 DOA 估计。MUSIC peak picking 保留为后端诊断/消融基线，不再作为 Case 9 主结果后端。Case 12 是当前更紧凑的 1/2/3-source RMSE 与谱函数展示入口。

## 先看这里

- [研究变更记录](docs/research-log.md)
- [评阅与修改意见](docs/comments.md)

## 最新摘要

截至 2026-05-13，当前功能分支 `codex/parallel-doa-backends` 已把 MUSIC、SPICE+、Grid ML 整理为并行 DOA backend family。Case 12/core 诊断现在可以在同一 HFSS-truth snapshots 下并行比较 backend；Case 13 advantage audit 仍保持 scalar backend 执行，并显式标注为 `metadata_only_scalar_audit`，避免把未来 backend-family 配置误读为当前并行审计结果。

- 当前代码默认仍是 Proposed V3.3，保留 ARD anchor、held-out guard 和 global-stable pair surrogate；GP-ANM 已作为离线诊断评估，不属于当前主线。
- 新增 backend family plumbing：`music`、`spice_plus`、双源 `pairwise_grid_ml`、三源 `triplet_grid_ml`。SPICE 代码已作为 tracked backend 集成进 `src/`，主项目不依赖未跟踪的 `algorithms/SPICE/` 实验目录。
- `4cfa7eb` 是本次 parallel-backend plumbing 的 Git code commit hash；它对应 former pending local hash `local-1816bb57`，结果目录 finalization 后为 `results/4cfa7eb/`。
- 本次 traceable smoke 只验证 wiring、结果结构、日志和小规模 Case 12 输出；它不是新的性能结论。
- Case 9 当前默认后端是 `pairwise_grid_ml`，默认诊断 pair 为 `[-12.2 -4.2; 6.8 16.8; 23.8 31.8]`，`monteCarlo = 20`。这是一条中等规模诊断主线，不是完整 paper-profile full run。
- Case 12 当前默认使用 `monteCarlo = 50`、`snapshots = 1000`，1/2/3-source 共用 HFSS-truth snapshots across methods；默认 backend families 覆盖 MUSIC、SPICE+ 和 Grid ML。三源 `triplet_grid_ml` 仍应按 coarse-grid diagnostic 解读。
- `local-8ed089e4` paper-readable figure assets are present in `docs/assets/`, but the corresponding local result folder is not present after local cleanup; `aa42472` remains the previous complete Case 12 diagnostic result folder.
- Large artifact note: `results/aa42472/case12_core_1to3_source_mainline/case12_results.mat` is about 40 MB and remains local-only when syncing through the GitHub REST path; published GitHub evidence includes code, docs, run metadata, and PNG figures.
- 2026-05-06 先做了 `local-2f83ff50` GP-ANM offline diagnostic smoke。由于本地没有 CVX/SDP solver，真正 GP-ANM SDP 被跳过；固定 diagonal proxy 基本不能解释 HFSS-vs-ideal manifold gap，也没有解决两源 pair。
- `602158e` Case 9 common-snapshot rerun 是旧 MUSIC-backend 证据，仍可用于解释历史问题，但不能与当前 pairwise-backend 主线数字直接混用。
- `fadea59` 是旧文档同步批次，不包含当前后端主线实验输出。
- 当前解释口径应保持清楚：V3.3 manifold calibration 是前端，pairwise covariance-fit ML 是双源主线后端，Case 11 是后端消融证据。
- `docs/comments.md` 的最新评阅仍绑定 Git code commit `a5a22d2`，只适用于旧的 V3-Revised screening；当前 parallel-backend branch 尚无匹配 comments review。
- 算法说明文件已从根目录收纳到 `algorithms/`，这是有意的文档整理，不是误删。

## Version Trace

- Former pending local hash: `local-1816bb57`
- Git code commit hash: `4cfa7eb`
- Current local core 1/2/3-source result folder: `results/4cfa7eb/`
- Previous finalized Case12 backend-consistent diagnostic hash: `aa42472`
- Previous finalized Case12 result folder: `results/aa42472/`
- Previous finalized documentation hash: `fadea59`
- Previous finalized documentation folder: `results/fadea59/`
- Prior local pairwise-backend result reference: `results/local-93b97e7f/`
- Prior local paper-readable figure reference: `local-8ed089e4`
- Previous MUSIC-backend empirical evidence hash: `602158e`
- Earlier same-day local smoke record: `results/local-2f83ff50/`
- Base HEAD for current local batch: `not-a-git-repo`
- Working branch: `codex/parallel-doa-backends`
- Latest reviewed comments hash: `a5a22d2`
- Review status: comments do not match the current Git code commit; treat comments as background only for this version.
- Hash finalization metadata: this branch includes the follow-up metadata commit that replaces `local-1816bb57` with `4cfa7eb` for the current parallel-backend plumbing smoke batch. Earlier finalized/local records such as `aa42472`, `fadea59`, `602158e`, and `local-2f83ff50` are left as trace entries.
- Published branch: `origin/codex/parallel-doa-backends` after push
- Published branch tip: see remote branch after push
- Historical result archive policy: older remote `results/` folders are retained as published history; local cleanup deletions are not part of ordinary sync unless explicitly requested.

## 当前结果判断

- Snapshot policy: `benchmark_music` records `snapshotPolicy = common_truth_snapshots_across_methods` and reuses identical HFSS-truth snapshots across methods for each target/trial.
- Current Case 9 mainline uses `backendName = pairwise_grid_ml`.
- Current Case 9 default source pairs are middle and non-extreme: `[-12.2 -4.2; 6.8 16.8; 23.8 31.8]`.
- Latest local Case 9 pairwise-backend diagnostic: `results/local-93b97e7f/`, `monteCarlo = 20`, candidate pair count `1991`.
- Latest local Case 9 mean resolution: `Ideal 0.8833 / Interpolation 1.0000 / ARD 1.0000 / Proposed V1 1.0000 / Proposed V2 1.0000 / Proposed V3.3 1.0000 / HFSS Oracle 1.0000`.
- Latest local Case 9 mean stable rate: `Ideal 0.0167 / Interpolation 0.5333 / ARD 0.4333 / Proposed V1 0.5333 / Proposed V2 0.4667 / Proposed V3.3 0.4500 / HFSS Oracle 0.4167`.
- Latest local Case 9 mean pair RMSE: `Ideal 2.1621 / Interpolation 0.4782 / ARD 0.5927 / Proposed V1 0.4685 / Proposed V2 0.5470 / Proposed V3.3 0.5448 / HFSS Oracle 0.5802`.
- Latest local Case 9 separation-collapse rate is `0` for all methods.
- Latest complete local Case 12 core diagnostic remains `results/aa42472/`, with `monteCarlo = 50`, `snapshots = 1000`, 1/2/3-source mean RMSE, backend-marginal three-source spectrum, and full diagnostic figures in `case12_core_1to3_source_mainline/`.
- Latest parallel-backend plumbing smoke: `results/4cfa7eb/`, with `monteCarlo = 1`, reduced snapshots, `ideal/oracle` methods only, and backend families exercised for 1/2/3-source Case 12 paths.
- Latest local Case 13 backend-switched advantage audit smoke: `results/local-ee2e48be/`, with practical smoke subset `calibrationCounts = [5 9]`, `SNR = [0 10]`, `strata = center/edge`, and `monteCarlo = 3`.
- Current result claims must be read as pairwise-backend diagnostics unless a full paper-profile run is explicitly cited.
- The full `case12_results.mat` for `aa42472` remains available only in the local workspace unless a standard git push path is available.
- Historical MUSIC-backend numbers remain useful as ablation/background, not as current Case 9 mainline evidence.

## Reminder: comments and current code are not hash-aligned

- `docs/comments.md` 最新评阅针对 `a5a22d2` V3-Revised；当前 Git code commit 批次是 `4cfa7eb`，因此不能把旧 comments 直接当作当前版本评价。
- 当前 README 只把 comments 用作背景；当前版本的直接证据来自 `docs/research-log.md`、`algorithms/proposed_algorithm_v3_3.md` 和 `results/4cfa7eb/`。
- `docs/comments.md` 没有包含 `local-1816bb57`，本次 hash finalization 不应改写 comments。
- 如果后续要评阅当前 V3.3 common-snapshot 版本，应以本次上传产生的 Git code commit hash 为 review target。

## 仍需保留的边界

- `4cfa7eb` 是 parallel-backend plumbing smoke，不是完整 paper-profile full run；`aa42472` 是 Case 12 backend-consistent plotting/diagnostic batch；`602158e` 是旧 MUSIC-backend Case 9 screening rerun。
- Current pairwise-backend evidence should be reported separately from older MUSIC-backend evidence.
- GP-ANM is retained only as an offline diagnostic / possible future expensive baseline; it is not an active V3.3 fallback path.
- 下一步应优先补齐 pairwise-backend Case 9 的 traceable medium run 和 backend ablation explanation，而不是只根据单张代表谱图做结论。

## 运行方式

在 MATLAB 中运行当前默认主线 Case 12，使用默认输出目录：

```matlab
setup_paths
cfg = default_config();
run_project([], cfg);
```

显式运行历史全部 case：

```matlab
setup_paths
cfg = default_config();
run_project(1:12, cfg);
```

使用可追溯版本目录时，需要为本批代码生成一个 pending local hash，并设置同一个版本目录：

```matlab
setup_paths
cfg = default_config(pwd);
cfg.run.useTraceableDirs = true;
cfg.run.pendingLocalHash = 'local-xxxxxxxx';
cfg.run.runId = 'local-xxxxxxxx';
cfg.run.command = 'run_project([3 7 9 10], cfg)';
run_project([3 7 9 10], cfg);
```

只运行当前核心 1/2/3-source 诊断：

```matlab
setup_paths
cfg = default_config();
run_project(12, cfg);
```

只快速检查数据上下文：

```matlab
setup_paths
cfg = default_config();
ctx = build_project_context(cfg);
disp([ctx.numElements, ctx.numAngles, ctx.gridStepDeg, ctx.dataFrequencyGHz])
```

## 仓库地址

```bash
https://github.com/MarcusBen/manifold-calibration
```
