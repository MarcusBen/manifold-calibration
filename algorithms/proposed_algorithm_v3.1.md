# Proposed Algorithm V3.1

## Title

**CGATRC-V3.1: Calibration-Guarded ARD-Anchored Task-Aware Residual Calibration**

中文名称：

**基于校准保护的 ARD 锚定任务感知残差流形校准算法**

---

## 1. Purpose

V3.1 是对 V3.0 的安全修正版。V3.0 证明了 ARD-anchored task residual 可以优化 DOA surrogate，但也暴露出一个核心问题：如果 task loss 权重过强，residual 会破坏 ARD 的校准角穿越能力和未见角几何泛化。

V3.1 的目标是：

1. 继续使用 ARD 作为 coarse manifold；
2. 继续允许 task-aware phase residual；
3. 在 calibration angles 附近抑制 residual；
4. 给 residual 加 trust-radius bound；
5. 使用 held-out guard 和 fallback 防止几何退化；
6. 只在安全条件满足时保留 V3 candidate。

V3.1 的原则是：

**先保住 ARD 的几何能力，再考虑任务收益。**

---

## 2. Inputs and outputs

### Inputs

- Ideal manifold: `A_I(theta)`
- HFSS truth manifold: `A_H(theta)`
- Sparse calibration angles: `Theta_cal`
- ARD manifold: `A_ARD(theta)`
- Held-out guard angles
- Single-source and two-source task definitions
- V3.1 safety thresholds

### Output

V3.1 输出：

```text
A_V3.1(theta) = normalize(A_ARD(theta) .* exp(j * Delta_phi_safe(theta)))
```

如果 guard 不通过，则输出回退：

```text
A_V3.1(theta) = A_ARD(theta)
```

并在 diagnostics 中记录 fallback reason。

---

## 3. Safe residual model

V3.1 先用低维 basis 预测 raw residual：

```text
Delta_phi_raw(theta; c)
```

然后经过三层安全处理。

### 3.1 Calibration-null gate

对每个角度 `theta`，计算它到最近 calibration angle 的距离。距离越近，residual scale 越小：

```text
g_cal(theta) = 1 - exp(-d(theta, Theta_cal)^2 / sigma_cal^2)
```

在 calibration angles 上，`g_cal(theta)` 接近 0，因此 residual 不会破坏校准点。

### 3.2 Edge mask

边缘角度区域的 residual 自由度降低：

```text
g_edge(theta) in [edgeMaskMinimum, 1]
```

这避免 pair task 把模型推到 ±60 deg 边缘而产生不可控变形。

### 3.3 Trust-radius bound

raw residual 经过 bounded transform：

```text
Delta_phi_safe(theta) =
    trustRadiusRad * tanh(Delta_phi_raw(theta) / trustRadiusRad)
    * g_cal(theta)
    * g_edge(theta)
```

默认 trust radius 为小幅相位修正，而不是重写 ARD manifold。

---

## 4. Objective

V3.1 objective 包含任务收益和安全约束：

```text
J_V3.1 =
    lambdaCal    * L_calibration
  + lambdaSingle * L_single
  + lambdaPair   * L_pair
  + lambdaMid    * L_midpoint
  + lambdaAnchor * L_anchor
  + lambdaGuard  * L_heldout_guard
  + lambdaCal0   * L_calibration_zero
  + lambdaSmooth * L_smooth
  + lambdaReg    * L_regularization
```

关键安全项：

- `L_anchor`: candidate manifold 与 ARD manifold 的 RMS drift；
- `L_heldout_guard`: held-out angles 上相对 ARD 的额外误差；
- `L_calibration_zero`: calibration angles 上 residual 应接近 0。

V3.1 默认将 `lambdaAnchor`, `lambdaGuard`, `lambdaCal0` 设置为强约束，使 task residual 只能做小幅修正。

---

## 5. Task surrogate

V3.1 的 task surrogate 包含两类 DOA 任务：

1. single-source tasks 检查真值角附近 MUSIC-like score；
2. pair-source tasks 检查两个 endpoint 的 subspace consistency；
3. midpoint suppression 降低两个源中点处的 false peak。

但 V3.1 不再允许这些 task losses 单独决定结果。即使 task loss 下降，如果 guard metrics 变差，candidate 仍会被拒绝。

---

## 6. Guard and fallback

优化完成后，V3.1 计算 guard metrics：

```text
maxCalibrationDrift
guardRelativeExcess
anchorRmsDrift
```

通过条件：

```text
maxCalibrationDrift <= maxCalibrationDriftLimit
guardRelativeExcess <= guardRelativeTolerance
anchorRmsDrift <= maxAnchorRmsDrift
```

若任一条件失败：

```text
A_V3.1 = A_ARD
usedARDFallback = true
```

这个 fallback 是 V3.1 的核心机制。它把 V3 从“可能破坏几何的任务优化器”变成“只有安全时才生效的 residual refinement”。

---

## 7. Algorithm flow

```text
Input: A_I, A_H, Theta_cal, A_ARD, task config, guard config

1. Build ARD manifold A_ARD(theta).
2. Build raw residual basis Delta_phi_raw(theta; c).
3. Apply calibration-null gate, edge mask, and trust-radius bound.
4. Construct candidate manifold A_cand(theta).
5. Build single-source and two-source task projectors from HFSS truth.
6. Optimize J_V3.1(c) with SPSA.
7. Compute guard metrics for the best candidate.
8. If guard passes, output A_cand.
9. If guard fails, output A_ARD and record fallback reason.
10. Evaluate screening cases.

Output: A_V3.1(theta), guard diagnostics, fallback status, screening metrics.
```

---

## 8. Strengths

- Preserves calibration angle behavior.
- Controls held-out geometry degradation.
- Keeps ARD as the default safe fallback.
- Makes task-aware residuals usable without catastrophic manifold drift.
- Establishes the safety backbone used by later V3.2 and V3.3.

---

## 9. Limitations

V3.1 is safer than V3.0, but not yet a Case 9 solution.

Known limitations:

1. pair surrogate still does not fully match Case 9 stable classification;
2. task pair selection can be distribution-mismatched;
3. endpoint balance is not strongly captured;
4. resolution can improve without stable rate improving;
5. the method can become overly conservative due to strong ARD anchoring.

The main lesson from V3.1 is that safety guards work, but Case 9 needs a more benchmark-aligned pair objective. That motivated V3.2.

---

## 10. Implementation pointers

Relevant implementation areas:

- `src/build_sparse_models.m`
  - safe residual construction
  - calibration-null gate
  - edge mask
  - trust-radius bound
  - guard metrics
  - ARD fallback

- `default_config.m`
  - V3 safety weights and guard thresholds

- `run_project.m`
  - screening and diagnostics

This document is a standalone description of V3.1 and does not rely on V3.0, V3.2, or V3.3 documents.
