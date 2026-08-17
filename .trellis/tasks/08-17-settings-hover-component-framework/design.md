# 设置悬浮与组件框架设计

## Investigation Boundary

按以下顺序验证输入所有权：`PanelWindow.mask` -> Settings Overlay -> Content viewport/叠层 -> Flickable 页面 -> Row 卡片 -> 嵌入控件 -> Tooltip bridge。先收集运行时证据，再选择局部修复或重构；不得用高层透明 Item 猜测性吞掉事件。

## Current Contracts To Preserve

- Row 卡片占据 Row 的完整视觉矩形；控件 hover/focus 和 reset hover 必须继续可观察。
- Choice 的可见 header 是 dropdown 的单一几何来源，TextField 的 editor 保持输入焦点。
- Slider 根的 hover/drag/focus 仍产生 priority 2 数值 Tooltip，几何 source 保持 `nubItem`。
- Settings Content 只处理自己 viewport 祖先链上的来源；Tooltip overlay 不拥有键盘焦点。

## Diagnostic Harness

诊断 harness 不进入生产代码。它需要对代表性 Row 逐点移动指针，记录屏幕坐标、`mapToItem` 结果、Row/card/control bounds、顶层可见 Item、mask、hover/focus 和 Tooltip source。优先使用可真正输出结果的 qmlscene/qs harness；若环境仍无法自动驱动 QML，保存明确的人工坐标步骤和启动日志，并把 runner 限制作为测试缺口。

## Ranked Hypotheses

1. Settings mask 或 Content 兄弟叠层拥有错误输入区域。
2. Flickable/page/contentY 或面板动画造成视觉矩形与输入矩形不同步。
3. Row 卡片、控件 surface 和 reset/dropdown 层之间存在错误 z/命中所有权。
4. 透明但仍在场景图的装饰层覆盖交互区域。
5. Tooltip bridge 残留造成视觉状态滞留，但不解释原始局部命中，因此最后验证。

## Refactor Decision Gate

只有在 harness 证明现有边界无法同时满足以下三点时才重构：

1. Row 完整卡片区域可 hover。
2. 嵌入控件仍可独立处理 hover、focus、tap、drag。
3. Tooltip source 与视觉几何保持一致。

若满足，采用局部修复。若不满足，候选重构为：Row 只负责布局/语义状态；独立 `SettingsRowSurface` 负责视觉和命中状态聚合；控件保留自己的交互 owner；Tooltip owner 接收显式的当前交互来源。重构必须先定义公开属性、信号和层级契约，再迁移一个代表性 Row，验证后扩展到三类页面。

## Rollback

诊断 harness 可直接删除。产品修改按输入层、Row contract、组件迁移分步提交；若回归出现，回退最后一个迁移阶段，不回退此前已验证的设置持久化和 Slider/Choice/TextField 协议。
