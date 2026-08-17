# 修复设置行悬浮滞留

## Goal

让设置面板在外观页面滚动与跨行悬浮后，始终把高亮卡片和提示指示绑定到当前仍在交互的设置项；离开的行或控件不得让提示停留在旧位置。

## Background

- 用户反馈：从“启用模糊”开始的外观设置项缺少悬浮/焦点反馈，悬浮指示停留在先前位置。
- `LazerSettingsRow` 的卡片高亮由本地悬浮或控件焦点状态决定；`LazerSettingsContent` 的提示由 `SettingsOverlayBridge` 中持久化的请求决定。这两条状态链目前没有共同的“请求仍活跃”校验。
- `LazerSettingsContent.ownedBestTooltipRequest()` 只确认来源仍属当前内容，未确认它仍被悬浮、聚焦或拖动。因此旧来源在当前来源关闭后可以重新成为回退候选，造成指示滞留。

## Requirements

- R1: Row 与 Slider 的设置 Tooltip 请求必须携带可查询的交互活性来源；活性来源失去悬浮、焦点或拖动后，不得作为 Tooltip 回退候选。既有三参数程序化请求不改变语义。
- R2: `LazerSettingsRow` 的描述提示与行卡片使用同一个本地高亮状态；控件区域、卡片边缘、重置按钮和控件焦点均保持既有高亮覆盖。
- R3: `LazerSettingsSlider` 继续以移动 Thumb 作为 Tooltip 几何锚点，以 Slider 根项的悬浮、拖动或焦点作为活性来源；不得改变其优先级、拖动、键盘或默认值行为。
- R4: 保留现有 Tooltip 优先级语义：高优先级可立即接管；同优先级不在正常相邻悬浮时抢占当前所有者；回退仅从仍活跃且属于当前内容的来源中选择。
- R5: 在实际挂载的设置面板回归测试中覆盖旧请求失活后不会回退到旧位置，以及 Slider 覆盖行描述后回退到仍活跃行的场景。

## Acceptance Criteria

- [ ] 在外观页从“启用模糊”及之后的行之间移动指针时，当前行卡片会显示悬浮高亮，离开的行不会保留高亮。
- [ ] 当当前 Tooltip 来源关闭、滚出视口或失去交互活性时，提示要么切换到仍活跃的候选，要么关闭；不得重新显示旧来源的位置或文本。
- [ ] Slider 的数值 Tooltip 仍锚定在 Thumb 上，优先级仍高于行描述；Slider 结束交互后只能回退到仍活跃的行描述。
- [ ] 同优先级的短暂重叠请求仍不使 Tooltip 跳动，且失效请求不会污染后续回退。
- [ ] 相关 QML 静态检查、Python 测试、配置启动检查和可用的 QML 测试入口均完成；已知测试运行器发现限制单独记录，不作为通过证据。

## Out Of Scope

- 不重做设置面板的布局、卡片颜色、动画或 Tooltip 视觉设计。
- 不改变 Dropdown 的输入层、页面导航或设置持久化。
- 不将 Tooltip 仲裁扩展到设置面板以外的悬浮界面。

## Notes

- 相关实现边界：`SettingsOverlayBridge.qml`、`LazerSettingsContent.qml`、`LazerSettingsRow.qml`、`LazerSettingsSlider.qml` 与挂载面板测试。
- Qt 的父/子 `HoverHandler` 可以并行悬浮，且默认不阻塞；本任务不通过叠层或 handler target 猜测修复问题。
