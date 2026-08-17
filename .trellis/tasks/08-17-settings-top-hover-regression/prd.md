# 诊断设置顶部悬浮失效

## Goal

恢复设置面板所有分类首批项目的即时悬浮与焦点反馈：当前指针所在行必须高亮，说明提示必须随当前行更新，且离开后不得留在旧位置。

## Background

- 用户确认该问题不限于外观页：顶部栏与通知分类的前四项也会出现相同症状。
- 三个分类都由 `LazerSettingsContent` 承载，页面通过 `LazerSettingsRow` 请求行说明提示。
- `LazerSettingsRow.refreshTooltip()` 在 `HoverHandler.onHoveredChanged`、控件 `hoveredChanged` 与 `activeFocusChanged` 回调中读取 `rowHighlighted`。该属性由多个输入状态派生；回调时可能仍为前一状态。
- `LazerSettingsSlider.refreshTooltip()` 已明确绕开同类问题，直接读取 `hoverHandler.hovered`、`dragHandler.active` 与 `activeFocus`，证明此类通知内读取派生状态并不可靠。
- 当行离开时旧请求未被及时撤销，`LazerSettingsContent` 按同优先级稳定性保留该请求，后续行的说明不会接管，形成提示固定在旧位置的表象。

## Requirements

- R1: 行卡片的视觉高亮仍由统一的悬浮/控件悬浮/控件焦点/恢复按钮悬浮状态驱动，不能因提示修复而改变卡片动画或控件行为。
- R2: 行说明请求必须在每个输入状态变化时使用该时刻的直接状态决定显示或撤销，不能依赖尚未重算的 `rowHighlighted`。
- R3: 鼠标从任意首批项目移至同分类的另一项目时，旧行说明必须撤销，新行说明必须成为可见提示；不允许出现停留在旧行坐标的提示。
- R4: 键盘焦点停在控件上时，所属行须持续高亮并显示其说明；焦点移走后须按相同状态链撤销。
- R5: 保持现有 Tooltip 优先级：Slider 值提示可覆盖行说明，同优先级的重叠请求仍不应发生无意义跳动。
- R6: 增加可直接调用行交互状态的确定性回归断言，覆盖首行离开、下一行进入及控件焦点场景。

## Acceptance Criteria

- [ ] 外观、顶部栏、通知三类页面的首个和后续行悬浮时，所属卡片立即显示既有高亮样式。
- [ ] 从一个行卡片、控件区域或恢复按钮移开后，该行不再保留 Tooltip 请求；下一行提示不复用旧行坐标。
- [ ] TextField、Choice、Toggle、Slider 的悬浮和键盘焦点均能驱动所属行反馈。
- [ ] Slider 的 `nubItem` 仍是值提示锚点，优先级与拖动/键盘行为不变。
- [ ] 新增测试覆盖状态转换，现有 Tooltip 优先级、下拉与设置面板测试语义保持不变。

## Out Of Scope

- 不改变设置页面布局、主题色、卡片尺寸、搜索或下拉菜单交互。
- 不重写 `SettingsOverlayBridge` 的请求优先级模型。
- 不处理测试运行器的导入/发现基础设施问题；该限制将明确记录在验证结果中。

## Notes

- 该任务涉及共享行状态、Tooltip 仲裁与三个页面，因此按复杂任务编写设计和执行计划。
