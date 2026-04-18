# manifold calibration

这个仓库保存 MATLAB 实验代码、HFSS 数据、可追溯实验结果和论文证据链记录。当前主线是用少量校准角重构未见方向流形，并比较 `Ideal / Interpolation / Proposed / HFSS Oracle` 在 MUSIC DOA 任务中的表现。

## 先看这里

- [研究变更记录](docs/research-log.md)

本次同步是特例：README 只依据 `docs/research-log.md` 更新，不合并 `docs/comments.md` 的内容。

## 最新摘要

截至 2026-04-18，当前默认实验已经切换到 `2.5GHz / 0.2 deg / lambda/4`，并完成了最新一轮 `paper` profile 全量运行：

- 默认 HFSS 数据源为 `data/hfss/step0.2deg.csv`，旧的 `data/hfss/port1-8_E.csv` 只作为历史数据保留。
- 理想阵列基线按 `elementSpacingLambda = 0.25` 生成，对应四分之一波长阵元间距；从 HFSS 数据诊断出的约 `0.276 lambda` 只作为失配诊断，不替代理想基线配置。
- `build_project_context.m` 会校验 0.2 度网格、2.5GHz 频率、8 路复数端口数据以及非 NaN/Inf 输入。
- 单源 DOA Monte Carlo 默认使用分层未见角抽样，避免 601 个角点全量运行过慢；流形误差指标仍覆盖全部未见角。
- `case09` 已适配细网格双源 near-threshold separation sweep，默认 `separationSweepDeg = [1 2 3 4 5 6 8 10]`，并同时比较 `Ideal / Interpolation / Proposed / HFSS Oracle`。
- `case09` 的 pair 选择默认使用 `research_coverage`，优先覆盖边缘区、高失配区、远离校准角的未见角和近阈值困难组合。
- `case04` 已保留 harder 设计，并切到严格公共测试集版本：所有 `L` 使用同一组单源测试角和双源 pair，`paper` profile 下使用 `MC = 200`，输出 `stable / biased / marginal / unresolved` 四状态分解。
- `default_config(rootDir, 'paper')` 提供更厚 Monte Carlo 的正式图配置；日常默认配置仍以较快迭代为主。

最新全量结果批次为 `results/<case-name>/20260418-195622-local-3e814f40/`。该批次跑完 10 个 case，所有 case 均生成 `RUN_NOTES.md`。它是当前本地收口归档候选和研究记录，但在完成 Git hash finalization 前，`local-3e814f40` 仍只是 pending local hash。

## Version Trace

- Pending local hash: `local-3e814f40`
- Base HEAD for this local batch: `bd11394`
- Git code commit hash: pending first upload commit
- Published branch hash: pending finalization after commit/push
- Latest traceable paper-profile full run: `results/<case-name>/20260418-195622-local-3e814f40/`

## 当前结果与清理状态

- 旧的顶层 `results_smoke*`、`results_case9_smoke_tmp`、`results_step0p2_qw` 以及旧 `results_v0.zip` 已从仓库清理。
- `results/` 下每个 case 里原来散落的未打包 `.mat` 和 `.png` 结果文件已删除。
- 新的可追溯结果保留在 `results/<case-name>/<run-id>/` 结构下。
- 关键论文候选图已复制到 `docs/assets/`，用于 `docs/research-log.md` 引用。

## 仍需保留的边界

- `local-3e814f40` 这一批 full run 来自 uncommitted worktree；同步后需要用真实 Git commit hash 替换 pending local hash。
- Case 4 已经不再“太容易”，但现在双源分辨很难；它更适合作为 calibration count 的严格压力测试，双源主证据仍应以 Case 9 为主。
- Case 4 中 `Proposed` 与 `Interpolation` 在四状态统计上非常接近，论文不能写成 Proposed 在该 case 中明显压过 Interpolation。
- Case 9 仍包含 `Ideal / Interpolation / Proposed / HFSS Oracle`，但 `Proposed` 未稳定全局优于 `Interpolation`，因此论文主张应收窄为“相对 Ideal 的流形失配校正有效，Proposed 与 Interpolation 的差异需要按角域和状态细分讨论”。
- 旧日志中关于 `5 deg` 网格和 coarse-grid benchmark 的条目是历史判断；当前默认入口已切到 `0.2 deg` HFSS 数据。
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
git add README.md docs/research-log.md docs/assets default_config.m run_project.m results
git commit -m "archive paper profile closeout"
git push origin main
```

## 新环境克隆

```bash
git clone https://github.com/MarcusBen/manifold-calibration.git
```
