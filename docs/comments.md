# 项目阶段性判断报告（基于 `local-1539bcdf` V3-Revised screening）

- Version hash: `local-1539bcdf`
- Base HEAD: `7a31dd1`
- Review target: pending local run / `results/local-1539bcdf/` V3-Revised guarded screening
- Review status: reviewed; current comments match the pending V3-Revised screening batch
- Main comments: V3-Revised is a successful safety repair with initial task-gain recovery, but Case 9 is not fully won yet.
- Conflicts with log/code: no direct conflict with `docs/research-log.md`; both say this is screening only and should not enter full `1:10` yet.
- Next action: keep the guard system stable and tune only the Case 9 pair-task surrogate, stable-rate alignment, and task-pair distribution.

## 原始评阅正文

我按你这次最新项目的 **代码 + results + research-log** 看完了，**不把 comments 当依据**，只看你基于 `proposed_algorithm_v3_initial_screening.md` 做出来的最新进展。

先给一句总判断：

**这次是一次“明显有效的修正”，而且修正方向是正确的。**
它没有把 V3 直接做成最终算法，但它已经把 V3 从“明显不安全、会拉坏几何”的版本，推进成了“几何上基本守住、Case 9 开始出现收益苗头”的版本。

这比你上一个 `87d7f16` screening 进展明显。

------

# 一、这次最新进展，最核心的变化是什么

如果把你最新这一版 `local-1539bcdf` 和上一版 `87d7f16` 直接比较，最重要的变化不是“Case 9 突然变得很强”，而是：

> **V3 的“安全性问题”基本被修掉了。**

也就是说，你这次改动真正解决的是：

- 不再明显破坏 ARD 在校准角上的精确性
- 不再明显拉坏全局未见方向几何
- 不再在 Case 10 随机 split 上出现明显泛化崩坏
- 同时在 Case 9 上开始拿到一点任务收益

这就是这次最重要的进展。

------

# 二、这次最值得肯定的地方

## 1. 校准角保护做对了

上一版 `87d7f16` 最致命的问题之一，就是：

- V3 的 task residual 把 ARD 在校准角上的精确穿越性质拉坏了
- representative Case 3 模型里，校准角误差能到 **`2.54e-2`**

而这次 `local-1539bcdf` 的 log 里，guard metrics 变成了：

- calibration drift：**`1.81e-16`**
- anchor RMS drift：**`0.001747`**
- guard relative excess：**`0.001159`**

这说明你这次引入的：

- calibration-null gate
- trust-radius residual
- stronger anchor
- guard-based fallback

不是摆设，是真正起作用了。

**这是这次最成功的改动。**

------

## 2. Case 3 被明显救回来了

上一版 `87d7f16` 在 `L=9` 时：

- `ARD`: **0.001034**
- `V3`: **0.017357**

这已经是明显退化。

而这次 `local-1539bcdf`：

- `ARD`: **0.001034**
- `V3-Revised`: **0.001917**

edge error：

- 上一版：**0.017567**
- 这版：**0.002993**

worst-10%：

- 上一版：**0.017536**
- 这版：**0.002882**

这说明什么？

说明你现在的 V3-Revised 已经不再是“为了 task objective 把全局流形弄坏”的版本了。
它和 ARD 之间虽然还有小差距，但已经从“严重退化”回到了“轻微退化且仍在 guard 内”。

这个结果非常重要，因为它说明 V3 路线现在至少在几何层面变得可控了。

------

## 3. Case 10 也被拉回来了

上一版 `87d7f16`：

- `ARD` mean manifold error：**0.005644**
- `V3`：**0.065962**

这差距非常大。

而这次 `local-1539bcdf`：

- `ARD`: **0.005644**
- `V3-Revised`: **0.006080**

几乎贴住了。

同时 mean DOA RMSE：

- `ARD`: **0.103499**
- `V3-Revised`: **0.103163**

这里 V3-Revised 甚至略好一点。

这个结果说明：

> **你这次不是只把 Case 3 的几何拉回来了，而是把“随机 split 下的稳健性”也一起修回来了。**

这很关键，因为它说明 V3-Revised 已经不再是只会在固定校准划分上工作的小技巧。

------

## 4. Case 7 还有轻微正收益

在高 SNR 单源上，这次也不是白修。

Case 7 在 `20 dB`：

- `ARD`: **0.002828**
- `V3-Revised`: **0.002309**

mean abs bias：

- `ARD`: **0.000040**
- `V3-Revised`: **0.000027**

这个提升不算大，但它很干净：

- 没有牺牲几何安全
- 没有牺牲随机泛化
- 单源高 SNR 还有一点增益

这说明 V3-Revised 已经开始具备“在不破坏 ARD 的前提下，买一点任务收益”的能力了。

------

# 三、这次还没有解决的核心问题

## Case 9 仍然没有被真正拿下

这是当前唯一真正没过关的地方。

这次 `local-1539bcdf` 的 Case 9：

### mean resolution

- `ARD`: **0.124800**
- `V1`: **0.130000**
- `V3-Revised`: **0.126822**

### mean stable rate

- `ARD`: **0.035400**
- `V1`: **0.037933**
- `V3-Revised`: **0.033933**

这说明：

### 好消息

- V3-Revised 的 mean resolution 已经 **略高于 ARD**
- 比上一版 `87d7f16` 的 **0.122018** 明显进了一步

### 但坏消息

- 它还是 **没有超过 V1**
- stable rate 也 **低于 ARD 和 V1**

所以从最严格的筛选标准看：

> **Case 9 还不能说过关。**

你现在最多只能说：

- V3-Revised 已经开始在 Case 9 上拿到“局部正向趋势”
- 但还没有形成“可以推广成正式算法结论”的优势

------

# 四、所以这次最新进展，应该怎么定性

我会把这次 `local-1539bcdf` 定义成：

## **一次成功的“安全修复 + 初步增益恢复” screening**

它的意义不是：

- V3 已经成熟了
- 可以直接 full 1:10 了

而是：

- 你把 V3 最大的结构性风险修掉了
- 现在 V3 已经可以在不毁掉几何和随机泛化的前提下，去尝试争取 Case 9 的收益

这在算法开发里是非常重要的一步。

换句话说：

### 旧 V3（87d7f16）回答的是：

- 这条路如果没有 guard，会不会坏？
  答案：**会，而且坏得很明显。**

### 新 V3-Revised（local-1539bcdf）回答的是：

- 如果加上 guard、anchor、calibration-null 和 fallback，这条路还能不能走？
  答案：**能走，而且已经开始出现局部收益。**

这就是这次最有价值的进展。

------

# 五、这次结果说明你的算法路线现在处于什么阶段

我觉得现在已经可以比较清楚地说：

## 当前 V3-Revised 已经从“概念试验”进入“可控调优阶段”

你现在不再需要纠结：

- 这条路线是不是错的

因为结果已经说明：

- **路线本身是对的**
- 问题只在于 **Case 9 的 task gain 还不够强**

所以你现在的阶段不是“重新换方向”，而是：

> **继续沿 V3-Revised 走，但下一步只围绕 Case 9 的 pair-task / surrogate 一致性来小步调优。**

------

# 六、我对你下一步的建议

## 1. 不要回退到旧 V3，也不要回退到 Full V2

因为这次已经说明：

- 旧 V3 最大问题是安全性
- Full V2 最大问题是过强 task refinement

而 V3-Revised 已经把这两个大坑绕开了。

所以现在不该回头。

------

## 2. 继续保持当前 guard 体系，不要先动

你这次最成功的就是这部分：

- calibration-null gate
- trust radius
- stronger anchor
- guard loss
- fallback

这些现在不要轻易再改大。

因为它们是你当前几何安全和随机 split 稳定性的来源。

------

## 3. 下一步只盯 Case 9 的任务项

你现在的主要矛盾已经很明确了：

- Case 3/7/10 基本守住了
- Case 9 还差最后一口气

所以后面不要同时再改太多东西。
我建议只集中改这三类内容：

### （1）pair surrogate 和 benchmark 指标的一致性

现在 log 里自己也写了：

- 下一步要改善 pair surrogate 和 `benchmark_music` 中 resolution / stable-rate 指标的一致性

我完全同意。
因为现在的症状很像：

- 训练时优化的是一套 proxy
- 评估时看的是真正的 stable / resolution
- 二者还没完全对齐

### （2）task pair 分布再往 evaluation pair 分布靠一点

这次你已经有进展了：

- task pair mean abs center 从旧 V3 的 **57.3°**
- 降到了 **42.87°**
- evaluation 的 mean abs center 是 **38.62°**

这说明你已经在往对的方向修。
但还可以再近一点。

### （3）Case 9 不要只看 mean resolution，也盯 stable rate

因为你这次已经证明：

- mean resolution 先起来了
- stable rate 还没起来

这说明 pair-task 可能先改善了“粗分辨”，但还没把“稳定双峰”真正拉起来。
所以下一步 task 设计应该更偏向 stable behavior，而不只是 resolution。

------

# 七、最终判断

一句话总结这次最新进展：

**这次不是“又一次 screening 没过”，而是“V3 路线第一次被你修成了一个几何安全、随机稳健、并且开始在 Case 9 上出现正向趋势的版本”。**

更直白地说：

- **旧 V3：方向对，但不安全**
- **这次 V3-Revised：方向对，而且安全了**
- **现在唯一剩下的问题：Case 9 还没真正赢**

所以我对你这次基于 `proposed_algorithm_v3_initial_screening.md` 的改进评价是：

> **明显有效，而且已经把 V3 推进到了值得继续小步打磨的阶段。**

如果你现在继续推进，我建议就一句话：

**不要再扩 benchmark，不要再看 2D，不要再大改架构；下一步只围绕 Case 9 的 pair-task surrogate 做精修。**
