# 基于阵列响应分解的插值与 DOA 估计算法表

## 论文信息
**Title:** Array response interpolation and DOA estimation with array response decomposition
**Source:** Signal Processing, 125 (2016), 97–109

---

## 1. 算法目标

本文提出一种基于**阵列响应分解（array response decomposition）**的阵列流形插值方法，用于提升真实阵列条件下的 DOA 估计性能。其核心思想不是直接插值原始嵌入式阵列响应，而是先利用理想阵列响应和互耦矩阵对其进行分解，再对更平滑的校正向量进行插值，最后重构阵列响应并用于 MUSIC 估计。

---

## 2. 信号模型

阵列接收信号写为：

\[
\mathbf{X}(k)=\sum_{m=1}^{M}\mathbf{a}_{\mathrm{emb}}(\eta_m)s_m(k)+\mathbf{W}(k)
\]

其中：

- \(\mathbf{X}(k)\in\mathbb{C}^{N\times 1}\)：第 \(k\) 个快拍的阵列输出向量；
- \(N\)：阵元数；
- \(M\)：信源数；
- \(\eta_m\)：第 \(m\) 个信号的 DOA；
- \(\mathbf{a}_{\mathrm{emb}}(\eta_m)\in\mathbb{C}^{N\times 1}\)：真实嵌入式阵列响应；
- \(s_m(k)\)：第 \(m\) 个信号的复包络；
- \(\mathbf{W}(k)\)：噪声向量。

---

## 3. 阵列响应分解模型

### 3.1 模型 1：理想阵列响应 + 校正向量

\[
\mathbf{a}_{\mathrm{emb}}(\eta)
=
\mathbf{a}_{\mathrm{ideal}}(\eta)\odot \mathbf{g}(\eta)
\]

其中：

- \(\mathbf{a}_{\mathrm{ideal}}(\eta)\in\mathbb{C}^{N\times 1}\)：理想阵列响应；
- \(\mathbf{g}(\eta)\in\mathbb{C}^{N\times 1}\)：方向相关校正向量；
- \(\odot\)：Hadamard 逐元素乘积。

在采样方向 \(\eta_l\) 上有：

\[
\mathbf{g}(\eta_l)
=
\mathbf{a}_{\mathrm{emb}}(\eta_l)\oslash \mathbf{a}_{\mathrm{ideal}}(\eta_l)
\]

其中 \(\oslash\) 表示逐元素相除。

插值后重构：

\[
\hat{\mathbf{a}}_{\mathrm{emb}}(\eta)
=
\mathbf{a}_{\mathrm{ideal}}(\eta)\odot \hat{\mathbf{g}}(\eta)
\]

---

### 3.2 模型 2：互耦矩阵 + 理想阵列响应 + 校正向量

\[
\mathbf{a}_{\mathrm{emb}}(\eta)
=
\mathbf{C}\bigl(\mathbf{a}_{\mathrm{ideal}}(\eta)\odot \mathbf{g}_e(\eta)\bigr)
\]

其中：

- \(\mathbf{C}\in\mathbb{C}^{N\times N}\)：互耦矩阵，与方向无关；
- \(\mathbf{g}_e(\eta)\in\mathbb{C}^{N\times 1}\)：去耦后的方向相关校正向量。

若 \(\mathbf{C}\) 已知，则

\[
\mathbf{g}_e(\eta_l)
=
\bigl[\mathbf{C}^{-1}\mathbf{a}_{\mathrm{emb}}(\eta_l)\bigr]
\oslash
\mathbf{a}_{\mathrm{ideal}}(\eta_l)
\]

插值后重构：

\[
\hat{\mathbf{a}}_{\mathrm{emb}}(\eta)
=
\mathbf{C}\bigl(\mathbf{a}_{\mathrm{ideal}}(\eta)\odot \hat{\mathbf{g}}_e(\eta)\bigr)
\]

---

## 4. 三种插值方法

### Method 1：直接插值 embedded array response

直接对原始嵌入式阵列响应 \(\mathbf{a}_{\mathrm{emb}}(\eta)\) 的实部和虚部分别进行插值，得到：

\[
\hat{\mathbf{a}}_{\mathrm{emb}}(\eta)
\]

可采用两种方式：

- Local Linear Interpolation (LLI)
- Fourier-based interpolation

该方法最直接，但由于 \(\mathbf{a}_{\mathrm{emb}}(\eta)\) 随角度变化较快，通常需要更密的采样网格或更多 Fourier 项。

---

### Method 2：插值校正向量 \(\mathbf{g}(\eta)\)

先利用理想阵列响应消除几何相位结构，再对剩余校正向量 \(\mathbf{g}(\eta)\) 进行插值：

1. 计算采样点处的 \(\mathbf{g}(\eta_l)\)；
2. 对 \(\mathbf{g}(\eta)\) 插值得到 \(\hat{\mathbf{g}}(\eta)\)；
3. 按照
   \[
   \hat{\mathbf{a}}_{\mathrm{emb}}(\eta)
   =
   \mathbf{a}_{\mathrm{ideal}}(\eta)\odot \hat{\mathbf{g}}(\eta)
   \]
   重构阵列响应。

该方法比 Method 1 更优，因为 \(\mathbf{g}(\eta)\) 通常比 \(\mathbf{a}_{\mathrm{emb}}(\eta)\) 更平滑。

---

### Method 3：插值去耦后的校正向量 \(\mathbf{g}_e(\eta)\)

进一步利用互耦矩阵 \(\mathbf{C}\) 去除互耦结构：

1. 若 \(\mathbf{C}\) 已知，则计算
   \[
   \mathbf{g}_e(\eta_l)
   =
   \bigl[\mathbf{C}^{-1}\mathbf{a}_{\mathrm{emb}}(\eta_l)\bigr]
   \oslash
   \mathbf{a}_{\mathrm{ideal}}(\eta_l)
   \]
2. 对 \(\mathbf{g}_e(\eta)\) 插值得到 \(\hat{\mathbf{g}}_e(\eta)\)；
3. 重构
   \[
   \hat{\mathbf{a}}_{\mathrm{emb}}(\eta)
   =
   \mathbf{C}\bigl(\mathbf{a}_{\mathrm{ideal}}(\eta)\odot \hat{\mathbf{g}}_e(\eta)\bigr)
   \]

Method 3 的核心优势在于：真正需要插值的对象 \(\mathbf{g}_e(\eta)\) 最平滑，因此插值误差最小。

---

## 5. 互耦矩阵未知时的估计方法

若 \(\mathbf{C}\) 未知，则通过最小二乘进行估计。

构造：

\[
\mathbf{A}_{\mathrm{emb}}
=
[\mathbf{a}_{\mathrm{emb}}(\eta_1),\dots,\mathbf{a}_{\mathrm{emb}}(\eta_L)]
\]

\[
\mathbf{A}_{\mathrm{ideal}}
=
[\mathbf{a}_{\mathrm{ideal}}(\eta_1),\dots,\mathbf{a}_{\mathrm{ideal}}(\eta_L)]
\]

\[
\mathbf{G}_e
=
[\mathbf{g}_e(\eta_1),\dots,\mathbf{g}_e(\eta_L)]
\]

最小二乘问题为：

\[
\hat{\mathbf{C}}
=
\arg\min_{\mathbf{C}}
\left\|
\mathbf{A}_{\mathrm{emb}}
-
\mathbf{C}\bigl[\mathbf{A}_{\mathrm{ideal}}\odot \mathbf{G}_e\bigr]
\right\|_F^2
\]

无结构约束时，其闭式解为：

\[
\hat{\mathbf{C}}
=
\mathbf{A}_{\mathrm{emb}}
[\mathbf{A}_{\mathrm{ideal}}\odot \mathbf{G}_e]^H
\Bigl(
[\mathbf{A}_{\mathrm{ideal}}\odot \mathbf{G}_e]
[\mathbf{A}_{\mathrm{ideal}}\odot \mathbf{G}_e]^H
\Bigr)^{-1}
\]

随后更新残差校正向量：

\[
\tilde{\mathbf{g}}_e(\eta)
=
\mathbf{a}_{\mathrm{emb}}(\eta)\oslash
\bigl[\hat{\mathbf{C}}\mathbf{a}_{\mathrm{ideal}}(\eta)\bigr]
\]

最终重构为：

\[
\hat{\mathbf{a}}_{\mathrm{emb}}(\eta)
=
\hat{\mathbf{C}}\mathbf{a}_{\mathrm{ideal}}(\eta)\odot \hat{\tilde{\mathbf{g}}}_e(\eta)
\]

---

## 6. MUSIC DOA 估计

得到插值后的阵列响应模型 \(\hat{\mathbf{a}}_{\mathrm{emb}}(\eta)\) 后，采用 MUSIC 进行 DOA 估计。

### 6.1 协方差矩阵

\[
\hat{\mathbf{R}}_{xx}
=
\frac{1}{K}\sum_{k=1}^{K}\mathbf{X}(k)\mathbf{X}^H(k)
\]

理想统计形式为：

\[
\mathbf{R}_{xx}
=
\mathbf{A}\mathbf{P}\mathbf{A}^H+\sigma^2\mathbf{I}
\]

其中：

- \(\mathbf{A}=[\mathbf{a}_{\mathrm{emb}}(\eta_1),\dots,\mathbf{a}_{\mathrm{emb}}(\eta_M)]\)
- \(\mathbf{P}\)：信号协方差矩阵；
- \(\sigma^2\mathbf{I}\)：白噪声协方差矩阵。

### 6.2 特征分解

\[
\mathbf{R}_{xx}
=
\mathbf{E}_s\mathbf{\Lambda}_s\mathbf{E}_s^H
+
\sigma^2\mathbf{E}_n\mathbf{E}_n^H
\]

其中：

- \(\mathbf{E}_s\)：信号子空间；
- \(\mathbf{E}_n\)：噪声子空间。

### 6.3 MUSIC 伪谱

\[
P_{\mathrm{MU}}(\eta)
=
\frac{\|\hat{\mathbf{a}}_{\mathrm{emb}}(\eta)\|^2}
{\|\mathbf{E}_n^H\hat{\mathbf{a}}_{\mathrm{emb}}(\eta)\|^2}
\]

搜索伪谱的 \(M\) 个最大峰值位置，即得到 DOA 估计：

\[
\{\hat{\eta}_m\}_{m=1}^{M}
\]

---

## 7. IEEE 风格伪代码

```text
Algorithm 1: Array Response Interpolation and DOA Estimation
Input:
    Calibration directions {η_l}_{l=1}^L
    Measured embedded responses {a_emb(η_l)}_{l=1}^L
    Ideal responses {a_ideal(η_l)}_{l=1}^L
    Isolated-element correction data {g_e(η_l)}_{l=1}^L if available
    Observation data {X(k)}_{k=1}^K
Output:
    Estimated DOAs {η̂_m}_{m=1}^M

1: Select interpolation model:
2: if Method 1 then
3:     Interpolate a_emb(η) directly
4:     Obtain â_emb(η)
5: else if Method 2 then
6:     Compute g(η_l) = a_emb(η_l) ⊘ a_ideal(η_l)
7:     Interpolate g(η) to obtain ĝ(η)
8:     Reconstruct â_emb(η) = a_ideal(η) ⊙ ĝ(η)
9: else if Method 3 then
10:    if C is known then
11:        Compute g_e(η_l) = [C^{-1}a_emb(η_l)] ⊘ a_ideal(η_l)
12:        Interpolate g_e(η) to obtain ĝ_e(η)
13:        Reconstruct â_emb(η) = C(a_ideal(η) ⊙ ĝ_e(η))
14:    else
15:        Estimate Ĉ by least squares
16:        Compute g̃_e(η) = a_emb(η) ⊘ [Ĉ a_ideal(η)]
17:        Interpolate g̃_e(η) to obtain ĝ̃_e(η)
18:        Reconstruct â_emb(η) = Ĉ a_ideal(η) ⊙ ĝ̃_e(η)
19:    end if
20: end if
21: Form sample covariance matrix R̂_xx from X(k)
22: Perform eigendecomposition of R̂_xx and extract noise subspace E_n
23: Compute MUSIC pseudo-spectrum
        P_MU(η) = ||â_emb(η)||^2 / ||E_n^H â_emb(η)||^2
24: Search the M largest peaks of P_MU(η)
25: Return {η̂_m}_{m=1}^M
```

---

## 8. 算法总结

本文算法的关键不在于采用了多复杂的插值器，而在于：

1. **利用理想阵列响应剥离几何相位结构；**
2. **利用互耦矩阵进一步剥离方向无关的耦合结构；**
3. **只对剩余更平滑的校正向量进行插值；**
4. **最后重构阵列响应并送入 MUSIC 完成 DOA 估计。**

因此，三种方法的性能关系通常为：

\[
\text{Method 3} > \text{Method 2} > \text{Method 1}
\]

即：越能提前提取物理结构，后续插值越准确，最终 DOA 估计性能越好。
