# osu!lazer 动画与特效惯例研究报告

研究对象：osu!lazer 源码库 `/home/Sighthesia/0_Files/Producing/Software/Quickshell/osu`

## 1. Easing 使用惯例（全库 grep 统计）

| Easing | 出现次数 | 典型用途 |
|---|---|---|
| **OutQuint** | **1332** | 绝对主力：hover、颜色、位移、展开收起，几乎所有状态过渡 |
| Out | 100 | 简单淡入 |
| OutExpo | 75 | 快进慢出的位移（屏幕切换文字、按钮收回） |
| In | 71 | 淡出/收缩 |
| OutPow10 | 47 | 大幅位移的柔和减速 |
| OutElastic / OutElasticHalf / OutElasticQuarter | 32/27/14 | 弹性强调：logo、选中指示器、按压回弹、popover scale |
| InQuint | 26 | 收场（toolbar 滑出、面板淡出） |
| InOutQuart / InOutSine / InOutCubic | 25/17/14 | 循环/往返动画 |

**结论：默认一切用 OutQuint；弹性只给"形变与强调"，透明度永远平滑。**

## 2. FadeIn/FadeOut 时长统计

- `FadeIn(ms)` 高频：**200(50次) / 300(33) / 500(23) / 100(20) / 250(11)**
- `FadeOut(ms)` 高频：**200(48) / 500(37) / 300(29) / 100(23) / 250(14)**
- 惯例：小反馈 200-300ms；面板级 500ms+；入场常比出场短或对称

## 3. hover 反馈标准写法

1. **additive 白层两段式**（OsuButton）：`FadeTo(0.2, 40, OutQuint).Then().FadeTo(0.1, 800, OutQuint)` —— 先快速点亮再回落到稳定值
2. **整体变色**（OsuHoverContainer）：`FadeColour(hover色, 500, OutQuint)` 双向往返
3. **低透明度色罩**（SidebarButton 等）：覆盖层 `FadeTo(0.1, 500, OutQuint)`
4. **背景提亮**（RoundedButton）：`FadeColour(Lighten(0.2), 300, OutQuint)`
5. **按压缩放**：down 极慢压缩 `ScaleTo(0.9, 4000, OutQuint)`，up 弹性恢复 `ScaleTo(1, 1000, OutElastic)`

## 4. Flash/脉冲特效
- 点击闪光：White@0.5 additive 层 `FadeOutFromOne(800, OutQuint)`
- Notification 初始闪光：`FadeOutFromOne(2000, OutQuart)` 长衰减
- Toolbar 按钮 flash：White α100，50ms 入 + 800ms OutQuint 出

## 5. 粒子特效（`osu.Game/Graphics/ParticleSpewer.cs`、`ParticleExplosion.cs`）
- ParticleSpewer 继承 Sprite，自绘 DrawNode；粒子结构：StartTime/StartPosition/Velocity/Duration/StartAngle/EndAngle/EndScale
- 生命周期插值：alpha = 1-progress（线性衰减）、scale 从 1 lerp 到 EndScale、角度 Start→End、支持 gravity
- `IsPresent = hasActiveParticles` 无粒子即不参与渲染；`Active` Bindable 控制发射开关
- ParticleExplosion：一次性爆发粒子云。QML 复刻可用 Canvas 或粒子 Repeater + Behavior 动画等价实现
- TrianglesV2 三角纹理层：按钮/对话框底纹（ColourLight/ColourDark 双色渐变三角），lazer 质感标志

## 6. 屏幕切换转场

### ScreenWhiteBox（通用白盒屏，`Screens/ScreenWhiteBox.cs`）
- `transition_time = 1000ms`
- 进入：boxContainer 从 scale 0.2 → `ScaleTo(1, 1000, OutElastic)` 弹性放大 + `FadeIn(1000, OutExpo)`；文字 `MoveTo(Vector2.Zero, 1000, OutExpo)`
- 退出：文字移向 `-DrawSize.X/16` + 整体 `FadeOut(1000, OutExpo)`

### OsuScreenStack + ParallaxContainer（`osu.Game/Screens/OsuScreenStack.cs`）
- 视差常量 `DEFAULT_PARALLAX_AMOUNT = 0.02f`（ParallaxContainer.cs:20）
- 实现技巧：内容预放大 `Scale = 1 + |amount|`（1.02 倍过扫描防露边）；偏移 = relativeAmount × size/2 × 0.02
- 视差跟随非逐帧硬跟，而是 **1000ms OutQuint 插值追赶**（惯性感来源）

## 7. Overlay 进出动效

### Toolbar（顶部栏，`Overlays/Toolbar/Toolbar.cs:289-298`）
- 显示：`MoveToY(0, 500, OutQuint)` + `FadeIn(125ms=500/4, OutQuint)`
- 隐藏：`MoveToY(-height, 500, InQuint)` + `FadeOut(500, InQuint)`
- 渐变衬底：进 2500ms OutQuint / 出 200ms —— 不对称节奏

### 全屏波浪 Overlay（WaveContainer）
- `APPEAR_DURATION=800` / `DISAPPEAR_DURATION=500` / `SHADOW_OPACITY=0.2`
- 四层波浪 Rotation 13/-7/4/-2，FinalPosition Y：-930/-560/-390/-220；show OutSine / hide InSine
- 内容 `MoveToY(0, 800, OutQuint)` 进、`MoveToY(2, 500, In)` 出；本体 FadeIn 仅 100ms / FadeOut 500 InQuint

### 弹性弹窗进场
- 对话框/Popover scale 回弹统一：从 0.7 `ScaleTo(1, 750/500, OutElasticHalf)` + fade 用 OutQuint（250-500ms）—— **弹性只给形变，透明度平滑**

### OSD toast 呼吸感（OnScreenDisplay.cs）
- 进：fade+resize 500 OutQuint；出：延迟 500ms 后 1500ms InQuint 缓慢"泄气"

## 8. 特殊效果组件

### MarqueeContainer（跑马灯，`osu.Game/Overlays/MarqueeContainer.cs`）
- 文字超宽时循环横向滚动（速度恒定），不超宽时静止 —— 用于窄空间显示长标题

### HoldToConfirm（`osu.Game/Overlays/HoldToConfirmOverlay.cs`）
- 长按进度环形/条形反馈 + tick 音效频率随进度爬升；松手进度回退

### Notification 手势物理（`Notifications/Notification.cs:394-396`）
- 入场三连：`FadeInFromZero(200)` + 内容 `MoveToX(DrawSize.X→0, 500, OutQuint)` + 白闪 `FadeOutFromOne(2000, OutQuart)`
- 关闭手势回弹：`MoveTo(Vector2.Zero, 800, OutElastic)` + `RotateTo(0, 800, OutElastic)` 双弹性
- 甩动阈值：左甩关闭 `velocity < -0.3 - 0.5×RNG`，右甩转发 `X > 30`

---

## 移植原则总结

1. 一切默认 **OutQuint**；弹性曲线只用于形变(scale/宽度)、透明度保持平滑
2. "快进慢出"不对称：进场果断（40-500ms），离场从容或带延迟（OSD 进 500/出 1500）
3. 打断永远顺滑：所有 transform 可被反向 transform 无缝接管（QML 中对应 Behavior 可被新动画打断）
4. 视差/跟随类动画用长时长插值追赶（1000ms OutQuint）制造惯性，而非逐帧硬跟
5. 大位移配 OutExpo/OutPow10，大表面配弹性 OutElastic*
