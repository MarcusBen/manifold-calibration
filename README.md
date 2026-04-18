# manifold calibration

这个仓库同时保存 MATLAB 实验代码、HFSS 数据、实验输出和论文证据链记录。当前主线是用少量校准角重构未见方向流形，并比较 `Ideal / Interpolation / Proposed / HFSS Oracle` 在 MUSIC DOA 任务中的表现。

## 先看这里

- [研究变更记录](docs/research-log.md)
- [评阅意见与补充评论](docs/comments.md)

## 最新摘要

截至 2026-04-18，当前默认实验已经切换到 `2.5GHz / 0.2 deg / lambda/4`：

- 默认 HFSS 数据源为 `data/hfss/step0.2deg.csv`，旧的 `data/hfss/port1-8_E.csv` 只作为历史数据保留。
- 理想阵列基线按 `elementSpacingLambda = 0.25` 生成，对应四分之一波长阵元间距；从 HFSS 数据诊断出的约 `0.276 lambda` 只作为失配诊断，不替代理想基线配置。
- `build_project_context.m` 会校验 0.2 度网格、2.5GHz 频率、8 路复数端口数据以及非 NaN/Inf 输入。
- 单源 DOA Monte Carlo 默认使用分层未见角抽样，避免 601 个角点全量运行过慢；流形误差指标仍覆盖全部未见角。
- `case09` 已适配细网格双源 near-threshold separation sweep，默认 `separationSweepDeg = [1 2 3 4 5 6 8 10]`，并限制每个 separation 的代表性 pair 数量。
- `results_step0p2_qw/` 保存了这轮默认配置对应的输出，可用于复查链路和图像，但仍应按研究日志中的说明谨慎区分 smoke / proof-of-trend 与最终论文 benchmark。

当前更稳妥的论文表述是：项目已经完成默认代码层面的 dense HFSS 数据切换，并建立了更严格的细网格评估入口；但正式论文结论仍需要更高置信度 Monte Carlo、结果稳定性复查和 hash 匹配评阅后再收束。

## Version Trace

- Local/research base hash: `ba9e6b7`
- Published GitHub hash: pending this sync commit
- Latest reviewed comments hash: unavailable in `docs/comments.md`
- Review status: `docs/comments.md` 没有可识别的 `Reviewed commit` 或 `Review for commit` 标记，因此只能作为背景意见；当前工作区版本尚未获得 hash-matched review。

## 提醒：`comments`、`research-log` 和当前代码并不完全对齐

以下差异需要保留，不要把旧评论平滑成当前结论：

- `docs/comments.md` 评价的是上一轮 `case09` 改进，并未标明评审 commit hash；它提到的 `centerAngleDeg = 37.5`、`separationSweepDeg = 4:2:18`、`numTrials = 250`、`scanGridDeg = -60:1:60` 不是当前默认配置。
- 当前代码与 `docs/research-log.md` 的最新条目一致：默认 `case09` 使用 `[1 2 3 4 5 6 8 10]` 的 separation sweep、`snapshots = 500`、`monteCarlo = 80`，并在细网格下使用更严格的状态阈值。
- 旧日志中关于 `5 deg` 网格和 coarse-grid benchmark 的条目是历史判断；当前默认入口已切到 `0.2 deg` HFSS 数据，但最终论文图仍需要按最新配置重新确认。
- `Amp+Phase` 仍应作为 oracle 上界，而不是同预算可实现基线。

## 运行方式

在 MATLAB 中运行全部 case：

```matlab
setup_paths
cfg = default_config();
run_project(1:10, cfg);
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

## 日常同步

拉取最新内容：

```bash
git pull
```

提交并推送本地修改：

```bash
git status --short
git add README.md docs/research-log.md default_config.m run_project.m src/benchmark_music.m src/build_project_context.m
git commit -m "update dense hfss default workflow"
git push origin main
```

## 新环境克隆

```bash
git clone https://github.com/MarcusBen/manifold-calibration.git
```
