# manifold calibration

这个仓库现在同时承担两件事：
- 保存 MATLAB 项目代码与实验结果
- 作为论文实验过程记录与任务收束入口

## 先看这里

- [研究变更记录](docs/research-log.md)
- [评阅意见与补充评论](docs/comments.md)

这份文档用于持续记录：
- 我对你发来文字的整理结果
- 当前实验判断
- 已确认结论
- 风险点与偏离点
- 下一步动作
- 对论文表述的影响

## 最新摘要

截至 2026-04-17，在同时阅读 `log` 与 `comments` 之后，当前更稳妥的综合判断是：

- `case09` 的方向已经明显改对：它不再只是“容易分开的双源演示”，而开始接近“近阈值 separation sweep + 状态分级”的分辨率 benchmark。
- `log` 与 `comments` 都同意：这次 `case09` 改动是有效的，但目前更像 `smoke / proof-of-trend` 版本，还不是最终论文版。
- 当前更准确的表述仍然是：`case09` 属于 coarse-grid near-threshold benchmark，而不是连续角域下的理论分辨率极限。
- `case01`、`case04`、`case08` 仍需继续重构，整条证据链才算补齐。
- `Proposed` 与 `Interpolation` 的差异仍需在更困难设置下重新验证。
- `Amp+Phase` 仍应作为 oracle 上界处理，不应当成同预算可实现基线。

## 提醒：`comments`、`log` 与当前代码并不完全一致

以下不一致已经在本次同步时显式保留，避免后续写论文或看首页时误判：

- `comments` 提到 `case09` 使用了更激进的配置，例如 `separationSweepDeg = 4:2:18`、`numTrials = 250`、`scanGridDeg = -60:1:60`、`centerAngleDeg = 37.5`；但当前仓库代码里已确认的默认配置仍是：
  - `separationSweepDeg = [5 10 15]`
  - `snapshots = 500`
  - `monteCarlo = 80`
  - 代码中没有同名的 `centerAngleDeg` 或 `scanGridDeg` 默认项
- `comments` 还提到 `case07/08` 已经切到边缘目标、细扫描，并加入 `bias floor / per-target stability`；但当前代码检查结果显示：
  - `case07/08` 仍主要在 `models.testAnglesDeg(:)` 上整体评估
  - 还没有看到与 `case09` 类似的稳定性分级或 bias-floor 输出结构
- 因此，当前首页结论应以“方向已经收紧、`case09` 明显改善，但部分更强说法尚未完全在代码中落地”为准。

详细记录见：
- [docs/research-log.md](docs/research-log.md)
- [docs/comments.md](docs/comments.md)

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
git add .
git commit -m "update"
git push
```

## 新环境克隆

```bash
git clone https://github.com/MarcusBen/manifold-calibration.git
```
