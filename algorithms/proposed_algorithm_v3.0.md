# Proposed Algorithm V3-Revised

## Title

**CGATRC: Calibration-Guarded ARD-Anchored Task-Aware Residual Calibration**

中文名称可写为：

**基于校准保护的 ARD 锚定任务感知残差流形校准算法**

---

## 1. Revision motivation

旧版 V3 的核心形式是：

\[
\hat{\mathbf a}_{V3}(\theta)
=
\operatorname{norm}
\left[
\hat{\mathbf a}_{ARD}(\theta)
\odot
\exp(j\Delta\boldsymbol\phi_{task}(\theta))
\right].
\]

这个方向是合理的：ARD Method 2 是当前最强几何主干，V3 不应绕开 ARD，而应只在 ARD 附近做小幅任务感知修正。

但 `local-5a1492f8` screening 暴露了旧 V3 的结构性问题：

1. pair-task loss 主导 objective，pair peak loss 从 `33.8768` 降到 `5.5569`，几乎贡献了全部 objective 下降；
2. calibration 和 ARD anchor 惩罚只有 \(10^{-4}\) 量级，挡不住 pair surrogate；
3. V3 把 ARD 在校准角上的精确穿越性质拉坏，representative max calibration-vector error 从 `4.36e-16` 变为 `2.54e-2`；
4. Case 3 / Case 10 的流形泛化明显退化，Case 9 resolution/stable rate 也没有超过 ARD 或 V1。

因此 V3-Revised 的重点不是增强 task loss，而是先加入几何护栏：

**task residual 只有在不破坏 ARD、校准角和 held-out manifold guard 的前提下才会被保留。**

---

## 2. Core model

ARD Method 2 给出 coarse manifold：

\[
\hat{\mathbf a}_{ARD}(\theta)
=
\mathbf a_I(\theta)\odot \hat{\mathbf g}(\theta),
\]

其中：

\[
\mathbf g(\theta_l)
=
\mathbf a_H(\theta_l)\oslash \mathbf a_I(\theta_l).
\]

V3-Revised 在 ARD 上叠加安全 residual：

\[
\hat{\mathbf a}_{V3r}(\theta)
=
\operatorname{norm}
\left[
\hat{\mathbf a}_{ARD}(\theta)
\odot
\exp(j\Delta\boldsymbol\phi_{safe}(\theta))
\right].
\]

初始化时：

\[
\Delta\boldsymbol\phi_{safe}(\theta)=0,
\qquad
\hat{\mathbf a}_{V3r}^{(0)}(\theta)=\hat{\mathbf a}_{ARD}(\theta).
\]

如果 guard 检查失败，则最终输出直接 fallback：

\[
\hat{\mathbf a}_{V3r}(\theta)=\hat{\mathbf a}_{ARD}(\theta).
\]

---

## 3. Safe residual parameterization

令：

\[
u=\sin\theta.
\]

原始 residual 仍使用三段 soft-gated Chebyshev basis，默认中心为：

\[
[-50^\circ,0^\circ,50^\circ].
\]

对每个阵元：

\[
\Delta\phi^{raw}_m(u)
=
\sum_{k=1}^{3}\sum_{p=0}^{P}
w_{m,k,p}\,
\alpha_k(u)
T_p\left(\frac{u-u_k}{w}\right),
\]

默认 \(P=1\)，不升阶。

---

### 3.1 Calibration-null gate

旧 V3 最大问题之一是 residual 会破坏校准角。V3-Revised 引入 calibration-null gate：

\[
\Gamma_c(u)
=
\prod_{\ell=1}^{L}
\left[
1-\exp\left(-\frac{(u-u_\ell)^2}{2\sigma_c^2}\right)
\right].
\]

因此：

\[
\Gamma_c(u_\ell)=0,
\qquad
\forall u_\ell\in\Omega_c^u.
\]

当前默认：

\[
\sigma_c = \sin(0.25^\circ).
\]

这保证 residual 在校准角附近自动收缩，校准角处严格为零。

---

### 3.2 Edge mask

V3-Revised 允许 edge/high-mismatch 区域有更大 residual，同时压低中心区不必要的修正：

\[
M_e(\theta)
=
m_0+(1-m_0)
\frac{1}{1+\exp\left(-\frac{|\theta|-\theta_e}{\tau_e}\right)}.
\]

默认：

- \(m_0=0.25\)
- \(\theta_e=35^\circ\)
- \(\tau_e=6^\circ\)

---

### 3.3 Trust-region clipping

最终 safe residual 为：

\[
\Delta\phi^{safe}_m(\theta)
=
\kappa
\tanh
\left(
\frac{
\Gamma_c(u)M_e(\theta)\Delta\phi^{raw}_m(u)
}{\kappa}
\right).
\]

默认：

\[
\kappa=0.04\ \mathrm{rad}.
\]

该式同时提供三层保护：

1. 校准角 residual 为零；
2. 中心区 residual 被压低；
3. 单个 residual 幅度被 trust radius 限制。

---

## 4. Objective function

V3-Revised 的 objective 为：

\[
\mathcal J
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
\lambda_{guard}\mathcal L_{guard}
+
\lambda_{cal0}\mathcal L_{cal0}
+
\lambda_{smooth}\mathcal L_{smooth}
+
\lambda_{reg}\mathcal L_{reg}.
\]

默认权重：

| term | value |
|---|---:|
| \(\lambda_{cal}\) | 1 |
| \(\lambda_{single}\) | 0.04 |
| \(\lambda_{pair}\) | 0.03 |
| \(\lambda_{mid}\) | 0.01 |
| \(\lambda_{anchor}\) | 50 |
| \(\lambda_{guard}\) | 10 |
| \(\lambda_{cal0}\) | 20 |
| \(\lambda_{smooth}\) | \(10^{-3}\) |
| \(\lambda_{reg}\) | \(10^{-4}\) |

相对旧 V3 的关键变化是：

- pair task 被降权；
- ARD anchor 被显著加权；
- calibration drift 和 held-out manifold guard 进入 objective；
- fallback 不再只看 objective 是否下降。

---

## 5. Guard terms

### 5.1 ARD anchor

\[
\mathcal L_{anchor}
=
\frac{1}{|\Theta|}
\sum_{\theta\in\Theta}
\left\|
\hat{\mathbf a}_{V3r}(\theta)
-
\hat{\mathbf a}_{ARD}(\theta)
\right\|_2^2.
\]

---

### 5.2 Calibration drift guard

\[
\mathcal L_{cal0}
=
\frac{1}{|\Omega_c|}
\sum_{\theta_l\in\Omega_c}
\left\|
\hat{\mathbf a}_{V3r}(\theta_l)
-
\hat{\mathbf a}_{ARD}(\theta_l)
\right\|_2^2.
\]

接受阈值：

\[
\max_{\theta_l\in\Omega_c}
\left\|
\hat{\mathbf a}_{V3r}(\theta_l)
-
\hat{\mathbf a}_{ARD}(\theta_l)
\right\|_2
\le 10^{-3}.
\]

若不满足，直接 fallback 到 ARD。

---

### 5.3 Held-out manifold guard

从非校准角中确定一组 held-out guard angles：

\[
\Omega_g\subset\Theta\setminus\Omega_c.
\]

默认包含高失配/边缘角和均匀覆盖角，共 `64` 个。

guard loss：

\[
\mathcal L_{guard}
=
\frac{1}{|\Omega_g|}
\sum_{\theta\in\Omega_g}
\left\|
\hat{\mathbf a}_{V3r}(\theta)
-
\mathbf a_H(\theta)
\right\|_2^2.
\]

接受阈值：

\[
\overline e_{guard,V3r}
\le
\overline e_{guard,ARD}+0.003.
\]

若不满足，直接 fallback 到 ARD。

---

### 5.4 Anchor drift guard

计算 RMS anchor drift：

\[
d_{anchor}
=
\sqrt{
\frac{1}{|\Theta|}
\sum_{\theta\in\Theta}
\left\|
\hat{\mathbf a}_{V3r}(\theta)
-
\hat{\mathbf a}_{ARD}(\theta)
\right\|_2^2
}.
\]

默认要求：

\[
d_{anchor}\le 0.02.
\]

若不满足，直接 fallback 到 ARD。

---

## 6. Task losses

single-source task 和 pair task 仍使用 HFSS truth exact covariance，不使用随机 snapshots。

single task 目标是减少高 SNR 单源 bias floor；pair task 目标是帮助 Case 9 near-threshold resolution。

但 V3-Revised 中 task loss 只是在 guard 内优化：

**只要 task refinement 破坏 calibration / guard manifold / ARD anchor，最终输出就回退到 ARD。**

---

## 7. Pair task coverage

旧 V3 的 pair task selection 只按综合 hard score 取 top 16，导致 task pair 几乎全部集中在 \(\pm60^\circ\) 边缘。

V3-Revised 改为 coverage 选择：

1. hard/high-mismatch pairs；
2. center/transition pairs；
3. edge pairs；
4. separation bucket coverage；
5. 剩余名额用 farthest-center sampling 补齐。

默认仍保留 `taskPairCount = 16`，但不允许全部落在极边缘。

正式 Case 9 评估仍排除 V2/V3 task pair union，并保存：

- `v2TaskPairsDeg`
- `v3TaskPairsDeg`
- `taskPairsDeg`
- `taskEvalOverlapCount`

---

## 8. Optimizer

V3-Revised 继续使用 deterministic SPSA + Adam moments，但参数更保守：

| parameter | default | paper profile |
|---|---:|---:|
| order | 1 | 1 |
| iterations | 8 | 12 |
| learning rate | 0.005 | 0.005 |
| perturbation scale | 0.005 | 0.005 |
| max grad norm | 5 | 5 |
| task scan stride | 1 deg | 1 deg |

---

## 9. MATLAB field mapping

| Concept | MATLAB field |
|---|---|
| ARD coarse manifold | `models.AARD` |
| V3-Revised manifold | `models.AProposedV3` |
| safe residual | `models.phaseDeltaV3Full` |
| equivalent phase fit | `models.phaseFitV3Full` |
| model config and coefficients | `models.phaseModelV3` |
| diagnostics | `models.v3Diagnostics` |
| guard metrics | `models.v3Diagnostics.guardMetrics` |
| candidate guard metrics before fallback | `models.v3Diagnostics.candidateGuardMetrics` |
| fallback reason | `models.v3Diagnostics.fallbackReason` |

---

## 10. Screening workflow

V3-Revised 仍然不直接进入 full paper profile。

第一阶段只跑：

```matlab
run_project([3 7 9 10], cfg)
```

通过标准：

1. Case 3, `L=9`: V3 mean unseen error 不高于 `ARD + 0.003`，edge/worst-10% 不明显退化；
2. Case 7: 高 SNR RMSE / bias 不回到 V1/V2 级别；
3. Case 9: `taskEvalOverlapCount = 0`；若 mean resolution/stable rate 未超过 ARD/V1，则记录为“安全但无收益”；
4. Case 10: mean manifold error 不高于 `ARD + 0.01`，mean DOA RMSE 不高于 `ARD + 0.01 deg`。

只有这四项都通过，才考虑 full `run_project(1:10, cfg)`。

---

## 11. Current positioning

V3-Revised 不声称已经优于 ARD。它当前的研究定位是：

1. 先证明 task refinement 不再破坏 ARD；
2. 再观察 Case 9 是否存在稳定、无泄漏的局部收益；
3. 如果没有 Case 9 收益，也应如实写成“安全但无额外收益”。

合理论文表述：

**V3-Revised is a guarded ARD-anchored task-refinement attempt. It is designed to preserve ARD's strong geometry before seeking task-specific gains.**

不应表述为：

**V3-Revised has already outperformed ARD.**
