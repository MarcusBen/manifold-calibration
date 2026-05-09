# Proposed Algorithm V3.2

## Title

**AATRC-V3.2: ARD-Anchored Distribution-Matched Stable-Pair Residual Calibration**

中文名称：

**基于 ARD 主干锚定与分布匹配稳定双峰任务的残差流形校准算法**

---

## 1. Purpose

V3.2 是面向 Case 9 双源分辨的任务代理重设计版本。它使用 ARD-anchored safe residual backbone，并重新设计 task pair selection 和 pair objective，使训练任务更接近正式 Case 9 的近阈值双源分布。

V3.2 的目标是：

1. 继续使用 ARD 作为 coarse manifold；
2. 继续使用 calibration-null、trust-radius、held-out guard 和 fallback；
3. 构造更接近 Case 9 evaluation distribution 的 task pairs；
4. 将 pair objective 从普通双峰增强改成 stable-neighborhood objective；
5. 提升 Case 9 resolution，同时避免破坏 Case 3 / 7 / 10。

V3.2 是第一个明确把 stable-rate behavior 当作训练目标的 V3 版本。

---

## 2. Inputs and outputs

### Inputs

- Ideal manifold: `A_I(theta)`
- HFSS truth manifold: `A_H(theta)`
- ARD manifold: `A_ARD(theta)`
- Sparse calibration angles: `Theta_cal`
- Candidate Case 9 pair pool
- Task-pair selection config
- Safety guard config

### Output

```text
A_V3.2(theta) = normalize(A_ARD(theta) .* exp(j * Delta_phi_safe(theta)))
```

若 guard 不通过，则：

```text
A_V3.2(theta) = A_ARD(theta)
```

---

## 3. Safe residual backbone

V3.2 使用与 V3.1 相同类型的 safe residual：

```text
Delta_phi_safe(theta) =
    bounded(Delta_phi_raw(theta; c))
    * calibration_null_gate(theta)
    * edge_mask(theta)
```

其中：

- `Delta_phi_raw` 由低维 segment basis 和 Chebyshev / polynomial basis 表示；
- `calibration_null_gate` 保证 calibration angles 附近 residual 接近 0；
- `edge_mask` 限制边缘角度 residual 自由度；
- `bounded` 使用 trust-radius 控制最大相位改动。

V3.2 的模型能力没有显著增加，主要变化在 task selection 和 pair loss。

---

## 4. Distribution-matched task pair selection

V3.2 的 task pair 不再只按 hard score 选择。它将 task pair selection 设计为接近 Case 9 evaluation distribution。

### 4.1 Pair attributes

对每个 candidate pair `(theta_1, theta_2)` 计算：

```text
separation = theta_2 - theta_1
center = (theta_1 + theta_2) / 2
```

V3.2 默认关注 separation：

```text
[4, 5, 6, 8, 10] deg
```

### 4.2 Selection rule

选择规则：

1. 按 separation 分配 task-pair 名额；
2. 每个 separation 内覆盖多个 center bins；
3. 避开最外侧 center bin，防止 residual 被边界任务主导；
4. 优先选择 mismatch / edge / calibration-distance score 较高的 pair；
5. 正式 Case 9 evaluation 时排除 V2/V3 task pairs，保持 `taskEvalOverlapCount = 0`。

这个设计的目的不是利用测试集，而是让训练任务的 separation/center 分布不要偏离正式 Case 9 太远。

---

## 5. Stable-neighborhood pair objective

对每个 task pair `(theta_1, theta_2)`，用 HFSS truth 构造双源 task covariance，并计算 candidate manifold 下的 MUSIC-like pseudo-spectrum。

定义：

- left endpoint neighborhood: `N(theta_1)`
- right endpoint neighborhood: `N(theta_2)`
- midpoint neighborhood: `N((theta_1 + theta_2)/2)`
- background neighborhood: endpoint / midpoint 外的局部背景区域

V3.2 的 stable-neighborhood objective 包含：

1. **Endpoint strength**
   两个真值端点附近的 score 应足够高。

2. **Subspace consistency**
   两个 endpoint steering vectors 应接近 task signal subspace。

3. **Midpoint suppression**
   midpoint 不应形成比 endpoint 更可信的假峰。

4. **Background suppression**
   background 不应压过 endpoint。

5. **Endpoint balance**
   两个 endpoint 的 score 不应严重失衡。

实际实现使用 `logmeanexp` 聚合局部 neighborhood score，避免 background 因点数更多被系统性抬高。

---

## 6. Full objective

V3.2 总目标：

```text
J_V3.2 =
    lambdaCal    * L_calibration
  + lambdaSingle * L_single
  + lambdaPair   * L_stable_pair
  + lambdaMid    * L_midpoint
  + lambdaAnchor * L_anchor
  + lambdaGuard  * L_heldout_guard
  + lambdaCal0   * L_calibration_zero
  + lambdaSmooth * L_smooth
  + lambdaReg    * L_regularization
```

其中 `L_stable_pair` 是 V3.2 的核心新增项。

V3.2 仍使用 SPSA 优化 residual coefficients，并在优化后执行 guard check。

---

## 7. Guard and fallback

V3.2 保留安全机制：

- calibration drift guard；
- held-out relative excess guard；
- ARD anchor RMS guard；
- fallback to ARD。

若 candidate 违反 guard，则：

```text
usedARDFallback = true
A_V3.2 = A_ARD
```

这保证了 distribution-matched pair objective 不能无限制地牺牲几何泛化。

---

## 8. Algorithm flow

```text
Input: A_I, A_H, Theta_cal, A_ARD, Case 9 pair pool, V3.2 config

1. Build ARD manifold A_ARD(theta).
2. Build safe residual basis Delta_phi_safe(theta; c).
3. Generate candidate Case 9-like task pairs.
4. Select task pairs with separation-balanced and center-covered distribution.
5. Exclude selected task pairs from final Case 9 evaluation.
6. Build single-source tasks and stable-pair tasks from HFSS truth.
7. Optimize J_V3.2(c) with SPSA.
8. Construct candidate manifold A_cand(theta).
9. Compute guard metrics.
10. If guard passes, output A_cand.
11. If guard fails, output A_ARD.
12. Run screening cases and save task/eval stratum diagnostics.

Output: A_V3.2(theta), pair selection diagnostics, guard diagnostics, screening metrics.
```

---

## 9. Evaluation interpretation

V3.2 screening showed:

```text
Case 9 mean resolution:
ARD 0.124474 / Proposed V1 0.126776 / V3.2 0.126908

Case 9 mean stable:
ARD 0.034825 / Proposed V1 0.036316 / V3.2 0.033333
```

Interpretation:

- V3.2 pushed mean resolution slightly above Proposed V1;
- stable rate did not improve;
- Case 7 high-SNR single-source behavior degraded;
- Case 3 edge/worst unseen geometry degraded relative to safer V3 variants.

Therefore V3.2 is not a final method. It is an important diagnostic version showing that resolution can improve while stable-rate remains misaligned.

---

## 10. Limitations

1. Stable-neighborhood surrogate was still too local.
2. Task covariance did not fully match 5 dB random-snapshot MUSIC.
3. Endpoint balance diagnostics did not reliably translate to stable classification.
4. Stable rate remained below ARD / Proposed V1.
5. Some non-Case-9 safety metrics degraded.

The main lesson from V3.2 is that pair-task distribution matching is useful but insufficient. The surrogate also needs to match 5 dB global top-k peak competition. That motivated V3.3.

---

## 11. Implementation pointers

Relevant implementation areas:

- `src/build_sparse_models.m`
  - distribution-matched pair selection
  - stable-neighborhood pair loss
  - pair/eval stratum diagnostics
  - guard and fallback

- `run_project.m`
  - Case 9 grouped resolution/stable diagnostics
  - task/eval overlap checks

This document is a standalone description of V3.2 and does not rely on other V3 documents.
