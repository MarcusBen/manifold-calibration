# manifold calibration

这个仓库保存 MATLAB 实验代码、HFSS 数据、可追溯实验结果和论文证据链记录。当前主线是用少量校准角重构未见方向流形，并比较 `Ideal / Interpolation / ARD / Proposed / HFSS Oracle` 在 MUSIC DOA 任务中的表现。

## 先看这里

- [研究变更记录](docs/research-log.md)
- [评阅与修改意见](docs/comments.md)

## 最新摘要

截至 2026-04-20，当前分支 `codex/proposed-v2` 的最新有效评阅批次是 `20260420-120416-local-c72eabab`。这一批把 `array_response_decomposition_algorithm.md` 中可由当前数据支持的 **ARD Method 2** 加为正式同场 baseline，并在 `paper` profile 下重跑 10 个 case。

- 默认 HFSS 数据源为 `data/hfss/step0.2deg.csv`，理想阵列基线仍按 `elementSpacingLambda = 0.25` 生成。
- ARD Method 2 使用 complex correction-vector interpolation：先在校准角计算 `g(theta)=a_HFSS(theta)./a_ideal(theta)`，再在 `u = sin(theta)` 域插值并重构流形。
- 本轮没有实现 unknown coupling matrix `C` 的 Method 3；不能把当前结果写成完整 array response decomposition 路线已经完成。
- `Proposed V2` 的 Full V2 C-route 已在前一批 `20260420-091822-local-8e021ea7` 完成同场 full run，但结果没有稳定优于 `Interpolation` 或 `Proposed V1`。
- 最新 comments 明确基于 `20260420-120416-local-c72eabab`：ARD 已成为强 baseline，下一步优先方向应是重构 Proposed 算法，而不是继续加 case 难度或立即转向 2D DOA。

## Version Trace

- Current pending local hash: `local-c72eabab`
- Current pending run: `results/<case-name>/20260420-120416-local-c72eabab/`
- Previous pending run on this branch: `results/<case-name>/20260420-091822-local-8e021ea7/`
- Base HEAD for both 2026-04-20 runs: `588318c`
- Working branch: `codex/proposed-v2`
- Latest reviewed comments hash: `local-c72eabab`
- Review status: comments match the current ARD run before Git hash finalization
- Git code commit hash: pending synchronization
- Hash finalization commit hash: pending synchronization
- Published branch: `origin/codex/proposed-v2`

## 当前结果判断

- Case 3 在 `L = 9` 时，mean unseen relative error 为 `Ideal 0.3210 / Interpolation 0.0447 / ARD 0.0010 / Proposed V1 0.0453 / Proposed V2 0.1054 / HFSS Oracle 0`，ARD 在流形重构指标上显著接近 Oracle。
- Case 7 在 `SNR = 20 dB` 时，RMSE 为 `Ideal 3.7502 / Interpolation 0.0016 / ARD 0.0037 / Proposed V1 0.0140 / Proposed V2 0.0114 / HFSS Oracle 0.0037 deg`。
- Case 9 mean resolution 为 `Ideal 0.0987 / Interpolation 0.1262 / ARD 0.1245 / Proposed V1 0.1268 / Proposed V2 0.1148 / HFSS Oracle 0.1238`；ARD 接近 Oracle/Interpolation，但不稳定超过 Proposed V1。
- Case 10 平均 manifold error 为 `Ideal 0.3214 / Interp 0.0459 / ARD 0.0056 / Proposed V1 0.0461 / Proposed V2 0.1025`；平均 single-source RMSE 为 `3.7287 / 0.1262 / ARD 0.1035 / 0.1138 / 0.1461 deg`。

## 仍需保留的边界

- `local-c72eabab` 仍是 pending local hash；同步后需要映射到真实 Git code commit hash。
- ARD Method 2 同时校正幅度和相位，不是当前 phase-only Interpolation 的同类预算对照；论文里应写成更强的 complex correction-vector baseline。
- 当前 Proposed V2 / Full V2 C-route 不能写成稳定胜过 V1、Interpolation 或 ARD；它更像一个已验证但暂未成功的 task-supervised 路线。
- 2026-04-20 的最新阶段判断是：1D benchmark 已经足够成熟，主要瓶颈在 Proposed 算法结构本身，而不是 case 难度不足。
- 2D DOA 更适合作为中后期扩展；在 1D 算法故事尚未收束前，不宜作为当前主线。

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

使用可追溯结果目录时，需要为本批代码生成一个 pending local hash，并设置同一个 `runId`：

```matlab
setup_paths
cfg = default_config(pwd);
cfg.run.useTraceableDirs = true;
cfg.run.pendingLocalHash = 'local-xxxxxxxx';
cfg.run.runId = 'YYYYMMDD-HHMMSS-local-xxxxxxxx';
cfg.run.command = 'run_project(1:10, cfg)';
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
