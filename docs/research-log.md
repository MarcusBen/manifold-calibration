# 研究变更记录

这份文档用于长期记录项目里的研究判断、实验变更、代码方向调整和论文表述收束。

更新方式：
- 你把新的原始文字、实验结论、疑问或修改想法发给我。
- 我负责阅读、去重、归类、压缩成可执行的记录。
- 新内容优先整理进“最新整理”，必要时再沉淀到“历史记录”。

建议每次更新都尽量落成下面这几类信息：
- 当前判断
- 已确认事实
- 主要风险或偏离点
- 下一步动作
- 对论文表述的影响

## 最新整理

### 2026-04-18：`local-3e814f40` Case 4 严格公共测试集与全量 paper run

- Version hash: `local-3e814f40`
- Base HEAD: `bd11394`
- Worktree state: uncommitted code changes; existing historical result deletions and prior local archive artifacts were preserved.
- Run command: `run_project(1:10, default_config(pwd, 'paper'))`
- Result path pattern: `results/<case-name>/20260418-195622-local-3e814f40/`
- Run scope: all 10 cases, paper profile.

#### 一句话结论

本轮保留 harder Case 4，不退回旧宽间隔双源版本；同时把 Case 4 改成“只比较 L”的严格公共测试集版本，并把右侧双源图从单一 stable probability 扩成 `stable / biased / marginal / unresolved` 四状态分解。随后用同一个 pending hash 跑完 10 个 case 的全量 paper-profile 结果，便于统一管理。

#### 代码与行为变化

- Case 4 默认 `monteCarlo` 提高到 `200`，paper profile 也保持 `case4.monteCarlo = 200`。
- Case 4 继续使用 harder near-threshold sweep：`separationSweepDeg = [4 5 6 8 10]`，每个 separation 最多 `8` 个 pair，`pairSelectionMode = research_coverage`。
- 新增 `cfg.case4.useCommonTestSet = true`。Case 4 会先收集所有 `L = [3 5 7 9 13 17]` 的 uniform calibration angles，并在这些角之外固定公共单源测试角和公共双源 pair。
- Case 4 每个 L 都使用同一组 `commonSingleAnglesDeg` 和 `commonSourcePairsDeg`，从而把变量收紧到校准数量 L 本身。
- Case 4 结果新增 `stableRate`、`biasedRate`、`marginalRate`、`unresolvedRate`、`commonSingleAnglesDeg`、`commonSourcePairsDeg`、`commonExcludedCalibrationAnglesDeg` 和 `useCommonTestSet`。
- Case 4 图改成 `2 x 3` 布局：manifold error、single-source RMSE、stable、biased、marginal、unresolved。
- `cfg.case1.exampleAngleDeg = 25` 保留为同一行 manual fallback 注释；默认 Case 1 仍由 high-SNR sweep 自动选择 stress angle。

#### 全量运行结果检查

- 10 个 case 均生成 `20260418-195622-local-3e814f40` 目录。
- 10 个 case 均生成 `RUN_NOTES.md`。
- Case 4 使用公共测试集：`useCommonTestSet = 1`。
- Case 4 公共双源 pair 数：`40`；每个 L 的 `sourcePairCount` 均为 `40`。
- Case 4 公共单源测试角数：`75`；所有 L 的校准角并集排除数：`25`。
- Case 4 full run 的 stable rate roughly 为：
  - Ideal: 全部约 `0`
  - Interpolation: `0.0560-0.0607`
  - Proposed: `0.0516-0.0561`
  - HFSS Oracle: `0.1032-0.1119`
- Case 4 unresolved rate roughly 为：
  - Ideal: 约 `0.9998-1.0000`
  - Interpolation: `0.7986-0.8081`
  - Proposed: `0.8033-0.8085`
  - HFSS Oracle: `0.7649-0.7711`
- Case 9 仍包含 `Ideal / Interpolation / Proposed / HFSS Oracle`，共 `168` 个 pair、`8` 个 separation，代表困难 pair 为 `[-38.4, -30.4] deg`。

#### 关键图片

以下图片来自 `20260418-195622-local-3e814f40` 全量 paper-profile run，并已复制到 `docs/assets/`。

![case01 mismatch floor paper local 3e814f40](assets/case01-mismatch-floor-paper-local-3e814f40.png)

![case04 calibration count paper local 3e814f40](assets/case04-calibration-count-paper-local-3e814f40.png)

![case07 snr metrics paper local 3e814f40](assets/case07-snr-metrics-paper-local-3e814f40.png)

![case08 snapshot metrics paper local 3e814f40](assets/case08-snapshot-metrics-paper-local-3e814f40.png)

![case09 resolution paper local 3e814f40](assets/case09-resolution-paper-local-3e814f40.png)

#### 仍然存在的风险或边界

- `local-3e814f40` 仍是 pending local hash，不是真实 Git commit hash。
- 本轮 full run 来自 uncommitted worktree；它是 traceable paper-profile run，但仍不是 clean repo final archive。
- Case 4 已经不再“太容易”，但现在双源分辨很难；它更适合作为 calibration count 的严格压力测试，双源主证据仍应以 Case 9 为主。
- Case 4 中 Proposed 与 Interpolation 在四状态统计上非常接近，论文不能写成 Proposed 在该 case 中明显压过 Interpolation。

### 2026-04-18：`local-7fa085bd` 按 comments 收紧 Case 4 双源难度

- Version hash: `local-7fa085bd`
- Base HEAD: `bd11394`
- Worktree state: uncommitted code changes; previous result deletions and local archive artifacts are preserved.
- Change reason: `docs/comments.md` 指出 `case1.exampleAngleDeg = 25` 仍像主配置，且 Case 4 旧双源 pair 太容易，`Interpolation / Proposed / Oracle` 基本饱和到 1。
- Affected cases: Case 1 config readability, Case 4 calibration-count sensitivity.
- Result path: `results/case04_calibration_count_sensitivity/20260418-193948-local-7fa085bd/`

#### 代码与行为变化

- `cfg.case1.exampleAngleDeg = 25` 改为同一行注释，明确它只是 manual fallback；默认 Case 1 仍由 high-SNR sweep 自动选择 stress angle。
- Case 4 的双源部分不再使用旧的宽间隔对称 pair `[-5,5] / [-10,10] / [-15,15] / [-20,20]`。
- Case 4 现在使用 `separationSweepDeg = [4 5 6 8 10]`，每个 separation 最多选 `8` 个 pair，并复用 Case 9 的 `research_coverage` 评分逻辑覆盖高失配、边缘和远离校准角的组合。
- Case 4 结果新增 `sourcePairCount`，每个 L 的 `perL` 中保存实际 `sourcePairsDeg` 和 `pairSelection`，便于回看双源样例来源。
- Case 4 图中第三栏改成 `Stable resolution probability`，标题改成 near-threshold two-source resolution，避免把它误读成旧版宽间隔演示。
- `paper` profile 将 `case4.monteCarlo` 提到 `120`，因为近阈值概率比旧宽间隔 pair 更需要厚一点的统计。

#### Smoke 验证

已跑低 Monte Carlo traceable smoke：

```matlab
run_project(4, cfgSmoke)
```

验证配置只用于链路检查：`lValues = [3 9 17]`，`monteCarlo = 8`。结果确认：

- 每个 L 自动选出 `40` 个双源 pair。
- 第一档 L 的 pair separation 覆盖 `[4.0, 10.0] deg`。
- `pairSelection.mode = case4_research_coverage`。
- `resolutionProb` 不再像旧 Case 4 那样在修正方法上饱和为 1；本次 smoke 中 corrected/oracle 方法约落在 `0.04-0.11`，而 Ideal 为 `0`。由于 MC 很低，这只能说明难度区间已被收紧，不能当作正式统计数值。

![case04 near-threshold smoke](assets/case04-near-threshold-smoke-local-7fa085bd.png)

#### 仍然存在的风险或边界

- 本次只按 comments 做局部代码收口，没有升级 Case 5 / Case 6 的实验结构。
- Case 4 现在避免了“太容易”，但 smoke 结果偏难；正式论文是否采用它作为主图仍需 paper profile 或更厚 MC 复核。
- Case 4 仍应定位为校准数量敏感性和辅助证据；真正的双源分辨主证据仍是 Case 9。

### 2026-04-18：`local-77d2252a` 本地收口归档候选 full paper run

- Pending local hash: `local-77d2252a`
- Base HEAD: `bd11394`
- Worktree state: uncommitted local closeout run; tracked historical `results*` deletions are intentionally preserved per user confirmation.
- Run command: `run_project(1:10, default_config(pwd, 'paper'))`
- Result path pattern: `results/<case-name>/20260418-190723-local-77d2252a/`
- Comment/review status: `docs/comments.md` is a current local project-completeness analysis, not a hash-matched review verdict.

#### 一句话结论

本轮按“收口归档”路线处理：不扩模型、不重写 Case 9 核心算法，先完成文本统一、legacy 配置说明、traceable full paper-profile run 和 `docs/assets/` 图像归档。当前结果可用于本地研究判断和 issue 收口，但仍是 pending local hash，不是最终 clean Git 归档。

#### 代码与行为变化

- 图题统一到 `HFSS truth snapshots; MUSIC scan uses the listed estimator manifolds`，避免 singular/plural 和 truth/estimator 表述混用。
- `case1.exampleAngleDeg = 25` 保留为 manual fallback，并在配置中注明默认 Case 1 仍由 high-SNR sweep 自动选择 stress angle。
- Case 9 保留现有 near-threshold + research_coverage + `Interpolation` baseline 设计，没有在本轮引入新算法变量。
- Case 4 / Case 5 / Case 6 的深层升级只在文档中标为后续阶段，不在 clean 归档前扩大代码改动面。

#### 全量结果摘要

- Case 7 在 `SNR = 20 dB` 时，`Ideal / Interpolation / Proposed / HFSS Oracle` 的 RMSE 约为 `3.7507 / 0.0037 / 0.0123 / 0.0043 deg`；mean absolute bias 约为 `2.9180 / 0.0001 / 0.0008 / 0.0001 deg`；P90 absolute error 约为 `6.6000 / 0.0000 / 0.0000 / 0.0000 deg`。Ideal 的 high-SNR mismatch floor 仍然清楚。
- Case 8 在 `SNR = 10 dB, snapshots = 1000` 时，`Ideal / Interpolation / Proposed / HFSS Oracle` 的 RMSE 约为 `3.7545 / 0.0455 / 0.0594 / 0.0473 deg`；mean absolute bias 约为 `2.9214 / 0.0027 / 0.0129 / 0.0023 deg`；P90 absolute error 约为 `6.6000 / 0.0000 / 0.0000 / 0.0000 deg`。这继续支持“快拍数增加不能自动修复错误流形”的表述。
- Case 9 的方法标签已确认为 `Ideal / Interpolation / Proposed / HFSS Oracle`，每个 separation 都有代表性 pair 和状态分级字段。
- Case 9 本次代表性困难 pair 为 `[-38.4, -30.4] deg`，选择原因是 `Proposed` 相比 `Interpolation` 在该 pair 上改善 stable/resolution 行为，同时仍是 mixed hard pair。
- Case 9 在 `10 deg` separation 下 resolution mean 约为 `Ideal 0.4748 / Interpolation 0.6192 / Proposed 0.6148 / HFSS Oracle 0.5887`，pair RMSE mean 约为 `18.6304 / 14.9388 / 15.0744 / 16.0637 deg`，stable mean 约为 `0.0243 / 0.1989 / 0.1933 / 0.1870`。因此双源结论仍应保持克制，不能写成 Proposed 全局稳定优于 Interpolation。

#### 关键图片

以下图片来自 `20260418-190723-local-77d2252a` 本地 paper-profile full run，并已复制到 `docs/assets/`。它们可用于当前研究日志和 issue 收口，但最终论文归档仍需真实 Git hash 或 clean rerun 对齐。

![case01 mismatch floor paper local](assets/case01-mismatch-floor-paper-local-77d2252a.png)

![case02 mismatch dominance paper local](assets/case02-mismatch-dominance-paper-local-77d2252a.png)

![case07 snr metrics paper local](assets/case07-snr-metrics-paper-local-77d2252a.png)

![case07 representative spectra paper local](assets/case07-representative-spectra-paper-local-77d2252a.png)

![case08 snapshot metrics paper local](assets/case08-snapshot-metrics-paper-local-77d2252a.png)

![case09 resolution paper local](assets/case09-resolution-paper-local-77d2252a.png)

#### 仍然存在的风险或边界

- `local-77d2252a` 是 pending local hash，不能冒充真实 Git code commit hash。
- 当前 full run 来自 uncommitted worktree；它已经 traceable，但还不是 clean repo final archive。
- 大量历史 `results*` 删除是本轮确认保留的清理方向，旧平铺结果不再恢复。
- Case 9 已经是正确困难 benchmark，但 `Proposed` 与 `Interpolation` 的全局差异很小，论文主张必须收窄。
- Case 4 双源升级、Case 5 辅助定位强化、Case 6 模型天花板路线选择都留到下一阶段。

#### 对论文表述的影响

- 可以继续写：本文实验使用 `2.5 GHz` HFSS truth manifold，在 `[-60 deg, 60 deg]` 上以 `0.2 deg` 步长构建角度网格，理想阵列基线按 `lambda/4` 阵元间距生成。
- 图注和正文应使用：`HFSS truth snapshots; MUSIC scan uses the listed estimator manifolds`。
- 可以写：错误的 Ideal manifold 在高 SNR / 高快拍条件下留下明显 bias floor，`Interpolation` 与 `Proposed` 都显著缓解该结构性误差。
- 不应写：`local-77d2252a` 已经是最终论文统计；也不应写：`Proposed` 在 Case 9 上稳定全局优于 `Interpolation`。

### 2026-04-18：`35756f6` GitHub issues 全量 paper-profile 运行

- Git code commit hash: `35756f6`
- Base HEAD: `7191dc4`
- Worktree state: dirty worktree full run; `README.md`、`docs/comments.md` 以及本批代码修改均记录在 `RUN_NOTES.md` 中。
- Run command: `run_project(1:10, default_config(pwd, 'paper'))`
- Result path pattern: `results/<case-name>/20260418-133202-35756f6/`
- Comment/review status: GitHub issues `#1-#11` were used as guidance, but this is not a clean-repo final-paper archive.

#### 一句话结论

本轮不再跑 smoke，而是直接用 `paper` profile 跑完 10 个 case。Case 7/8 已补入更严格的 `0.5 deg` 判据、bias 和 P90 指标；Case 9 的图题语义已补齐 HFSS truth / estimator manifold 分工；Case 2 的 `Amp+Phase` 已明确标成 oracle upper bound。

#### 代码与行为变化

- Case 2 将 `Amp+Phase` 改名为 `Amp+Phase Oracle`，并在图题中说明它是完整残差上界，不是同预算可实现 baseline。
- Case 7 默认 `toleranceDeg = 0.5`，代表性谱图角度改为自动选择边缘/高失配未见角。本次 full run 选中 `-59.8 deg`。
- Case 7 主图新增 mean absolute bias 与 P90 absolute error；结果中保存 `meanAbsBias`、`p90AbsError`、`exampleSelectionReason`。
- Case 8 默认 `toleranceDeg = 0.5`，图中同时展示 RMSE、mean absolute bias 与 P90 absolute error，用于区分快拍增益和结构性失配。
- `benchmark_music` 单源结果新增 `p90AbsError` 和 `perTargetP90AbsError`，用排序实现，不依赖 Statistics Toolbox。
- Case 9 保留 `Ideal / Interpolation / Proposed / HFSS Oracle` 和 `research_coverage` pair 选择；图题补入 HFSS truth snapshots / estimator manifold scan 原则。

#### 全量结果摘要

- Case 7 在 `SNR = 20 dB` 时，`Ideal / Interpolation / Proposed / HFSS Oracle` 的 RMSE 约为 `3.7507 / 0.0037 / 0.0123 / 0.0043 deg`；mean absolute bias 约为 `2.9180 / 0.0001 / 0.0008 / 0.0001 deg`。这说明 Ideal 的 high-SNR mismatch floor 已经清楚显现。
- Case 8 在 `SNR = 10 dB, snapshots = 1000` 时，`Ideal / Interpolation / Proposed / HFSS Oracle` 的 RMSE 约为 `3.7545 / 0.0455 / 0.0594 / 0.0473 deg`；mean absolute bias 约为 `2.9214 / 0.0027 / 0.0129 / 0.0023 deg`。这支持“快拍数增加不能自动修复错误流形”的表述。
- Case 9 本次 full run 的代表性困难 pair 为 `[-38.4, -30.4] deg`，选择原因是 `Proposed` 相比 `Interpolation` 在该 pair 上改善了 stable/resolution 行为。
- 但从 Case 9 按 separation 聚合的结果看，`Proposed` 没有稳定优于 `Interpolation`。例如 `10 deg` separation 下 resolution mean 约为 `Ideal 0.4748 / Interpolation 0.6192 / Proposed 0.6148 / HFSS Oracle 0.5887`，pair RMSE mean 约为 `18.6304 / 14.9388 / 15.0744 / 16.0637 deg`。因此论文主张必须收窄，不能写成 Proposed 在双源分辨上稳定碾压 Interpolation。

#### 关键图片

这些图片来自 dirty worktree 的 `paper` profile full run，可用于 issue 收口验证和研究日志，但还不是 clean repo 最终归档图。

![case01 mismatch floor paper](assets/case01-mismatch-floor-paper-35756f6.png)

![case02 mismatch dominance paper](assets/case02-mismatch-dominance-paper-35756f6.png)

![case07 snr metrics paper](assets/case07-snr-metrics-paper-35756f6.png)

![case07 representative spectra paper](assets/case07-representative-spectra-paper-35756f6.png)

![case08 snapshot metrics paper](assets/case08-snapshot-metrics-paper-35756f6.png)

![case09 resolution paper](assets/case09-resolution-paper-35756f6.png)

#### 仍然存在的风险或边界

- 本次 full run 已由 `project-github-sync` 映射到真实 Git code hash `35756f6`，但运行本身来自 dirty worktree，不能冒充 clean repo final result；后续仍需在 clean repo 上复跑正式归档。
- Case 7/8 已能清楚展示 Ideal 的结构性误差地板，但 `Proposed` 与 `Interpolation` 的差异非常小，应避免把论文主张写成均值性能显著压倒插值。
- Case 9 中 `Proposed` 与 `Interpolation` 的双源分辨表现非常接近，论文应重点讨论“相对 Ideal 的修正有效”和“不同 pair/状态下的稳定性差异”，而不是笼统宣称 Proposed 全局优于 Interpolation。

#### 对论文表述的影响

- 可以更有把握地写：在 `0.2 deg` dense HFSS grid 上，错误的理想流形会在高 SNR 和高快拍区留下明显 bias floor。
- 可以写：`Interpolation` 和 `Proposed` 都显著修复了 Ideal 的系统失配，但二者的优势需要按角域、pair 类型和状态分级细分。
- 不应写：本次 dirty worktree full run 已经是最终论文统计；也不应写：Proposed 在 Case 9 上稳定优于 Interpolation。

### 2026-04-18：`996b0e4` 加固 Case 1/9 与可追溯运行目录

- Git code commit hash: `996b0e4`
- Base HEAD: `81eaaf4`
- Worktree state before upload: uncommitted code/docs changes; existing `.codex/skills/*` and `docs/comments.md` edits were preserved.
- Result paths:
  - `results/case01_problem_validation/20260418-101955-996b0e4/`
  - `results/case09_two_source_resolution/20260418-101955-996b0e4/`
- Comment/review status: no hash-matched reviewed Git commit yet.

#### 一句话结论

本轮不是普通调参，而是在 `2.5GHz / 0.2 deg / lambda/4` 默认基线上继续收紧证据链：Case 1 开始显式寻找 high-SNR mismatch floor，Case 9 补回 `Interpolation` 并把 source pair 选择从均匀裁剪升级为研究问题导向覆盖。

#### 代码与行为变化

- `default_config` 保持旧调用兼容，同时新增 `default_config(rootDir, 'paper')`，用于正式图的更厚 Monte Carlo 配置；日常默认 `case09.monteCarlo = 80` 不变。
- 新增 `cfg.run` 可追溯输出配置。启用 `cfg.run.useTraceableDirs = true` 后，结果写入 `results/<case-name>/<runId>/`，并自动生成 `RUN_NOTES.md`。
- Case 1 默认 stress 设置改为 `SNR = 40 dB`、`snapshots = 2000`、`monteCarlo = 80`、`toleranceDeg = 0.4`。逐角 high-SNR sweep 先运行，再自动选择 Ideal 相对 HFSS Oracle 压力最大的角度作为代表性谱图角度。
- `benchmark_music` 对单源任务新增 `perTargetMeanError`、`perTargetAbsBias`、`trialErrorStd`，用于区分统计波动和 signed bias。
- Case 9 方法列表改为 `Ideal / Interpolation / Proposed / HFSS Oracle`。source pair 仍按 `[1 2 3 4 5 6 8 10]` 分离度组织，但每档最多 21 个 pair 时优先覆盖边缘区、高失配区、远离校准角和中心角多样性。
- Case 9 代表性 hard spectrum 优先选择 `Proposed` 相比 `Interpolation` 在 stable/resolution 行为上有优势、且仍处在混合困难状态的 pair；若没有这种 pair，会退回高失配困难 pair，并记录原因。

#### Smoke 验证

已跑低 Monte Carlo traceable smoke：

```matlab
run_project([1 9], cfgSmoke)
```

该 smoke 只验证链路和字段，不作为最终论文统计强度。已确认：

- `case01_results.mat` 包含 `highSnrSweep.methods(...).perTargetMeanError`、`stressExampleAngleDeg`、`exampleSelectionReason`。
- Case 1 代表性谱图角度来自逐角 bias/RMSE sweep，本轮 smoke 自动选中 `-52 deg`。
- `case09_results.mat` 的方法标签为 `Ideal / Interpolation / Proposed / HFSS Oracle`。
- Case 9 分离度分组为 `[1 2 3 4 5 6 8 10]`，每档 pair 数量不超过 21，且 source pair 不触碰校准角。
- Case 9 本轮 smoke 自动选中 `[-45.6, -35.6] deg` 作为代表性困难 pair，原因是 `Proposed` 相比 `Interpolation` 在 stable/resolution 行为上有优势，同时仍是混合困难 pair。

下面两张图只作为本轮代码链路 smoke 证据，不是最终论文图：

![case01 mismatch floor smoke](assets/case01-mismatch-floor-996b0e4.png)

![case09 resolution smoke](assets/case09-resolution-996b0e4.png)

#### 仍然存在的风险或边界

- Case 1 smoke 的 Monte Carlo 很低，不能把 `-52 deg` 的数值结果当成最终 mismatch floor 强度；它只说明自动选角、谱图和逐角偏差图已经对齐。
- Case 9 现在可以比较 `Proposed` 与 `Interpolation`，但正式论文主张必须看 paper profile 或更厚 Monte Carlo；如果 `Proposed` 不能稳定优于 `Interpolation`，主张要收窄为“相对 Ideal 的校正有效”。
- `results_step0p2_qw/` 仍保留为兼容默认输出目录；正式可回溯结果应使用 `results/<case-name>/<timestamp>-<localhash>/`。

#### 对论文表述的影响

- 图注必须说明：snapshots 由 HFSS truth manifold 生成，`Ideal / Interpolation / Proposed / HFSS Oracle` 只是 MUSIC 扫描使用的 estimator manifolds。
- Case 1 的正确说法是“之前 benchmark 过于容易，掩盖了可观测的结构性偏差”，不能写成“失配不存在”。
- Case 9 的正确说法必须包含 `Interpolation` 基线；只有 `Proposed > Interpolation` 稳定成立时，才能强调建模方式相对普通插值的额外价值。

### 2026-04-18：项目默认实验切换到 `2.5GHz / 0.2 deg / lambda/4`

#### 一句话结论

本轮已经把 MATLAB 默认实验从旧的粗角度 HFSS 数据切换到 `data/hfss/step0.2deg.csv`，频率统一为 `2.5GHz`，理想导向矢量按用户最终确认的四分之一波长间距生成；HFSS 流形仍作为真值，`Ideal / Interpolation / Proposed / HFSS Oracle` 的比较框架保持不变。

#### 当前判断

- 新数据源 `step0.2deg.csv` 是后续默认实验的唯一入口；旧 `port1-8_E.csv` 只保留为历史数据，不再参与默认流程。
- 阵元间隔以 `elementSpacingLambda = 0.25` 为准，而不是旧文档中的 `lambda/2`，也不是从数据反推得到的等效间距。
- 从新 HFSS 数据拟合出的等效间距约为 `0.276 lambda`，这个结果只作为诊断信息保留，不改变算法中理想导向矢量的生成方式。
- 0.2 度密网格会显著增加 DOA Monte Carlo 的运行量，因此单源 DOA 默认改为分层未见角抽样；流形级误差指标仍使用全部未见角，避免证据变弱。

#### 已确认事实

- `default_config.m` 已更新：
  - `cfg.data.csvPath = fullfile(rootDir, 'data', 'hfss', 'step0.2deg.csv')`
  - `cfg.array.frequencyHz = 2.5e9`
  - `cfg.array.elementSpacingLambda = 0.25`
  - 默认输出目录改为 `results_step0p2_qw`
  - 新增 `cfg.eval`，默认使用 `targetMode = 'stratified'` 和 `targetStrideDeg = 2`
- `build_project_context.m` 已更新数据校验：
  - 期望角度数为 `601`
  - 角度网格为 `-60:0.2:60`
  - 数据频率列必须全为 `2.5`
  - 端口数据为 8 路复数响应
  - 不允许出现 `NaN` 或 `Inf`
- 理想导向矢量现在由

  ```matlab
  a_m(theta) = exp(1j * (m-1) * (pi/2) * sind(theta))
  ```

  生成，对应 `2*pi*0.25 = pi/2`。
- 角度查找已经从严格浮点匹配改为最近网格点匹配，容差为半个网格步长，因此 `37.5 deg` 这类不落在 0.2 度网格上的角度会映射到最近可用 HFSS 角度，并记录请求角与实际使用角。
- Case 1/2/4/5/7/8/10 的 DOA Monte Carlo 不再默认遍历全部 601 个角点，而是从未见角中分层抽样，并强制覆盖边缘区、中心区和若干高失配区域。
- Case 3/4/5/6/10 的流形误差仍使用全部未见角计算。
- Case 9 已改为基于 0.2 度网格生成双源 pair，默认 separation sweep 为 `[1 2 3 4 5 6 8 10]`，并按每个 separation 限制代表性 pair 数量，避免组合爆炸。
- Case 9 的状态阈值已适配细网格：
  - `stableToleranceDeg = 0.6`
  - `biasedToleranceDeg = 2`
  - `marginalToleranceDeg = 5`

#### 验证记录

- 已完成 context 级数据读取验证：
  - `size(ctx.AH) == [8 601]`
  - `ctx.thetaDeg(1) == -60`
  - `ctx.thetaDeg(end) == 60`
  - `ctx.gridStepDeg == 0.2`
  - `ctx.dataFrequencyGHz == 2.5`
  - `cfg.array.elementSpacingLambda == 0.25`
- 已确认默认配置中不再出现旧的 `2.36e9`、`port1-8_E.csv`、`elementSpacingLambda = 0.5` 或旧版 Case 9 separation sweep。
- 已跑通过低 Monte Carlo smoke test：
  - `run_project([1 3 7 9], cfgSmoke)`
  - `run_project([2 4 5 6 8 10], cfgSmokeRest)`
- smoke 输出只用于链路验证，本条暂不插入新的结果图，避免把低 Monte Carlo 图误读为正式实验图。后续如需要纳入图像，统一保存到 `docs/assets/`，并用 `assets/<image>.png` 相对路径引用。

#### 这次改动实际解决了什么

1. 解决了代码默认数据源、频率配置和用户当前 HFSS 数据不一致的问题。
2. 解决了理想导向矢量仍沿用旧阵元间距假设的问题。
3. 解决了 0.2 度密网格下 DOA Monte Carlo 默认全量运行过慢的问题。
4. 解决了 `10 deg`、`37.5 deg` 等角度因为浮点或网格不重合而直接报错的问题。
5. 解决了 Case 9 在细网格下 pair 生成、pair 数量和状态阈值没有同步适配的问题。

#### 仍然存在的风险或边界

- `0.276 lambda` 的等效间距诊断说明 HFSS 真值流形和 `lambda/4` 理想流形仍有系统性差异；这正是项目要校正的对象，但论文表述中要避免把 `lambda/4` 理想模型说成物理真值。
- 分层 DOA 抽样提升了默认实验速度，但正式论文图如果需要极高置信度，仍应提高 Monte Carlo 次数或单独跑更密的目标角集合。
- Case 9 当前通过限制每个 separation 的 pair 数量控制运行量；如果正式结果对边缘角特别敏感，需要检查每个 separation 的 pair 覆盖是否足够均衡。
- 本轮没有重写旧 Markdown 条目中关于 `5 deg` 网格的历史记录；那些内容作为历史判断保留，不代表当前默认代码状态。

#### 下一步动作

- 用默认参数跑一版完整 `results_step0p2_qw`，确认正式图中的排序和误差曲线是否稳定。
- 回读 Case 7/8 的 `evalAnglesDeg`，确认 DOA 曲线确实来自分层未见角，而不是校准角。
- 回读 Case 9 的 `sourcePairsDeg` 与 per-separation pair 数量，确认每个 separation 都有足够代表性困难样例。
- 如果后续把图写入文档，先把图片复制或导出到 `docs/assets/`，再在 Markdown 中用 `assets/<image>.png` 相对路径引用，避免文档迁移或读取时路径失效。

#### 对论文表述的影响

- 可以明确写成：本文实验使用 `2.5GHz` HFSS 流形作为真值，并在 `[-60 deg, 60 deg]` 上以 `0.2 deg` 步长构建角度网格。
- 理想阵列基线应表述为“按 `lambda/4` 阵元间距生成的理想 ULA steering vector”，而不是从 HFSS 数据拟合得到的阵列模型。
- 流形误差图和 DOA 性能图需要区分说明：前者默认覆盖全部未见角，后者默认使用分层未见角抽样以控制计算量。
- Case 9 可以表述为“细角度网格下的双源 near-threshold separation sweep”，并应说明状态分级阈值是工程化评价标准，不是解析 Rayleigh 极限。

### 2026-04-17：`case09` 已从“容易分开”改成“近阈值分辨率扫描”

#### 一句话结论

`case09` 已经从少量居中对称、明显容易分开的双源样例，改成覆盖近阈值困难区的 separation sweep，并补入状态分级，使它开始能够支撑“接近分辨率极限时不同流形方法有明显差异”这一论点。

#### 当前判断

- 这次改动方向是正确的，核心不是再多加几个 source pair，而是把 benchmark 的难度区间重新定义到真正有区分度的区域。
- `case09` 现在比之前更接近“分辨率测试”而不是“普通双源定位演示”。
- 目前它已经能区分 `unresolved / marginal / biased / stable` 这几类状态，但由于 HFSS 角度网格仍然是 `5 deg` 步进，状态边界仍然会受 coarse grid 影响。

#### 实验结果图

下面这张图来自缩小版 `case09` smoke run，用于确认重构后的 benchmark 形式已经成立。该图不是最终论文主图，对应的是快速验证配置，而不是完整默认参数。

![case09 smoke result](assets/case09-two-source-resolution-smoke.png)

图中已经可以看到新的 `case09` 结构同时包含：
- 按 separation 聚合的 resolution probability
- 按 separation 聚合的 pair RMSE
- representative hard pair 的状态分解
- representative hard spectrum

#### 已确认事实

- 改动文件已落在：
  - `default_config.m`
  - `run_project.m`
  - `src/benchmark_music.m`
- `case09` 默认配置不再写死为少量宽间隔对称源对，而是改成近阈值 separation sweep：
  - `separationSweepDeg = [5 10 15]`
  - 自动从当前 HFSS 角度网格生成 pair
  - 不再只取居中的对称 pair，会自然包含偏中心、边缘附近和非对称组合
- 双源 benchmark 新增了状态分级输出：
  - `perTargetResolutionRate`
  - `perTargetMarginalRate`
  - `perTargetBiasedRate`
  - `perTargetStableRate`
  - `perTargetUnresolvedRate`
- `case09` 的结果图已经从原来的“三条简单曲线 + 一个写死示例谱图”改成：
  - 按 separation 聚合后的 resolution probability
  - 按 separation 聚合后的 pair RMSE
  - 代表性困难样例的状态分解柱图
  - 自动挑选的 representative hard spectrum
- `benchmark_music` 的双峰挑选逻辑做了修正，不再因为过强的一格间隔限制而压制 close peaks。
- 已做过缩小版 smoke test，只跑 `case09`，链路能正常运行，且在缩小配置下已经出现了 `marginal / biased / stable` 的分层。

#### 这次改动实际解决了什么

1. 解决了旧 `case09` 的 source pair 大多过于轻松、无法打到困难区的问题。
2. 解决了旧 benchmark 只能回答“有没有分开”，不能回答“勉强分开、分开但偏了、稳定分开”这些不同状态的问题。
3. 解决了示例谱图不够代表真实困难样例的问题，示例 pair 现在由 benchmark 结果自动挑选，而不是写死。

#### 仍然存在的风险或边界

- 当前 HFSS 角度仍是 `[-60, 60]` 上 `5 deg` 间隔，严格说这还是 coarse-grid near-threshold benchmark，不是连续角域下的真正分辨率极限。
- `marginal / biased / stable` 的分界目前是工程化判据，不是经典解析分辨率定义；论文里应把它表述为“状态分级统计”而不是理论极限本身。
- 默认 separation sweep 目前是 `[5 10 15]`，已经比原来更难，但是否足够还要看完整 Monte Carlo 结果图；如果大部分 pair 仍然过稳，后续需要继续向 `5 deg` 甚至更细分的困难区压缩。
- 示例样例当前是按“状态更混合、分辨概率不极端”的准则自动选取，能代表困难区，但不保证每次都是最直观的视觉样例。

#### 下一步动作

- 跑一版完整默认参数的 `case09`，确认正式结果图里 separation 维度上的曲线确实落在有区分度的难区，而不是仍然很快饱和。
- 读回 `case09_results.mat`，检查各 separation 下 pair 数量是否平衡，避免某一档只靠极少数边缘 pair 支撑结论。
- 若完整结果里 `marginal` 占比仍然过低，就继续收紧 pair 设计或重新调状态阈值，使“勉强分开”这档更稳定可见。
- 如果后续要把 `case09` 作为论文主图之一，需要在图注和正文里明确说明：
  - true data 仍由 HFSS manifold 生成
  - benchmark 是 near-threshold separation sweep
  - 状态分级是经验判据而非解析 Rayleigh 限

#### 对论文表述的影响

- 现在可以比之前更有把握地说：`case09` 不再只是“两个源也能估到”的演示，而是在接近分辨阈值的困难区比较不同流形质量对 MUSIC 分辨表现的影响。
- 论文里关于“双源分辨率提升”的表述仍应保持克制，建议写成：
  - “在近阈值 separation sweep 下，所提流形能提高 resolved / stable resolved 的比例，并降低 pair RMSE”
  - 不建议直接写成“显著提升阵列理论分辨极限”
- 如果后续完整结果显示 `Proposed` 相比 `Ideal` 明显改善，但与 `HFSS Oracle` 仍有较大差距，这个差距本身也应作为结果的一部分保留，而不是回避。

### 2026-04-17：实验框架方向基本正确，但验证难度偏低

#### 一句话结论

当前代码框架与论文设想大体一致，但若干 DOA benchmark 设得过于容易，导致关键 case 还不能充分证明想证明的结论。

#### 当前判断

- 框架设计基本正确。
- 证据强度目前不足。
- 问题主要出在 benchmark 设置，而不一定是方法本身错误。

#### 已确认与应当保留的部分

- case 结构整体与论文证据链对齐。
- 已经做了校准角与测试角分离。
- 相位主导假设有结果支持。
- 低阶模型方向合理，模型阶数升高到约 3 后趋于饱和。
- 已经纳入 `Ideal`、`Interpolation`、`Proposed`、`HFSS Oracle` 等对比对象。
- 核心方法主线应继续保留：
  - 稀疏校准
  - 相位主导修正
  - 在 `u = sin(theta)` 域做低维拟合
  - 用重构流形恢复 DOA，而不是只做理想流形下的简单 on-grid 实验

#### 当前最主要的问题

1. `case01` 没有真正展示出高 SNR 下的模型失配误差地板。
2. `case04` 的 DOA 指标已经饱和，无法回答“校准角数量何时不足、何时饱和”。
3. `case08` 没有清楚分离“快拍数降低统计误差”和“模型误差不会自行消失”。
4. `case09` 还不是严格意义上的分辨率极限测试。
5. 当前未见角测试仍然过于接近 coarse-grid on-grid 评估。
6. `Proposed` 与 `Interpolation` 的差距还没有被明确拉开。
7. `Amp+Phase` 更像 oracle upper bound，不应和可实现方法放在同一层级叙述。

#### 最怀疑的代码偏离点

- 真值角和扫描角都过于依赖同一套 HFSS 角度网格。
- 双源分辨 case 的源间隔设置还没有打到真正困难区。
- 若干 case 的 SNR、快拍数、角度分布或判定阈值组合得太“友好”。
- baseline 压力不足，掩盖了 proposed 与 interpolation 的真实差异。

#### 下一步代码检查重点

- 检查真值角生成与扫描角网格设置。
- 检查 `case01` 中数据生成端与估计端是否真正分离。
- 检查 `case04`、`case08` 的 SNR、快拍数、角度和容差设置。
- 重写 `case09` 的 source pair 设计，使其覆盖接近阵列分辨极限的区间。
- 统一结果数组类型，避免 RMSE、概率等量落入整数容器。

#### 对论文表述的直接影响

- 目前更准确的说法不是“代码方向错了”，而是“实验壳子搭对了，但验证难度和验证目标还没有完全对齐”。
- 如果后续更困难设置下 `Proposed` 仍与 `Interpolation` 接近，就需要主动收窄论文主张。
- `Amp+Phase` 应写成 oracle 上界，而不是同预算竞争方法。

#### 已落地的项目管理动作

- 已在仓库中建立中文 issue 结构，作为论文实验执行清单。
- 已建立总控 issue：`#10 总控：论文实验对齐与执行路线图`。
- 已拆出以下主线任务：
  - 代码审计
  - benchmark 重构
  - baseline 差异验证
  - 论文证据链收束

## 历史记录

当前暂无更早整理条目。后续每轮更新将按日期追加。
