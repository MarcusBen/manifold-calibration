# manifold calibration

这个仓库保存 MATLAB 实验代码、HFSS 数据、可追溯实验结果和论文证据链记录。当前主线是用少量校准角重构未见方向流形，并比较 `Ideal / Interpolation / ARD / Proposed / HFSS Oracle` 在 MUSIC DOA 任务中的表现。

## 先看这里

- [研究变更记录](docs/research-log.md)
- [评阅与修改意见](docs/comments.md)

## 最新摘要

截至 2026-04-20，当前工作分支是 `codex/proposed_v3`，最新当前批次是 `results/local-fc4e69f9/`。这一批实现并筛选 **Proposed V3.2 = V3-Revised safety guards + distribution-matched stable-pair objective**，只运行 Case 3 / 7 / 9 / 10，用于判断是否值得进入完整 `paper` profile。

- V3.2 保留 V3-Revised 的 calibration-null gate、trust-radius residual、strong ARD anchor、held-out guard 和 fallback。
- 新增 distribution-matched task-pair selection、separation-balanced/center-covered pair sampling、stable-neighborhood pair loss，以及 Case 9 task/eval stratum 和 per-separation delta 诊断。
- 筛选结论是 mixed：V3.2 没有触发 fallback，Case 9 mean resolution 略高于 Proposed V1，但 stable rate 仍低于 ARD / V1，且 Case 7 高 SNR 单源退化。
- 当前仍不进入 full `1:10`：这轮证明了 V3.2 的实现链路可运行，也给出 Case 9 resolution 的局部进展，但 stable surrogate 还没有对齐 `benchmark_music` 的 stable 判据。
- `docs/comments.md` 的最新评阅仍绑定 Git code commit `a5a22d2`，只适用于上一轮 V3-Revised screening；当前 V3.2 批次尚无匹配 comments review。
- 算法说明文件已从根目录收纳到 `algorithms/`，这是有意的文档整理，不是误删。

## Version Trace

- Pending local hash before sync: `local-fc4e69f9`
- Git code commit hash: pending until upload commit is created
- Current version result folder: `results/local-fc4e69f9/`
- Base HEAD for current V3.2 screening: `6bb1a19`
- Working branch: `codex/proposed_v3`
- Latest reviewed comments hash: `a5a22d2`
- Review status: comments do not match the current V3.2 pending hash; treat comments as background only for this version.
- Hash finalization metadata: this sync should replace `local-fc4e69f9` with the Git code commit hash in current logs/results metadata after the first upload commit.
- Published branch: `origin/codex/proposed_v3`
- Published branch tip: see remote branch after push
- Historical result archive policy: older remote `results/` folders are retained as published history; local cleanup deletions are not part of ordinary sync unless explicitly requested.

## 当前结果判断

- Stable diagnostics: mean `minEndpointMinusMid = 29.98`，mean `minEndpointMinusBackground = 20.83`，mean `endpointImbalance = 4.269`。这说明内部 surrogate 有分离信号，但 endpoint balance / benchmark stable 判据仍未对齐。
- Case 3, `L = 9`: mean unseen relative error `ARD 0.001034 / V3.2 0.003177`，edge `0.001179 / 0.004960`，worst-10% `0.001048 / 0.004852`。mean 仍在 `ARD + 0.003` guard 附近，但 edge/worst 明显差于上一轮 V3-Revised。
- Case 7, `SNR = 20 dB`: RMSE `ARD 0.002828 / V3.2 0.003651 deg`，mean absolute bias `0.000040 / 0.0000667 deg`。V3.2 相对 ARD 和上一轮 V3-Revised 都退化。
- Case 9: mean resolution `ARD 0.124474 / Proposed V1 0.126776 / V3.2 0.126908`；mean stable rate `ARD 0.034825 / Proposed V1 0.036316 / V3.2 0.033333`。V3.2 resolution 略高于 V1，但 stable rate 没有改善，是本轮未过关的核心原因。
- Case 10: mean manifold error `ARD 0.005644 / V3.2 0.006616`，mean DOA RMSE `ARD 0.103499 / V3.2 0.103073 deg`。随机 split 几何略退化，DOA RMSE 略好于 ARD。

## Reminder: comments and current code are not hash-aligned

- `docs/comments.md` 最新评阅针对 `a5a22d2` V3-Revised；当前 V3.2 批次是 `local-fc4e69f9`，因此不能把旧 comments 直接当作当前版本评价。
- 当前 README 只把 comments 用作背景和 change basis；当前版本的直接证据来自 `docs/research-log.md` 和 `results/local-fc4e69f9/`。
- 如果后续要评阅 V3.2，应以本次上传产生的 Git code commit hash 为 review target。

## 仍需保留的边界

- `local-fc4e69f9` 是 screening run，不是完整 paper-profile full run。
- 当前 V3.2 证明的是“stable-pair surrogate 可以推动 Case 9 mean resolution”，但还没有证明 stable-rate 优势，也没有守住 Case 7。
- 论文表述不能写成 V3.2 已优于 ARD / V1；目前只能写成 Case 9 resolution 有局部进展，但 stable 判据和单源高 SNR 仍有代价。
- 下一步应改善 stable surrogate 与 `benchmark_music` 的一致性，而不是只增加 `lambdaPair` 或 SPSA iterations。

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
