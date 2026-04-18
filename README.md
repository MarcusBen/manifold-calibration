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
- `case09` 已适配细网格双源 near-threshold separation sweep，默认 `separationSweepDeg = [1 2 3 4 5 6 8 10]`，并同时比较 `Ideal / Interpolation / Proposed / HFSS Oracle`。
- `case09` 的 pair 选择默认使用 `research_coverage`，优先覆盖边缘区、高失配区、远离校准角的未见角和近阈值困难组合。
- `results_step0p2_qw/` 是兼容旧运行习惯的默认输出目录；可追溯实验应使用 `cfg.run.useTraceableDirs = true`，输出到 `results/<case-name>/<timestamp>-<localhash>/`。
- `default_config(rootDir, 'paper')` 提供更厚 Monte Carlo 的正式图配置；日常默认配置仍以较快迭代为主。

当前更稳妥的论文表述是：项目已经完成默认代码层面的 dense HFSS 数据切换，并建立了更严格的细网格评估入口。`35756f6` 这一批已直接跑完 dirty worktree 上的 `paper` profile 全量 `run_project(1:10, cfg)`；它可以作为 issue 收口验证和研究记录，但不能冒充 clean repo 最终归档。

## Version Trace

- Git code commit hash: `35756f6`
- Base HEAD before this batch: `7191dc4`
- Published branch hash: pending finalization push
- Latest comments entry: `2026-04-18` review of `996b0e4`
- Review status: latest comments explicitly evaluate `996b0e4`, but they are not marked with `Reviewed commit:` / `Review for commit`; treat them as current reviewer guidance rather than a formal hash-matched review marker.
- Latest traceable paper-profile full run: `results/<case-name>/20260418-133202-35756f6/`

## 提醒：`comments`、`research-log` 和当前代码并不完全对齐

以下差异需要保留，不要把旧评论平滑成当前结论：

- `docs/comments.md` 最新条目认可 `996b0e4` 的方向；`35756f6` 已进一步补齐 Case 7/8 严格判据、Case 9 图题语义和 Case 2 oracle 标注。
- 当前代码与 `docs/research-log.md` 的最新条目一致：默认 `case09` 使用 `[1 2 3 4 5 6 8 10]` 的 separation sweep、`snapshots = 500`、`monteCarlo = 80`，包含 `Interpolation` 基线，并在细网格下使用更严格的状态阈值。
- `paper` profile full run 显示 Case 7/8 中 `Ideal` 的结构性误差地板很明显；但 Case 9 中 `Proposed` 未稳定优于 `Interpolation`，因此论文主张应收窄为“相对 Ideal 的流形失配校正有效，Proposed 与 Interpolation 的差异需要按角域/状态细分讨论”。
- 这次 full run 记录了 dirty worktree，仍需后续 clean repo + finalized Git hash 归档。
- 旧日志中关于 `5 deg` 网格和 coarse-grid benchmark 的条目是历史判断；当前默认入口已切到 `0.2 deg` HFSS 数据，但最终论文图仍需要按最新配置重新确认。
- `Amp+Phase` 仍应作为 oracle 上界，而不是同预算可实现基线。

## 运行方式

在 MATLAB 中运行全部 case，使用兼容默认输出目录：

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

使用可追溯结果目录时，需要为本批代码生成一个 pending local hash，并设置同一个 `runId`：

```matlab
setup_paths
cfg = default_config(pwd);
cfg.run.useTraceableDirs = true;
cfg.run.pendingLocalHash = 'local-xxxxxxxx';
cfg.run.runId = 'YYYYMMDD-HHMMSS-local-xxxxxxxx';
cfg.run.command = 'run_project([1 9], cfg)';
run_project([1 9], cfg);
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
