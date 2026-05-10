# Proposed Algorithm Full V2（C 路线强化版）

## 题目

**基于任务驱动优化的稀疏角阵列流形校准与 DOA 性能恢复方法**

英文可表述为：

**Task-Driven Sparse-Angle Manifold Calibration with Piecewise Edge-Regularized Phase Modeling for DOA Recovery**

---

## 1. 文档定位

本文档给出在当前项目基础上沿 **C 路线大幅加强** 的正式改进方案。所谓 C 路线，是指：**不再满足于“让重构流形更像真值流形”，而是直接将单源峰定位与困难双源分辨目标嵌入校准算法本身的优化目标中。**

与当前已经实现的 V2-lite 相比，Full V2 的核心区别不在于分段数更多、阶数更高或正则更复杂，而在于：

1. **从几何误差驱动转向任务性能驱动；**
2. **从单一相位拟合转向“数据一致性 + 单源峰定位 + 近阈值双源分辨”的联合优化；**
3. **让最终得到的校准流形不仅在点对点意义上更接近真实流形，而且在 MUSIC 子空间与伪谱行为上更贴近最终任务需求。**

本文档采用正式化表述，作为后续 Full V2 算法设计、代码实现和实验修改的统一依据。

---

## 2. 改进动机

### 2.1 当前项目已验证的事实

现有项目已经较为明确地验证了以下结论：

1. **理想流形与真实流形之间存在结构性失配；**
2. **在高信噪比与高快拍条件下，该失配会形成明显的 DOA 偏差地板；**
3. **当前场景下失配主要表现为相位残差，而非幅度残差；**
4. **基于稀疏校准角的残差建模，能够显著修复理想流形的系统性误差。**

这些结论说明：从理想流形出发做少样本校准修正这一主方向是成立的。

### 2.2 当前 Proposed-v1 / V2-lite 的瓶颈

尽管 V1 与 V2-lite 均已证明相对 Ideal 有效，但现有结果同时表明：

1. **降低流形误差并不自动保证双源困难分辨提升；**
2. **V2-lite 在部分单源指标上优于 V1，但其改进幅度有限且不稳定；**
3. **在某些随机划分或困难 pair 场景下，较小的流形误差未必转化为更好的 DOA 结果。**

这说明当前瓶颈已经不再是“局部表达能力明显不足”，而更可能是：

> **当前优化目标与最终 DOA 任务之间仍存在错位。**

因此，下一阶段的改进重心应从“继续加强残差拟合能力”转向“让校准模型直接面向 DOA 任务进行学习”。

---

## 3. 基本问题建模

设阵列有 \(M\) 个阵元，候选角域网格为
\[
\Theta = \{\theta^{(1)},\theta^{(2)},\ldots,\theta^{(G)}\}.
\]

记：

- 理想流形为
\[
\mathbf a_I(\theta)\in\mathbb C^{M\times 1},
\]
- 真实流形为
\[
\mathbf a_H(\theta)\in\mathbb C^{M\times 1},
\]
- 稀疏校准角集合为
\[
\Omega_c = \{\vartheta_1,\vartheta_2,\ldots,\vartheta_L\}, \qquad L \ll G.
\]

目标是在仅有少量校准样本
\[
\{\mathbf a_H(\vartheta_\ell)
\}_{\ell=1}^{L}
\]
的条件下，构造校准后流形
\[
\hat{\mathbf a}(\theta;\boldsymbol\Xi),\qquad \theta\in\Theta,
\]
其中 \(\boldsymbol\Xi\) 表示待估参数，并使其在以下两类意义上同时成立：

1. 在校准角上与真实流形一致；
2. 在后续 DOA 任务中，特别是在高 SNR、高快拍与困难双源场景中，能够比当前 V1/V2-lite 更稳定地恢复谱峰与子空间结构。

---

## 4. Full V2 的总体结构

Full V2 由两部分组成：

### 4.1 结构主干（继承 V2-lite）

保留当前已验证有效的结构化先验：

- 相位主导残差建模；
- \(u=\sin\theta\) 域建模；
- 边缘感知分段局部模型；
- 软门控三段相位残差表达。

### 4.2 任务驱动强化（本轮新增核心）

在结构主干基础上，引入：

- 单源峰定位任务损失；
- 近阈值双源分辨任务损失；
- 子空间一致性约束；
- 中点抑制与困难区间旁瓣控制约束。

这样，校准模型的训练目标不再是单一的“残差拟合”，而是：

> **在满足校准角一致性的前提下，直接最小化 DOA 任务层面的错误倾向。**

---

## 5. 相位残差主干模型

### 5.1 相位残差定义

在统一的列归一化与参考阵元去公共相位处理后，定义第 \(m\) 个阵元在方向 \(\theta\) 处的相位残差：
\[
\phi_m(\theta)=\operatorname{unwrap}\Big(\angle a_{H,m}(\theta)-\angle a_{I,m}(\theta)\Big).
\]

令
\[
u = \sin\theta,
\]
并在 \(u\)-域上进行建模。

### 5.2 软门控分段模型

设共有 \(K\) 个局部段，当前建议取 \(K=3\)：

- 左边缘段
- 中心段
- 右边缘段

定义软门控函数：
\[
g_k(u)=
\frac{\exp\big(-\beta (u-\mu_k)^2\big)}{
\sum_{r=1}^{K}\exp\big(-\beta (u-\mu_r)^2\big)},
\qquad k=1,2,\ldots,K,
\]
其中：

- \(\mu_k\) 为第 \(k\) 个分段中心；
- \(\beta>0\) 控制分段过渡锐度。

对每个阵元 \(m\)，相位残差建模为：
\[
\hat\phi_m(u)=
\sum_{k=1}^{K} g_k(u)
\sum_{p=0}^{P}
 c_{m,k,p}
 T_p\big(\tilde u_k(u)\big),
\]
其中：

- \(T_p(\cdot)\) 为第 \(p\) 阶 Chebyshev 基函数；
- \(\tilde u_k(u)\) 为相对于第 \(k\) 段中心的归一化局部坐标；
- \(c_{m,k,p}\) 为待估系数。

这样可得到相位残差向量：
\[
\hat{\boldsymbol\phi}(u)=
\left[
\hat\phi_1(u),\hat\phi_2(u),\ldots,\hat\phi_M(u)
\right]^T.
\]

最终流形写为：
\[
\hat{\mathbf a}(\theta;\boldsymbol\Xi)=
\mathcal N\Big(
\mathbf a_I(\theta)
\odot
\exp\big(j\hat{\boldsymbol\phi}(\sin\theta)\big)
\Big),
\]
其中 \(\mathcal N(\cdot)\) 表示参考阵元去公共相位并单位范数归一化。

---

## 6. Full V2 的核心：任务驱动联合目标函数

设待估参数全集为
\[
\boldsymbol\Xi=
\{c_{m,k,p}\}_{m,k,p}
\cup
\{\mu_k\}_{k=1}^{K}
\cup
\{\beta\}.
\]

Full V2 的总目标函数定义为：
\[
\mathcal J(\boldsymbol\Xi)=
\lambda_{\mathrm{cal}}\mathcal L_{\mathrm{cal}}+
\lambda_{\mathrm{sm}}\mathcal L_{\mathrm{smooth}}+
\lambda_{\mathrm{gate}}\mathcal L_{\mathrm{gate}}+
\lambda_{\mathrm{ss}}\mathcal L_{\mathrm{single}}+
\lambda_{\mathrm{pair}}\mathcal L_{\mathrm{pair}}+
\lambda_{\mathrm{mid}}\mathcal L_{\mathrm{mid}}+
\lambda_{\mathrm{reg}}\mathcal L_{\mathrm{reg}}.
\]

下面逐项定义。

---

## 6.1 校准一致性项

由于相位展开在边界附近可能不稳定，Full V2 不再仅在实数相位域中拟合，而直接在复流形域约束校准一致性：
\[
\mathcal L_{\mathrm{cal}}=
\sum_{\ell=1}^{L}
\omega_\ell
\left
\|
\mathbf a_H(\vartheta_\ell)-
\hat{\mathbf a}(\vartheta_\ell;\boldsymbol\Xi)
\right\|_2^2.
\]

其中校准权重为：
\[
\omega_\ell=
1+
\alpha_1\rho(\vartheta_\ell)+
\alpha_2\frac{|\sin\vartheta_\ell|}{\max_{\ell} |\sin\vartheta_\ell|},
\]
而
\[
\rho(\vartheta_\ell)=
\frac{\|\mathbf a_H(\vartheta_\ell)-\mathbf a_I(\vartheta_\ell)\|_2}{\|\mathbf a_H(\vartheta_\ell)\|_2}
\]
表示失配强度。

该项保证：

- 高失配校准角更受关注；
- 边缘角更受关注；
- 目标直接作用于复流形，而非仅作用于相位标量。

---

## 6.2 平滑与门控正则项

### 平滑项

对系数施加二阶差分平滑：
\[
\mathcal L_{\mathrm{smooth}}=
\sum_{m=1}^{M}\sum_{k=1}^{K}
\|\mathbf D \mathbf c_{m,k}\|_2^2,
\]
其中 \(\mathbf D\) 为二阶差分矩阵。

### 门控正则项

防止软门控过窄或中心塌缩，定义：
\[
\mathcal L_{\mathrm{gate}}=
\sum_{k=1}^{K}(\mu_k-\mu_k^{(0)})^2+
\eta_\beta(\beta-\beta_0)^2,
\]
其中 \(\mu_k^{(0)}\) 和 \(\beta_0\) 为初始化中心与宽度。

该项保证 V2 不会因为局部过拟合而退化成极窄的分段插值器。

---

## 6.3 单源任务损失

### 6.3.1 单源任务构造

对每个校准角 \(\vartheta_\ell\)，构造单源协方差：
\[
\mathbf R_{\ell}=
\mathbf a_H(\vartheta_\ell)
\mathbf a_H^H(\vartheta_\ell)+
\sigma^2\mathbf I.
\]

记其噪声子空间为 \(\mathbf U_{n,\ell}\)。

### 6.3.2 子空间一致性损失

对真实目标角，希望校准流形在噪声子空间上的投影尽量小，因此定义：
\[
\mathcal L_{\mathrm{single-sub}}=
\sum_{\ell=1}^{L}
\left
\|
\mathbf U_{n,\ell}^H
\hat{\mathbf a}(\vartheta_\ell;\boldsymbol\Xi)
\right\|_2^2.
\]

### 6.3.3 伪谱峰值定位损失

定义基于估计流形的 MUSIC 伪谱：
\[
P_{\ell}(\theta;\boldsymbol\Xi)=
\frac{1}{
\hat{\mathbf a}^H(\theta;\boldsymbol\Xi)
\mathbf U_{n,\ell}\mathbf U_{n,\ell}^H
\hat{\mathbf a}(\theta;\boldsymbol\Xi)+\varepsilon
}.
\]

令 softmax 归一化谱为：
\[
S_{\ell}(\theta;\boldsymbol\Xi)=
\frac{
\exp\big(\gamma P_{\ell}(\theta;\boldsymbol\Xi)\big)
}{
\sum_{\theta'\in\Theta_{\mathrm{eval}}}
\exp\big(\gamma P_{\ell}(\theta';\boldsymbol\Xi)\big)
}.
\]

则单源峰值定位损失定义为：
\[
\mathcal L_{\mathrm{single-peak}}=
-
\sum_{\ell=1}^{L}
\log S_{\ell}(\vartheta_\ell;\boldsymbol\Xi).
\]

### 6.3.4 单源任务总损失

因此：
\[
\mathcal L_{\mathrm{single}}=
\mathcal L_{\mathrm{single-sub}}+
\eta_{\mathrm{peak}}\mathcal L_{\mathrm{single-peak}}.
\]

该项的物理意义是：

- 保证真实角对应 steering vector 更贴近信号子空间；
- 保证伪谱主峰更容易落在真实角附近；
- 从而直接针对高 SNR 偏差地板施加约束。

---

## 6.4 近阈值双源任务损失

这是 Full V2 与 V2-lite 最关键的区别。

### 6.4.1 困难双源任务集构造

从稀疏校准角集合 \(\Omega_c\) 或其公共评估扩展集 \(\Omega_h\) 中，构造近阈值双源对：
\[
\mathcal P_{\mathrm{hard}}=
\{(\theta_i,\theta_j): \Delta_{\min}\le |\theta_i-\theta_j|\le \Delta_{\max}\}.
\]

优先选取：

- 边缘区；
- 高失配区；
- Case 9 中已知困难的 separation 区间。

### 6.4.2 双源协方差构造

对每个 pair \((\theta_i,\theta_j)\)，构造：
\[
\mathbf R_{ij}=
\mathbf a_H(\theta_i)\mathbf a_H^H(\theta_i)+
\mathbf a_H(\theta_j)\mathbf a_H^H(\theta_j)+
\sigma^2\mathbf I.
\]

对应噪声子空间记为 \(\mathbf U_{n,ij}\)。

### 6.4.3 双源子空间一致性项

要求两个真实 steering vector 都落在信号子空间内：
\[
\mathcal L_{\mathrm{pair-sub}}=
\sum_{(i,j)\in\mathcal P_{\mathrm{hard}}}
\left(
\left
\|
\mathbf U_{n,ij}^H\hat{\mathbf a}(\theta_i;\boldsymbol\Xi)
\right\|_2^2+
\left
\|
\mathbf U_{n,ij}^H\hat{\mathbf a}(\theta_j;\boldsymbol\Xi)
\right\|_2^2
\right).
\]

### 6.4.4 双峰目标增强项

定义双源伪谱：
\[
P_{ij}(\theta;\boldsymbol\Xi)=
\frac{1}{
\hat{\mathbf a}^H(\theta;\boldsymbol\Xi)
\mathbf U_{n,ij}\mathbf U_{n,ij}^H
\hat{\mathbf a}(\theta;\boldsymbol\Xi)+\varepsilon
}.
\]

再定义对应的 softmax 谱：
\[
S_{ij}(\theta;\boldsymbol\Xi)=
\frac{
\exp\big(\gamma P_{ij}(\theta;\boldsymbol\Xi)\big)
}{
\sum_{\theta'\in\Theta_{\mathrm{eval}}}
\exp\big(\gamma P_{ij}(\theta';\boldsymbol\Xi)\big)
}.
\]

双峰目标增强项定义为：
\[
\mathcal L_{\mathrm{pair-peak}}=
-
\sum_{(i,j)\in\mathcal P_{\mathrm{hard}}}
\left[
\log S_{ij}(\theta_i;\boldsymbol\Xi)+
\log S_{ij}(\theta_j;\boldsymbol\Xi)
\right].
\]

### 6.4.5 中点抑制项

设中点为
\[
\theta_{m,ij}=\frac{\theta_i+\theta_j}{2}.
\]

为了抑制双峰合并成单峰，在中点加入惩罚：
\[
\mathcal L_{\mathrm{mid}}=
\sum_{(i,j)\in\mathcal P_{\mathrm{hard}}}
P_{ij}(\theta_{m,ij};\boldsymbol\Xi).
\]

其物理意义是：若中点伪谱过高，则代表双峰倾向合并，不利于近阈值分辨。

### 6.4.6 双源任务总损失

因此：
\[
\mathcal L_{\mathrm{pair}}=
\mathcal L_{\mathrm{pair-sub}}+
\eta_{\mathrm{pair}}\mathcal L_{\mathrm{pair-peak}}.
\]

而中点抑制项单独保留在总目标函数中，以便单独调节其强度。

---

## 6.5 正则项

为避免参数规模膨胀或任务项过拟合，还需加入整体正则：
\[
\mathcal L_{\mathrm{reg}}=
\sum_{m,k,p} c_{m,k,p}^2.
\]

---

## 7. 求解策略

由于 Full V2 的目标函数已非凸，因此采用两阶段求解。

## 7.1 阶段一：结构初始化

首先忽略任务项，仅优化：
\[
\min_{\boldsymbol\Xi}
\lambda_{\mathrm{cal}}\mathcal L_{\mathrm{cal}}+
\lambda_{\mathrm{sm}}\mathcal L_{\mathrm{smooth}}+
\lambda_{\mathrm{gate}}\mathcal L_{\mathrm{gate}}+
\lambda_{\mathrm{reg}}\mathcal L_{\mathrm{reg}}.
\]

该阶段可通过加权最小二乘与小规模非线性参数搜索完成，用于获得稳定初值 \(\boldsymbol\Xi^{(0)}\)。

## 7.2 阶段二：任务驱动细化

在 \(\boldsymbol\Xi^{(0)}\) 基础上，优化完整目标函数：
\[
\min_{\boldsymbol\Xi} \mathcal J(\boldsymbol\Xi).
\]

建议采用：

- L-BFGS
- Adam
- 或 Levenberg–Marquardt / Gauss–Newton 混合更新

进行少量迭代细化。

为了控制训练不稳定性，建议：

1. 先只启用 \(\mathcal L_{\mathrm{single}}\)，确认高 SNR 偏差地板确实进一步下降；
2. 再逐步加入 \(\mathcal L_{\mathrm{pair}}\) 和 \(\mathcal L_{\mathrm{mid}}\)；
3. 最后再调大 \(\lambda_{\mathrm{pair}}\) 与 \(\lambda_{\mathrm{mid}}\)。

---

## 8. Full V2 的伪代码

```text
Input:
    Ideal manifold dictionary A_I(Theta)
    Sparse calibration truth columns {a_H(vartheta_l)}
    Calibration angles Omega_c
    Hard pair set P_hard
    Hyperparameters lambda_*

Output:
    Corrected manifold dictionary A_hat(Theta)

Step 1. Preprocess
    normalize all steering vectors
    remove common phase by reference element
    compute mismatch scores rho(vartheta_l)

Step 2. Initialize piecewise phase model
    set gate centers {mu_k}, gate sharpness beta
    fit piecewise residual coefficients by weighted calibration loss
    obtain Xi^(0)

Step 3. Build single-source task set
    for each calibration angle vartheta_l:
        construct R_l = a_H(vartheta_l)a_H^H(vartheta_l) + sigma^2 I
        compute noise subspace U_n,l

Step 4. Build hard pair task set
    choose near-threshold pairs (theta_i, theta_j)
    construct R_ij and U_n,ij for each pair

Step 5. Task-driven refinement
    optimize J(Xi) = calibration + smooth + gate + single + pair + midpoint + regularization
    initialize from Xi^(0)

Step 6. Synthesize corrected manifold
    for each theta in Theta:
        evaluate a_hat(theta; Xi)
        normalize column

Return A_hat(Theta)
```

---

## 9. 对现有 case 的修改建议

Full V2 若要被准确评估，现有 case 不能完全照搬，至少需做如下正式调整。

## 9.1 Case 3：增加“边缘区与困难区”指标

当前 Case 3 仅报告全局 mean unseen relative error，不足以突出 C 路线的价值。建议新增：

1. **Edge-band unseen error**：仅在边缘区统计误差；
2. **Worst-10% unseen error**：统计最难 10% 角度的平均误差；
3. **Per-angle bias map**：观察 V2 是否主要改善了高失配角。

原因是：Full V2 的意义不只是降低全局均值，而是要改善“任务真正困难的那部分角度”。

---

## 9.2 Case 6：改为 V2 超参数敏感性，而不再只扫 V1 风格参数

Case 6 目前更适合 V1。对于 Full V2，建议改扫：

- 门控中心 \(\mu_k\)
- 门控锐度 \(\beta\)
- 单源任务权重 \(\lambda_{\mathrm{ss}}\)
- 双源任务权重 \(\lambda_{\mathrm{pair}}\)
- 中点抑制权重 \(\lambda_{\mathrm{mid}}\)
- 困难 pair 数量与 separation 范围

否则 Case 6 无法真正回答“任务驱动 V2 的收益来自哪里”。

---

## 9.3 Case 7 / Case 8：保留，但明确加入任务导向结论

Case 7 / 8 目前已经较成熟，建议保留，但要增加两类解读：

1. **V2 是否进一步压低高 SNR / 高快拍区的 bias floor；**
2. **V2 的提升是否主要发生在 edge/high-mismatch 角。**

因此建议在图后追加：

- edge-only bias curve
- top-k hard-angle P90 error

---

## 9.4 Case 9：必须拆分为“参数选择对”与“正式评估对”

这是 Full V2 最关键的 case 修改。

当前若直接用 Case 9 全部 hard pairs 同时参与任务优化与结果评估，容易形成泄漏。因此建议：

### Phase A: task-selection pairs

用于：
- 选择 \(\lambda_{\mathrm{pair}}\)、\(\lambda_{\mathrm{mid}}\)
- 调整 hard-pair 覆盖范围

### Phase B: held-out hard pairs

用于：
- 正式报告 resolution / stable / biased / marginal / unresolved
- 避免“在训练对上看起来更强”的偏差

即：Case 9 要从一个“纯评估 case”升级成“task-aware V2 的验证主战场”。

---

## 9.5 Case 10：必须保留

Case 10 在 Full V2 中反而更关键。原因是：

- 若 V2 只是对固定 calibration split 有效，则意义有限；
- 若 V2 在随机 split 下仍能保持或提升 DOA 指标，则说明任务驱动改造是稳健的。

因此，Case 10 应成为 Full V2 的必须保留 case，而不是附属 case。

---

## 10. Full V2 的实验验证重点

建议 Full V2 的成败首先看以下四个 case：

1. **Case 3**：边缘区与困难区未见误差是否真正下降；
2. **Case 7**：高 SNR 下 bias floor 是否继续下降；
3. **Case 9**：困难双源 stable rate / unresolved rate 是否有稳定改善；
4. **Case 10**：随机 split 下 DOA 表现是否比 V2-lite 更稳。

若这四个 case 都不能形成清晰改进，则说明 Full V2 的任务项设计还不够准确，不宜直接推广到全部实验章节。

---

## 11. 与现阶段项目的关系

### 11.1 当前项目阶段定位

当前项目已经完成：

- 问题成立性验证；
- phase-dominant 现象验证；
- V1 有效性验证；
- V2-lite 可行性验证。

因此，现在推进 Full V2 是合理的，但必须建立在：

- benchmark 不再频繁大改；
- 任务目标设计可被追踪和消融；
- case 修改只服务于 V2 评估，而不是重新定义问题。

### 11.2 当前最不建议的做法

不建议继续：

- 仅靠调高分段阶数；
- 仅靠继续换分段位置；
- 仅靠更多 case 抛光；
- 在没有任务项的情况下继续细磨 V2-lite。

这些做法可能带来边际改进，但不太可能解决当前“流形误差改善不能稳定转化为 DOA 收益”的核心矛盾。

---

## 12. 预期创新点

若 Full V2 最终有效，则论文可形成如下正式创新表述：

1. 提出一种**任务驱动的稀疏角流形校准框架**，在少量校准样本条件下同时优化流形一致性与 DOA 任务表现；
2. 提出一种**基于边缘感知软分段相位残差建模**的结构先验，用于增强困难角域的流形表达能力；
3. 提出一种**近阈值双源分辨任务正则化机制**，使流形校准过程能够直接针对难分离谱峰进行优化；
4. 在统一的 HFSS truth benchmark 下验证：该方法在高 SNR、高 snapshots 以及困难双源分辨场景中，相较 V1/V2-lite 具有更稳定的 DOA 任务收益。

---

## 13. 结论

Full V2 的关键不是再做一个更复杂的“残差拟合器”，而是把流形校准问题从

> “如何拟合真实流形”

转成

> “如何通过有限校准样本，构造一个更适合 DOA 任务的流形模型”。

这一路线比当前 V1/V2-lite 更激进，但也更符合现阶段项目已经暴露出的主要矛盾。若要继续推进 Proposed 算法而不是继续反复磨 case，则 Full V2 的 C 路线强化应当成为下一阶段的主要工作方向。
