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
| 图标尺寸 | 20×20 | ToolbarButton.cs:117 |
| 显隐动画 | MoveToY ±500ms，OutQuint 进 / InQuint 出 | Toolbar.cs:289-298 |
| 主菜单按钮 | 140×100，WEDGE 20 切变 | ButtonSystem.cs:38-39 |
| hover 扩宽 | ×1.5，500ms OutElastic | MainMenuButton.cs:229 |
| logo hover | ×1.1，500ms OutElastic | OsuLogo.cs:419 |
| logo 呼吸 | −2% 振幅缩放，beatLength×2 OutQuint 回弹 | OsuLogo.cs:321-323 |
| 状态切换延迟 | 150ms（Initial 起始） | ButtonSystem.cs:441 |
