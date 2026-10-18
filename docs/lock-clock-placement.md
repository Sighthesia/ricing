# 锁屏时钟自动定位

日期：2026-10-18 · 分支 `lazer` · 脚本 `scripts/semantic_blank_region.py` · 设置 `外观 → 锁屏时钟自动定位`

## 它解决什么

锁屏时钟默认落在屏幕正中。壁纸正中通常是人群、角色或细节最密的地方，于是时钟压在画面上。自动定位把时钟挪到这张壁纸**没有角色**的一块区域。

判定不是「低方差」：天花板的梁、格栅、榻榻米纹理都很有结构，但它们是空的；角色的头发又大又平滑单色，却是被完全占据的。脚本因此同时看四类局部度量，再叠加到「角色像素」的距离：

| 度量 | 回答什么 |
| --- | --- |
| 墨线密度（Sobel + Laplacian） | 这里是不是一堆线稿 |
| Lab 色度扩散 | 这里是一种涂料，还是二十套服装 |
| 频谱残差显著性 | 相对整张图，这里是不是在抢注意力 |
| 长直线结构占比（Hough + 自相关） | 这是人造结构（梁缝、格栅），可以豁免，并算作加分 |

窗口分数 = 空白均值 + 结构加分 + 距离加分 − 细节像素覆盖 − 角色覆盖 − keep-out 覆盖。

## 依赖

| 依赖 | 是否必需 | 说明 |
| --- | --- | --- |
| `python3` ≥ 3.8 | 必需 | 脚本解释器 |
| `opencv-python` / `opencv-python-headless` | 必需 | 只用到 imread/resize/Sobel/Hough/integral/distanceTransform 等老 API，4.x 可用 |
| `numpy` | 必需 | FFT、积分图 |
| `isnetis.onnx`（176 MB） | 仅设计期 | `--segment-model`；OpenCV 自带 ONNX 导入器，**不需要 onnxruntime** |
| `face_detection_yunet_2023mar.onnx`（232 KB） | 仅设计期 | `--face-model`，OpenCV ≥ 4.5.4 |
| `curl` 或 Python `urllib` | 仅设计期 | `--segment-model auto` 下载模型（huggingface.co，失败回退 hf-mirror.com），下完校验 sha256 |
| ImageMagick | **不再需要** | 旧 `wallpaper_clock_layout.py` 需要，锁屏已不走它 |

```bash
pip install --user opencv-python-headless numpy
```

## 设置项

`外观 → 锁屏时钟自动定位`，持久化键 `appearance.lockClockAutoPlacement`，默认 **开**。

- 关掉后锁屏时钟回到屏幕中心 `(0.5, 0.5)`。
- 依赖不满足时整行**变灰**（`LazerTheme.settingsDisabledAlpha = 0.3`），开关不可操作，行下方出现警告 footer：`! 需要 python3 与 OpenCV (cv2)、numpy`。
- 判定来源：`ClockPlacementService` 启动时跑一次 `python3 -c "import cv2, numpy"`。探测中显示「正在检测运行时…」，失败才落到上面那句；两者都只读探测，不跑扫描。

## 运行时怎么走

```
settings.json ──► SettingsService.appearance.lockClockAutoPlacement / wallpaperPath
                              │
              ┌───────────────┴────────────────┐
              ▼                                ▼
   ClockPlacementService               WallpaperClockLayout（锁屏表面内）
   探测 python3+cv2+numpy             只读缓存 → 命中即应用
   启动后 5s / 换壁纸后预热            未命中则 request() 一次（冷缓存兜底）
   每屏尺寸缓存一份结果                钳制到 x∈[0.06,0.94] y∈[0.10,0.90]
```

**为什么预热**：锁屏表面是在会话真正锁屏时才创建的（实测启动后 12s 内 `semantic_blank_region.py` 一次都没被拉起）。一次扫描 1.4s，而入场波只有 800ms——锁屏时会先看到一个居中的时钟，随后再滑到定位点。预热把结果提前放进缓存，锁屏时直接命中。

**为什么缓存键带壁纸**：同一台机器的屏幕尺寸不会变，但换壁纸必须重算。缓存项存 `{path, result}`，路径不匹配就算 miss。

**成本**：单次扫描 1.4s CPU、206 MB RSS，`nice -n 19`，启动后 5s 才开始，避开壁纸揭示（`wallpaperSwap = 480ms`）。多屏按尺寸排队串行。

## 命令行契约

`--screen-width/--screen-height` 打开运行时模式：按 `PreserveAspectCrop` 把壁纸裁成屏幕所见的样子，**只往 stdout 打一行 JSON，不写任何文件**。

```json
{"ok": true, "center_x": 0.83, "center_y": 0.14, "luminance": 0.457,
 "score": 0.989, "qualified": true, "clock_norm": [0.22, 0.16], "work_size": [1400, 875]}
```

- `center_x/center_y`：归一化到**屏幕**（不是原图）的时钟中心。
- `luminance`：命中区域的平均亮度，留给主题挑文字色。
- `qualified`：该尺寸下是否存在真正干净（角色覆盖 ≤ 1%）的窗口；为 false 时仍会给出最优解。
- 时钟框固定 `--clock 0.22x0.16`、`--margin 0.06`（约等于 48px 数字的 "23:45" 加呼吸空间，见 `ClockPlacementService.clockShape`）。

## 设计期用法

```bash
# 只看这张图最好的几个落点，输出 overlay/裁剪/报告
scripts/semantic_blank_region.py --image art.jpg --outdir /tmp/blank --top 5

# 拿手挑的参考裁剪做校验（会做多尺度模板匹配，逐候选报 coverage/IoU）
scripts/semantic_blank_region.py --image art.jpg --reference crop.png --outdir /tmp/blank

# 打开"角色分割"，把头发/衣物这类平滑角色区域排除
scripts/semantic_blank_region.py --image art.jpg --segment-model auto --outdir /tmp/blank

# 换时钟尺寸看灵敏度
scripts/semantic_blank_region.py --image art.jpg --scales 0.12 0.18 0.24
```

产物：`overlay.png`（热力图 + 候选框 + 参考框 + 角色轮廓）、`candidate_N.png`、`reference_region.png`、`report.json`。

## 已知边界

- **厚涂 / 水彩**：分割模型（anime-seg）在这类画风上会漏检，此时脚本自动退回纯统计，落点可能落在角色衣物上。实测 `103896155_p0.png` 就落在裙子上。运行时路径**不带**模型，所以这条风险在锁屏上是敞开的。
- **模型不进实时路径**：ISNet 单次推理约 1s、常驻内存约 1 GB，放进桌面壳的启动路径不划算。`--segment-model` 只建议在设计期用。
- **`luminance` 是区域均值**：它是一个窗口的平均编码亮度，不是逐像素保证。均值达标的墨色仍可能压在一条深色格栅或角色描边上，所以时间与日期始终带一层逆向描边（见下节）。
- **冷缓存**：启动后 5s 内就锁屏、或刚换壁纸就锁屏，仍会走「居中出现→滑过去」的兜底路径。

## 锁屏时钟墨色

时钟是锁屏上唯一没有面板托底的元素，所以它的颜色不能跟着主题方案走，只能跟着它脚下的壁纸区域走。

`semantic_blank_region.py` 命中窗口时顺带报出该窗口的 `luminance`（`cv2.RGB2GRAY / 255` 的均值，编码值，0..1）。`WallpaperClockLayout` 把它交给 `LockSurface`，`LockSurfaceLogic` 据此求色：

| 步骤 | 做什么 |
| --- | --- |
| 极性 | 比较亮墨（L=`0.99`）与深墨（L=`0.01`）两极对该区域的 WCAG 对比度，谁高用谁 |
| 求解 | 从该极性的「软端」（亮 `0.74` / 深 `0.32`）出发，只朝极端走到刚好达标为止（时间 4.5:1，日期 3.3:1） |
| 描边 | 按极性取逆向 20% / 28% 的微弱描边，只做字形边缘分离，不改填充 |

为什么不直接固定两档：固定亮墨 L=`0.76` 压在亮壁纸区域只有约 1.3:1，这正是原先时钟「糊进背景」的原因。反过来固定深墨在暗区同样失败。而按需求解让时钟在暗区保持自然色相（不漂白成纯白），在亮区只压到刚好够读的深度。

- 区域均值是 `sRGB 编码` 值，对比度计算前会先线性化；直接把 0.46 当线性亮度会让阈值整体偏亮。
- 区域亮度缺失时（冷缓存，`clockLuminance = -1`）回退到主题方案（浅色方案用深墨、深色方案用亮墨），定位结果到达后 `refreshClockTheme()` 只重算时钟三个角色，不动其余快照。
- 区域极性交叉点随 accent 色相/饱和度略微移动（实测 0.46–0.47），不是一条固定阈值线。

## 验证

```bash
scripts/check-shell.sh                     # QML 错误 / 服务失败门禁
scripts/afloat-ipc settings toggle         # 打开设置面板看那一行
```

日志关键字：`ClockPlacementService:`（探测失败、解析失败、扫描 stderr 都从这里出）。启动约 9s 后应看到一次 `semantic_blank_region.py --screen-width … --screen-height …` 被拉起，之后直到换壁纸都不会再跑。
