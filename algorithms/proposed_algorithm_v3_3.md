# Proposed Algorithm V3.3

## Title

**AATRC-V3.3: ARD-Anchored Case-9-Aligned Global Stable-Pair Residual Calibration**

中文名称：

**基于 ARD 主干锚定与 Case 9 全局稳定双峰代理的残差流形校准算法**

---

## 1. Purpose

V3.3 是当前代码线中的 V3 默认算法。它保留 ARD-anchored safe residual backbone，但进一步修正 V3.2 的 pair surrogate，使训练更接近正式 Case 9 的条件：

- 5 dB SNR；
- random-snapshot MUSIC；
- global top-k peak competition；
- strict stable / biased / marginal / unresolved classification。

2026-05-08 之后，Case 9 的双源主线评估后端切换为 pairwise covariance-fit ML。MUSIC peak picking 仍保留为谱图解释和 Case 11 后端消融基线，但不再作为 Case 9 主结果后端。

V3.3 的目标是：

1. 继续使用 ARD 作为 coarse manifold；
2. 继续使用 calibration-null、trust-radius、held-out guard 和 fallback；
3. 将 task SNR 对齐到 Case 9 的 5 dB；
4. 将 stable score 从 neighborhood mean 改成 peak score；
5. 将 background suppression 从局部窗口改成 global competitor；
6. 在不破坏安全 guard 的前提下提升 Case 9 双源分辨。

---

## 2. Inputs and outputs

### Inputs

- Ideal manifold: `A_I(theta)`
- HFSS truth manifold: `A_H(theta)`
- ARD manifold: `A_ARD(theta)`
- Sparse calibration angles: `Theta_cal`
- Case 9-like task pair pool
- V3.3 task/guard/optimization config

### Output

```text
A_V3.3(theta) = normalize(A_ARD(theta) .* exp(j * Delta_phi_safe(theta)))
```

若 guard 不通过，则：

```text
A_V3.3(theta) = A_ARD(theta)
```

---

## 3. Safe residual backbone

V3.3 residual 形式：

```text
Delta_phi_safe(theta) =
    trustRadiusRad * tanh(Delta_phi_raw(theta; c) / trustRadiusRad)
    * calibration_null_gate(theta)
    * edge_mask(theta)
```

默认配置：

```matlab
trustRadiusRad = 0.04
calibrationNullSigmaDeg = 0.25
edgeMaskEnabled = true
edgeMaskStartDeg = 35
edgeMaskTransitionDeg = 6
edgeMaskMinimum = 0.25
```

这说明 V3.3 只允许在 ARD 附近做小幅相位 residual，不直接重估完整 manifold。

---

## 4. Current default configuration

当前实现中的 V3.3 关键配置：

```matlab
cfg.model.v3.label = 'Proposed V3.3'
cfg.model.v3.stage = 'case9_aligned_global_stable_refinement'
cfg.model.v3.base = 'ard'
cfg.model.v3.taskSnrDb = 5
cfg.model.v3.lambdaSingle = 0.02
cfg.model.v3.lambdaPair = 0.08
cfg.model.v3.lambdaAnchor = 50
cfg.model.v3.lambdaGuard = 10
cfg.model.v3.lambdaCal0 = 20
cfg.model.v3.stableScoreMode = 'peak'
cfg.model.v3.stableBackgroundMode = 'global_competitor'
```

优化配置：

```matlab
numSpsaIterations = 8
learningRate = 0.004
perturbationScale = 0.004
maxGradNorm = 5
```

---

## 5. Task construction

V3.3 使用 held-out HFSS truth 构造任务。

### 5.1 Single-source tasks

单源任务保留，但权重较低：

```matlab
lambdaSingle = 0.02
```

其作用是防止 residual 完全牺牲单源 DOA behavior。

### 5.2 Pair-source tasks

双源任务是 V3.3 重点：

```matlab
lambdaPair = 0.08
taskPairSeparationDeg = [4 5 6 8 10]
taskPairCount = 20
taskPairSelectionMode = 'distribution_matched'
```

pair selection 覆盖多个 separation 和 center bins，并在 Case 9 evaluation 前排除 task pairs，保持训练/评估不重叠。

---

## 6. 5 dB task projector

V3.3 将 task projector 的 SNR 设置为：

```matlab
taskSnrDb = 5
```

这是为了对齐 Case 9：

```matlab
cfg.case9.evalSNRDb = 5
```

对每个 task pair `(theta_1, theta_2)`：

```text
A_pair = [a_H(theta_1), a_H(theta_2)]
R_pair = A_pair A_pair^H + noise(5 dB)
```

然后从 `R_pair` 得到 noise subspace，并计算 candidate manifold 的 MUSIC-like score：

```text
P_cand(theta) = 1 / ||E_n^H a_cand(theta)||_2^2
```

---

## 7. Peak-score stable surrogate

V3.3 的 stable score mode 是：

```matlab
stableScoreMode = 'peak'
```

对某个角度邻域 `N(theta)`：

```text
score(theta) = max_{theta' in N(theta)} P_cand(theta')
```

这比 neighborhood mean 更接近正式 MUSIC peak picker，因为最终 DOA 估计选的是 local peaks，不是邻域平均能量。

---

## 8. Global competitor background

V3.3 的 background mode 是：

```matlab
stableBackgroundMode = 'global_competitor'
```

对 task pair `(theta_1, theta_2)` 定义：

```text
theta_mid = (theta_1 + theta_2) / 2
B_global = task_scan_grid
           \ (N(theta_1) union N(theta_2) union N(theta_mid))
```

background score：

```text
score_bg = max_{theta in B_global} P_cand(theta)
```

这个设计直接模拟正式 benchmark 中的全局 top-k 竞争：远处假峰也可能抢走第二个 peak，因此训练时不能只压 midpoint 或局部背景。

---

## 9. Stable-pair loss

V3.3 pair loss 包含：

1. **Subspace consistency**
   Endpoint steering vectors 应靠近 signal subspace。

2. **Endpoint floor**
   两个 true DOA 邻域都应有足够强的 peak。

3. **Midpoint margin**
   midpoint peak 不应压过 endpoints。

4. **Global background margin**
   全局 competitor peak 不应压过 endpoints。

5. **Endpoint balance**
   两个 endpoint peaks 不应严重失衡。

概念形式：

```text
L_pair =
    etaSub * L_subspace
  + etaEnd * L_endpoint_floor
  + etaMid * L_midpoint_margin
  + etaBg  * L_global_background_margin
  + etaBal * L_endpoint_balance
```

当前默认：

```matlab
stableEndpointFloor = -2.5
stableMidMargin = 0.15
stableBackgroundMargin = 0.10
stableBalanceMargin = 0.15
stableEtaSub = 1
stableEtaEnd = 1
stableEtaMid = 1
stableEtaBg = 0.5
stableEtaBalance = 0.5
```

---

## 10. Full objective

V3.3 总目标：

```text
J_V3.3 =
    lambdaCal    * L_calibration
  + lambdaSingle * L_single
  + lambdaPair   * L_pair
  + lambdaAnchor * L_anchor_to_ARD
  + lambdaGuard  * L_heldout_guard
  + lambdaCal0   * L_calibration_zero
  + lambdaSmooth * L_smooth
  + lambdaReg    * L_regularization
```

默认主要权重：

```matlab
lambdaCal = 1
lambdaSingle = 0.02
lambdaPair = 0.08
lambdaAnchor = 50
lambdaGuard = 10
lambdaCal0 = 20
lambdaSmooth = 1e-3
lambdaReg = 1e-4
```

---

## 11. Guard and fallback

V3.3 candidate 优化完成后，检查：

```text
maxCalibrationDrift <= 1e-3
guardRelativeExcess <= 0.003
anchorRmsDrift <= 0.02
```

若失败：

```text
usedARDFallback = true
A_V3.3 = A_ARD
```

若通过：

```text
usedARDFallback = false
A_V3.3 = A_cand
```

---

## 12. Algorithm flow

```text
Input: A_I, A_H, Theta_cal, ARD config, V3.3 config

1. Build project context and normalize A_I / A_H.
2. Select sparse calibration angles.
3. Build ARD manifold A_ARD(theta).
4. Build safe residual basis Delta_phi_safe(theta; c).
5. Select held-out single-source tasks.
6. Select distribution-matched two-source task pairs.
7. Build 5 dB task projectors from HFSS truth.
8. Compute single-source and global-stable pair losses.
9. Optimize J_V3.3(c) with SPSA.
10. Construct candidate manifold A_cand(theta).
11. Compute calibration, held-out guard, and anchor metrics.
12. If guards pass, output A_cand.
13. If guards fail, output A_ARD.
14. Evaluate Case 9, including all-separation and >=6 deg summaries.

Output: A_V3.3(theta), diagnostics, fallback status, Case 9 metrics.
```

---

## 13. Evaluation interpretation

V3.3 improves surrogate alignment with Case 9. The current Case 9 mainline should be interpreted as:

```text
A_V3.3(theta) + pairwise covariance-fit ML backend
```

The older MUSIC-backend Case 9 evidence remains useful as a historical baseline and backend-failure diagnosis, but it should not be mixed directly with the current pairwise-backend mainline numbers.

### Older MUSIC-backend evidence

Common-snapshot Case 9 rerun, discriminative `>=6 deg`:

```text
ARD           resolution 0.305328 / stable 0.081148 / RMSE 28.107252
Proposed V1   resolution 0.314344 / stable 0.092828 / RMSE 27.747758
Proposed V3.3 resolution 0.312500 / stable 0.082582 / RMSE 27.664849
HFSS Oracle   resolution 0.303074 / stable 0.081148 / RMSE 28.195703
```

Interpretation:

- V3.3 is competitive in resolution and RMSE;
- V3.3 stable rate remains below Proposed V1;
- representative spectra should be interpreted only with common snapshots;
- endpoint balance remains the unresolved issue.

### Current pairwise-backend evidence

Case 9 now reports double-source recovery through a joint covariance-fit pair backend. Case 11 provides the backend ablation for `music / music_pair_rescore / pairwise_grid_ml`. Current medium Case 9 runs should be described as diagnostic mainline evidence unless a full paper-profile run is explicitly cited.

---

## 14. Limitations

1. Stable rate still lags Proposed V1.
2. Endpoint balance is not fully solved by the current global competitor surrogate.
3. `1-5 deg` Case 9 pairs are near-feasibility stress and should not dominate method claims.
4. V3.3 is a screening variant, not a final paper-profile method.
5. GP-ANM has been evaluated only as an offline diagnostic / future expensive baseline direction; it is not an active V3.3 fallback path.

---

## 15. Implementation pointers

Relevant implementation areas:

- `default_config.m`
  - V3.3 label, stage, weights, SNR, stable score mode, background mode

- `src/build_sparse_models.m`
  - safe residual model
  - task pair construction
  - 5 dB projector
  - peak score
  - global competitor background
  - guard/fallback diagnostics

- `run_project.m`
  - Case 9 all-separation summary
  - `>=6 deg` discriminative summary
  - true-DOA markers
  - `v1ExperienceDiagnostics`

This document is a standalone description of V3.3 and does not rely on earlier V3 documents.
