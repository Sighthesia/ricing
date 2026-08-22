# osu!lazer 通用组件研究报告

研究对象：osu!lazer 源码库 `/home/Sighthesia/0_Files/Producing/Software/Quickshell/osu`

## 1. 颜色体系

### OsuColour（`osu.Game/Graphics/OsuColour.cs`）
- 组织方式：按色族定义 `readonly Color4` 常量，每族五档：`{Colour}Lighter / Light / {Colour} / Dark / Darker`
- 色族：Purple、Pink、Blue、Yellow、Green、Sky、SeaFoam、Red、Orange、Grey* 等
- 关键值：`Blue #66ccff`、`BlueDark #44aadd`（OsuButton 默认底色）、`Yellow #ffcc22`（= Highlighted/强调金）、`Pink #ff66aa`（Ok 按钮）、`Red3`（危险操作）、`ContextMenuGray #223034`（右键菜单底色）
- 用法惯例：**语义色**（与所在视图主题无关的固定含义）才用 OsuColour；跟随视图主题的颜色一律走 OverlayColourProvider

### OverlayColourProvider（`osu.Game/Overlays/OverlayColourProvider.cs`）
- 核心：一个 `Hue` 值生成整套 HSL 色阶 —— `getColour(saturation, lightness)`；`OverlayColourScheme` 枚举提供各 hue（紫 200、蓝 220+ 等）
- 色阶表（saturation, lightness）：
  - `Highlight1 (1, 0.7)` — 高饱和强调色（选中指示器、accent）
  - `Content1 (0.4, 1)` / `Content2 (0.4, 0.9)` — 正文近白
  - `Light1..4 (0.4; 0.8/0.75/0.7/0.5)` — hover/次级文字
  - `Dark1..6 (0.2; 0.35→0.1)` — 控件底
  - `Foreground1 (0.1, 0.6)`
  - `Background1..6 (0.1; 0.4→0.1)` — 表面层次（数字越大越暗越"深"）
- 层次惯例：面板主体 `Background4`，侧栏/搜索条垫底 `Background5`，分隔线/区块 dim `Background5/6`，popover `Background4`

## 2. 字体（`osu.Game/Graphics/OsuFont.cs`）

- 默认字号 `DEFAULT_FONT_SIZE = 16`，默认字重 **Medium**
- 字体族：Torus（正文）、TorusAlternate（标题/flair）、Venera（数字显示，Bold）、Inter
- 语义字号模板 `OsuFont.Style.*`：

| 模板 | 字号 | 字重 |
|---|---|---|
| Title | 32 | Regular（TorusAlternate） |
| Subtitle | 28 | Regular |
| Heading1 | 22 | Bold |
| Heading2 | 18 | SemiBold |
| Body | 16 | Regular |
| Caption1 | 14 | Regular |
| Caption2 | 12 | Regular |

## 3. OsuButton（`osu.Game/Graphics/UserInterface/OsuButton.cs`）

结构：Masking 圆角容器内叠 Background Box + additive 白色 Hover Box + 文字 + additive flashLayer。

- 高度 **40**，圆角 **5**
- 默认底色 `colours.BlueDark`
- **hover 两段式**：additive 白层 `FadeTo(0.2, 40ms, OutQuint).Then().FadeTo(0.1, 800ms, OutQuint)`（先亮后回落）；hover 离开 `FadeOut(800, OutQuint)`；子类可覆写 `HoverLayerFinalAlpha`（如 RoundedButton 设为 0 改用背景提亮方案）
- **点击闪光**：flashLayer（White @ 0.5, additive）`FadeOutFromOne(800ms, OutQuint)`
- **按压弹性**：MouseDown `ScaleTo(0.9, 4000, OutQuint)`（极慢压缩），MouseUp `ScaleTo(1, 1000, OutElastic)` 回弹 —— "打断永远顺滑"
- 禁用态：整体 `FadeColour(Gray, 200, OutQuint)`（乘灰而非降透明度）
- 文字：Bold 字重居中

### OsuHoverContainer（`osu.Game/Graphics/Containers/OsuHoverContainer.cs`）
- 无背景容器的 hover 变色标准件：`FADE_DURATION = 500`，hover 时 EffectTargets `FadeColour(HoverColour, 500, OutQuint)`，离开回 IdleColour；fallback hover=Yellow / idle=White
- Enabled 变化时若正被 hover 会即时切换反馈

## 4. OsuTextBox
- 标准控件高度 **40**（同按钮），圆角 5；焦点时边框/底色向 accent 过渡；placeholder 低透明度常驻；详见 `osu.Game/Graphics/UserInterface/OsuTextBox.cs`（继承 framework TextBox，样式层只管颜色与几何）

## 5. Checkbox 与 SliderBar

### OsuCheckbox（`osu.Game/Graphics/UserInterface/OsuCheckbox.cs` + Nub）
- Nub 为胶囊形滑块：选中填充 accent 色，未选中空心边框
- 切换动画：fill 200ms OutQuint + 宽度 0.75↔1 弹性呼吸（见下 SwitchButton 同源语言）

### OsuSliderBar / RoundedSliderBar
- 轨道高约 **5px** 圆角胶囊，nub 约 **50×15** 圆角块
- 值变化动画 250ms OutQuint；拖动中 nub 即时跟随、绑定值按 TransferValueOnCommit 决定何时写入

## 6. 圆角与几何惯例

| 对象 | 圆角 | 备注 |
|---|---|---|
| 按钮/文本框 | 5 | CornerExponent≈2.5 的 osu! 曲线圆角 |
| 右键菜单 | 4（基础）/5（context） | |
| 新式 Form 控件/RoundedButton | 10 | |
| 对话框卡片 | 20 | 大表面大圆角 |
| Notification 卡片 | 6 | |

## 7. Dropdown chevron 微交互（`OsuDropdown.cs:278-337`）
- 子菜单项 chevron 平时藏在文字左侧偏移 -3px 且 Alpha=0，hover 时 **400ms OutQuint** 滑入归位
- header chevron 展开时 Y 翻转（Scale Y=-1），300ms OutQuint —— 用翻转代替换图标

## 8. RoundedButton 的 hover 策略（`UserInterfaceV2/RoundedButton.cs`）
- 覆写 `HoverLayerFinalAlpha => 0`（去掉白色叠加层），改为**背景色整体提亮**：hover `FadeColour(BackgroundColour.Lighten(0.2f), 300, OutQuint)`，离开 300ms 回落
- 内部铺 TrianglesV2 粒子三角形纹理（垂直渐变 Lighten(0.2)→原色），是 lazer 按钮的招牌质感

## 9. SwitchButton 三态边框语言（`UserInterfaceV2/SwitchButton.cs:102-129`）
- 56×16 全圆轨道、3.2px 白边框
- 未选：透明填充 + `Light4` 边框，宽度缩至 **0.75**（120ms OutExpo）
- hover：边框变 `Highlight1`
- 选中：填充=边框=`Highlight1.Darken(0.1)`，宽度弹回 **1**（200ms OutElasticQuarter）
- 颜色过渡统一 250ms OutQuint。"选中即展开"的宽度呼吸是其现代感来源

## 10. Form 系列（`UserInterfaceV2/`）是新方向
- `FormControlBackground` 统一控件底板、`LabelledSliderBar/TextBox/SwitchButton` 组合"标签+控件+描述"行、`FormNumberBox/FormDropdown` 收拢校验逻辑
- 注释明说旧 UserInterface 控件样式是过渡态，新 UI 以 Form 控件为准 —— 复刻最新观感优先参考 Form 系列

---

## QML 复刻速查表

| 规格 | 数值 |
|---|---|
| 控件标准高度 | 按钮/文本框/dropdown header = **40px** |
| 圆角 | 菜单 4 / 表单类 5 / 新式按钮 10 + exponent≈2.5 |
| accent | Highlight1 = HSL(hue, 100%, 70%) |
| hover 进入 | additive 白层 alpha 0→0.2（40ms）→0.1（800ms），OutQuint |
| 点击闪光 | White@0.5 FadeOutFromOne 800ms |
| 按压缩放 | 0.9~0.75，松开 OutElastic 回弹 |
| checkbox 切换 | fill 200ms OutQuint + 宽度 0.75↔1 弹性 |
| slider | 轨道高 5、nub 50×15、值动画 250ms OutQuint |
| 菜单展开 | 高度 300ms OutQuint，关闭延迟 50ms 后淡出 280ms |
| 禁用态 | 整体 Gray 乘色（200ms）或 Alpha 0.3 |

核心可迁移思想：**单 hue 生成式配色 + 两段式 hover + 弹性打断按压 + 语义音效通道**，四者共同构成 lazer 的"手感"。
