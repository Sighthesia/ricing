# osu!lazer 弹窗/对话框/通知体系研究报告

研究对象：osu!lazer 源码库 `/home/Sighthesia/0_Files/Producing/Software/Quickshell/osu`

---

## 1. DialogOverlay + PopupDialog（模态确认对话框）

### PopupDialog 卡片本体
`osu.Game/Overlays/Dialog/PopupDialog.cs`

- 布局：`RelativeSizeAxes = X; AutoSizeAxes = Y`，居中锚定；宽度由宿主决定
- 圆角：`CornerRadius = 20`，`CornerExponent = 2.5f`
- 阴影：`EdgeEffect Shadow, Black 0.2f, Radius = 14`
- 背景：纯色 `#221a21` + Triangles 三角纹理层（`ColourLight #271e26 / ColourDark #1e171e, TriangleScale = 4`）+ additive flashLayer
- 内容 Padding：垂直 60，元素间距 10
- 图标环（ring）：尺寸 `100×100`，收起态 `20×20`，白边框 `BorderThickness = 5`，图标 50px
- 文字：header 字号 25、body 字号 18，水平 padding 15

### 动画参数（PopupDialog.PopIn/PopOut）
- 常量：`ENTER_DURATION = 500`、`EXIT_DURATION = 500`
- PopIn：content 从 scale 0.7 → `ScaleTo(1, 750, Easing.OutElasticHalf)` + `FadeIn(500, OutQuint)`；ring `ResizeTo(100, 750ms, OutQuint)`；icon `Delay(100)` 后 750ms 缩放进入
- PopOut：`ScaleTo(0.7, 500, Out)` + `FadeOut(500, OutQuint)`
- Flash()：additive 白闪 `FadeInFromZero(80, OutQuint)` → `FadeOutFromOne(1500, OutQuint)`

### 按钮体系
- `osu.Game/Overlays/Dialog/PopupDialogButton.cs`：高 **50**，背景 `#150e14`，TextSize 18
- `PopupDialogOkButton.cs`：粉色（`colours.Pink`），HoverSampleSet.DialogOk
- `PopupDialogCancelButton.cs`：蓝色（`colours.Blue`）
- `PopupDialogDangerousButton.cs`：红色 `Red3` + **HoldToConfirm** 长按进度条（additive Box 宽度随 Progress），tick 音效频率 `1+progress`、音量 `0.1+p/2`、40ms 节流
- 按钮基类 `osu.Game/Graphics/UserInterface/DialogButton.cs`：宽度动画 idle **0.8×** → hover **0.9×**（300ms OutQuint），点击再放大 1.05×（100ms）；剪切 `Shear = OsuGame.SHEAR = (0.2, 0)`；内含 Triangles 纹理与三段渐变 glow；文字 hover 时字间距扩散到 `(1.4, 0)`

### DialogOverlay 遮罩与框架
`osu.Game/Overlays/DialogOverlay.cs`

- 继承 `OsuFocusedOverlayContainer`；自身 `Width = 500`，AutoSize Y，居中
- **遮罩 dim 不是本类实现**：全局 dim 由 `OsuGame.updateBlockingOverlayFade()`（`osu.Game/OsuGame.cs:270`）完成——有 blocking overlay 可见时 `ScreenContainer.FadeColour(Gray(0.5f), 500, Easing.OutQuint)`，即整屏压暗到 50% 灰
- 音频 ducking：PopIn 时音乐 `Duck(DuckVolumeTo=1, DuckDuration=100, RestoreDuration=100)`
- 音效：`UI/dialog-pop-in` / `UI/dialog-pop-out`
- 单对话框模型：Push 时先 Hide 旧对话框；对话框隐藏后 `Delay(EXIT_DURATION).Expire()`
- GlobalAction.Select 触发 OkButton（或第一个按钮）
- 键盘支持（PopupDialog 内）：数字键 1-9 直接触发对应按钮；未选择就关闭时自动触发最后一个按钮（默认取消）

---

## 2. Popover 系统

### OsuPopover
`osu.Game/Graphics/UserInterfaceV2/OsuPopover.cs`（继承 framework 的 `Popover`）

- 圆角：`Body.CornerRadius = 10`，Body 外边距 `Margin = 10`（给阴影留空间）
- 阴影：`Shadow, Offset (0,2), Radius = 5, Black 0.3f`
- Content 默认 `Padding = 20`
- 背景/箭头同色：`colourProvider.Background4`（无 provider 时 `GreySeaFoamDarker`）
- **箭头被禁用**：`CreateArrow() => Empty()` —— lazer 的 popover 无箭头
- 动画：PopIn `ScaleTo(1, 500, OutElasticHalf)` + `FadeIn(250, OutQuint)`；PopOut `ScaleTo(0.7, 500, OutQuint)` + `FadeOut(250, OutQuint)`
- 音效：`UI/overlay-pop-in/out`；GlobalAction.Back 关闭

### 定位逻辑
- `PopoverContainer` 与 `Popover` 基类在 **osu.Framework**（本仓库为 NuGet 依赖，无源码）：PopoverContainer 监听子树内 `IHasPopover.GetPopover()`，弹出物放置于独立 overlay layer，箭头方向/翻转由 framework 按 anchor 空间计算——lazer 侧只覆盖视觉
- 使用模式见 `osu.Game/Overlays/OnlineOverlay.cs:46`（Scroll → ContextMenuContainer → PopoverContainer 层级嵌套）及各业务 popover（如 `Screens/Ranking/CollectionPopover.cs`）

---

## 3. NotificationOverlay + Toast Tray

### NotificationOverlay 主面板
`osu.Game/Overlays/NotificationOverlay.cs`

- 常量：`WIDTH = 320`，`TRANSITION_LENGTH = 600`
- 抽屉式：初始 `X = WIDTH`（藏在屏幕右外），PopIn `MoveToX(0, 600, OutQuint)` + 内容 `FadeTo(1, 300, OutQuint)`；PopOut 反向
- 边缘阴影用 WaveContainer.SHADOW_OPACITY/APPEAR_DURATION 过渡
- 双通道分发：overlay 打开时进永久分区（NotificationSection），关闭时进 toast tray；非激活模式下延迟 250ms 才开始处理通知
- 音效去抖：`OsuGameBase.SAMPLE_DEBOUNCE_TIME` 共享节流；重要通知触发窗口任务栏闪烁

### NotificationOverlayToastTray（toast 堆叠）
`osu.Game/Overlays/NotificationOverlayToastTray.cs`

- 右上角堆叠，`Padding = 20`；FillFlow 排列动画 `LayoutDuration = 150, LayoutEasing = OutQuart`
- 背景为 Box + 竖向渐变（`Background6` Opacity 0.7→0.5）+ `BlurEffect Sigma = 20` 的模糊光晕；高度 = flow 高度 + **120**，alpha 按 `clamp(flowHeight/41) × maxNotificationAlpha` 计算，均用 `Interpolation.DampContinuously(…, 10)` 平滑跟随

### Notification 卡片本体
`osu.Game/Overlays/Notifications/Notification.cs`

- 圆角：`CORNER_RADIUS = 6`；行最小高 60，图标列宽 40，内容 Padding 10，内容间距 15
- 关闭按钮：宽 28、图标 12，hover 背景淡入 `FadeIn(200, OutQuint)`
- 背景：`colourProvider.Background3`，hover 变 `Background2`（200ms OutQuint）
- 进场（LoadComplete）：`FadeInFromZero(200)`；主内容从 `X = DrawSize` 右侧滑入到 0（**500ms, OutQuint**）；白色 additive 初始闪光 `FadeOutFromOne(2000, OutQuart)`
- 高度收缩动画：MainContent `AutoSizeDuration = 400, Easing.OutQuint`
- **自动关闭计时**（ToastTray 内）：普通 **2500ms**，`IsImportant` **12000ms**；hover/拖拽中会重新排队延迟
- 转场进永久存储：移出 flow 后 `MoveToOffset((400, 0), 600, OutQuint)` + `FadeOut(600, OutQuint)`
- 手势物理：拖拽橡皮筋 `pow(length, 0.8)`；旋转 `min(0, X * 0.1)`；左甩关闭阈值 `Rotation < -10 || velocity.X < -0.3`；右甩转发阈值 `X > 30`；弹回动画 800ms `Easing.OutElastic`
- NotificationLight：6×15，脉冲循环 1000ms（0.4↔1 alpha）

---

## 4. OnScreenDisplay / OSD 提示条

### 容器与进出动画
`osu.Game/Overlays/OnScreenDisplay.cs`

- 位置：屏幕 `(0.5, 0.75)` 居中；`CornerRadius = 20`，Masking
- 高度常量：展开 **110**，收起 `height_contracted = 99`（110 × 0.9）
- 进场：`FadeIn(500, OutQuint)` + `ResizeHeightTo(110, 500, OutQuint)`
- 出场：延迟 500ms 后 `FadeOutFromOne(1500, InQuint)` + `ResizeHeightTo(99, 1500, InQuint)`——"快速弹出、缓慢泄气"的呼吸感
- 连续触发时取消旧 fadeOut 重置计时

### 样式
`osu.Game/Overlays/OSD/Toast.cs`

- 最小宽度 **240**（用占位 Container 实现）
- 背景：纯黑 `Alpha = 0.7f`
- Description：字号 14 Bold、字间距 1，顶部居中，Padding 10
- Value：字号 24 Light，居中
- ExtraText（快捷键）：字号 12 Bold，Alpha 0.3，底部 margin 15

`osu.Game/Overlays/OSD/TrackedSettingToast.cs`

- OptionLight 指示灯：25×5、圆角 3、glow `Radius 8 / 强度 0.4 / BlueDark`，过渡 300ms OutQuint；灯组距底 40
- 音效：`UI/osd-on/off/change`，change 音调随选中项映射 `1 + idx/(n-1)*0.25`

---

## 5. FullscreenOverlay / OnlineOverlay 弹出框架

继承链：`FullscreenOverlay<T> : WaveOverlayContainer : OsuFocusedOverlayContainer : FocusedOverlayContainer`

### WaveContainer（波浪底层）
`osu.Game/Graphics/Containers/WaveContainer.cs`

- 常量：`APPEAR_DURATION = 800`、`DISAPPEAR_DURATION = 500`、`SHADOW_OPACITY = 0.2f`
- 四层波浪 Rotation：13 / -7 / 4 / -2，FinalPosition Y：**-930 / -560 / -390 / -220**
- 波浪 easing：show `OutSine`、hide `InSine`；内容容器 `MoveToY(0, 800, OutQuint)` 进、`MoveToY(2, 500, In)` 出
- 音效：`UI/wave-pop-in` / `UI/overlay-big-pop-out`

### 各层补充
`osu.Game/Overlays/WaveOverlayContainer.cs`

- `WIDTH_PADDING = 80`、`HORIZONTAL_PADDING = 50`
- PopIn：`FadeIn(100, OutQuint)` + Waves.Show()；PopOut：`FadeOut(500, InQuint)`

`osu.Game/Overlays/FullscreenOverlay.cs`

- 面板宽度 **85% 屏宽**（`Width = 0.85f`），TopCentre 锚定，Masking
- Hollow 边缘阴影 Radius 10，PopIn 时渐入至 `SHADOW_OPACITY`（800ms Out），PopOut 渐出后回调 `PopOutComplete()`
- 波浪配色取自 ColourProvider：Light4 / Light3 / Dark4 / Dark3；面板底色 Background5

`osu.Game/Overlays/OnlineOverlay.cs`

- 内容层级固定为：`OverlayScrollContainer → OsuContextMenuContainer → PopoverContainer → Header(Depth=float.MinValue) + content`，外挂 `LoadingLayer(true)` 并按 Header 可见高度动态让位

---

## 6. 输入隔离手段

`osu.Game/Graphics/InputBlockingContainer.cs`

- 最简实现：`OnHover / OnMouseDown / OnClick` 全部返回 `true` 吞掉穿透事件（注意会连右键一起挡掉）

`osu.Game/Graphics/Containers/OsuFocusedOverlayContainer.cs`

- `BlockNonPositionalInput = true`：阻断键盘/非定位输入
- `BlockScreenWideMouse`（默认随 BlockPositionalInput）：覆写 `ReceivePositionalInputAt` 全屏接收，配合 MouseDown/MouseUp 记录"按下点在面板外"实现**点击外部关闭**
- `DimMainContent => true` 时调用 `overlayManager.ShowBlockingOverlay(this)` 触发全局 dim

全局遮罩 dim（无独立遮罩层）：`OsuGame.updateBlockingOverlayFade()`（`osu.Game/OsuGame.cs:270`）——`ScreenContainer.FadeColour(Gray(0.5f), 500, Easing.OutQuint)`，把整个屏幕内容染色成 50% 灰。

> 注：`DimmedInputContainer` 在本仓库源码中不存在（应为 osu.Framework 侧或旧版类型）；本仓库对应的手段就是上述 `InputBlockingContainer` + focused overlay 的 `BlockNonPositionalInput` + 全局灰度染色的组合。

---

## 关键常量速查表

| 场景 | 尺寸 | 进场 | 出场 |
|---|---|---|---|
| PopupDialog | overlay 宽 500；圆角 20 | scale 0.7→1, 750ms OutElasticHalf + fade 500 OutQuint | scale→0.7, 500 Out |
| 对话框按钮 | 高 50，宽 0.8→0.9× | hover 300ms OutQuint | 150ms 回缩 |
| OsuPopover | 圆角 10，padding 20 | scale 500 OutElasticHalf + fade 250 | scale→0.7, fade 250 |
| Notification 卡片 | 圆角 6，最小高 60 | slide 500 OutQuint + fade 200 | fling 600 In / 100 直切 |
| Toast tray | 边距 20 | layout 150 OutQuart | 转发 offset 400, 600 OutQuint |
| 自动关闭 | 普通 2500ms / 重要 12000ms | — | — |
| OSD toast | 高 110→99，最小宽 240 | fade+resize 500 OutQuint | 延迟 500ms 后 1500 InQuint |
| 全屏 Overlay（波浪） | 宽 85% 屏 | 波浪 -930/-560/-390/-220，800ms OutSine + 内容 MoveToY(0) 800 OutQuint；本体 FadeIn 100 | 波浪 500ms InSine + 内容 MoveToY(2) 500 In；本体 FadeOut 500 InQuint |
| NotificationOverlay 抽屉 | 宽 320 | MoveToX(0) 600 OutQuint，内容 fade 300 | MoveToX(320) 600 OutQuint |
| 全局 dim | Gray(0.5f) 染色 | 500ms OutQuint 渐入 | 同参数渐出 |

---

## 跨体系共性设计总结

1. **统一弹性进场曲线**：对话框与 Popover 都用 `OutElasticHalf` 做 scale 回弹（0.7→1），fade 用 `OutQuint`——弹性只给形变、透明度保持平滑。
2. **遮罩即染色**：lazer 没有黑色半透明遮罩层，dim 是对 `ScreenContainer` 做 `FadeColour(Gray(0.5f), 500, OutQuint)`，天然支持多 overlay 叠加计数。
3. **双段式通知生命周期**：toast（短暂、右上、可拖拽）→ 自动转发（offset 400 飞入抽屉）→ 永久分区（历史记录），用同一 Drawable 迁移父节点而非重建。
4. **"快进慢出"节奏**：OSD 进 500ms / 出 1500ms；DialogButton hover 展开 300ms / 回缩 150ms——进场果断、离场从容是全局惯例。
5. **音效与动画同源**：每个 PopIn/PopOut 配对采样，节流共享 `SAMPLE_DEBOUNCE_TIME`；危险操作有独立的 tick→confirm 音调爬升。
