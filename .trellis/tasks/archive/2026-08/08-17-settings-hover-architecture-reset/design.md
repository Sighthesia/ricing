# 设置悬浮根因与组件框架设计

## Investigation Boundary

按输入实际到达顺序调查：`PanelWindow.mask` -> `LazerSettingsOverlay` -> `LazerSettingsContent.viewport` 及兄弟叠层 -> 分类 Flickable/page -> Row card -> embedded control -> Tooltip bridge。诊断先于产品修改，避免把视觉问题误判成 Tooltip 优先级问题。

## Current Contracts To Preserve

- Row 的视觉卡片覆盖 Row 完整矩形；卡片高亮不能吞掉控件的 hover、focus、tap 或 drag。
- Choice 的 header 是其可见选择器和焦点边框的几何 owner，下拉菜单打开时保留独立菜单层。
- TextField 的 editor 保持键盘焦点与文本编辑；Toggle 保持键盘和悬浮反馈。
- Slider 根负责 hover/drag/focus 状态，数值 Tooltip 使用 priority 2，几何 source 保持 `nubItem`。
- Content Tooltip 只处理自己 viewport 祖先链上的来源，Tooltip 视觉层不应取得焦点或覆盖触发输入。

## Diagnostic Harness

诊断 harness 不进入生产模块。对三个分类中的代表性 Row 按 screen coordinate 采样边缘、中心、控件内外和相邻边界，输出各层 `mapToItem` 矩形、visible/enabled/opacity/z、可观察 hover/focus、Tooltip source、mask 是否覆盖该点。优先使用真正能输出 verdict 的 qmlscene/qs harness；若当前环境仍不能自动驱动 QML，保存人工坐标步骤与启动日志，并明确 runner 缺口。

## Ranked Hypotheses

1. PanelWindow mask 或 Content 兄弟叠层的输入区域与视觉区域不一致。
2. Flickable 的 contentY、页面动画或显式/隐式高度使视觉 Row 与输入矩形不同步。
3. Row card、control surface、Choice menu 或 reset 层之间存在错误的输入 owner/z 顺序。
4. 透明但仍在场景图中的装饰层覆盖交互区域。
5. Tooltip bridge 残留或焦点生命周期放大了问题，但不能单独解释多个局部命中区域，最后验证。

## Refactor Decision Gate

仅当诊断证明现有结构不能同时满足以下条件，才实施组件框架重构：

1. Row 完整卡片区域能产生 hover/highlight。
2. 嵌入控件仍由自身 owner 独立处理 hover、focus、tap、drag/edit。
3. Tooltip 的 source 与实际视觉几何保持一致，并能在离开、滚动、切换、重开后清理。

若局部边界修复足够，则只修证据指向的层。若不够，候选结构为：`SettingsRowLayout` 只负责布局/语义与公开控件插槽；`SettingsRowSurface` 负责卡片视觉和非拦截的状态聚合；控件继续拥有自己的交互；`SettingsTooltipOwner` 接收显式活动来源和几何 anchor。先迁移一个 Appearance Row，再验证并扩展到 Bar/Notifications。

## Compatibility And Rollback

优先保持现有 Row 属性、控件公开属性、信号以及页面注入方式。组件迁移按“抽象契约 -> 一个 Row -> 三分类”分步提交；任何回归只回退最后迁移阶段，不触碰设置持久化和已有 Slider/Choice/TextField 协议。
