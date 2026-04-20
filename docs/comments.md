# 项目阶段性判断报告（基于 `20260420-120416-71650f7` 结果）

- Version hash: `71650f7`
- Base HEAD: `588318c`
- Review target: Git code commit / `20260420-120416-71650f7` paper-profile full run
- Review status: reviewed; ARD Method 2 is the current matching evaluation baseline
- Main comments: prioritize restructuring Proposed around an ARD-anchored path; do not make harder cases or 2D DOA the immediate main line.
- Conflicts with log/code: no direct hash conflict for the ARD batch; `local-8e021ea7` remains a previous pending Full V2 run rather than the latest reviewed result.
- Next action: design a stronger Proposed variant against ARD before expanding the benchmark scope.

## 1. 文档目的

本文档基于最新一次完整同场运行结果，对当前项目所处阶段进行判断，并回答如下核心问题：

1. 当前项目是否已经取得阶段性成果；
2. 新加入的对比算法 `array_response_decomposition_algorithm`（简称 ARD Method 2）对项目判断产生了什么影响；
3. 下一步应该优先：
   - 改进 Proposed 算法，
   - 继续增加 case 难度，
   - 还是转向 2D DOA；
4. 应如何组织后续研究路线。

本文档只依据最新一批结果进行判断，不依赖更早版本的日志作为结论依据。

---

## 2. 当前项目已经取得的成果

### 2.1 问题本身已经被证明成立

当前项目已经较为明确地证明：

- 理想流形与 HFSS 真值流形之间存在明显模型失配；
- 在高 SNR、高快拍条件下，这种失配会留下稳定的 DOA 偏差地板；
- 错误流形的影响不能通过单纯提高 SNR 或 snapshots 自动消除。

因此，项目研究对象本身是成立的，不属于“人为制造问题”。

---

### 2.2 相位主导假设已经被验证

现有结果已经表明，在当前阵列与 HFSS 数据下，理想流形与真实流形之间的主要差异来自相位残差，而非幅度残差。

这意味着：

- 当前流形修正路线在物理上是有支撑的；
- 后续 Proposed 算法仍可以以“相位主导 + 结构化建模”为核心；
- 不必贸然转向复杂的全幅相黑箱建模。

---

### 2.3 Benchmark 体系已经足够成熟

当前项目的 10 个 case 已经形成了较完整的验证链条：

- **Case 1 / 2**：问题成立性与失配主导机理；
- **Case 3**：未见方向泛化；
- **Case 4**：校准数量敏感性（严格公共测试集 hard version）；
- **Case 5**：采样策略；
- **Case 6**：模型/超参数敏感性；
- **Case 7 / 8**：高 SNR、高快拍下的单源偏差地板；
- **Case 9**：近阈值双源分辨；
- **Case 10**：随机划分稳健性。

这意味着：

> 你现在已经拥有一套足够成熟的 1D 基准评测体系，后续不再需要频繁大改 case 才能验证新算法。

---

## 3. 新加入 ARD baseline 后，项目判断发生了什么变化

这是本轮最重要的部分。

### 3.1 ARD 是一个明显更强的 baseline

本轮新加入的是 `array_response_decomposition_algorithm` 中可由现有数据支持的 **ARD Method 2**。从结果看，ARD 不是一个“凑数 baseline”，而是一个真正会改变项目判断的强基线。

#### Case 3（未见方向流形误差）

在 `L = 9` 时：

- Ideal: `0.3210`
- Interpolation: `0.0447`
- **ARD: `0.0010`**
- Proposed V1: `0.0453`
- Proposed V2: `0.1054`
- Oracle: `0`

ARD 在流形重构指标上几乎贴近 Oracle，远强于当前 Proposed 系列。

#### Case 7（高 SNR 单源）

在 `SNR = 20 dB` 时：

- Ideal: `3.7502 deg`
- Interpolation: `0.0016 deg`
- **ARD: `0.0037 deg`**
- Proposed V1: `0.0140 deg`
- Proposed V2: `0.0114 deg`
- Oracle: `0.0037 deg`

ARD 与 Oracle 已几乎重合。

#### Case 10（随机 split）

平均 manifold error：

- Interp: `0.0459`
- **ARD: `0.0056`**
- Proposed V1: `0.0461`
- Proposed V2: `0.1025`

平均 single-source RMSE：

- Interp: `0.1262`
- **ARD: `0.1035`**
- Proposed V1: `0.1138`
- Proposed V2: `0.1461`

ARD 在随机划分泛化上也显著更强。

### 3.2 ARD 没有在所有指标上完全碾压，但已经足够改变项目叙事

在 Case 9 这种困难双源分辨任务中，ARD 并没有形成对所有方法的稳定压制。例如：

- Case 9 mean resolution：
  - Ideal: `0.0987`
  - Interpolation: `0.1262`
  - ARD: `0.1245`
  - Proposed V1: `0.1268`
  - Proposed V2: `0.1148`
  - Oracle: `0.1238`

这说明：

- ARD 在双源近阈值分辨上只是“接近最强组”，不是绝对统治；
- 但它已经足够说明：当前 Proposed 在单源、流形重构、随机 split 这些基础能力上并未站住优势。

因此，**ARD 的加入把项目从“Proposed 和 Interpolation 谁更好”这个问题，推进到了“为什么一个强 complex correction-vector 方法能轻易超过当前 Proposed”这个更本质的问题。**

---

## 4. 基于这批结果，对三个策略选项的判断

下面直接回答你最关心的问题。

---

### 4.1 选项一：继续增加 case 难度

#### 结论：**当前不是优先项。**

原因如下：

1. **Case 4 已经很难。**
   当前 hard common test set 下，连 Oracle 的 stable rate 也只有约 `0.10 ~ 0.11`，并不存在“case 太容易所以看不出差别”的问题。

2. **Case 9 已经足够难。**
   整体 mean resolution 只有 `0.10 ~ 0.13` 量级，说明 benchmark 本身已经处于困难区间。

3. **ARD 已经在现有 benchmark 上显出明显优势。**
   这意味着问题不在于“场景不够毒”，而在于“当前 Proposed 本身不够强”。

因此，如果此时继续通过加大 case 难度来寻找 Proposed 的优势，容易给人一种“回避强 baseline”的感觉。

**判断：暂时不应把“继续加难度”作为主线。**

---

### 4.2 选项二：直接转向 2D DOA

#### 结论：**现在也不建议作为主线。**

原因如下：

1. **1D 里还没有形成令人满意的算法故事。**
   你当前最大的问题不是“场景维度太低”，而是“现有 Proposed 在成熟 1D benchmark 上已经被 ARD 压住了”。

2. **2D DOA 会引入大量新变量。**
   包括：
   - 方位角/俯仰角耦合；
   - 2D manifold 表达与网格维度爆炸；
   - 更复杂的 HFSS 数据组织；
   - 更复杂的峰值搜索与分辨分析。

3. **如果 1D 故事还没讲清楚，直接跳 2D 风险很大。**
   因为读者很容易理解为：
   - 并不是算法已经成熟，而是换了一个更复杂但更不透明的场景继续试。

因此，2D DOA 目前更适合作为**中后期扩展方向**，不适合作为你现在的主救火路线。

**判断：2D DOA 现在不该成为主线，只能作为后续扩展。**

---

### 4.3 选项三：优先改进 Proposed 算法

#### 结论：**这是当前最合理、最紧迫的主线。**

原因非常直接：

1. **ARD 已经把问题钉死了。**
   在现有 benchmark 上，一个更强的校正思路已经展示出明显优势。说明：
   - 问题本身可解；
   - 当前 Proposed 的不足主要是算法结构问题，而不是 benchmark 问题。

2. **V2-lite / Full V2 都说明“单纯增强局部建模”或“直接强上任务项”都还不够。**
   - V2-lite：有局部改进，但整体提升有限；
   - Full V2：任务项过强时会伤害全局泛化。

3. **现在最缺的不是更多 case，而是一个真正有辨识度的新 Proposed。**

因此，下一阶段应该明确转入：

> **以 ARD 为强 baseline，对 Proposed 进行结构性重构。**

**判断：当前主线应当是“改进 Proposed 算法”。**

---

## 5. 当前最值得做的不是“继续沿旧 Proposed 微调”，而是重新定义 Proposed 的目标

### 5.1 当前 Proposed 的核心问题

从最新结果看，当前 Proposed 系列的问题不是一点点参数没调好，而是结构目标存在偏差：

- V1 太接近全局低维相位拟合；
- V2-lite 只改善局部边缘建模，但仍未触及强 baseline 的核心；
- Full V2 直接加强任务项后，又明显破坏了全局几何泛化。

因此，下一版 Proposed 不应该只是：

- 再换一个阶数；
- 再换一个分段位置；
- 再多加几个 task weight；
- 再多做几个 case。

这些操作的边际收益已经很小。

---

### 5.2 新 Proposed 的核心目标应是什么

基于当前结果，我建议下一版 Proposed 应明确追求：

> **同时继承 ARD 的强几何重构能力，以及任务驱动方法对困难双源局部行为的调节能力。**

也就是说，新的 Proposed 不应再是单纯的“phase-only global fit”或“task-heavy local fit”，而应是：

1. **以更强的 complex correction-vector 粗模型作为几何主干；**
2. **在此基础上做受控的任务驱动细化，而不是无约束重写整个流形。**

这比继续把当前 V1/V2 硬磨下去更有前途。

---

## 6. 下一阶段推荐的主算法方向

### 6.1 建议路线：ARD-anchored task-aware refinement

我建议下一阶段的新 Proposed 可定义为：

### **Proposed V3 = ARD coarse model + anchored task-aware residual refinement**

基本思想：

1. 先用 ARD Method 2 得到一个强的 complex correction-vector 初值；
2. 再在该初值附近，仅用小幅残差 refinement 去优化：
   - 高 SNR 单源偏差地板；
   - 困难双源 stable / unresolved 行为；
3. 引入锚定项，防止任务项把流形整体拉坏。

可写成：
$$
\hat{\mathbf a}_{\mathrm{V3}}(\theta)
=
\hat{\mathbf a}_{\mathrm{ARD}}(\theta)
\odot
\exp\big(j\Delta\boldsymbol\phi_{\mathrm{task}}(\theta)\big),
$$
其中 \(\Delta\boldsymbol\phi_{\mathrm{task}}(\theta)\) 是小幅任务驱动细化项，而非重建整个流形的主模型。

对应目标函数可定义为：
$$
\mathcal J
=
\mathcal L_{\mathrm{cal}}
+
\lambda_1 \mathcal L_{\mathrm{single}}
+
\lambda_2 \mathcal L_{\mathrm{pair}}
+
\lambda_3 \mathcal L_{\mathrm{mid}}
+
\lambda_4 \mathcal L_{\mathrm{anchor}},
$$
其中锚定项为：
$$
\mathcal L_{\mathrm{anchor}}
=
\sum_{\theta\in\Theta_{\mathrm{val}}}
\left\|
\hat{\mathbf a}_{\mathrm{V3}}(\theta)
-
\hat{\mathbf a}_{\mathrm{ARD}}(\theta)
\right\|_2^2.
$$

该结构的优点是：

- 不再放弃 ARD 已经证明有效的强几何能力；
- 任务驱动项只做小范围受控修正；
- 比当前 Full V2 更不容易伤害全局泛化。

---

### 6.2 为什么这条路比“继续直接磨 V2”更合理

因为最新结果已经说明：

- **ARD 已经非常强；**
- **V2 的增益主要集中在少数 hard pair，而代价是大范围泛化恶化；**
- 因此下一步最自然的做法，不是“让 V2 更强”，而是“让任务驱动只在 ARD 主干附近做小修正”。

这条路线更符合结果，也更有希望形成真正有说服力的新算法故事。

---

## 7. 对 case 的后续调整建议

### 7.1 不需要继续整体增加难度

当前 Case 4 / 9 已经足够难，后续应保持稳定，不再频繁提升难度。

### 7.2 需要把 case 从“扩展”转为“筛选工具”

建议后续新算法开发时，先只用以下 4 个 case 快速筛选：

1. **Case 3**：全局与边缘未见误差
2. **Case 7**：高 SNR 单源偏差地板
3. **Case 9**：困难双源分辨
4. **Case 10**：随机 split 稳健性

如果新算法在这 4 个 case 上没有形成稳定改进，就没有必要先跑全套 10 个 case。

### 7.3 可适度加强 Case 9 的局部分析，而不是整体加难度

与其继续提升 Case 9 难度，不如增加：

- `V1 / ARD / 新 Proposed` 的 per-separation paired delta 图；
- representative hard pair 的失败类型统计；
- stable / marginal / biased / unresolved 的分解对比。

这样对算法方向判断更有帮助。

---

## 8. 是否应该现在转向 2D DOA

### 结论：暂不建议

2D DOA 可以作为后续扩展，但不建议现在转为主线，原因是：

1. 当前 1D benchmark 已足够成熟并且能明显区分方法；
2. ARD 已经在 1D 上强烈改变了项目判断，说明 1D 阶段还有很多信息没吃干净；
3. 2D DOA 会显著增加实验复杂度，容易稀释当前最关键的问题——**为什么 Proposed 在成熟 1D benchmark 上不如 ARD。**

因此，2D 应当是：

- 当 1D 上已经形成清晰新算法故事后，
- 用来放大优势与拓展应用范围的第二阶段工作，
- 而不是当前的主救火路线。

---

## 9. 最终建议

基于 `20260420-120416-71650f7` 这一批结果，我的最终建议是：

### 主线选择

**优先改进 Proposed 算法。**

### 不建议作为当前主线的方向

- 继续整体增加 case 难度：**不建议**
- 立即转向 2D DOA：**不建议**

### 推荐的下一步算法路线

**以 ARD 为强几何主干，发展一个受控的任务驱动细化型 Proposed V3。**

这是当前结果最自然、也最有希望的延伸方向。

---

## 10. 一句话结论

当前项目已经不再缺“更难的 case”，也不急缺“更复杂的维度”；当前最缺的是一个能够在 ARD 强基线上仍然提供额外任务收益、同时不破坏全局泛化的新 Proposed 算法。因此，下一阶段应当把主要精力集中到 **改进 Proposed 算法** 上，而不是继续通过加大 case 难度或转向 2D 来回避当前 1D 基准中已经暴露出的核心问题。
