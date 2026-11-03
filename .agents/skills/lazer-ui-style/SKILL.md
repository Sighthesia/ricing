---
name: lazer-ui-style
description: "Use when 新增任何可见 QML 元素或形状（面板/卡片/指示条/图标）、调整颜色/圆角/透明度/阴影/间距、实现 hover 与按压反馈（高亮/点击闪烁/默认按钮月牙）、修改滚动行为（边缘接管/橡皮筋阻力/回弹）、编辑设置面板或 LazerSettings* 组件、或改 BarTrayMenu 托盘子菜单的开合变形动效。先判形态层级与过渡覆盖，再复用设置面板权威实现与 MotionTokens 数值，禁止大圆角大表面、硬切颜色状态和第二套平行机制。"
---

# Lazer UI 风格、过渡与表面运动

Afloat 的视觉域：osu!lazer "sharp" 形态语言、风格权威样本（设置面板）、过渡与点击反馈契约、通用滚动系统、波浪 overlay 与托盘子菜单的表面运动，以及 QML 注释约定。结论先行：**主体锐利、细节圆润**；一切时长/缓动引用 `MotionTokens`；任何可感知的样式变化都要过渡；找不到现成模式时先在权威源文件里找，而不是另设计一套。

## 先看这里

- **形态先分层再写数值**：面板、分类区块、整行表面、侧栏、全屏容器一律 `radius: 0` 直角矩形，圆角只给组件内部细节与图标。`radius ≥ 8` 的圆角容器用在面板/区块/整行上就是回归。
- **禁止魔法数**：一切时长、缓动、位移比例引用 `MotionTokens`（`fast=100`、`medium=160`、`slow=240`、`page=320`，主缓动 `Easing.OutQuint`）。
- **可感知的变化必须过渡**：color、opacity、blur、shadow、radius、border intensity、spacing、position、scale，以及任何会改变外观的几何值。
- **所有动效受 `MotionTokens.reducedMotion` 门控**：降低动效时直接落到终态，不保留位移/闪烁/缩放。

## 按症状路由

| 症状 / 任务 | 读这个 |
|---|---|
| 改设置面板、`LazerSettings*` 的 row/分类区块/默认按钮/滑条刻度/hover 隔离，或改完设置面板需要核对层级、尺寸、z-order | `references/settings-panel.md` |
| 改 `BarTrayMenu` 托盘菜单或二级子菜单：揭示/退场看不见、变形瞬移、高度塌成细条、跨面板流转、开合动效 | `references/submenu-motion.md` |

## 通用法则

### 形态层级（圆角归属）

主体锐利，细节圆润。大表面用直角矩形与几何拼接表达层次，圆角只属于组件内部细节与图标。

| 层级 | 形态 | 圆角 | 本项目中对应 |
| --- | --- | --- | --- |
| 大表面 | 直角矩形 | 0 | 面板背景、分类区块 `settingsSection`、侧栏、全屏页、滚动容器 |
| 组件表面 | 直角矩形或轻微圆角 | 0–6 | 行卡片 `cardSurface`、输入框、下拉标题/列表、滑条轨道、搜索框、选择胶囊 `settingsChoiceHeight` |
| 交互细节 | 小圆角 | 4–6（约高度×0.25） | 滑块 thumb、toggle 滑块、选中高亮块、重置区角 |
| 图标/徽标 | 圆角或圆 | ≤ 高度/2 | 图标容器、状态点 |

> 行卡片（`LazerSettingsRow.cardSurface`）按**组件表面**处理，允许保留 6px 圆角；若未来要纯直角整行，将 radius 归零并保留色块层差。

### 几何拼接手法

- **选中指示**：细矩形条带（侧栏 4px 竖条）或菱形色块，不靠圆角描边。
- **方向/指针**：三角形或切角（corner cut）制造锐利感。
- **状态分层**：色块亮度差（分类区块 vs 内部卡片 vs 悬停加深），而不是边框粗细。
- **区块划分**：相邻区块用细 Padding（4px 级）分隔，配合背景亮度差，不用分隔圆角容器。

### 禁止清单

- 面板/区块/整行用 `radius ≥ 8` 的圆角容器。
- 用大圆角描边作为 hover/focus/active 的主要视觉手段。
- 为"柔和"引入 round 风格大表面（与 osu 语言冲突）。
- 无语义地添加菱形/三角/切角装饰。
- 运行中改变 `radius`/切角作为状态反馈（形态是静态定义，状态反馈用色块/亮度/指示条）。
- 引入 `MotionTokens` 之外的时长/缓动常量。
- 新建与 click flash、hover swap、边缘回弹平行的第二套机制。
- 在无 `reducedMotion` 门控的情况下添加动效。

新增视觉变量前自问：它属于哪一层？该层允许圆角吗？形态是否静态？

### 过渡覆盖

每个**可感知**的视觉变量变化都必须过渡，除非有明确理由不这样做。需要给出过渡行为的属性：

- color、opacity、blur、shadow、radius、border intensity、spacing、position、scale，以及会视觉重塑对象的几何值。

项目级约束：

- 不要把读起来像对象状态变化的颜色切换硬切。
- 不要瞬切样式变量，如果结果像"视觉瞬移"。
- 优先一条连续过渡链，而不是若干互不相关的分段硬跳。
- 相关属性的时长要协调，让对象仍读作同一个对象。
- 若某属性因技术原因必须瞬变，就把感知变化藏起来或给出理由。

定稿前自问：用户会感知到这次属性变化吗？会的话过渡路径是什么？这条过渡让对象仍然连续吗？它和定义同一对象的其它属性同步变化吗？

反模式（避免）：可见表面瞬时换色；radius 无过渡跳变；opacity 硬切且无配套状态变化；blur 突然出现/消失；spacing 或 scale 变化造成硬视觉跳变；只动画一个相关属性而把其余硬切。

### 动效令牌与权威源文件

设置面板是 Afloat 全项目的风格权威样本。任何新的可见效果——高亮、点击反馈、按压形变、滚动、动效曲线——**先在下面的权威源文件里找到对应实现，再复用其模式与数值**。找不到对应模式时才允许新设计，且新设计必须回写本 skill 或说明理由。

| 模式 | 权威实现 |
| --- | --- |
| 行卡片 / hover 高亮 / 焦点环 / 点击闪烁 | `modules/lazerbar/LazerSettingsRow.qml` |
| 分类区块 / 压暗遮罩 / 标题分隔线 | `modules/lazerbar/LazerSettingsSection.qml` |
| 通用滚动系统（接管区 / 阻力 / 回弹 / 波浪挂起） | `modules/lazerbar/LazerSettingsSections.qml` |
| 导航项高亮 / 侧栏点击闪烁 | `modules/lazerbar/LazerSettingsSidebar.qml`、`LazerSettingsNavItem.qml` |
| 选中指示条（拖尾动效） | `modules/lazerbar/TrailIndicator.qml`；配方见 `lazer-motion-perf` |
| 全部时长与缓动常量 | `modules/lazerbar/MotionTokens.qml` |
| 颜色令牌 | `modules/lazerbar/LazerTheme.qml` |

常用值：`fast=100`（hover/颜色切换）、`medium=160`、`slow=240`（展开收起/淡入）、`page=320`；主缓动为 `Easing.OutQuint`。按压形变统一用 `MotionTokens.pressScale`（0.985），**悬停不缩放**（顶栏图标按钮例外见下）。

### 高亮、焦点环与点击闪烁

hover / focus / active / 禁用：用色块亮度、透明度、指示条切换，不走形态变化。

- **hover 高亮**：表面颜色在 `<surface>` ↔ `<surface>Hover` 间用 `ColorAnimation { duration: MotionTokens.fast }` 过渡；禁止瞬时切换。
- **焦点/强调环**：独立 Rectangle 层（z 高于内容、`enabled: false` 不参与输入），边框 `1.5px` 的 accent 色，宽度过渡用 `fast`。
- **点击闪烁配方（所有可点组件统一）**：透明覆盖矩形填充 `LazerTheme.textPrimary`，激活时播放 `NumberAnimation { from: MotionTokens.clickFlashOpacity; to: 0; duration: MotionTokens.clickFlashDuration; easing.type: MotionTokens.clickFlashEasing }`；通过 `restartFlash()` 触发，reducedMotion 时直接归零。参考 `resetFlashAnimation` 与 `restartResetFlash()`。
- 共享参数固定为 `clickFlashOpacity: 0.3`、`clickFlashDuration: 800`、`clickFlashEasing: Easing.OutQuint`；闪烁层必须是非交互视觉层，不得改变命中区域或布局尺寸。

### 双层覆盖几何（矩形月牙）

设置面板的标志性构成手法（权威实现：`LazerSettingsRow` 默认按钮），可复用于任何"角部附属控件嵌进主表面"的场景：

- 下层是附属控件表面，上层是带圆角的主表面；主表面的圆角把下层露出的角裁成**矩形月牙**（一侧直角、一侧被圆角切掉的月牙形），不使用任何遮罩或 clip。
- 逻辑宽度与视觉宽度分离：逻辑宽度是交互区（28px），视觉宽度 = 逻辑宽度 + 主表面圆角（34px）；多出的圆角宽度向主表面内侧延伸并被裁掉。
- 图标以可见区域为居中基准，不以扩展后的视觉宽度为基准。
- 状态表达仍走色块亮度/hover swap，月牙形态本身静态不变。

### 输入隔离

- hover 观察（`HoverHandler`/`MouseArea`）不得吞掉内嵌控件的指针事件：全行 catcher 用 `blocking: false`，按钮区域留独立 handler。
- 默认按钮位于较低 z 层时，检查上方 `MouseArea`、`HoverHandler`、`Rectangle` 是否会吞掉它的 pointer/hover 事件；不要靠把按钮提到背景之上来绕过（那会破坏月牙裁切）。
- 组件不可见或未揭示时必须同时关闭输入：用统一的 `interactable` 类属性门控（如 `matchesSearch && !revealHeld`），不要只依赖 `visible`。

### 通用滚动系统（复用于任何可滚列表）

以下契约实现在 `LazerSettingsSections.qml`，新列表优先整体复用该组件而非复制逻辑：

- **边缘接管区**：距边界 `edgeTakeoverDistance`（80px）内的滚轮增量绕过 Flickable 平滑队列，先 `cancelFlick()` 再驱动一个短追逐动画（`edgeDriveAnim`，80ms OutQuint）。原因：Flickable 的滚轮平滑队列会让 contentY 落后用户意图数百毫秒。
- **橡皮筋阻力**：越界后的步长按已拉伸比例衰减（`_resistedTarget`：`delta * (1 - past/overscrollDistance)`），形成"弹簧拉紧"的到头提示；`overscrollDistance = 88`。
- **回落**：输入停止约 `140ms`（edgeSettleTimer）后用 260ms InOutCubic 缓动回边界。
- **回程再推入**：回弹回程阶段收到同向输入必须从当前位置重新弹出，不允许"等动画结束再加滚"。
- **程序滚动让位**：分类跳转等 scrollAnim 进行中若用户在边界滚轮，立即停 anim 接管。
- **波浪挂起**：开场波浪期间（`entranceBusy`）整表滚动禁用（native `interactive` + onWheel 双重守卫），结束后自动恢复。
- 边界情况修改滚动逻辑前，先用 `/tmp/opencode/edgeloop` 式合成滚轮回路验证时序（意图到达→250ms 内回弹必须接管），不要凭感觉调参。

### 结构模式（新增列表型 UI 时照抄）

- **布局/视觉分离**：根 Item 只做布局占位；纯视觉的生长、位移效果放进 clip 包裹层（visualHost），避免视觉动画扰动布局与滚动。
- **间距折叠进高度**：列表 gap 折入子项 height（含完全退出时恰好归零），从布局移除子项时不产生跳变。
- **声明式可见性**：过滤退场用 `!hidden || height > 0.5 || opacity > 0.01` 这类"动画落定后才隐藏"的绑定，配合 Timer 冻结隐藏时机，禁止多信号处理器竞写状态机。

### Filtered List Animation Ownership

Use this when a search/filter list regression still feels abrupt even though `add`, `remove`, or `displaced` transitions exist on a `ListView`/`GridView`.

- First identify the old animation owner: model transitions animate item insertion/removal/reflow, while delegate `Behavior`s animate a persistent row changing `height`, `opacity`, `x`, `scale`, or blur.
- If the desired feel is rows softly collapsing out of the list, keep the candidate model stable and let each delegate derive `matchesFilter` from the current query. Animate all perceptible properties on that delegate.
- Use model-driven filtered subsets only when destroying/recreating items is the intended effect. They can bypass the old collapse animation because the delegate disappears instead of transforming.
- For keyboard navigation and empty states, derive behavior from visible matches, not raw model count, so hidden zero-height delegates are skipped.
- When compact and full variants share a search surface, verify both variants use the same animation ownership model before assuming a transition rule applies.

### 已批准的顶栏例外

以下偏差经审视后确认为 lazer 原版忠实还原，仅限顶部栏使用，不得扩散到其他区域：

- **图标按钮 hover 缩放**：`IconButton` / `OsuTopBarButton` 悬停 `hoverScale`、按压 `pressScale`（设置面板规则"悬停不缩放"不适用于栏上图标按钮）。
- **ModeSelector 凹槽胶囊**：容器 `radius 9` + 底部锚定 xScale 0.97，是 lazer 模式选择器的标志性形态；选中指示仍为细条带。

### 波浪 overlay 的两套 chrome（`WaveSurfaceHost`）

overlay 本体**同时保留两套布局**，都是一等代码路径，不要因为"更干净"删掉其中一套：

| `chromeLayout` | 形态 | 导航花费 |
| --- | --- | --- |
| `blocks` | osu wiki 三段式：标识标题条 → 页面条（页面名 + 横向标签）→ 内容列 | 高度，宽度全给内容 |
| `rail` | 旧设置面板形态：标题条 + 可折叠竖向导航栏 + 内容列 | 宽度，高度还给结果 |

- **色阶方向与设置面板相反**：设置面板是 rail 比 panel 深（lazer `Background5` 垫底 `Background4`）；overlay 三段式是标题条最深、内容列最浅，因为它照 osu wiki 的堆叠。三档由 `LazerTheme.overlayHeaderSurface` / `overlaySectionSurface` / `overlayContentSurface` 给出，两种布局共用。
- **三段之间不画分隔线**：色阶本身就是分隔，加 hairline 反而多一层。
- **内容列锚到页面条的下边缘**（不是标题条下边缘）。页面条在 `rail` 下高度为 0，所以这一个锚点覆盖两种布局；锚错会让内容盖住页面条而不是排在它下面。
- **页面条塌成 0 高度**表示"当前没有分段"（如控制中心），内容列自动上抬，不预留空条。
- 竖向栏走 `Loader`（每个条目都要建 nav item + 图标 + 效果，是页面条布局要省掉的那笔开销）；页面条只有 3 个标签委托，直接内联声明。`Loader` 三边锚定时高度为 0，会把 0 传给 item，所以页面条**不能**放进只锚三边的 `Loader`。
- 对比开关：**默认 `rail`**（竖向导航把宽度换成结果列表的高度，在这个桌面实测更顺）；`AFLOAT_LAUNCHER_CHROME=blocks` 选另一套，`qs ipc call launcher chrome` 热切。启动器自己的查询面（搜索条 + 分类芯片）也跟随布局——`rail` 下是改动前的通栏 `settingsRail` 条，这样对比才是真的 A/B 而不是只换了导航。

### 注释约定

编辑 QML 时：

- 在每个主要元素声明（`Variants`、`Item`、`PanelWindow`，以及 `IconButton` 这类可复用视觉组件）的正上方放一句简短英文注释。
- 注释保持简短、描述性，说明意图而不是机制。
- 不要写只是复述下一行的注释。

```qml
// Keep the root item centered in the window.
Item {
    readonly property int radius: 24
}
```

目标是让代码一眼可读，不需要长段内联解释。

### 维护

- 修改权威文件中的共享模式时，同步更新本 skill 与 `references/settings-panel.md`。
- 设置面板的实现级契约（表面层级、row 几何、默认按钮状态与动效、滑条刻度反馈、验证清单）见 `references/settings-panel.md`；托盘子菜单的表面运动契约见 `references/submenu-motion.md`。
