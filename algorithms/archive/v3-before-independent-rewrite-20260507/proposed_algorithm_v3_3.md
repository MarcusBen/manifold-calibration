# Proposed Algorithm V3.3

## Title

**AATRC-V3.3: ARD-Anchored Case-9-Aligned Global Stable-Pair Residual Calibration**

中文名称可表述为：

**基于 ARD 主干锚定与 Case 9 全局稳定双峰代理的残差流形校准算法**

---

## 1. Design target

V3.3 的目标不是重新设计流形模型，而是在 V3.2 的基础上进一步修正双源任务代理与正式 Case 9 benchmark 之间的不一致。

V3.2 已经引入了 distribution-matched stable-pair objective，但筛选结果显示：

- Case 9 mean resolution 可以被推高；
- stable rate 仍低于 ARD / Proposed V1；
- Case 7 高 SNR 单源指标有退化；
- pair surrogate 仍偏向局部、理想协方差下的双峰增强，没有充分对齐正式 benchmark 的 5 dB random-snapshot MUSIC 与全局 top-k peak selection。

因此，V3.3 的核心任务是：

1. 保留 V3-Revised / V3.2 的安全残差主干；
2. 将 pair task 的 SNR 对齐到 Case 9 的 5 dB；
3. 将 stable score 从局部均值型评分改成 peak 型评分；
4. 将 background competitor 从局部窗口改成全局竞争峰；
5. 降低单源 task 权重，将筛选重点放在双源 stable-pair behavior 上。

一句话概括：

**V3.3 = V3.2 safety backbone + 5 dB task projector + peak-score stable surrogate + global competitor background.**

---

## 2. Model backbone

V3.3 仍使用 ARD Method 2 作为几何主干：

```text
A_V3.3(theta) = normalize(A_ARD(theta) .* exp(j * delta_phi_safe(theta)))
```

其中：

- `A_ARD(theta)` 是 ARD complex correction-vector interpolation 得到的流形；
- `delta_phi_safe(theta)` 是 V3 residual model 预测的相位残差；
- residual 经过 calibration-null gate、edge mask 和 trust-radius bound；
- 最终流形按项目统一规则做列归一化与首阵元相位对齐。

V3.3 不引入新的 coupling matrix，也不直接估计 amplitude residual。它仍然是一个 **ARD-anchored phase residual refinement**。

---

## 3. Safety constraints retained from V3.2

V3.3 保留以下安全机制：

1. **Calibration-null gate**
   residual 在 calibration angles 附近被压低，避免破坏已知校准点。

2. **Trust-radius residual**
   residual 使用 bounded transform 限制最大相位漂移，当前默认 `trustRadiusRad = 0.04`。

3. **Edge mask**
   在边缘区域降低 residual 自由度，避免 task pairs 将模型推向边界过拟合。

4. **Strong ARD anchor**
   objective 中保留强 ARD anchor，当前默认 `lambdaAnchor = 50`。

5. **Held-out guard**
   若 candidate manifold 在 held-out guard angles 上相对 ARD 超出容忍范围，则回退到 ARD。

6. **Calibration drift guard**
   若 calibration point drift 超过阈值，则回退到 ARD。

这些机制的目的不是提升 Case 9，而是限制 V3.3 的负面外溢，尤其是 Case 3 / Case 7 / Case 10。

---

## 4. Main changes from V3.2

## 4.1 Task SNR aligned to Case 9

V3.2 的 pair surrogate 使用较干净的 task condition。V3.3 将 V3 task SNR 调整为：

```matlab
cfg.model.v3.taskSnrDb = 5;
```

这与 Case 9 evaluation 的 `cfg.case9.evalSNRDb = 5` 对齐。

这个改动的理由是：正式 Case 9 不是高 SNR deterministic spectrum test，而是 5 dB random-snapshot MUSIC。若 task projector 在过高 SNR 下构造，优化会偏向理想化双峰，不能稳定转化为 benchmark 中的 `stable` 状态。

## 4.2 Pair-oriented objective weights

V3.3 当前默认权重为：

```matlab
cfg.model.v3.lambdaSingle = 0.02;
cfg.model.v3.lambdaPair = 0.08;
```

相比 V2/V3.2 早期配置，V3.3 明确降低 single-source surrogate 的影响，把筛选重点放在双源 pair behavior。

同时保留：

```matlab
cfg.model.v3.lambdaAnchor = 50;
cfg.model.v3.lambdaGuard = 10;
cfg.model.v3.lambdaCal0 = 20;
```

也就是说，V3.3 不是放开 residual 去追 Case 9，而是在强 safety/anchor 约束下做小幅双源任务修正。

## 4.3 Peak score instead of mean score

V3.2 stable-neighborhood objective 对 endpoint / midpoint / background 的局部评分更接近 neighborhood mean。

V3.3 改成：

```matlab
cfg.model.v3.stableScoreMode = 'peak';
```

对一个角度邻域 `N(theta)`，score 不再强调邻域平均强度，而强调该邻域中最强 peak：

```text
score(theta) = max_{theta' in N(theta)} P(theta')
```

其中 `P(theta)` 是基于 candidate manifold 与 task signal/noise subspace 构造的 MUSIC-like score。

这个改动更贴近 `benchmark_music` 的 top-k peak picker：正式估计不是看平均能量，而是找局部峰。

## 4.4 Global competitor background

V3.2 的 background suppression 主要在局部窗口里看背景。V3.3 改成：

```matlab
cfg.model.v3.stableBackgroundMode = 'global_competitor';
```

对于 task pair `(theta_1, theta_2)`，先定义：

- left endpoint neighborhood；
- right endpoint neighborhood；
- midpoint neighborhood；
- 全训练 scan grid。

然后 background competitor 从全训练 scan grid 中选择，但排除 endpoint 与 midpoint neighborhoods：

```text
B_global = scan_grid \ (N(theta_1) union N(theta_2) union N(midpoint))
```

background score 为：

```text
score_bg = max_{theta in B_global} P(theta)
```

这样 pair surrogate 直接面对全局假峰竞争，而不是只压制局部 midpoint 附近的假峰。

这个改动是 V3.3 相对 V3.2 的关键：正式 MUSIC 估计是全局 top-k peak competition；若训练只看局部背景，就会低估远处假峰对双源判决的破坏。

---

## 5. Stable-pair objective

对每个 task pair `(theta_1, theta_2)`，V3.3 使用 HFSS truth steering vectors 构造 task signal subspace，并在 5 dB 条件下构造 projector。

对 candidate manifold `A_cand` 计算 MUSIC-like score：

```text
P_cand(theta) = 1 / || E_n^H a_cand(theta) ||_2^2
```

其中 `E_n` 是 task covariance 对应的 noise subspace。

V3.3 的 stable-pair loss 包含以下部分：

1. **Subspace consistency**
   真实两个 endpoint 的 candidate steering vectors 应该更接近 task signal subspace。

2. **Endpoint floor**
   两个 true DOA 附近都需要有足够强的 peak score。

3. **Midpoint suppression**
   midpoint 附近的 peak score 不应高于 endpoints。

4. **Global background suppression**
   除 endpoint / midpoint 邻域外的全局 competitor peak 不应压过 endpoints。

5. **Endpoint balance**
   两个 endpoint peak 不能严重失衡，否则 top-k peak picker 容易只保留一个真峰并被假峰替代。

实际 objective 通过 softplus/hinge-like penalties 聚合上述 margin violations。概念上可写为：

```text
L_pair =
    eta_sub * L_subspace
  + eta_end * L_endpoint_floor
  + eta_mid * L_midpoint_margin
  + eta_bg  * L_global_background_margin
  + eta_bal * L_endpoint_balance
```

当前默认权重包括：

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

## 6. Full objective

V3.3 的总体优化目标为：

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

当前默认主要配置：

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

优化仍使用 SPSA：

```matlab
numSpsaIterations = 8
learningRate = 0.004
perturbationScale = 0.004
maxGradNorm = 5
```

若优化后的 candidate 违反 guard，则 V3.3 回退到 ARD manifold。

---

## 7. Task pair construction

V3.3 沿用 V3.2 的 distribution-matched task-pair selection 思路：

- task pair separations 覆盖 `[4, 5, 6, 8, 10] deg`；
- task pair count 默认 `20`；
- selection mode 为 `distribution_matched`；
- 按 separation 和 center distribution 选取 representative held-out HFSS task pairs；
- Case 9 正式评估时排除 V2/V3 task pairs，保持 `taskEvalOverlapCount = 0`。

因此，V3.3 仍然避免直接用 evaluation pairs 做训练。

---

## 8. Evaluation interpretation

V3.3 的筛选结果显示：

- 相比 V3.2，surrogate 更贴近 Case 9 的 5 dB global peak competition；
- resolution 与 RMSE 有竞争力；
- stable rate 仍没有超过 Proposed V1；
- endpoint balance / global top-k surrogate 仍未完全对齐正式 `stable` 判据。

旧 default Case 9 screening 中：

```text
Case 9 mean resolution:
ARD 0.124013 / Proposed V1 0.126645 / V3.3 0.125000 / HFSS Oracle 0.122697

Case 9 mean stable:
ARD 0.035691 / Proposed V1 0.038898 / V3.3 0.036266 / HFSS Oracle 0.035033
```

后续 common-snapshot rerun 的 discriminative `>=6 deg` 结果为：

```text
ARD           resolution 0.305328 / stable 0.081148 / RMSE 28.107252
Proposed V1   resolution 0.314344 / stable 0.092828 / RMSE 27.747758
Proposed V3.3 resolution 0.312500 / stable 0.082582 / RMSE 27.664849
HFSS Oracle   resolution 0.303074 / stable 0.081148 / RMSE 28.195703
```

因此，V3.3 应表述为：

> A Case-9-aligned screening variant that improves surrogate consistency with the benchmark and is competitive in resolution/RMSE, but still does not solve the stable-rate gap to Proposed V1.

不应表述为最终优于 V1 的方法。

---

## 9. Known limitations

1. **Stable rate still lags Proposed V1**
   V3.3 的 stable-rate gap 说明 endpoint balance 和 peak selection 稳定性还没有完全解决。

2. **Representative spectra can be misleading**
   单次 representative spectrum 受 snapshot realization 影响。当前更可靠的比较应使用 common snapshots across methods。

3. **Case 9 all-separation mean includes near-infeasible pairs**
   `1-5 deg` separation 主要是 feasibility stress；`>=6 deg` 更适合作为 discriminative two-source indicator。

4. **Still a screening variant**
   V3.3 不是 full paper-profile final method。若写论文，应把它作为当前 proposed branch 的受限筛选结果，而不是最终强结论。

---

## 10. Implementation pointers

Current implementation is in:

- `default_config.m`
  - `cfg.model.v3.label = 'Proposed V3.3'`
  - `cfg.model.v3.stage = 'case9_aligned_global_stable_refinement'`
  - `cfg.model.v3.taskSnrDb = 5`
  - `cfg.model.v3.lambdaSingle = 0.02`
  - `cfg.model.v3.lambdaPair = 0.08`
  - `cfg.model.v3.stableScoreMode = 'peak'`
  - `cfg.model.v3.stableBackgroundMode = 'global_competitor'`

- `src/build_sparse_models.m`
  - V3 residual model construction;
  - task pair precomputation;
  - stable-pair objective;
  - global competitor background selection;
  - guard metrics and fallback.

- `run_project.m`
  - Case 9 summary;
  - discriminative `>=6 deg` split;
  - true-DOA markers in representative spectrum;
  - `v1ExperienceDiagnostics`.
