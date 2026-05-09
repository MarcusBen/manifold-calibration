# Proposed Algorithm V3

## Title

**AATRC: ARD-Anchored Task-Aware Residual Calibration**

中文名称可写为：

**基于 ARD 主干锚定的任务感知残差流形校准算法**

---

## 1. Design goal

Proposed V3 的目标不是继续沿着 V1/V2 的 phase-only 低阶残差路线硬调参数，而是承认当前项目里最强的几何主干已经变成 **ARD Method 2**。

因此 V3 的设计原则是：

1. 先用 ARD 给出一个很强的粗模型；
2. 不重新拟合完整流形；
3. 只在 ARD 附近叠加一个小幅任务驱动相位 residual；
4. 用强 anchor 限制 residual，避免为了局部 DOA task 破坏全局流形；
5. 先通过 Case 3 / 7 / 9 / 10 screening，再决定是否值得 full paper-profile run。

一句话概括：

**V3 = ARD coarse manifold + anchored task-aware phase residual refinement.**

---

## 2. Relationship to existing methods

### 2.1 V1

V1 的核心形式是：

\[
\hat{\mathbf a}_{V1}(\theta)
=
\mathbf a_I(\theta)\odot \exp(j\hat{\boldsymbol\phi}_{V1}(\theta))
\]

其中 \(\hat{\boldsymbol\phi}_{V1}\) 是基于稀疏校准角拟合出的全局 phase residual。

V1 的优势是结构简单，能证明“理想流形和 HFSS truth 的失配可以被校正”。
V1 的问题是对边缘区、高失配区和双源 near-threshold resolution 不够稳定。

---

### 2.2 V2

V2 从理想流形出发，引入：

- 三段 soft-gated piecewise phase model；
- held-out HFSS single-source task；
- held-out HFSS pair task；
- midpoint suppression；
- deterministic SPSA + Adam-moment refinement。

形式上仍然接近：

\[
\hat{\mathbf a}_{V2}(\theta)
=
\mathbf a_I(\theta)\odot \exp(j\hat{\boldsymbol\phi}_{V2}(\theta))
\]

V2 的问题是：task objective 虽然下降，但容易把全局流形泛化拉坏，尤其在 Case 3 / Case 10 中明显退化。

---

### 2.3 ARD Method 2

ARD Method 2 先计算 complex correction vector：

\[
\mathbf g(\theta_l)
=
\mathbf a_H(\theta_l)\oslash \mathbf a_I(\theta_l)
\]

在 \(u=\sin\theta\) 域对 \(\mathbf g\) 插值，得到 \(\hat{\mathbf g}(\theta)\)，再重构：

\[
\hat{\mathbf a}_{ARD}(\theta)
=
\mathbf a_I(\theta)\odot \hat{\mathbf g}(\theta)
\]

当前项目里 ARD 是一个很强 baseline。它同时修正幅度和相位，不再只是 phase-only residual。

V3 选择以 ARD 为主干，而不是绕开 ARD。

---

## 3. Core V3 model

V3 的输出定义为：

\[
\hat{\mathbf a}_{V3}(\theta)
=
\operatorname{norm}
\left[
\hat{\mathbf a}_{ARD}(\theta)
\odot
\exp\left(j\Delta\boldsymbol\phi_{task}(\theta)\right)
\right]
\]

其中：

- \(\hat{\mathbf a}_{ARD}(\theta)\)：ARD Method 2 重构的 coarse manifold；
- \(\Delta\boldsymbol\phi_{task}(\theta)\)：V3 额外学习的小幅 phase residual；
- \(\operatorname{norm}[\cdot]\)：项目统一的列归一化，包括参考阵元相位对齐和 \(L_2\) 归一化。

V3 初始化为：

\[
\Delta\boldsymbol\phi_{task}(\theta)=\mathbf 0
\]

因此初始状态严格满足：

\[
\hat{\mathbf a}_{V3}^{(0)}(\theta)=\hat{\mathbf a}_{ARD}(\theta)
\]

这点很重要：V3 的优化不应该先破坏 ARD，而应该只在 ARD 附近寻找任务收益。

---

## 4. Known quantities

当前默认实验基线为：

- frequency: \(2.5\,\mathrm{GHz}\)
- angle grid: \(-60^\circ:0.2^\circ:60^\circ\)
- ideal spacing: \(\lambda/4\)
- truth manifold: HFSS data, \(\mathbf A_H\)
- ideal manifold:

\[
a_{I,m}(\theta)
=
\exp\left(j(m-1)\frac{\pi}{2}\sin\theta\right)
\]

稀疏校准角集合为：

\[
\Omega_c=\{\theta_1,\theta_2,\dots,\theta_L\}
\]

V3 可使用的训练信息包括：

- calibration angles 上的 HFSS truth；
- deterministic held-out single-source task angles；
- deterministic held-out near-threshold pair task angles；
- ARD coarse manifold。

需要强调：DOA benchmark snapshots 始终由 HFSS truth 生成，估计时 MUSIC scan 才使用不同 estimator manifold。

---

## 5. Residual parameterization

V3 在 \(u=\sin\theta\) 域建模：

\[
u=\sin\theta
\]

默认采用三段 soft-gated Chebyshev residual：

\[
c = [-50^\circ, 0^\circ, 50^\circ]
\]

对应到 \(u\) 域：

\[
u_k=\sin(c_k)
\]

对每个 segment 构造 soft gate：

\[
\alpha_k(u)
=
\frac{
\exp\left[-\frac{1}{2}\left(\frac{u-u_k}{w}\right)^2\right]
}{
\sum_r
\exp\left[-\frac{1}{2}\left(\frac{u-u_r}{w}\right)^2\right]
}
\]

每段内部使用低阶 Chebyshev basis：

\[
\psi_{k,p}(u)
=
\alpha_k(u)\,T_p\left(\frac{u-u_k}{w}\right)
\]

当前默认阶数为 \(P=1\)，因此每个阵元只学习一个很轻的 piecewise linear residual：

\[
\Delta\phi_m(u)
=
\sum_{k=1}^{3}\sum_{p=0}^{P}
w_{m,k,p}\psi_{k,p}(u)
\]

矩阵形式：

\[
\Delta\boldsymbol\Phi
=
\mathbf W\boldsymbol\Psi
\]

其中 \(\mathbf W\in\mathbb C^{M\times B}\)，实际实现中 \(\mathbf W\) 是实值相位系数矩阵。

---

## 6. Task set construction

V3 复用 Full V2 的 deterministic task construction。

### 6.1 Single-source tasks

single task set 包含：

1. 稀疏校准角；
2. held-out edge/high-mismatch angles。

高失配角通过 HFSS truth 和 ideal manifold 的 relative error 评分获得；边缘角通过 \(|\theta|/60^\circ\) 评分获得。

综合评分：

\[
s(\theta)
=
0.65\,\rho(\theta)+0.35\,e(\theta)
\]

其中：

\[
\rho(\theta)
=
\frac{\|\mathbf a_H(\theta)-\mathbf a_I(\theta)\|_2}
{\|\mathbf a_H(\theta)\|_2}
\]

\[
e(\theta)
=
\frac{|\theta|}{60^\circ}
\]

---

### 6.2 Pair tasks

pair task set 从 near-threshold separations 中选取：

\[
\Delta\theta\in[4^\circ,5^\circ,6^\circ,8^\circ,10^\circ]
\]

候选 pair 必须避开 calibration angles。
选择时优先考虑：

- pair endpoints 的 mismatch score；
- edge score；
- 到最近 calibration angle 的距离。

这些 task pairs 只用于 V3 优化。正式 Case 9 评估时必须排除 V2/V3 task pairs 的 union，避免 training-evaluation leakage。

---

## 7. Objective function

V3 的总目标为：

\[
\mathcal J_{V3}
=
\lambda_{cal}\mathcal L_{cal}
+
\lambda_{single}\mathcal L_{single}
+
\lambda_{pair}\mathcal L_{pair}
+
\lambda_{mid}\mathcal L_{mid}
+
\lambda_{anchor}\mathcal L_{anchor}
+
\lambda_{smooth}\mathcal L_{smooth}
+
\lambda_{reg}\mathcal L_{reg}
\]

当前默认权重：

| term | default |
|---|---:|
| \(\lambda_{cal}\) | 1 |
| \(\lambda_{single}\) | 0.08 |
| \(\lambda_{pair}\) | 0.12 |
| \(\lambda_{mid}\) | 0.04 |
| \(\lambda_{anchor}\) | 5 |
| \(\lambda_{smooth}\) | \(10^{-3}\) |
| \(\lambda_{reg}\) | \(10^{-4}\) |

---

### 7.1 Calibration loss

校准角上要求 V3 不偏离 HFSS truth：

\[
\mathcal L_{cal}
=
\frac{1}{|\Omega_c|}
\sum_{\theta_l\in\Omega_c}
\left\|
\hat{\mathbf a}_{V3}(\theta_l)
-
\mathbf a_H(\theta_l)
\right\|_2^2
\]

由于 ARD 在校准角上几乎精确穿过 HFSS，V3 的 residual 不应把校准角拉坏。

---

### 7.2 ARD anchor loss

V3 的核心约束是 ARD anchor：

\[
\mathcal L_{anchor}
=
\frac{1}{|\Theta|}
\sum_{\theta\in\Theta}
\left\|
\hat{\mathbf a}_{V3}(\theta)
-
\hat{\mathbf a}_{ARD}(\theta)
\right\|_2^2
\]

这个项防止 task loss 为了局部峰值收益而大幅改变 ARD 流形。

本轮 screening 表明，当前 \(\lambda_{anchor}=5\) 仍然不够强。

---

### 7.3 Smoothness and coefficient regularization

对分段 Chebyshev 系数施加 order-weighted smoothness：

\[
\mathcal L_{smooth}
=
\left\|
\mathbf W\mathbf D^T
\right\|_F^2
\]

并加入简单系数范数：

\[
\mathcal L_{reg}
=
\|\mathbf W\|_F^2
\]

---

### 7.4 Single-source task loss

对每个 single-source task angle \(\theta_t\)，用 HFSS truth 构造 exact covariance：

\[
\mathbf R_t
=
\mathbf a_H(\theta_t)\mathbf a_H^H(\theta_t)
+
\sigma^2\mathbf I
\]

由 \(\mathbf R_t\) 得到 noise projector \(\mathbf P_N\)。
V3 manifold 的目标 steering vector 应落在 signal subspace 中，因此有 subspace loss：

\[
\mathcal L_{single,sub}
=
\hat{\mathbf a}_{V3}^H(\theta_t)
\mathbf P_N
\hat{\mathbf a}_{V3}(\theta_t)
\]

同时使用 MUSIC peak surrogate。对 training scan grid 上每个角度计算：

\[
z(\theta)
=
\gamma
\left[
-\log
\left(
\hat{\mathbf a}_{V3}^H(\theta)\mathbf P_N\hat{\mathbf a}_{V3}(\theta)
\right)
-
\max_{\theta'}(\cdot)
\right]
\]

single-source peak loss：

\[
\mathcal L_{single,peak}
=
-z(\theta_t)
+
\log\sum_{\theta\in\Theta_{scan}}\exp z(\theta)
\]

于是：

\[
\mathcal L_{single}
=
\mathcal L_{single,sub}
+
\mathcal L_{single,peak}
\]

---

### 7.5 Pair task loss

对每个 pair task \((\theta_1,\theta_2)\)，用 HFSS truth 构造 two-source exact covariance：

\[
\mathbf R_p
=
\mathbf A_H(\theta_1,\theta_2)
\mathbf A_H^H(\theta_1,\theta_2)
+
\sigma^2\mathbf I
\]

其中：

\[
\mathbf A_H(\theta_1,\theta_2)
=
[
\mathbf a_H(\theta_1),
\mathbf a_H(\theta_2)
]
\]

pair subspace loss 要求两个端点都落在 signal subspace 中：

\[
\mathcal L_{pair,sub}
=
\sum_{r=1}^{2}
\hat{\mathbf a}_{V3}^H(\theta_r)
\mathbf P_N
\hat{\mathbf a}_{V3}(\theta_r)
\]

pair peak loss 要求两个真实端点在 training MUSIC spectrum 中有高响应：

\[
\mathcal L_{pair,peak}
=
-z(\theta_1)-z(\theta_2)
+
2\log\sum_{\theta\in\Theta_{scan}}\exp z(\theta)
\]

于是：

\[
\mathcal L_{pair}
=
\mathcal L_{pair,sub}
+
\mathcal L_{pair,peak}
\]

---

### 7.6 Midpoint suppression

双源 near-threshold 场景容易把两个源合成一个中点峰。
因此加入 midpoint suppression：

\[
\mathcal L_{mid}
=
\max
\left(
0,
z(\theta_{mid})
-
\frac{z(\theta_1)+z(\theta_2)}{2}
+
\mu
\right)^2
\]

其中：

\[
\theta_{mid}
=
\frac{\theta_1+\theta_2}{2}
\]

当前默认 margin：

\[
\mu=0.2
\]

---

## 8. Optimizer

V3 使用 deterministic SPSA + Adam moments 优化 residual coefficients。

不使用 `fminunc` 的原因是：

- 系数维度较高；
- finite-difference 成本过大；
- objective 内部包含 MUSIC-like surrogate；
- deterministic SPSA 更容易控制全量 case 的运行时间。

默认配置：

| config | default | paper profile |
|---|---:|---:|
| order | 1 | 1 |
| numSpsaIterations | 12 | 18 |
| learningRate | 0.020 | 0.020 |
| perturbationScale | 0.015 | 0.015 |
| maxGradNorm | 5 | 5 |
| taskScanStrideDeg | 1 deg | 1 deg |
| taskSingleHeldoutCount | 12 | 12 |
| taskPairCount | 16 | 16 |

如果 final objective 高于 initial objective，则 V3 fallback 到 ARD initializer：

\[
\hat{\mathbf a}_{V3}=\hat{\mathbf a}_{ARD}
\]

当前实现只检查 objective 是否下降，还没有检查 Case 3/Case 10 这类外部泛化指标是否退化。

---

## 9. Implementation mapping

当前 MATLAB 字段对应如下：

| concept | MATLAB field |
|---|---|
| ARD coarse manifold | `models.AARD` |
| V3 final manifold | `models.AProposedV3` |
| V3 equivalent phase fit relative to ideal | `models.phaseFitV3Full` |
| V3 task residual phase | `models.phaseDeltaV3Full` |
| V3 model coefficients | `models.phaseModelV3.coeff` |
| V3 diagnostics | `models.v3Diagnostics` |
| V3 task pairs | `models.v3Diagnostics.taskPairsDeg` |
| Case 9 V2/V3 excluded task union | `caseResult.taskPairsDeg` |
| Case 9 V2 task pairs | `caseResult.v2TaskPairsDeg` |
| Case 9 V3 task pairs | `caseResult.v3TaskPairsDeg` |
| Case 9 leakage check | `caseResult.taskEvalOverlapCount` |

核心实现位置：

- `default_config.m`: `cfg.model.v3`
- `src/build_sparse_models.m`: `local_refine_v3_ard_model`
- `run_project.m`: Case 3 / 7 / 9 / 10 method lists and Case 9 leakage exclusion

---

## 10. Screening protocol

V3 不直接进入 full paper profile。
第一阶段只跑：

\[
\texttt{run\_project([3\ 7\ 9\ 10], cfg)}
\]

筛选标准：

1. Case 3, \(L=9\): V3 global unseen error 不高于 `ARD + 0.002`，edge/worst-10% 不明显退化；
2. Case 7: 高 SNR RMSE 不能回到 V1/V2 级别；
3. Case 9: mean resolution 或 stable rate 应超过 ARD 和 Proposed V1 一个小幅 margin；
4. Case 10: 平均 DOA RMSE 不高于 `ARD + 0.01 deg`，且 manifold error 不能明显崩坏。

只有通过 screening，才跑 full paper profile `1:10`。

---

## 11. Current screening result

本轮实现版本：

- pending hash: `local-5a1492f8`
- run id: `20260420-134208-local-5a1492f8`
- run scope: Case 3 / 7 / 9 / 10 screening only

模型级检查：

- `AProposedV3` 存在；
- `size(AProposedV3) == size(ctx.AH)`；
- 无 `NaN/Inf`；
- representative objective: initial `4.065220`，final `0.678386`；
- `usedARDFallback = 0`。

但 screening 没有通过：

| Case | Key metric | ARD | Proposed V3 | Conclusion |
|---|---:|---:|---:|---|
| Case 3, L=9 | mean unseen error | 0.001034 | 0.017357 | V3 degrades manifold |
| Case 3, L=9 | edge error | 0.001179 | 0.017567 | V3 degrades edge band |
| Case 3, L=9 | worst-10% error | 0.001048 | 0.017536 | V3 degrades hard angles |
| Case 7, 20 dB | RMSE deg | 0.002828 | 0.002828 | neutral |
| Case 9 | mean resolution | 0.124474 | 0.122018 | worse than ARD |
| Case 9 | mean stable rate | 0.034825 | 0.033465 | worse than ARD |
| Case 10 | mean manifold error | 0.005644 | 0.065962 | V3 degrades manifold |
| Case 10 | mean DOA RMSE deg | 0.103499 | 0.106980 | within RMSE gate, but not useful |

Calibration guard check for the representative Case 3 model:

| Model | max calibration-vector error |
|---|---:|
| ARD | \(4.36\times 10^{-16}\) |
| Proposed V3 | \(2.54\times 10^{-2}\) |

这说明当前 V3 的 task residual 会把 ARD 在校准角上的精确穿越性质拉坏。
因此本轮没有继续跑 full `1:10`。

---

## 12. Current conclusion

V3 的方向仍然合理：

\[
\text{strong ARD backbone}
+
\text{small task-aware residual}
\]

但当前版本的 objective 还不够安全。
它能降低内部 task objective，却会损害 ARD 已经很强的 global manifold reconstruction。

因此当前结论应写为：

**Proposed V3 has been implemented as an ARD-anchored task-aware residual refinement, but the first screening version failed because task refinement degraded the ARD manifold and did not improve two-source resolution.**

不应写成：

**Proposed V3 outperforms ARD.**

---

## 13. Recommended next revision

下一版 V3 应优先修 objective，而不是加难 case 或转向 2D DOA。

建议修改方向：

1. 增大 \(\lambda_{anchor}\)，例如从 `5` 提高到 `20` 或 `50`；
2. 增加 explicit calibration hard guard，若校准角误差超过 ARD 太多则直接 reject step；
3. 增加 global manifold guard，用少量 held-out manifold angles 限制 V3 不偏离 ARD；
4. 将 order 保持为 `1`，不要先升阶；
5. 减小 learning rate 和 perturbation scale；
6. 如果 Case 3/10 screening 指标退化，则自动 fallback 到 ARD；
7. 将 pair task gain 作为局部目标，而不是允许它牺牲全局流形。

也就是说，下一版 V3 应从：

\[
\text{objective-only fallback}
\]

升级为：

\[
\text{objective + manifold guard + calibration guard fallback}
\]

只有这样，V3 才有机会在保住 ARD 强项的同时，在 Case 9 near-threshold resolution 上拿到额外收益。
