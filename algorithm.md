# Signal Model and Proposed Algorithm

## 1. Signal Model

### A. Array Response Acquisition and Manifold Definition

Consider an $M$-element receiving array with $M=8$, operating at the carrier frequency $f_0=2.36\,\mathrm{GHz}$. The inter-element spacing is set to $d=\lambda/2$, where $\lambda=c/f_0$ denotes the wavelength and $c$ is the speed of light.

To characterize the practical array response, a full-wave electromagnetic model is established in HFSS. For each incident direction $\theta$, a far-field plane wave is imposed on the array, and the complex voltages at the eight receiving ports are extracted. Therefore, the practical array response corresponding to $\theta$ can be written as

$$
\mathbf{a}_{\mathrm{H}}(\theta)
=
\left[
 v_1(\theta),\,
 v_2(\theta),\,
 \ldots,\,
 v_M(\theta)
\right]^T
\in \mathbb{C}^{M\times 1},
\tag{1}
$$

where $v_m(\theta)$ denotes the complex voltage at the $m$-th port under the plane-wave incidence from direction $\theta$.

Since the array is a passive linear electromagnetic system under the narrowband assumption, the responses of multiple simultaneously impinging far-field sources can be represented by the linear superposition of the corresponding single-direction responses. Hence, the HFSS plane-wave response in (1) can be directly used as the steering vector of the practical array manifold.

To eliminate the irrelevant common phase and global gain ambiguity, the extracted response vector is normalized with respect to the first port and the Euclidean norm, i.e.,

$$
\tilde{\mathbf{a}}_{\mathrm{H}}(\theta)
=
\frac{
\mathbf{a}_{\mathrm{H}}(\theta)\exp\!\left[-j\angle v_1(\theta)\right]
}{
\left\|\mathbf{a}_{\mathrm{H}}(\theta)\right\|_2
}.
\tag{2}
$$

The vector $\tilde{\mathbf{a}}_{\mathrm{H}}(\theta)$ is regarded as the practical array manifold used in the subsequent analysis.

### B. Ideal Steering Vector

For an ideal uniform linear array with half-wavelength spacing, the steering vector corresponding to the incident direction $\theta$ is given by

$$
\mathbf{a}_{\mathrm{I}}(\theta)
=
\left[
1,\,
e^{jkd\sin\theta},\,
e^{j2kd\sin\theta},\,
\ldots,\,
e^{j(M-1)kd\sin\theta}
\right]^T,
\tag{3}
$$

where $k=2\pi/\lambda$ is the wavenumber. Since $d=\lambda/2$, (3) can be further written as

$$
\mathbf{a}_{\mathrm{I}}(\theta)
=
\left[
1,\,
e^{j\pi\sin\theta},\,
e^{j2\pi\sin\theta},\,
\ldots,\,
e^{j(M-1)\pi\sin\theta}
\right]^T.
\tag{4}
$$

For consistency with the practical manifold in (2), the ideal steering vector is also normalized as

$$
\tilde{\mathbf{a}}_{\mathrm{I}}(\theta)
=
\frac{
\mathbf{a}_{\mathrm{I}}(\theta)\exp\!\left[-j\angle a_{\mathrm{I},1}(\theta)\right]
}{
\left\|\mathbf{a}_{\mathrm{I}}(\theta)\right\|_2
}.
\tag{5}
$$

### C. Sparse Calibration-Based Practical Manifold Correction Model

In practical applications, only a small number of known-direction calibration measurements are usually available due to experimental cost and measurement complexity. Let

$$
\Theta_{\mathrm c} = \{\vartheta_1,\vartheta_2,\ldots,\vartheta_L\}
\tag{6}
$$

denote the set of $L$ available calibration directions, where $L$ is much smaller than the number of all candidate directions.

For each $\vartheta_\ell \in \Theta_{\mathrm c}$, the corresponding practical array response $\tilde{\mathbf a}_{\mathrm H}(\vartheta_\ell)$ is assumed to be known from calibration measurement. The objective is to reconstruct a corrected manifold model that can approximate the practical manifold at unseen directions.

To this end, the practical manifold is modeled as a corrected version of the ideal manifold:

$$
\tilde{\mathbf a}(\theta)
=
\mathbf q(\theta) \odot \tilde{\mathbf a}_{\mathrm I}(\theta),
\tag{7}
$$

where $\odot$ denotes the Hadamard product, and

$$
\mathbf q(\theta)
=
\left[q_1(\theta),q_2(\theta),\ldots,q_M(\theta)\right]^T
\tag{8}
$$

is the angle-dependent correction vector.

Each correction coefficient can be decomposed into amplitude and phase terms as

$$
q_m(\theta)=g_m(\theta)e^{j\phi_m(\theta)},
\qquad m=1,2,\ldots,M,
\tag{9}
$$

where $g_m(\theta)$ and $\phi_m(\theta)$ denote the amplitude correction and phase correction, respectively.

According to the preliminary observations on the available HFSS data, the mismatch between the ideal and practical manifolds is mainly dominated by the phase discrepancy. Therefore, a phase-dominant correction model is adopted in the first stage, i.e.,

$$
g_m(\theta)\approx 1,
\tag{10}
$$

and thus

$$
\tilde{\mathbf a}(\theta)
\approx
 e^{j\boldsymbol\phi(\theta)} \odot \tilde{\mathbf a}_{\mathrm I}(\theta),
\tag{11}
$$

where

$$
\boldsymbol\phi(\theta)
=
\left[\phi_1(\theta),\phi_2(\theta),\ldots,\phi_M(\theta)\right]^T.
\tag{12}
$$

To improve the smoothness and physical consistency of the correction model, the residual phase is modeled as a low-dimensional function of $u=\sin\theta$, namely,

$$
\phi_m(\theta)=\phi_m(u)
\approx
\sum_{p=0}^{P} c_{m,p}\,\psi_p(u),
\qquad u=\sin\theta,
\tag{13}
$$

where $\{\psi_p(u)\}_{p=0}^{P}$ denotes a chosen set of basis functions, such as polynomial or Chebyshev bases, and $c_{m,p}$ are the unknown model coefficients determined from the sparse calibration set $\Theta_{\mathrm c}$.

Consequently, the reconstructed practical manifold can be written as

$$
\hat{\mathbf a}(\theta)
=
\exp\!\left(j\hat{\boldsymbol\phi}(\theta)\right)
\odot
\tilde{\mathbf a}_{\mathrm I}(\theta),
\tag{14}
$$

where $\hat{\boldsymbol\phi}(\theta)$ is the estimated residual phase vector obtained from the calibration samples.

It should be emphasized that the proposed model does not rely on dense full-angle calibration in practical deployment. Instead, it aims to infer the practical manifold over unseen directions from a limited number of known-direction calibration samples. In this work, the complete HFSS manifold is used only as a controllable reference to validate the effectiveness and generalization capability of the proposed correction strategy.

### D. Received Signal Model for DOA Estimation

Assume that $K$ narrowband far-field sources simultaneously impinge on the array from directions

$$
\boldsymbol\theta = [\theta_1,\theta_2,\ldots,\theta_K].
\tag{15}
$$

Then the received snapshot at time instant $t$ can be expressed as

$$
\mathbf x(t)
=
\mathbf A(\boldsymbol\theta)\mathbf s(t)+\mathbf n(t),
\tag{16}
$$

where

$$
\mathbf A(\boldsymbol\theta)
=
\left[
\mathbf a(\theta_1),\,
\mathbf a(\theta_2),\,
\ldots,\,
\mathbf a(\theta_K)
\right]
\in\mathbb C^{M\times K}
\tag{17}
$$

is the array manifold matrix, $\mathbf s(t)\in\mathbb C^{K\times 1}$ is the source signal vector, and $\mathbf n(t)\in\mathbb C^{M\times 1}$ is the additive noise vector.

When the practical array manifold is employed, $\mathbf a(\theta_k)$ in (17) can be taken as either the HFSS-extracted manifold $\tilde{\mathbf a}_{\mathrm H}(\theta_k)$ or the reconstructed manifold $\hat{\mathbf a}(\theta_k)$. Accordingly, the snapshot matrix with $N$ temporal samples is

$$
\mathbf X
=
\left[\mathbf x(1),\mathbf x(2),\ldots,\mathbf x(N)\right]
=
\mathbf A(\boldsymbol\theta)\mathbf S+\mathbf N,
\tag{18}
$$

where $\mathbf S\in\mathbb C^{K\times N}$ and $\mathbf N\in\mathbb C^{M\times N}$.

The corresponding covariance matrix is given by

$$
\mathbf R_x
=
\mathbb E\{\mathbf x(t)\mathbf x^H(t)\}
=
\mathbf A(\boldsymbol\theta)\mathbf R_s\mathbf A^H(\boldsymbol\theta)+\mathbf R_n,
\tag{19}
$$

where $\mathbf R_s=\mathbb E\{\mathbf s(t)\mathbf s^H(t)\}$ is the source covariance matrix and $\mathbf R_n=\mathbb E\{\mathbf n(t)\mathbf n^H(t)\}$ is the noise covariance matrix.

### E. Problem Statement in This Work

Let

$$
\Theta_{\mathrm{all}}=
\{\theta^{(1)},\theta^{(2)},\ldots,\theta^{(G)}\}
\tag{20}
$$

be the full angular grid available in the HFSS simulation, and let $\Theta_{\mathrm c}\subset \Theta_{\mathrm{all}}$ denote the sparse calibration subset. In the proposed framework:

1. the responses at $\Theta_{\mathrm c}$ are treated as the only available calibration samples;
2. the remaining directions in $\Theta_{\mathrm{all}}\setminus\Theta_{\mathrm c}$ are regarded as unseen directions;
3. the reconstructed manifold $\hat{\mathbf a}(\theta)$ is evaluated by comparing it with the full HFSS manifold and by assessing the resulting DOA performance.

Therefore, HFSS is used here as a controllable surrogate of practical measurement, while the proposed manifold correction algorithm itself is designed for the realistic scenario in which only a small number of known-direction calibration measurements can be acquired.

---

## 2. Proposed Algorithm

### A. Motivation

Let $\tilde{\mathbf a}_{\mathrm H}(\theta)$ and $\tilde{\mathbf a}_{\mathrm I}(\theta)$ denote the normalized practical manifold and the normalized ideal manifold, respectively. In practice, only a small number of known-direction calibration measurements are available,

$$
\Theta_{\mathrm c}=\{\vartheta_1,\vartheta_2,\ldots,\vartheta_L\},
\qquad L \ll G,
\tag{21}
$$

where $G$ is the number of all candidate directions in the angular sector of interest.

A direct reconstruction of the full practical manifold from sparse samples is severely ill-posed if no structure is imposed. Therefore, instead of reconstructing each steering vector independently, we exploit the fact that the practical manifold is a smoothly distorted version of the ideal one and model the distortion in a low-dimensional parametric form.

Based on the previous experimental observations, the mismatch is mainly dominated by the phase discrepancy. Accordingly, a phase-dominant manifold correction strategy is adopted.

### B. Phase Residual Extraction

For each calibration direction $\vartheta_\ell \in \Theta_{\mathrm c}$, define the element-wise residual between the practical and ideal manifolds as

$$
\mathbf r(\vartheta_\ell)
=
\tilde{\mathbf a}_{\mathrm H}(\vartheta_\ell)
\odot
\tilde{\mathbf a}_{\mathrm I}^{*}(\vartheta_\ell),
\tag{22}
$$

where $(\cdot)^*$ denotes the complex conjugate.

Then, the phase residual vector is extracted as

$$
\boldsymbol\delta(\vartheta_\ell)
=
\angle \mathbf r(\vartheta_\ell)
\in \mathbb R^{M\times 1}.
\tag{23}
$$

For notational convenience, define

$$
u_\ell=\sin\vartheta_\ell,
\qquad \ell=1,2,\ldots,L.
\tag{24}
$$

Since the ideal ULA phase progression is naturally linear in $\sin\theta$, modeling the residual phase as a function of $u=\sin\theta$ yields better smoothness and stability than directly modeling it in $\theta$.

### C. Low-Dimensional Residual Model

For the $m$-th array element, the residual phase is approximated by a low-order basis expansion:

$$
\phi_m(u)
=
\sum_{p=0}^{P} c_{m,p}\,\psi_p(u),
\qquad m=1,2,\ldots,M,
\tag{25}
$$

where

- $\psi_p(u)$ is the $p$-th basis function,
- $P$ is the model order,
- $c_{m,p}$ is the coefficient to be estimated.

Define

$$
\boldsymbol\psi(u)
=
[\psi_0(u),\psi_1(u),\ldots,\psi_P(u)]^T
\in\mathbb R^{Q\times 1},
\qquad Q=P+1.
\tag{26}
$$

Then (25) can be written compactly as

$$
\phi_m(u)=\mathbf c_m^T\boldsymbol\psi(u),
\tag{27}
$$

where $\mathbf c_m\in\mathbb R^{Q\times 1}$ is the coefficient vector of the $m$-th element.

Stacking all elements gives

$$
\boldsymbol\phi(u)=\mathbf C\,\boldsymbol\psi(u),
\tag{28}
$$

where $\mathbf C\in\mathbb R^{M\times Q}$ is the coefficient matrix to be estimated.

### D. Regularized Optimization Formulation

From the calibration measurements, define the phase residual matrix

$$
\mathbf Y
=
\left[
\boldsymbol\delta(\vartheta_1),\,
\boldsymbol\delta(\vartheta_2),\,
\ldots,\,
\boldsymbol\delta(\vartheta_L)
\right]
\in\mathbb R^{M\times L},
\tag{29}
$$

and the basis matrix

$$
\mathbf \Psi
=
\left[
\boldsymbol\psi(u_1),\,
\boldsymbol\psi(u_2),\,
\ldots,\,
\boldsymbol\psi(u_L)
\right]
\in\mathbb R^{Q\times L}.
\tag{30}
$$

The coefficient matrix $\mathbf C$ is estimated by solving the following regularized least-squares problem:

$$
\min_{\mathbf C}
\;\left\|\mathbf Y-\mathbf C\mathbf \Psi\right\|_F^2
+\lambda\left\|\mathbf C\mathbf D\right\|_F^2,
\tag{31}
$$

where $\lambda>0$ is the regularization parameter, and $\mathbf D$ is a smoothing or Tikhonov regularization matrix. The first term enforces data fidelity on the sparse calibration directions, while the second term suppresses overfitting and stabilizes the extrapolation to unseen directions.

#### Closed-form solution

Problem (31) is convex and admits the following closed-form solution:

$$
\hat{\mathbf C}
=
\mathbf Y\mathbf \Psi^T
\left(
\mathbf \Psi\mathbf \Psi^T+\lambda \mathbf D^T\mathbf D
\right)^{-1}.
\tag{32}
$$

Thus, the unknown phase correction model can be obtained directly without iterative optimization.

### E. Corrected Manifold Reconstruction

For any query direction $\theta$, define $u=\sin\theta$. Its estimated phase correction vector is

$$
\hat{\boldsymbol\phi}(\theta)
=
\hat{\mathbf C}\,\boldsymbol\psi(\sin\theta).
\tag{33}
$$

Then the corrected manifold is reconstructed as

$$
\hat{\mathbf a}(\theta)
=
\exp\!\big(j\hat{\boldsymbol\phi}(\theta)\big)
\odot
\tilde{\mathbf a}_{\mathrm I}(\theta),
\tag{34}
$$

where the exponential is taken element-wise.

Finally, to maintain consistency with the calibration data, the reconstructed steering vector is re-normalized by reference-port phase removal and unit-norm scaling, i.e.,

$$
\hat{\mathbf a}(\theta)
\leftarrow
\frac{
\hat{\mathbf a}(\theta)\exp\!\left[-j\angle \hat a_1(\theta)\right]
}{
\|\hat{\mathbf a}(\theta)\|_2
}.
\tag{35}
$$

Equation (35) yields the corrected practical manifold over the entire angular sector, even though only a small number of calibration directions are used.

### F. DOA Estimation Using the Reconstructed Manifold

Once the corrected manifold is obtained, the array manifold matrix for a candidate direction set can be formed as

$$
\hat{\mathbf A}(\boldsymbol\theta)
=
\left[
\hat{\mathbf a}(\theta_1),\,
\hat{\mathbf a}(\theta_2),\,
\ldots,\,
\hat{\mathbf a}(\theta_K)
\right].
\tag{36}
$$

Given the received data matrix $\mathbf X$, the sample covariance matrix is calculated as

$$
\hat{\mathbf R}_x
=
\frac{1}{N}\mathbf X\mathbf X^H.
\tag{37}
$$

Let $\mathbf U_n$ denote the noise subspace obtained from the eigendecomposition of $\hat{\mathbf R}_x$. Then the MUSIC pseudo-spectrum is constructed as

$$
P_{\mathrm{MU}}(\theta)
=
\frac{1}{
\hat{\mathbf a}^H(\theta)
\mathbf U_n\mathbf U_n^H
\hat{\mathbf a}(\theta)
}.
\tag{38}
$$

The DOA estimates are finally obtained from the $K$ dominant peaks of $P_{\mathrm{MU}}(\theta)$.

### G. Optional Nonlinear Refinement

To further reduce the mismatch between the reconstructed manifold and the practical manifold, the closed-form estimate in (32) can be used as an initialization for the following nonlinear refinement:

$$
\min_{\mathbf C}
\sum_{\ell=1}^{L}
\left\|
\tilde{\mathbf a}_{\mathrm H}(\vartheta_\ell)
-
\exp\!\big(j\mathbf C\boldsymbol\psi(u_\ell)\big)
\odot
\tilde{\mathbf a}_{\mathrm I}(\vartheta_\ell)
\right\|_2^2
+
\lambda\left\|\mathbf C\mathbf D\right\|_F^2.
\tag{39}
$$

Problem (39) is nonconvex due to the complex exponential term, but it is smooth and low-dimensional. Therefore, it can be efficiently solved by a few Gauss-Newton or Levenberg-Marquardt iterations initialized by $\hat{\mathbf C}$ from (32). In practice, this refinement is optional; when the mismatch is phase-dominant and smooth, the closed-form solution in (32) is often already sufficient.

### H. Proposed Algorithm Summary

#### Algorithm 1: Sparse Calibration-Based Phase-Corrected Manifold Reconstruction MUSIC

**Input:**

- sparse calibration set $\Theta_{\mathrm c}=\{\vartheta_\ell\}_{\ell=1}^{L}$
- measured practical manifold $\tilde{\mathbf a}_{\mathrm H}(\vartheta_\ell)$
- ideal manifold $\tilde{\mathbf a}_{\mathrm I}(\theta)$
- basis functions $\boldsymbol\psi(u)$
- regularization parameter $\lambda$
- scan grid $\Theta$

**Steps:**

1. Normalize the calibration responses and ideal manifold vectors.
2. Compute the phase residuals $\boldsymbol\delta(\vartheta_\ell)$ using (22)-(23).
3. Construct the basis matrix $\mathbf \Psi$ using $u_\ell=\sin\vartheta_\ell$.
4. Solve the regularized least-squares problem in (31) and obtain $\hat{\mathbf C}$ via (32).
5. For each scan angle $\theta$, reconstruct $\hat{\mathbf a}(\theta)$ using (33)-(35).
6. Form the corrected manifold dictionary and compute the MUSIC spectrum using (38).
7. Detect the dominant peaks and output the DOA estimates.

**Output:**

- corrected practical manifold $\hat{\mathbf a}(\theta)$
- estimated DOAs

### I. Discussion

The proposed algorithm transforms the original ill-posed sparse-calibration manifold recovery problem into a low-dimensional regularized optimization problem. Its main advantages are:

1. **Physical interpretability**: the corrected manifold is explicitly modeled as a residual-modified version of the ideal manifold.
2. **Low calibration burden**: only a small number of known-direction calibration samples are required.
3. **Generalization to unseen directions**: the correction is learned as a smooth function of $\sin\theta$, rather than as a dense lookup table.
4. **Compatibility with existing DOA estimators**: once the corrected manifold is reconstructed, it can be directly plugged into MUSIC or other subspace-based methods.

