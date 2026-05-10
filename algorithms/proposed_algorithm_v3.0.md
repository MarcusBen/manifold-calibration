# Proposed Algorithm V3.0

## Title

**AATRC-V3.0: ARD-Anchored Task-Aware Residual Calibration**

中文名称：

**基于 ARD 主干锚定的任务感知残差流形校准算法**

---

## 1. Purpose

V3.0 是第一版 ARD-anchored V3 方法。它的核心判断是：在当前项目中，ARD Method 2 已经比直接从 ideal manifold 拟合低阶 phase residual 更强，因此 proposed 方法不应绕开 ARD，而应在 ARD 流形附近叠加一个小幅任务驱动相位 residual。

V3.0 的目标是：

1. 使用 ARD 作为 coarse manifold；
2. 学习一个低维 phase residual；
3. 让 residual 面向 DOA 任务，而不是只面向流形误差；
4. 在单源和双源 MUSIC surrogate 上取得收益；
5. 通过 anchor 限制 residual 不要远离 ARD。

V3.0 是探索性版本。它证明了“ARD 主干 + 任务 residual”这条路线可实现，但后续实验显示其几何安全性不足。

---

## 2. Inputs and outputs

### Inputs

- Ideal manifold: `A_I(theta)`
- HFSS truth manifold: `A_H(theta)`
- Sparse calibration angles: `Theta_cal`
- ARD reconstructed manifold: `A_ARD(theta)`
- Evaluation scan grid: `Theta_scan`
- Single-source task angles and two-source task pairs

### Output

V3.0 输出一个 corrected manifold：

```text
A_V3.0(theta) = normalize(A_ARD(theta) .* exp(j * Delta_phi(theta)))
```

其中 `Delta_phi(theta)` 是任务感知 residual phase model。

---

## 3. Model

V3.0 使用分段低阶基函数表示每个阵元的 residual phase：

```text
Delta_phi_m(theta) = sum_b sum_p c_{m,b,p} * B_b(theta) * T_p(theta)
```

其中：

- `m` 是阵元编号；
- `B_b(theta)` 是按角度区间定义的 segment basis；
- `T_p(theta)` 是 polynomial 或 Chebyshev basis；
- `c_{m,b,p}` 是待优化系数。

当前代码线中 V3 系列默认使用 Chebyshev-style basis，并在 `src/build_sparse_models.m` 中统一构造。

---

## 4. Task construction

V3.0 构造两类任务。

### 4.1 Single-source tasks

对单个真值角 `theta0`，使用 HFSS truth vector 构造 covariance：

```text
R_single = a_H(theta0) a_H(theta0)^H + noise
```

然后以 candidate manifold `A_cand(theta)` 计算 MUSIC-like score。目标是让 `theta0` 附近的 score 高于邻域外背景。

### 4.2 Pair-source tasks

对两个真值角 `(theta1, theta2)`，构造：

```text
A_pair = [a_H(theta1), a_H(theta2)]
R_pair = A_pair A_pair^H + noise
```

pair task 鼓励：

- 两个 endpoint 接近 signal subspace；
- 两个真实角附近有较高 pseudo-spectrum；
- midpoint 不形成过强假峰。

---

## 5. Objective

V3.0 objective 可写为：

```text
J_V3.0 =
    lambdaCal    * L_calibration
  + lambdaSingle * L_single
  + lambdaPair   * L_pair
  + lambdaMid    * L_midpoint
  + lambdaAnchor * L_anchor
  + lambdaSmooth * L_smooth
  + lambdaReg    * L_regularization
```

各项含义：

- `L_calibration`: candidate manifold 在 calibration angles 上接近 HFSS truth；
- `L_single`: 单源 MUSIC surrogate；
- `L_pair`: 双源 endpoint/subspace surrogate；
- `L_midpoint`: midpoint false peak suppression；
- `L_anchor`: candidate 不应远离 ARD；
- `L_smooth`: residual 随角度变化平滑；
- `L_regularization`: 系数范数正则。

V3.0 的初始版本中过度依赖 task loss，anchor 和 calibration 保护不足，这是后续 V3-Revised 的主要修正对象。

---

## 6. Optimization

V3.0 使用 SPSA 优化 residual coefficients：

1. 初始化 residual coefficients 为零；
2. 构造 candidate manifold；
3. 计算 objective；
4. 用 SPSA 估计梯度方向；
5. 更新 coefficients；
6. 重复固定迭代次数；
7. 输出 objective 最低的 candidate。

V3.0 的优化是 task-driven screening，不是 convex optimization，也不保证全局最优。

---

## 7. Algorithm flow

```text
Input: A_I, A_H, Theta_cal, ARD config, V3.0 config

1. Select sparse calibration angles.
2. Build ARD manifold A_ARD(theta).
3. Build residual phase basis Delta_phi(theta; c).
4. Select single-source task angles.
5. Select two-source task pairs.
6. For each task, build HFSS-truth covariance and MUSIC-like projector.
7. Initialize c = 0.
8. Optimize J_V3.0(c) with SPSA.
9. Construct A_V3.0(theta) = normalize(A_ARD(theta) .* exp(j Delta_phi(theta; c_best))).
10. Evaluate Case 3 / 7 / 9 / 10 screening.

Output: A_V3.0(theta), objective diagnostics, screening metrics.
```

---

## 8. Strengths

- Establishes ARD as the correct geometric backbone for V3.
- Allows task-specific residual corrections without replacing the whole manifold model.
- Can improve selected DOA surrogate terms during optimization.
- Provides the diagnostic foundation for V3-Revised / V3.2 / V3.3.

---

## 9. Limitations

V3.0 is not the current recommended version.

Known issues:

1. task pair loss can dominate the objective;
2. calibration-point accuracy can be damaged;
3. ARD anchor was not strong enough in the first screening;
4. Case 3 and Case 10 manifold generalization can degrade;
5. Case 9 stable rate did not reliably exceed ARD or Proposed V1.

The main lesson from V3.0 is that task-aware residuals need explicit safety guards. That led to V3.1 / V3-Revised.

---

## 10. Implementation pointers

Relevant implementation areas:

- `src/build_sparse_models.m`
  - V3 residual basis construction
  - task construction
  - SPSA objective
  - candidate manifold construction

- `run_project.m`
  - Case 3 / 7 / 9 / 10 screening
  - method registration and diagnostics

This document is a standalone description of V3.0 and does not rely on later V3 variants.
