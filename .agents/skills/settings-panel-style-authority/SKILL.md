---
name: settings-panel-style-authority
description: 在 Afloat 中实现任何新的可见 QML 表面、交互反馈、滚动行为或动效之前必须加载。设置面板是项目风格的权威样本：高亮、点击闪烁、组件状态、通用滚动（边缘接管/橡皮筋阻力/回弹）都必须以样本实现为准复用，不得另起一套。
---

# Lazer 设置面板风格权威

设置面板是 Afloat 全项目的风格权威样本。任何新的可见效果——高亮、点击反馈、按压形变、滚动、动效曲线——**先在下面的权威源文件里找到对应实现，再复用其模式与数值**。找不到对应模式时才允许新设计，且新设计必须回写本 skill 或说明理由。

## 权威源文件

| 模式 | 权威实现 |
| --- | --- |
| 行卡片 / hover 高亮 / 焦点环 / 点击闪烁 | `modules/lazerbar/LazerSettingsRow.qml` |
| 分类区块 / 压暗遮罩 / 标题分隔线 | `modules/lazerbar/LazerSettingsSection.qml` |
| 通用滚动系统（接管区 / 阻力 / 回弹 / 波浪挂起） | `modules/lazerbar/LazerSettingsSections.qml` |
| 导航项高亮 / 侧栏点击闪烁 | `modules/lazerbar/LazerSettingsSidebar.qml`、`LazerSettingsNavItem.qml` |
| 全部时长与缓动常量 | `modules/lazerbar/MotionTokens.qml` |
| 颜色令牌 | `modules/lazerbar/LazerTheme.qml` |

## 动效令牌规则

- 一切时长、缓动、位移比例必须引用 `MotionTokens`，禁止在组件内写魔法数。常用值：`fast=100`（hover/颜色切换）、`slow=240`(展开收起/淡入)、`medium=160`、`page=320`；主缓动为 `Easing.OutQuint`。
- 按压形变统一用 `MotionTokens.pressScale`（0.985），悬停不缩放。
- 所有动效必须受 `MotionTokens.reducedMotion` 门控；禁用动画时直接落到终态。

## 高亮与点击闪烁

- hover 高亮：表面颜色在 `<surface>` ↔ `<surface>Hover` 间用 `ColorAnimation { duration: MotionTokens.fast }` 过渡；禁止瞬时切换。
- 焦点/强调环是独立 Rectangle 层（z 高于内容、`enabled: false` 不参与输入），边框 `1.5px` 的 accent 色，宽度过渡用 fast。
- 点击闪烁配方（所有可点组件统一）：透明覆盖矩形填充 `LazerTheme.textPrimary`，激活时播放 `NumberAnimation { from: MotionTokens.clickFlashOpacity; to: 0; duration: MotionTokens.clickFlashDuration; easing.type: MotionTokens.clickFlashEasing }`；通过 `restartFlash()` 触发，reducedMotion 时直接归零。参考 `resetFlashAnimation` 与 `restartResetFlash()`。

## 双层覆盖几何（矩形月牙）

设置面板的标志性构成手法（权威实现：`LazerSettingsRow` 默认按钮），可复用于任何"角部附属控件嵌进主表面"的场景：

- 下层是附属控件表面，上层是带圆角的主表面；主表面的圆角把下层露出的角裁成**矩形月牙**（一侧直角、一侧被圆角切掉的月牙形），不使用任何遮罩或 clip。
- 逻辑宽度与视觉宽度分离：逻辑宽度是交互区（28px），视觉宽度 = 逻辑宽度 + 主表面圆角（34px）；多出的圆角宽度向主表面内侧延伸并被裁掉。
- 图标以可见区域为居中基准，不以扩展后的视觉宽度为基准。
- 状态表达仍走色块亮度/hover swap，月牙形态本身静态不变。

## 输入隔离

- hover 观察（HoverHandler/MouseArea）不得吞掉内嵌控件的指针事件：全行 catcher 用 `blocking: false`，按钮区域留独立 handler。
- 组件不可见或未揭示时必须同时关闭输入：用统一的 `interactable` 类属性门控（如 `matchesSearch && !revealHeld`），不要只依赖 `visible`。

## 通用滚动系统（复用于任何可滚列表）

以下契约实现在 `LazerSettingsSections.qml`，新列表优先整体复用该组件而非复制逻辑：

- **边缘接管区**：距边界 `edgeTakeoverDistance`（80px）内的滚轮增量绕过 Flickable 平滑队列，先 `cancelFlick()` 再驱动一个短追逐动画（`edgeDriveAnim`，80ms OutQuint）。原因：Flickable 的滚轮平滑队列会让 contentY 落后用户意图数百毫秒。
- **橡皮筋阻力**：越界后的步长按已拉伸比例衰减（`_resistedTarget`：`delta * (1 - past/overscrollDistance)`），形成"弹簧拉紧"的到头提示；`overscrollDistance = 88`。
- **回落**：输入停止约 `140ms`（edgeSettleTimer）后用 260ms InOutCubic 缓动回边界。
- **回程再推入**：回弹回程阶段收到同向输入必须从当前位置重新弹出，不允许"等动画结束再加滚"。
- **程序滚动让位**：分类跳转等 scrollAnim 进行中若用户在边界滚轮，立即停 anim 接管。
- **波浪挂起**：开场波浪期间（`entranceBusy`）整表滚动禁用（native `interactive` + onWheel 双重守卫），结束后自动恢复。
- 边界情况修改滚动逻辑前，先用 `/tmp/opencode/edgeloop` 式合成滚轮回路验证时序（意图到达→250ms 内回弹必须接管），不要凭感觉调参。

## 结构模式（新增列表型 UI 时照抄）

- **布局/视觉分离**：根 Item 只做布局占位；纯视觉的生长、位移效果放进 clip 包裹层（visualHost），避免视觉动画扰动布局与滚动。
- **间距折叠进高度**：列表 gap 折入子项 height（含完全退出时恰好归零），从布局移除子项时不产生跳变。
- **声明式可见性**：过滤退场用 `!hidden || height > 0.5 || opacity > 0.01` 这类"动画落定后才隐藏"的绑定，配合 Timer 冻结隐藏时机，禁止多信号处理器竞写状态机。

## 已批准的顶栏例外

以下偏差经审视后确认为 lazer 原版忠实还原，仅限顶部栏使用，不得扩散到其他区域：

- **图标按钮 hover 缩放**：`IconButton` / `OsuTopBarButton` 悬停 `hoverScale`、按压 `pressScale`（设置面板规则"悬停不缩放"不适用于栏上图标按钮）。
- **ModeSelector 凹槽胶囊**：容器 `radius 9` + 底部锚定 xScale 0.97，是 lazer 模式选择器的标志性形态；选中指示仍为细条带。

## 禁止事项

- 禁止引入 MotionTokens 之外的时长/缓动常量。
- 禁止新建与 click flash、hover swap、边缘回弹平行的第二套机制。
- 禁止在无 `reducedMotion` 门控的情况下添加动效。
- 修改权威文件中的共享模式时，同步更新本 skill 与 `lazer-settings-surface-details`。
