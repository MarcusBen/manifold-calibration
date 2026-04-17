# manifold calibration

这个仓库现在同时承担两件事：
- 保存 MATLAB 项目代码与实验结果
- 作为论文实验过程记录与任务收束入口

## 先看这里

- [研究变更记录](docs/research-log.md)

这份文档用于持续记录：
- 我对你发来文字的整理结果
- 当前实验判断
- 已确认结论
- 风险点与偏离点
- 下一步动作
- 对论文表述的影响

## 最新摘要

截至 2026-04-17，当前整理结论是：

- `case09` 已经从“容易分开的双源演示”改成“近阈值 separation sweep”，并加入了 `unresolved / marginal / biased / stable` 状态分级。
- 这说明实验正在从“能跑”转向“能检验论文主张”的方向收紧。
- 当前 `case09` 仍然受 HFSS `5 deg` 粗网格限制，更准确的说法是 coarse-grid near-threshold benchmark，而不是连续角域下的理论分辨率极限。
- `case01`、`case04`、`case08` 仍需继续重构，才能把整条证据链补齐。
- `Proposed` 与 `Interpolation` 的差异仍需在更困难设置下重新验证。
- `Amp+Phase` 仍应作为 oracle 上界处理，不应当成同预算可实现基线。

详细记录见：
- [docs/research-log.md](docs/research-log.md)

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
