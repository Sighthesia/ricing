# 诊断设置悬浮不稳定

## Goal

恢复设置面板悬浮反馈的稳定性：鼠标所在 Row 的卡片高亮和 Tooltip 必须始终跟随当前指针，离开、滚动、切换分类或重新打开面板后不能停留在旧状态或旧坐标。

## Background

- 用户确认此前针对 Row 派生状态、Tooltip activity source 和跨分类回归的修复仍未改善问题，说明当前根因尚未被验证。
- 用户报告了明确的部分命中区域：外观分类中，壁纸路径完全无法触发悬浮；配色方案只有最左上角一小块区域可以触发，且聚焦边框被下拉框遮盖；面板不透明度和启用模糊只有从上到下约三分之一高度的一条横向细区域可以触发；模糊表面不透明度只有高度下半部分可以触发；其他分类也有类似但不固定的表现。
- 当前 Row 同时存在两条状态链：`rowHover`/控件 `hovered`/`activeFocus` 驱动卡片高亮；`refreshTooltip()` 向全局 `SettingsOverlayBridge` 登记或撤销 Tooltip 请求。
- `LazerSettingsContent` 只负责本 Content 实例的 Tooltip 所有权，并按优先级和请求登记顺序进行回退；这条链可能与实际指针事件生命周期不同步。
- 当前 QML 测试运行环境不能可靠发现或报告 QtTest 结果，因此必须建立真实可红的诊断入口，不能把静默退出当作通过。
- `HoverHandler.target` 只决定处理或反馈的目标 Item，不改变 Handler 监测的 parent bounds；当前 Row handler 的实际命中边界仍需通过运行时探针确认。

## Requirements

- R1: 明确区分并记录 Row 卡片高亮、控件悬浮、键盘焦点和 Tooltip 可见性的实际事件来源，定位不稳定发生在事件命中、状态传播、Bridge 请求生命周期或 Tooltip 几何更新中的哪一层。
- R2: 建立可重复的最小回归循环，使用实际屏幕坐标覆盖连续移动相邻 Row、控件内部与边缘、跨分类切换、滚动后重新悬浮和关闭/重新打开面板；循环必须能在修复前捕获用户描述的部分命中区域或滞留。
- R3: 修复必须让当前指针所在行与视觉高亮、Tooltip source 和 Tooltip 几何保持一致；旧 Row 不得继续作为活动候选。
- R4: 修复不得破坏 Slider 值提示的高优先级、`nubItem` 锚点、Choice 下拉和 TextField 编辑焦点。
- R5: 回归测试必须覆盖实际输入路径或其最近的正确集成边界；如果环境无法执行 QML 集成测试，必须保留明确的测试缺口和人工复现步骤。
- R6: Choice 的焦点边框必须位于 Row 卡片之上且不被 Choice header 遮盖；Row 卡片边缘和各控件完整可见区域必须属于同一可验证的命中契约。

## Acceptance Criteria

- [ ] 可用一个明确命令或人工复现脚本稳定重现修复前的不稳定行为，并在修复后稳定通过。
- [ ] Appearance、Bar、Notifications 页面连续悬浮和分类切换后，卡片高亮与 Tooltip 不停留在旧 Row。
- [ ] 壁纸路径、配色方案、面板不透明度、启用模糊和模糊表面不透明度的可见完整区域均可触发所属 Row 高亮；配色方案焦点边框不被 header 覆盖。
- [ ] 滚动、关闭/重新打开面板后，不存在旧 source 的 Tooltip 请求或固定坐标。
- [ ] Slider、Choice、TextField、Toggle 的悬浮和键盘焦点行为保持可用，且没有新的 QML WARN/ERROR。
- [ ] 完成独立质量审查、相关验证、规范更新和 Conventional Commit。

## Out Of Scope

- 不改变设置面板的布局、主题视觉参数或 Tooltip 文案。
- 不在没有可复现证据前继续叠加 Tooltip 优先级或焦点绑定特判。
- 不把静默退出的 `qmltestrunner` 结果记为测试通过。
- 不在未确认事件命中边界前修改 Bridge 优先级或继续添加来源特判。

## Notes

- 该任务涉及共享输入、控件层级、坐标映射、跨层 Tooltip 所有权和三个分类页面，按复杂任务处理；先完成运行时命中探针，再补充实现和集成回归。
