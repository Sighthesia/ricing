# osu!lazer 侧边栏类组件研究报告

研究对象：osu!lazer 源码（`/home/Sighthesia/0_Files/Producing/Software/Quickshell/osu`）
覆盖组件：`OverlaySidebar`、`SettingsSidebar` / `SidebarButton` / `SidebarIconButton`、`SettingsPanel` / `SettingsOverlay`（含 `SettingsSectionsContainer`）、`SectionsContainer<T>`、`SettingsSection` / `SettingsHeader`、`SettingsItem` / `SettingsItemV2` / `SettingsSlider`、`SettingsRevertToDefaultButton`，以及 `WikiSidebar` / `NewsSidebar` 等 OverlaySidebar 子类。

---

## 1. OverlaySidebar（overlay 通用左侧栏）

文件：`osu.Game/Overlays/OverlaySidebar.cs`

| 项目 | 值 |
|---|---|
| 宽度 | `Width = 250`，`RelativeSizeAxes = Y` |
| 背景 | `OverlayColourProvider.Background4`（HSL: sat 0.1 / light 0.2） |
| 滚动条底槽 | 右侧锚定一条 `Background3` 的 Box，宽 = `OsuScrollContainer.SCROLL_BAR_WIDTH`（10px），`Alpha = 0.5` |
| 内容内边距 | `Vertical = 20, Left = WaveOverlayContainer.HORIZONTAL_PADDING (=50), Right = 30` |

- 色阶逻辑：overlay 主体内容区用 `Background4`（SettingsPanel.cs:103 主面板也是 Background4），侧栏同色但通过**滚动条底槽的 Background3 半透明条**制造层次；即"侧栏与主体同底色 + 细节元素降一档"而非强对比。
- 内容排布：三层容器嵌套 —— 外层 `Padding { Right = -3 }` 抵消滚动条 margin → `SidebarScrollContainer`（OsuScrollContainer 子类）→ 内容层 `Padding { Right = 3 }` 补回 → 最终 padding 层包 `CreateContent()`。子类只需覆写 `CreateContent()`（如 `osu.Game/Overlays/Wiki/WikiSidebar.cs`：小标题 12px Bold + 目录流；`osu.Game/Overlays/News/Sidebar/NewsSidebar.cs` 同构）。
- 细节：滚动/拖拽到边界时事件直接穿透给下层（`OnScroll` / `OnDragStart` 在已滚到头时 return false，OverlaySidebar.cs:77-97）——侧栏不"吞"滚动链。
- 滚动条常量来源：`osu.Game/Graphics/Containers/OsuScrollContainer.cs:32-33`：`SCROLL_BAR_WIDTH = 10`，`SCROLL_BAR_PADDING = 3`。

## 2. SettingsSidebar 与返回按钮

文件：`osu.Game/Overlays/Settings/SettingsSidebar.cs`、`osu.Game/Overlays/Settings/SidebarButton.cs`

### SettingsSidebar
- 继承 `ExpandingContainer`（`osu.Game/Graphics/Containers/ExpandingContainer.cs`）：
  - `CONTRACTED_WIDTH = 70`、`EXPANDED_WIDTH = 170`
  - 展开动画：`ResizeWidthTo(目标宽, TRANSITION_DURATION=500ms, Easing.OutQuint)`（ExpandingContainer.cs:82）
  - 但设置面板中 `ExpandOnHover => false` 且构造里 `Expanded.Value = true` —— **恒定展开为 170**；收缩宽度只在子面板打开时使用（见 §4）。
- 背景：内部一个 `Box` 填 `Background5`，`Depth = float.MaxValue` 垫底（比主面板 Background4 更暗一档）（SettingsSidebar.cs:41-46）。

### BackButton（SettingsSidebar.cs:59-112）
- 尺寸 = 整个侧栏宽（`Size = new Vector2(EXPANDED_WIDTH)` 即 170×170），`Padding = 40`；
- 内容竖排 FillFlow，`Spacing = 5`：
  - ChevronLeft 图标 `Size = 30`，带阴影
  - "back" 文字：`size 16, weight Regular`（小写化处理）
- hover 时整体内容色切换：未 hover `Light3` → hover `Light1`（500ms OutQuint）。

### SidebarButton 基类（SidebarButton.cs）
- hover 反馈不是换背景色，而是一个覆盖层：`Hover.Colour = ColourProvider.Light4`，`FadeTo(IsHovered ? 0.1 : 0, FADE_DURATION, Easing.OutQuint)` —— 即 **Light4 色调以 10% 透明度淡淡罩上**。
- `FADE_DURATION = 500`（ms）。
- 默认 hover 音效 `HoverSampleSet.ButtonSidebar`。

## 3. SettingsOverlay 左侧分类导航

相关文件：
- `osu.Game/Overlays/SettingsPanel.cs`（面板骨架 + `SettingsSectionsContainer`）
- `osu.Game/Graphics/Containers/SectionsContainer.cs`（滚动同步核心）
- `osu.Game/Overlays/Settings/SidebarIconButton.cs`（导航项）
- `osu.Game/Overlays/Settings/SettingsSection.cs`（区块与标题）
- `osu.Game/Overlays/SettingsOverlay.cs`（sections 列表与子面板联动）

### 面板几何
| 项目 | 值 |
|---|---|
| `PANEL_WIDTH` | 400（不含侧栏） |
| 总宽 `WIDTH` | `sidebar_width(170) + PANEL_WIDTH(400) = 570` |
| 内容边距 `CONTENT_MARGINS` | 20 |
| 行内边距 `CONTENT_PADDING` | `{ Left = 12, Right = 22 }`（右侧多留是给恢复默认按钮的空间） |

### 导航按钮 SidebarIconButton（SidebarIconButton.cs）
| 项目 | 值 |
|---|---|
| 高度 | `Height = 46`，外层 `Padding = 5` |
| 图标 | ConstrainedIconContainer `20×20`，`Margin.Left = 25` |
| 文字 | x=60 起，默认色 `OsuColour.Gray(0.6f)`（暗态）；字号走 OsuSpriteText 默认 20px，字重 Regular |
| 选中指示器 | CircularContainer `Width = 4`，高 `inactive 4 → active 18` 弹性变化，`CornerRadius = 1.5f`，`Margin.Left = 9`，颜色 `ColourProvider.Highlight1`（主题紫高饱和色） |

状态切换全部 `FADE_DURATION = 500ms, Easing.OutQuint`：
- **选中**：内容色 → `Content1`（近白）；指示器 FadeIn + 高度 `ResizeHeightTo(18, 500ms, Easing.OutElasticHalf)` 弹性展开
- **未选中**：hover `Light1` / 常态 `Light3`；指示器 FadeOut + 缩回 4

### 滚动同步高亮（SectionsContainer.cs + SettingsPanel.cs）
核心是每帧计算的 `SelectedSection` Bindable（SectionsContainer.cs:245-308）：
- 判定中心点 `scroll_y_centre = 0.1f` —— 取可视区高度 10% 处（非正中）作为当前 section 的判定线；
- 向上容差 `selectionLenienceAboveSection = min(最小区块高/2, 可视高度 × 5%)`，防止向上滚动时立刻取消选中；
- 判定式：取"内容位置 − scroll − 判定线 ≤ 0"的最后一个子项为当前 section；
- **点击导航后**：`lastClickedSection` 锁定选中项，直到用户手动接管滚动（`UserScrolling` 时重置）；
- `ScrollTo(target)` 用 50ms 周期的调度循环反复校正目标位置（内容异步加载会改变偏移，直到误差 <1px 或用户中断）（SectionsContainer.cs:163-206）；
- 点击侧栏按钮 → `SectionsContainer.ScrollTo(section)`（SettingsPanel.cs:292）；反向点击 section 本体也会滚到中心（SettingsSection.OnClick）。

### 区块 dim 联动（SettingsSection.cs:167-177）
非当前 section 上盖一层 `Background5` 的 Box：
- 常态 alpha `0.8`（`inactive_alpha`）
- hover 该区块时降到 `0.5`
- 当前 section 为 `0`
- 过渡 `300ms, Easing.OutQuint`
——**"聚焦当前区块"靠压暗其它区块实现**。且非当前区块不接受输入（`ShouldBeConsideredForInput` 只放行当前 section），首次点击仅触发滚动。

### 区块与标题样式（SettingsSection.cs / SettingsHeader.cs）
| 项目 | 值 |
|---|---|
| 区块分隔条 | 顶部 2px `Background6` 线（`border_size = 2`） |
| 区块标题字体 | TorusAlternate `24px`（`header_size = 24`） |
| 区块内边距 | `Top = 24, Bottom = 40` |
| FlowContent | `Margin.Top = 36`；行距 V2 = 4（V1 `ITEM_SPACING = 14` 已弃用） |
| 固定搜索栏区 | `Vertical = 6` padding 包裹 SearchTextBox |
| 大标题（可折叠 header） | 标题 TorusAlternate `40px`；副标题 `18px, Content2` 色；垂直 padding 20 |
| HeaderBackground 渐显 | `Alpha = -ExpandableHeader.Y / LayoutSize.Y`（SettingsPanel.cs:339）——大标题滚出时搜索栏 Background5 底平滑浮现 |

### SectionsContainer 结构要点
- 支持 `ExpandableHeader`（随滚动折叠的大标题）+ `FixedHeader`（固定搜索栏）+ `Footer`（锚定底部）；
- 折叠逻辑：`offset = min(expandableHeaderSize, currentScroll)`，ExpandableHeader 上移 offset，FixedHeader 紧贴其下（SectionsContainer.cs:272-278）。

## 4. 出现 / 消失动画

统一时长 `TRANSITION_LENGTH = 600`（ms），方向缓动均为 `Easing.OutQuint`（SettingsPanel.cs:175-209）：

### PopIn
- 主内容：`MoveToX(-WIDTH → 0)` 600ms OutQuint
- 侧栏：`MoveToX(-sidebar_width(-170) → 0)` 600ms OutQuint 同步滑入
- 整面板 alpha：0→1 仅用一半时长（`TRANSITION_LENGTH/2 = 300ms` OutQuint）
- 阴影 EdgeEffect 按 WaveContainer 节奏淡入：`WaveContainer.APPEAR_DURATION = 800ms`、`SHADOW_OPACITY = 0.2`（`osu.Game/Graphics/Containers/WaveContainer.cs:19-21`）
- 区块加载延迟 `TRANSITION_LENGTH/3 (=200ms)` 再开始，避免加载卡顿打断入场动画（SettingsPanel.cs:185）

### PopOut
- 镜像滑出：主内容 `MoveToX(-WIDTH)`、侧栏 `MoveToX(-sidebar_width)`，各 600ms OutQuint
- alpha 淡出 300ms OutQuint；阴影按 `WaveContainer.DISAPPEAR_DURATION = 500ms, Easing.In` 淡出

### 侧栏按钮 stagger 入场（SettingsPanel.cs:252-266）
逐个 `FadeInFromZero(500ms, Easing.OutQuint)`，每个按钮延迟递增 **40ms**。

### 子面板（如按键绑定 KeyBindingPanel）联动（SettingsOverlay.cs:107-129）
- 打开：侧栏 `Expanded.Value = false` 收缩到 70（500ms OutQuint）+ 整体 `FadeColour(DarkGray, 300ms, OutQuint)`；主内容区左移 `-PANEL_WIDTH`（500ms OutQuint）让位；主 sections `FadeOut(300ms)`
- 关闭：反向恢复——侧栏回 170 并恢复白色（300ms）、主内容回 0（500ms）、sections `FadeIn(500ms)`
- 这是 ExpandingContainer 收缩动画在设置面板中的唯一实际用途

## 5. 设置行布局规格

文件：`osu.Game/Overlays/Settings/SettingsItem.cs`、`SettingsItemV2.cs`、`SettingsSlider.cs`、`SettingsRevertToDefaultButton.cs`

### 行布局（SettingsItem）
- 行容器：横向填满（`RelativeSizeAxes = X`）、纵向自适应（`AutoSizeAxes = Y`）
- 左侧沟槽：宽 `CONTENT_MARGINS = 20`，放**恢复默认按钮**（垂直居中于 label 或控件）
- 右侧外边距：`Padding.Right = CONTENT_MARGINS (20)`
- 控制区再 `Padding.Left = 20`
- FlowContent 行内纵向间距 `Spacing = (0, 5)`
- 提示文字（notice）：黄/绿色 LinkFlowContainer，底部 margin 5
- 禁用态：label alpha 降到 `0.3`

**没有整行 hover 背景** —— osu!lazer 设置行不做 row-level hover 高亮，反馈都在控件本体和区块级 dim 上。

### RevertToDefaultButton（伪月牙按钮）
| 项目 | 值 |
|---|---|
| 图标 | `IconSize = 10`，`Margin { Left = 12, Right = 5 }` |
| 常态 | icon `Light1` / 底 `Background3` |
| hover | icon `Content2` / 底 `Background2`（300ms OutQuint） |
| 出现 | `FadeIn().MoveToX(WIDTH-10, 200ms, Easing.OutElasticQuarter)` 从右弹入 |
| 消失 | `MoveToX(0, 120ms, Easing.OutExpo)` 后 FadeOut |

### SettingsSlider
- 泛型壳：控件为 `RoundedSliderBar<T>`，相对宽度填满（`RelativeSizeAxes = X`）
- 支持 `TransferValueOnCommit`（拖动中只更新 UI，松手才写入绑定值）与 `KeyboardStep`（键盘步进）
- V2 行（SettingsItemV2）：FillFlow 包裹控件 + 底部 SettingsNote，padding 用 `CONTENT_PADDING { Left=12, Right=22 }`；恢复默认按钮锚右上，高度每帧对齐控件主区高度

## 6. 值得复刻到 Quickshell 桌面 shell（Afloat）的设计决策

1. **统一 500ms OutQuint 状态语言**：所有 hover / 选中 / 指示器动画共用同一时长和缓动，只对"弹性强调"做例外（选中指示器 OutElasticHalf、恢复按钮弹入 OutElasticQuarter）——Afloat 的 lazer 设置面板应固化这一节奏。

2. **低透明度色罩代替背景切换**：SidebarButton 的 hover 是 `Light4 @ alpha 0.1` 罩层而非换底色，避免闪烁感；Quickshell 中可用一个覆盖 Rectangle + opacity 动画等价实现。

3. **滚动同步高亮的三要素**：判定线放可视区顶部 10% 处、向上容差 `min(区块高/2, 可视高度×5%)`、点击后锁定选中直至用户手动滚动——这三点缺一都会导致高亮抖动或跳变。

4. **压暗其它区块代替高亮当前区块**：非当前 section 盖 `Background5` Box（alpha 0.8→hover 0.5，300ms OutQuint），比给当前区块加边框/底色更安静，且天然形成视觉焦点层级。

5. **侧栏与主体同底色、靠暗一档区分**：OverlaySidebar 用 Background4 贴近主体，SettingsSidebar 用 Background5 暗一档垫底——"同色系相邻色阶"是 osu!lazer 层次感的来源，符合 Afloat 的 OverlayColourProvider 用法。

6. **滚动穿透**：侧栏滚到边界时把滚轮事件还给下层（`return false`），Quickshell 里对应 WheelHandler 边界透传/Flickable 边界处理，值得在 island/dockzone 弹出面板中采用。

7. **入场 stagger 序列**：导航按钮逐个 500ms FadeInFromZero、间隔 40ms，配合面板整体滑入——低成本高质感，适合 Afloat 面板首次展开时复刻。

8. **恢复默认按钮的弹入/快出不对称**：出现 200ms OutElasticQuarter（有存在感）、消失 120ms OutExpo 后淡出（利落收尾）——与 lazer-settings-surface-details skill 中已验证的伪月牙按钮契约一致，可保留。

9. **子面板打开时收缩侧栏并降灰**：`Expanded=false` 收至 70 + `FadeColour(DarkGray, 300ms)` 表达"此栏暂时不可用"，比隐藏更保留空间感和上下文。

10. **大标题折叠 + 搜索栏背景渐显**：ExpandableHeader 随滚动折叠，HeaderBackground alpha 与滚动量线性挂钩——长列表顶部信息密度的优雅解法。

---

## 附录：关键数值速查表

| 常量 | 值 | 出处 |
|---|---|---|
| OverlaySidebar 宽度 | 250 | OverlaySidebar.cs:21 |
| SettingsSidebar CONTRACTED / EXPANDED | 70 / 170 | SettingsSidebar.cs:22-23 |
| PANEL_WIDTH / WIDTH | 400 / 570 | SettingsPanel.cs:44-49 |
| CONTENT_MARGINS / CONTENT_PADDING | 20 / L12 R22 | SettingsPanel.cs:32-35 |
| TRANSITION_LENGTH | 600ms | SettingsPanel.cs:37 |
| FADE_DURATION / ExpandingContainer.TRANSITION_DURATION | 500ms | SidebarButton.cs:13 / ExpandingContainer.cs:17 |
| SidebarIconButton 高度 / 图标 / 指示器 | 46 / 20×20 / w4 h4→18 | SidebarIconButton.cs:61,77,91-92 |
| Section 标题字号 / 分隔线 | TorusAlternate 24px / 2px | SettingsSection.cs:40-41,116 |
| Header 标题/副标题字号 | 40 / 18 | SettingsHeader.cs:44-49 |
| scroll_y_centre | 0.1 | SectionsContainer.cs:49 |
| 区块 dim alpha | 0.8 / hover 0.5 / 当前 0 | SettingsSection.cs:30,173 |
| SCROLL_BAR_WIDTH / PADDING | 10 / 3 | OsuScrollContainer.cs:32-33 |
| HORIZONTAL_PADDING（WaveOverlay） | 50 | WaveOverlayContainer.cs:25 |
| Wave APPEAR / DISAPPEAR / SHADOW_OPACITY | 800 / 500 / 0.2 | WaveContainer.cs:19-21 |
| stagger 间隔 / 加载延迟 | 40ms / TRANSITION_LENGTH/3 (200ms) | SettingsPanel.cs:264,185 |
| Revert 按钮 icon / 弹入 / 收回 | 10px / 200ms OutElasticQuarter / 120ms OutExpo | SettingsRevertToDefaultButton.cs:20,84,89 |
