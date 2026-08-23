# osu!lazer 顶部工具栏与主菜单研究报告

研究对象：osu!lazer 源码库 `/home/Sighthesia/0_Files/Producing/Software/Quickshell/osu`
覆盖：`osu.Game/Overlays/Toolbar/`（Toolbar、ToolbarButton、ToolbarUserButton、ToolbarOverlayToggleButton、ToolbarClock 等）与 `osu.Game/Screens/Menu/ButtonSystem*.cs`、`MainMenuButton.cs`、`OsuLogo.cs`。

## 1. Toolbar 整体结构

文件：`Overlays/Toolbar/Toolbar.cs`

- 高度 `HEIGHT = 40`，tooltip 区高 30；背景半透明深色 + 底部渐变衬底
- **显示**：`MoveToY(0, 500, OutQuint)` + `FadeIn(125ms=500/4, OutQuint)`；渐变衬底 `FadeIn(2500, OutQuint)`
- **隐藏**：`MoveToY(-DrawSize.Y, 500, InQuint)` + `FadeOut(500, InQuint)`；渐变衬底 `FadeOut(200, OutQuint)`
- 渐戏进入时整条上滑隐藏，回到菜单时滑回 —— 与全屏内容状态联动

## 2. ToolbarButton hover / 激活反馈

文件：`Overlays/Toolbar/ToolbarButton.cs:83-192`、`ToolbarOverlayToggleButton.cs:54-74`

- 按钮圆角 **6**（CornerExponent 3），padding 3
- **hover 背景**：Gray(80) @ α180 additive 层，进入 300ms In / 离开 200ms Out —— additive 发光的单色 hover 是顶栏质感核心
- **点击 flash**：White @ α100，50ms 入 + 800ms OutQuint 出
- **激活态**（overlay 开关按钮）：Carmine 红 @ α180，200ms OutQuint 切换 —— 三态分离：hover 白光 / click 闪光 / active 常亮红

## 3. 图标与文字排版

- 图标尺寸 **20×20**
- 文字 OsuSpriteText 默认字号；图标与文字水平 FillFlow 排布，间距紧凑（按钮 padding 3）
- tooltip 显示在 toolbar 下方 30px 区域内（TOOLTIP_HEIGHT = 30）

### 3.1 按钮几何与比例（逐文件核实）

- **按钮是撑满栏高的正方形**：`ButtonContent.Width = Toolbar.HEIGHT`（40×40），`RelativeSizeAxes = Y`（ToolbarButton.cs:82-84）
- PADDING=3 是 `ButtonContent` 的内边距 → **可见 hover/flash 表面为 34×34**，圆角 6（Exponent 3）
- 标准图标 `ConstrainedIconContainer Size=(20)` 居中于 34 面内（每侧余白 7px）
- **关键比例**：图标:栏高 = 50%；hover面:栏高 = 85%（40−2×3）；图标:hover面 ≈ 59%
- 特例放大件：用户头像 **32×32**（80% 栏高，圆角 4 + 阴影）；模拟表盘 **22×22**（55%）
- 带文字按钮的 Flow 左右各留 `HEIGHT/2`（20px）水平内边距
- **按钮横向 Spacing = 0**：FillFlow 不设间隔，视觉 6px 间隙由相邻按钮各自的 3px 内边距拼出；左右按钮组直接贴屏幕边缘，无额外水平 padding
- RulesetSelector 激活指示条高 3、宽 18（ToolbarRulesetSelector.cs:66）——细条带指示而非描边

## 4. 细节交互

### ToolbarUserButton
- API 连接状态直接改写自身 TooltipMain/TooltipSub（"连接中…" / "正在尝试重新连接"，ToolbarUserButton.cs:113-145），异常叠加黄色警告图标 —— **状态文字内联于 tooltip，不弹窗不占新空间**

### ToolbarClock
- 点击循环切换形态并持久化：Digital → Analog → Full → DigitalWithRuntime；24h 制独立开关即时生效立即刷新（不等下一秒，ToolbarClock.cs:53）—— "点击即切换形态"而非藏进设置面板

## 5. ButtonSystem 主菜单（logo 侧边大按钮）

文件：`Screens/Menu/ButtonSystem.cs`、`Screens/Menu/MainMenuButton.cs`、`Graphics/Sprites/OsuLogo.cs`

- 主菜单按钮尺寸 **140×100**，WEDGE 形（右侧 20px 斜切 Shear），多个 wedge 几何拼接成侧边栏
- **hover 扩宽 ×1.5，500ms OutElastic**（MainMenuButton.cs:229）；图标 hover 时旋转+位移微动，离开 `RotateTo(0)/MoveTo(Zero), 500, Out` + `ScaleTo(1, 200, Out)`
- **logo hover 放大 ×1.1，500ms OutElastic**（OsuLogo.cs:419）
- **logo 呼吸**：−2% 振幅缩放循环，beatLength×2 周期 OutQuint 回弹（OsuLogo.cs:321-323）—— 跟随音乐节拍
- 状态机：Initial → TopLevel → Play → Exiting，状态间切换统一延迟 150ms（Initial 起始，ButtonSystem.cs:441）；按钮组随状态级联展开/收回
- logo 进出：`MoveTo((0.5f), 800, OutExpo)` + `ScaleTo(1, 800, OutExpo)` 进入；离开 `ScaleTo(0.5, 200, In)`

## 6. 设计决策总结

1. **Additive 发光的单色 hover**：不用换底色，用 additive 半透明白/灰层点亮
2. **语义分离的三态反馈**：hover（白光）/ click（短闪光）/ active（常亮 accent 色）各自独立视觉通道
3. **数据驱动的微动画内联在组件内部**：时钟形态、连接状态等直接在组件内交互，不打断主流程
4. **切变几何拼接**：Wedge 斜切形状是 osu!lazer 主菜单的魂，与 Afloat 的 osu-sharp 视觉语言同构
5. **多层分职的节拍动画**：呼吸跟随音乐节拍，状态切换统一 150ms 延迟节奏
6. **动画不对称原则**：toolbar 弹入 500ms / 衬底进 2500ms 出 200ms；hover 进 300 出 200 —— 保持"打断永远顺滑"比精确数值更重要

## 关键常量速查表

| 用途 | 数值 | 出处 |
|---|---|---|
| Toolbar 高度 | 40 | Toolbar.cs:26 |
| 按钮 padding | 3 | ToolbarButton.cs:26 |
| hover 背景 | Gray(80)/α180 Additive，300ms In / 200ms Out | ToolbarButton.cs:90-192 |
| 点击 flash | 白 α100，50ms 入 + 800ms OutQuint 出 | ToolbarButton.cs:176 |
| 激活态 | Carmine α180，200ms OutQuint | ToolbarOverlayToggleButton.cs:54-74 |
| 按钮圆角 | 6（Exponent 3） | ToolbarButton.cs:83 |
| 图标尺寸 | 20×20（=50% 栏高；hover 面的 ≈59%） | ToolbarButton.cs:117 |
| 按钮形状 | 40×40 正方形撑满栏高，可见面 34×34 | ToolbarButton.cs:82-84 |
| 按钮横向间距 | FillFlow Spacing=0，视觉间隙=相邻 padding 之和(6px) | Toolbar.cs:100-119 |
| 特例图标 | 头像 32×32（80%）；模拟表盘 22×22 | ToolbarUserButton.cs:58 / AnalogClockDisplay.cs:28 |
| 显隐动画 | MoveToY ±500ms，OutQuint 进 / InQuint 出 | Toolbar.cs:289-298 |
| 主菜单按钮 | 140×100，WEDGE 20 切变 | ButtonSystem.cs:38-39 |
| hover 扩宽 | ×1.5，500ms OutElastic | MainMenuButton.cs:229 |
| logo hover | ×1.1，500ms OutElastic | OsuLogo.cs:419 |
| logo 呼吸 | −2% 振幅缩放，beatLength×2 OutQuint 回弹 | OsuLogo.cs:321-323 |
| 状态切换延迟 | 150ms（Initial 起始） | ButtonSystem.cs:441 |

## 7. Afloat 移植映射（modules/bar，已实现）

Afloat 顶栏组件（`modules/bar/widgets/`）按上述规格移植，全部数值收敛在 `LazerTheme` 令牌，绑定实时栏高设置（40–64 clamp），改栏高自动缩放：

| LazerTheme 令牌 | 定义 | osu 对应 |
|---|---|---|
| `barWidgetGutter` = 3 | 组件上下留白 | ToolbarButton PADDING |
| `barWidgetHeight` = 栏高−6 | 组件（pill/hover 面）高度 | 可见面 34 @40 |
| `barGlyphSize` = round(栏高×0.5) | 标准图标尺寸 | 图标 20 @40 |

- **纯图标按钮为正方形**：`implicitWidth = barWidgetHeight`（SettingsButton、Notifications、Workspaces 方块）
- 带文字的 pill（媒体/音量/亮度/时钟）图标取 `barGlyphSize − 4` 平衡文字
- 按钮横向间隔由 `BarContent` SectionRow 的 `BarLayoutSections.widgetSpacing`(6) 提供，等效 osu 的"0 Spacing + 相邻 padding"
- hover 面用直角色块（sharp 语言），不用 osu 的圆角 6；三态反馈沿用 IconButton 的 hover swap + click flash
- 教训：图标比例以**源码核实值为准**——曾按直觉放大到栏高 71%，osu 实际是"大方块小图标"（50%），空间给 hover 表面而非字形
