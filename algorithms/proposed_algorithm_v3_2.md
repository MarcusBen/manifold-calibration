# Proposed Algorithm V3.2

## Title

**AATRC-V3.2: ARD-Anchored Distribution-Matched Stable-Pair Residual Calibration**

中文名称可表述为：

**基于 ARD 主干锚定与分布匹配稳定双峰任务的残差流形校准算法**

---

## 1. Design target

V3.2 的目标不是继续加强全局几何拟合，而是**在保持 V3-Revised 几何安全性的前提下，定向提升 Case 9 的近阈值双源分辨表现**。

根据最新 screening 结果，V3-Revised 已经基本解决了：

- ARD 校准角精确穿越被破坏的问题；
- Case 3 全局/边缘未见几何崩坏的问题；
- Case 10 随机 split 几何与单源 DOA 退化的问题；
- Case 7 高 SNR 单源偏差没有收益的问题。

当前剩余瓶颈非常明确：

> **Case 9 mean resolution 略高于 ARD，但 stable rate 仍低于 ARD / Proposed V1，说明当前 pair surrogate 还没有真正对齐 benchmark 的“稳定双峰”判据。**

因此，V3.2 的核心任务是：

1. **保持 V3-Revised 的 calibration guard / manifold guard / strong anchor 不变；**
2. **把 pair task 从“泛化的双峰增强”改成“和 Case 9 stable-rate 更一致的分布匹配稳定双峰任务”；**
3. **让优化真正面向 `stable` 而不是只面向 `mean resolution`。**

一句话概括：

**V3.2 = V3-Revised safety guards + Case 9-oriented distribution-matched stable-pair objective.**

---

## 2. What remains unchanged from V3-Revised

V3.2 **不改动** 以下部分：

1. **ARD coarse manifold 作为几何主干；**
2. **calibration-null gate；**
3. **trust-radius bounded residual；**
4. **strong ARD anchor；**
5. **held-out manifold guard；**
6. **guard-based fallback；**
7. **Case 3 / 7 / 10 screening guard lines。**

也就是说，V3.2 不是重写 V3-Revised，而是只替换/增强与 Case 9 直接相关的 pair task 设计。

---

## 3. Model backbone

V3.2 仍采用：
\[
\hat{\mathbf a}_{V3.2}(\theta)
=
\operatorname{norm}
\left[
\hat{\mathbf a}_{ARD}(\theta)
\odot
\exp\big(j\Delta\boldsymbol\phi_{safe}(\theta)\big)
\right].
\]

其中：

- \(\hat{\mathbf a}_{ARD}(\theta)\) 为 ARD Method 2 输出；
- \(\Delta\boldsymbol\phi_{safe}(\theta)\) 为带 calibration-null、edge-mask 和 trust-radius 的安全残差；
- `norm` 与项目现有列归一化规则保持一致。

因此，V3.2 的改进不来自更复杂的全局模型，而来自**任务损失的重新设计**。

---

## 4. Why the current pair task is not enough

旧 V3/V3-Revised 的 pair task 主要包含：

- pair subspace loss；
- pair peak loss；
- midpoint suppression。

这类损失能够鼓励：

- 两个真实角位置有较高伪谱；
- 中点不形成太高假峰；
- 真实 steering vector 接近信号子空间。

但最新结果说明，这还不足以直接转化为 benchmark 里的：

- `stable rate`
- `resolved / marginal / biased / unresolved` 状态分解

也就是说，旧 pair surrogate 更像在优化：

> “有没有双峰趋势”

而不是：

> “这两个峰是否足够稳定、对称、分离，并且比 midpoint 与背景峰更可信。”

因此，V3.2 必须让 pair objective 更贴近 Case 9 的最终评估定义。

---

## 5. Distribution-matched pair task construction

## 5.1 Pair strata

设正式 Case 9 评估 pair 集合为
\[
\mathcal P_{eval}.
\]

对每个 pair \((\theta_1,\theta_2)\)，定义两个属性：

1. **separation bin**
\[
\Delta = |\theta_2-\theta_1|,
\qquad
\Delta\in\{4^\circ,5^\circ,6^\circ,8^\circ,10^\circ\}
\]
2. **center bin**
\[
\theta_c = \frac{\theta_1+\theta_2}{2}
\]

将所有 pair 按 \((\Delta, \theta_c)\) 分层，得到若干 stratum：
\[
\mathcal P_{eval}^{(b)} ,
\qquad b=1,2,\ldots,B.
\]

---

## 5.2 Distribution matching

V3.2 的 task pair 集合 \(\mathcal P_{task}\) 不再只按 hard score 选取，而应满足：

\[
\pi_{task}(b) \approx \pi_{eval}(b),
\qquad
\pi_{eval}(b)=\frac{|\mathcal P_{eval}^{(b)}|}{|\mathcal P_{eval}|}.
\]

> Codex note: 实现时我没有直接用“最终排除 task pair 之后的 eval set”来反推 task 分布，因为那会形成先选 task、再定义 eval、再回头匹配 task 的循环依赖。代码里用 Case 9 候选 pair 的 stratum 分布作为目标分布，再在 Case 9 正式评估阶段排除 V2/V3 task pairs，保持 `taskEvalOverlapCount = 0`。

> Codex note: 第一版分布匹配如果在 task pair 很少时直接按 stratum tie-break，会优先选到最外侧中心 bin，触发 held-out manifold guard fallback。当前实现先按 separation 分配名额，再在每个 separation 内做 center coverage，并避开最外侧 center bin；这样仍覆盖 Case 9 的 separation 分布，但不把 residual 训练集中压到 ±60° 边界。

也就是说，task pairs 的 separation 分布和 center 分布要尽量贴近正式评估对，而不是过度集中在最边缘位置。

实践上可采用：

1. 先从每个 stratum 中按 hard score 排序；
2. 再按 \(\pi_{eval}(b)\) 比例从各 stratum 抽取 task pairs；
3. 保证 `taskEvalOverlapCount = 0`。

这会让训练任务的分布更像真正的 Case 9 评估场景，从而提高 surrogate 与 benchmark 的一致性。

---

## 6. Stable-pair objective

这是 V3.2 的核心新增部分。

---

## 6.1 Pair covariance and scan score

对每个 task pair \((\theta_1,\theta_2)\in\mathcal P_{task}\)，用 HFSS truth 构造双源协方差：
\[
\mathbf R_p
=
\mathbf A_H(\theta_1,\theta_2)
\mathbf A_H^H(\theta_1,\theta_2)
+
\sigma^2 \mathbf I,
\]
其中
\[
\mathbf A_H(\theta_1,\theta_2)
=
[\mathbf a_H(\theta_1),\mathbf a_H(\theta_2)].
\]

对应噪声投影矩阵记为 \(\mathbf P_N^{(p)}\)。

定义与 MUSIC 一致的 log-spectrum surrogate：
\[
q_p(\theta)
=
-
\log\Big(
\hat{\mathbf a}_{V3.2}^H(\theta)
\mathbf P_N^{(p)}
\hat{\mathbf a}_{V3.2}(\theta)
+
\varepsilon
\Big).
\]

---

## 6.2 Local neighborhood scores

令：

- \(\mathcal N_1\)：\(\theta_1\) 邻域；
- \(\mathcal N_2\)：\(\theta_2\) 邻域；
- \(\mathcal N_m\)：中点 \(\theta_m=(\theta_1+\theta_2)/2\) 邻域；
- \(\mathcal N_b\)：背景候选邻域（除两目标邻域和中点邻域外的局部峰区）。

定义局部聚合分数：
\[
s_1 = \log\sum_{\theta\in\mathcal N_1} e^{\gamma q_p(\theta)},
\qquad
s_2 = \log\sum_{\theta\in\mathcal N_2} e^{\gamma q_p(\theta)},
\]
\[
s_m = \log\sum_{\theta\in\mathcal N_m} e^{\gamma q_p(\theta)},
\qquad
s_b = \log\sum_{\theta\in\mathcal N_b} e^{\gamma q_p(\theta)}.
\]

> Codex note: 实现时我把这里的局部聚合从 `logsumexp` 改成了 `logmeanexp`。原因是 background neighborhood 通常比 endpoint / midpoint neighborhood 更大，如果直接用 `logsumexp`，背景项会因为候选点数量多而被系统性抬高，优化会偏向压制背景数量而不是压制真实背景峰强度。

这里不直接用单点 \(q_p(\theta_1),q_p(\theta_2)\)，而是用 neighborhood 聚合，是为了更贴近 benchmark 对“稳定双峰”的判别，而不是偶然落在单点上的尖峰。

---

## 6.3 Stable-pair loss decomposition

### (1) Endpoint strength term

要求两个真实端点邻域都形成足够强的局部峰：
\[
\mathcal L_{end}
=
\operatorname{softplus}(\tau_e-s_1)
+
\operatorname{softplus}(\tau_e-s_2).
\]

### (2) Midpoint suppression term

要求中点邻域显著低于两个目标端点：
\[
\mathcal L_{mid}^{stable}
=
\operatorname{softplus}
\Big(
s_m - \min(s_1,s_2) + m_m
\Big).
\]

### (3) Background suppression term

要求非目标背景峰不高于两端主峰：
\[
\mathcal L_{bg}
=
\operatorname{softplus}
\Big(
s_b - \min(s_1,s_2) + m_b
\Big).
\]

### (4) Peak balance term

要求两端主峰强度不要严重失衡，否则更容易被 benchmark 归类为 biased / marginal：
\[
\mathcal L_{bal}
=
\operatorname{softplus}
\Big(
|s_1-s_2|-m_{bal}
\Big).
\]

### (5) Subspace consistency term

保留旧 pair subspace consistency：
\[
\mathcal L_{sub}
=
\sum_{r=1}^{2}
\hat{\mathbf a}_{V3.2}^H(\theta_r)
\mathbf P_N^{(p)}
\hat{\mathbf a}_{V3.2}(\theta_r).
\]

---

## 6.4 Stable-pair total loss

于是对单个 pair：
\[
\mathcal L_{pair}^{stable}(p)
=
\eta_{sub}\mathcal L_{sub}
+
\eta_{end}\mathcal L_{end}
+
\eta_{mid}\mathcal L_{mid}^{stable}
+
\eta_{bg}\mathcal L_{bg}
+
\eta_{bal}\mathcal L_{bal}.
\]

对全部 task pairs：
\[
\mathcal L_{pair}^{V3.2}
=
\sum_{p\in\mathcal P_{task}}
\omega_p^{dist}
\mathcal L_{pair}^{stable}(p),
\]
其中 \(\omega_p^{dist}\) 为 distribution-matching 权重，例如：
\[
\omega_p^{dist}
=
\frac{\pi_{eval}(b(p))}{\pi_{task}(b(p))+
\nu},
\]
其中 \(b(p)\) 表示 pair 所在 stratum，\(\nu\) 是防止分母为零的小常数。

这样可以避免 task objective 被某一类过度采样的 pair 主导。

---

## 7. Full objective of V3.2

V3.2 总目标函数定义为：
\[
\mathcal J_{V3.2}
=
\lambda_{single}\mathcal L_{single}
+
\lambda_{pair}\mathcal L_{pair}^{V3.2}
+
\lambda_{anchor}\mathcal L_{anchor}
+
\lambda_{guard}\mathcal L_{guard}
+
\lambda_{cal0}\mathcal L_{cal0}
+
\lambda_{smooth}\mathcal L_{smooth}
+
\lambda_{reg}\mathcal L_{reg}.
\]

与旧 V3-Revised 相比，最核心的替换是：

- 旧的 `pair peak + midpoint` 组合
- 改成以 **stable-pair neighborhood objective** 为中心的 pair loss

从而让优化目标更直接贴近 benchmark 的 stable / unresolved 判据。

---

## 8. Suggested hyperparameters

初始建议值如下：

| 参数 | 建议值 |
|---|---:|
| \(\lambda_{single}\) | 0.04 |
| \(\lambda_{pair}\) | 0.05 |
| \(\lambda_{anchor}\) | 50 |
| \(\lambda_{guard}\) | 10 |
| \(\lambda_{cal0}\) | 20 |
| \(\lambda_{smooth}\) | \(10^{-3}\) |
| \(\lambda_{reg}\) | \(10^{-4}\) |
| \(\eta_{sub}\) | 1 |
| \(\eta_{end}\) | 1 |
| \(\eta_{mid}\) | 1 |
| \(\eta_{bg}\) | 0.5 |
| \(\eta_{bal}\) | 0.5 |
| \(\tau_e\) | 目标峰强阈值 |
| \(m_m\) | 0.10 ~ 0.20 |
| \(m_b\) | 0.10 |
| \(m_{bal}\) | 0.15 |
| SPSA iterations | 8 ~ 12 |
| learning rate | 0.003 ~ 0.005 |
| perturbation scale | 0.003 ~ 0.005 |

总体原则：

- **比旧 V3-Revised 更强的 pair objective**
- **不降低几何护栏强度**
- **仍然采用小步长、少迭代的保守优化**

---

## 9. Screening protocol for V3.2

V3.2 仍然只跑 screening：
\[
\texttt{run\_project([3\ 7\ 9\ 10], cfg)}
\]

通过条件建议改为：

### Guard conditions

1. **Case 3, L=9**
\[
\text{mean unseen error}_{V3.2}
\le
\text{ARD}+0.003
\]

2. **Case 10 manifold**
\[
\text{mean manifold error}_{V3.2}
\le
\text{ARD}+0.01
\]

3. **Case 10 DOA RMSE**
\[
\text{mean DOA RMSE}_{V3.2}
\le
\text{ARD}+0.01
\text{ deg}
\]

### Case 9 pass conditions

4. **mean resolution**
\[
\text{Case 9 mean resolution}_{V3.2}
\ge
\max(\text{ARD},\text{V1})
\]

5. **mean stable rate**
\[
\text{Case 9 mean stable rate}_{V3.2}
\ge
\max(\text{ARD},\text{V1})-0.001
\]

6. **per-separation safety**
对于每个 \(\Delta\in\{4,5,6,8,10\}\)：
\[
\text{resolution}_{V3.2}(\Delta)
\ge
\text{ARD}(\Delta)-0.005.
\]

也就是说，V3.2 不仅要提高整体均值，还不能在某些关键 separation 上显著退化。

只有全部满足时，才继续跑 full `1:10`。

---

## 10. Case updates required

## 10.1 Case 9

Case 9 需要新增以下输出：

1. `taskStratumHist`：task pair 的 stratum 统计；
2. `evalStratumHist`：evaluation pair 的 stratum 统计；
3. `pairDeltaResolution`：`V3.2 - ARD` 的 per-separation resolution 差值；
4. `pairDeltaStable`：`V3.2 - ARD` 的 per-separation stable rate 差值；
5. representative pair 的 `s1, s2, sm, sb` 诊断量。

这些输出是判断 V3.2 是否真的改善 stable-pair behavior 的关键。

## 10.2 Case 3 / 10

不需要改难度，只需要继续保留：

- global error
- edge error
- worst-10%
- random split manifold error
- random split DOA RMSE

它们仍然是 V3.2 的核心 guard。

## 10.3 Case 7

保留现有 edge/high-mismatch 子集指标即可，因为 V3.2 的重点不是单源，而是 Case 9；Case 7 主要作为“不要把 ARD 的单源优势弄丢”的安全检查。

---

## 11. Final positioning

V3.2 的定位非常明确：

- **不是新的全局几何模型；**
- **不是更激进的 task refinement；**
- **而是在 V3-Revised 几何安全基础上，定向提升 Case 9 稳定双峰行为的版本。**

因此，V3.2 的预期成功标准不是“全面超过 ARD”，而是：

1. 保持接近 ARD 的几何能力；
2. 不破坏 Case 10 随机泛化；
3. 在 Case 9 上首次把 `mean resolution` 和 `stable rate` 同时拉到 `max(ARD, V1)` 附近或之上。

---

## 12. One-sentence conclusion

V3-Revised 已经把安全性修好了，V3.2 的任务就是把 Case 9 的优化目标从“泛化的双峰增强”改成“与 benchmark stable-rate 更一致的分布匹配稳定双峰任务”，从而在不破坏 ARD 主干的前提下，真正拿到近阈值双源分辨的可验证收益。
