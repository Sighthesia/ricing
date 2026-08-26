---
name: submenu-surface-motion
description: 修改 Afloat 的托盘菜单（BarTrayMenu）、二级子菜单面板、弹出层变形动效或其开合/流转/缩回行为时使用。固化已验证的遮挡式揭示、退场缓入与数据保活、跨面板流转门控、异步内容高度保持等契约，避免退场不可见、细条塌缩、瞬移等回归。
---

# Submenu Surface Motion（二级菜单表面运动契约）

这份 skill 是 `osu-sharp-design-language` 与 `settings-panel-style-authority` 在 BarTrayMenu 子菜单上的实现级沉淀。所有规则均经 E2E 探针实测验证。

## 表面层级（遮挡式揭示）

子菜单必须垫在一级菜单的"脸面"之下，靠遮挡而非透明度隐藏：

- z 序：`submenuSurface z:1` < `menuFace z:2`（不透明重绘的一级菜单脸）< `contentFlickable z:3`（行内容）。
- **opacity 恒为 1，不参与动画**——与宿主弹窗被顶栏遮挡同一条法则。任何让 opacity 跟随动画进度的写法都会吞掉缩放/位移，表现为"没有动效"。
- 揭示 = 从锚定行近侧边缘的 Scale 原点 + `enterTravel = gap + width * popupFromScale + 4` 的 Translate 滑出；出生即整体藏在脸面之下。

## 退场三定律

1. **缓入曲线**：缩回用 `MotionTokens.inOut` + `slow(240ms)`。ease-out 会把全部位移压进前几十毫秒且随即钻入遮挡区——感知上就是瞬间消失。
2. **数据保活**：`closeSubmenu()` 不得清空 entry/anchor。提前清空会让子项列表瞬间蒸发、高度塌成细条，动画拖的是空壳。数据在 `submenuAnimation.onFinished` 且 progress===0 时才释放。
3. **关闭意图先行**：监听 `BarPopupService.closePending` 立即折返（240ms 恰好嵌进宿主 grace 窗口），否则指针离场路径下面板会全开着被宿主整体带走，退场动画从未播放。

生命周期用显式函数驱动：`openSubmenu(entry,row)` / `closeSubmenu()`，不要依赖 property change handler（重悬停同一行时属性不变、无法翻回 opening）。

**共享行组件的规则必须按层级作用域化**：`MenuEntryRow` 同时服务两级菜单，"悬停普通行折叠当前子菜单"的规则若不限定 `level === 1`，指针一进入子菜单内部的任何条目就会把面板自己杀掉（症状：二级菜单"不会停留、直接消失"，且探针测不出来——无头环境没有真实 hover）。子菜单行标记 `level: 2`，折叠分支只对根级行生效。

## 跨面板流转

- x/y/height 的 Behavior 门控条件是 **`submenuProgress > 0`（可见即可滑），不是 phase**。行间移动几乎总会扫过普通行触发折叠（closing）再重开（opening），按相位门控必然瞬移。
- 重定向不重播揭示：`openSubmenu` 里 phase 已是 opening/open 时只更新锚点与 entry。
- 异步内容高度保持：切换后新 opener 未返回条目时（column implicitHeight ≤ 20）沿用上一个高度，防止形变先塌陷再弹回。副作用写入必须放在 `onRawColumnHeightChanged` 处理器里——在自己的绑定求值内写依赖属性会被判定 binding loop。

## 一级菜单对齐

宿主关闭形变使用同一参数：`slow(240ms)` + `inOut`（BarPopupHost exit 分支），两级菜单共用一套离场语言。

## 诊断清单

- 退场"看不见"→ 依次查：opacity 是否跟随进度、缓动是否 ease-out、数据是否提前清空、关闭意图是否有人折返。
- 形变"瞬移"→ 查 Behavior 的 enabled 条件是否含 phase。
- 高度"细条/塌陷"→ 查 closeSubmenu 是否清了数据源、异步加载是否有高度保持。
- 头部无光标探针间歇失败 → 真实桌面光标扫过窗口会触发宿主 HoverHandler 的 requestClose；探针需每 tick 中和（`pointerInPopup=true` + `cancelClose`）并在意外 closing 时自愈重开。
- 扫描交接横移抖动 → 逐字 Row 排版与单串 Text 整形宽度天然不一致（~1px）；必须用 TextMetrics 前缀偏移绝对定位。
