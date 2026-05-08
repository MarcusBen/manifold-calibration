# manifold calibration

这个仓库保存 MATLAB 实验代码、HFSS 数据、可追溯实验结果和论文证据链记录。当前主线是用少量校准角重构未见方向流形，并比较 `Ideal / Interpolation / ARD / Proposed / HFSS Oracle` 在 MUSIC DOA 任务中的表现。

## 先看这里

- [研究变更记录](docs/research-log.md)
- [评阅与修改意见](docs/comments.md)

## 最新摘要

截至 2026-05-07，当前工作分支是 `codex/proposed_v3`，最新当前批次是 `fadea59`。这一批是文档同步：新增 `algorithms/proposed_algorithm_v3_3.md`，把当前 Proposed V3.3 的 ARD-anchored safe residual backbone、5 dB Case-9-aligned pair surrogate、peak score、global competitor background、guard/fallback 逻辑和已知限制整理成算法说明。

- 当前代码默认仍是 Proposed V3.3，保留 ARD anchor、held-out guard 和 global-stable pair surrogate；GP-ANM 已作为离线诊断评估，不属于当前主线。
- 2026-05-06 先做了 `local-2f83ff50` GP-ANM offline diagnostic smoke。由于本地没有 CVX/SDP solver，真正 GP-ANM SDP 被跳过；固定 diagonal proxy 基本不能解释 HFSS-vs-ideal manifold gap，也没有解决两源 pair。
- 最新实验证据仍是 `602158e` Case 9 common-snapshot rerun。它只运行 Case 9，`monteCarlo = 80`，不是完整 paper-profile full run。
- 最新 `fadea59` 只新增算法文档，不改变代码行为、不新增 case 输出，也不改变 `602158e` 的实验判断。
- Common-snapshot rerun 结论仍是 restrained：V3.3 在 `>=6 deg` resolution / pair RMSE 上有竞争力，但 stable-rate 仍明显低于 Proposed V1；代表谱图不能再被解读成 V3.3 单次视觉优势。
- `docs/comments.md` 的最新评阅仍绑定 Git code commit `a5a22d2`，只适用于旧的 V3-Revised screening；当前 V3.3 common-snapshot 和 V3.3 algorithm documentation 批次尚无匹配 comments review。
- 算法说明文件已从根目录收纳到 `algorithms/`，这是有意的文档整理，不是误删。

## Version Trace

- Pending local hash: `fadea59`
- Git code commit hash: `fadea59`
- Current version result folder: `results/fadea59/`
- Previous empirical evidence hash: `602158e`
- Earlier same-day local smoke record: `results/local-2f83ff50/`
- Base HEAD for current local batch: `not-a-git-repo`
- Working branch: `codex/proposed_v3`
- Latest reviewed comments hash: `a5a22d2`
- Review status: comments do not match the current pending local hash; treat comments as background only for this version.
- Hash finalization metadata: this branch includes the follow-up metadata commit that replaces `fadea59` with the Git code commit hash after upload. The earlier `local-2f83ff50` smoke record is left as a local-hash trace entry.
- Published branch: `origin/codex/proposed_v3`
- Published branch tip: see remote branch after push
- Historical result archive policy: older remote `results/` folders are retained as published history; local cleanup deletions are not part of ordinary sync unless explicitly requested.

## 当前结果判断

- Snapshot policy: `benchmark_music` now records `snapshotPolicy = common_truth_snapshots_across_methods` and reuses identical HFSS-truth snapshots across methods for each target/trial.
- Case 9 leakage check remained clean: `taskEvalOverlapCount = 0`, `taskExcludedPairCount = 16`, evaluation pairs `152`.
- All-separation resolution: `ARD 0.123520 / Proposed V1 0.126891 / V3.3 0.126562 / HFSS Oracle 0.122533`。
- All-separation stable: `ARD 0.032730 / Proposed V1 0.037253 / V3.3 0.033388 / HFSS Oracle 0.032730`。
- Discriminative `>=6 deg` resolution: `ARD 0.305328 / Proposed V1 0.314344 / V3.3 0.312500 / HFSS Oracle 0.303074`。
- Discriminative `>=6 deg` stable: `ARD 0.081148 / Proposed V1 0.092828 / V3.3 0.082582 / HFSS Oracle 0.081148`。
- Discriminative `>=6 deg` mean pair RMSE: `ARD 28.107252 / Proposed V1 27.747758 / V3.3 27.664849 / HFSS Oracle 28.195703`。

## Reminder: comments and current code are not hash-aligned

- `docs/comments.md` 最新评阅针对 `a5a22d2` V3-Revised；当前 pending 批次是 `fadea59`，因此不能把旧 comments 直接当作当前版本评价。
- 当前 README 只把 comments 用作背景；当前版本的直接证据来自 `docs/research-log.md`、`algorithms/proposed_algorithm_v3_3.md` 和 `results/fadea59/`。
- `docs/comments.md` 没有包含 `fadea59`，本次 hash finalization 不应改写 comments。
- 如果后续要评阅当前 V3.3 common-snapshot 版本，应以本次上传产生的 Git code commit hash 为 review target。

## 仍需保留的边界

- `fadea59` 是文档批次，不是实验 rerun；`602158e` 是 Case 9 screening rerun，不是完整 paper-profile full run。
- Current evidence supports the snapshot-policy fix and a more meaningful visual comparison; it does not prove a final V3.3 win over Proposed V1.
- GP-ANM is retained only as an offline diagnostic / possible future expensive baseline; it is not an active V3.3 fallback path.
- 下一步应优先改善 stable surrogate 与 `benchmark_music` stable classification 的一致性，而不是只根据单张代表谱图做结论。

## 运行方式

在 MATLAB 中运行全部 case，使用默认输出目录：

```matlab
setup_paths
cfg = default_config();
run_project(1:10, cfg);
```

使用正式图 Monte Carlo 配置：

```matlab
setup_paths
cfg = default_config(pwd, 'paper');
run_project(1:10, cfg);
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
