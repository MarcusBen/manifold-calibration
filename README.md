# manifold calibration

这个仓库保存 MATLAB 实验代码、HFSS 数据、可追溯实验结果和论文证据链记录。当前主线是用少量校准角重构未见方向流形，并比较 `Ideal / Interpolation / ARD / Proposed / HFSS Oracle` 在 MUSIC DOA 任务中的表现。

## 先看这里

- [研究变更记录](docs/research-log.md)
- [评阅与修改意见](docs/comments.md)

## 最新摘要

截至 2026-04-20，当前工作分支是 `codex/proposed_v3`，最新当前批次是 `results/local-1539bcdf/`。这一批实现并筛选 **Proposed V3-Revised = Calibration-Guarded ARD-Anchored Task-Aware Residual Calibration**，只运行 Case 3 / 7 / 9 / 10，用于判断是否值得进入完整 `paper` profile。

- V3-Revised 仍以 ARD 为主干，但 residual 经过 calibration-null gate、edge mask、`tanh` trust radius、held-out manifold guard 和 guard-based fallback 约束。
- 训练目标保留 single-source / pair / midpoint task 项，同时显著增强 ARD anchor、calibration-zero 和 guard 约束；task pair selection 改为 coverage 选择。
- 筛选结论是安全性修复有效：Case 3 / 10 不再出现旧 V3 的几何崩坏，Case 7 有轻微收益，Case 9 mean resolution 开始高于 ARD。
- 当前仍不进入 full `1:10`：Case 9 低于 Proposed V1，stable rate 也低于 ARD / V1，因此还不能写成最终有效算法。
- `docs/comments.md` 的最新评阅绑定 `local-1539bcdf`，与当前 pending V3-Revised screening 匹配；同步时会映射为真实 Git code commit hash。
- 算法说明文件已从根目录收纳到 `algorithms/`，这是有意的文档整理，不是误删。

## Version Trace

- Pending local hash: `local-1539bcdf`
- Current version result folder: `results/local-1539bcdf/`
- Base HEAD for current V3-Revised screening: `7a31dd1`
- Working branch: `codex/proposed_v3`
- Latest reviewed comments hash: `local-1539bcdf`
- Review status: comments match the current pending V3-Revised screening; final sync will replace the pending hash with the Git code commit hash.
- Git code commit hash: pending until sync commit
- Hash finalization commit hash: pending
- Published branch: `origin/codex/proposed_v3`
- Published branch tip: see remote branch after push
- Historical result archive policy: older remote `results/` folders are retained as published history; local cleanup deletions are not part of ordinary sync unless explicitly requested.

## 当前结果判断

- Guard metrics: calibration drift `1.81e-16`，guard relative excess `0.001159`，anchor RMS drift `0.001747`，均低于当前阈值。
- Case 3, `L = 9`: mean unseen relative error `ARD 0.001034 / V3-Revised 0.001917`，edge `0.001179 / 0.002993`，worst-10% `0.001048 / 0.002882`。旧 V3 的大幅几何退化已被拉回到 guard 内。
- Case 7, `SNR = 20 dB`: RMSE `ARD 0.002828 / V3-Revised 0.002309 deg`，mean absolute bias `0.000040 / 0.000027 deg`。单源高 SNR 有轻微收益。
- Case 9: mean resolution `ARD 0.124800 / Proposed V1 0.130000 / V3-Revised 0.126822`；mean stable rate `0.035400 / 0.037933 / 0.033933`。V3-Revised 高于 ARD 的 mean resolution，但仍低于 V1，stable rate 也不占优。
- Case 10: mean manifold error `ARD 0.005644 / V3-Revised 0.006080`，mean DOA RMSE `ARD 0.103499 / V3-Revised 0.103163 deg`。随机 split 稳健性基本守住，DOA RMSE 略好于 ARD。

## 仍需保留的边界

- `local-1539bcdf` 是 screening run，不是完整 paper-profile full run。
- 当前 V3-Revised 证明的是“安全修复 + 初步增益恢复”：它已经把旧 V3 的几何风险修掉，但还没有真正拿下 Case 9。
- 论文表述不能写成 V3-Revised 已优于 ARD / V1；目前只能写成几何安全、随机稳健、Case 9 出现局部正向趋势。
- 下一步应只围绕 Case 9 的 pair-task surrogate、stable-rate 对齐和 task pair 分布继续小步调优；不应马上扩 benchmark、转 2D 或大改架构。

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
