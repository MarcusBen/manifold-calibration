# manifold calibration

这个仓库保存 MATLAB 实验代码、HFSS 数据、可追溯实验结果和论文证据链记录。当前主线是用少量校准角重构未见方向流形，并比较 `Ideal / Interpolation / ARD / Proposed / HFSS Oracle` 在 MUSIC DOA 任务中的表现。

## 先看这里

- [研究变更记录](docs/research-log.md)
- [评阅与修改意见](docs/comments.md)

## 最新摘要

截至 2026-04-20，当前工作分支是 `codex/proposed_v3`，最新当前批次是 `results/87d7f16/`。这一批实现并筛选 **Proposed V3 = ARD coarse model + anchored task-aware phase residual refinement**，只运行 Case 3 / 7 / 9 / 10，用于判断是否值得进入完整 `paper` profile。

- V3 初始状态严格等于 ARD，再用小幅三段软门控 Chebyshev 相位 residual 做 task-aware refinement。
- 训练目标包含 calibration、single-source task、pair task、midpoint suppression、ARD anchor、smooth/reg。
- 筛选结论是不通过：V3 可运行且 objective 下降，但明显破坏 ARD 的全局流形重构优势，并且 Case 9 没有超过 ARD / Proposed V1。
- 因此当前不应把 V3 写成已优于 ARD，也不应继续跑 full 1:10 作为正式论文结果。
- `docs/comments.md` 的最新评阅仍绑定 `71650f7` ARD Method 2 full run；当前 V3 screening 的 Git code commit `87d7f16` 还没有匹配 comments review。

## Version Trace

- Former pending local hash: mapped from `local-5a1492f8` to `87d7f16`
- Current version result folder: `results/87d7f16/`
- Base HEAD for current V3 screening: `489efb6`
- Working branch: `codex/proposed_v3`
- Latest reviewed comments hash: `71650f7`
- Review status: current V3 screening has no matching comments review yet
- Git code commit hash: `87d7f16`
- Hash finalization commit hash: pending synchronization
- Intended published branch: `origin/codex/proposed_v3`
- Historical version folders retained after layout migration: `results/2962bc3/`, `results/71650f7/`, `results/local-8e021ea7/`, `results/local-aa29a0fd/`

## 当前结果判断

- Case 3, `L = 9`: mean unseen relative error `ARD 0.001034 / V3 0.017357`，edge `0.001179 / 0.017567`，worst-10% `0.001048 / 0.017536`。V3 明显退化，未通过全局/边缘流形筛选。
- Case 7, `SNR = 20 dB`: RMSE `ARD 0.002828 / V3 0.002828 deg`，mean absolute bias `0.000040 / 0.000040 deg`。单源高 SNR 没有变坏，但也没有新收益。
- Case 9: mean resolution `ARD 0.124474 / Proposed V1 0.126776 / V3 0.122018`；mean stable rate `0.034825 / 0.036316 / 0.033465`。V3 低于 ARD 和 V1，未达到筛选门槛。
- Case 10: mean manifold error `ARD 0.005644 / V3 0.065962`，mean DOA RMSE `ARD 0.103499 / V3 0.106980 deg`。RMSE 尚可，但流形误差明显崩坏。

## 仍需保留的边界

- `87d7f16` 是由 `local-5a1492f8` 映射后的 Git code commit hash；该批是 screening run，不是完整 paper-profile full run。
- 当前 V3 证明的是一条失败筛选路径：task residual 会把校准角从 ARD/HFSS anchor 拉开，不能把它描述为有效改进。
- 下一步应优先修 V3 objective，使 task residual 不再以牺牲 ARD 全局流形为代价；可以尝试更强 ARD anchor、更小 residual order/step、显式 global/edge manifold guard，或退化时 fallback 到 ARD。
- 继续加难 case 或立即转向 2D DOA 都不是当前主线。

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
