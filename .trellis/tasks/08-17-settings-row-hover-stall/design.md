# 设置 Tooltip 活性回退设计

## Boundary

`SettingsOverlayBridge` 继续只传递和登记请求；每个请求新增一个可选的活性来源。`LazerSettingsContent` 仍是每屏唯一的 Tooltip 视觉所有者，并在选择回退候选时读取该来源的当前活性状态。

## Data Flow

1. Row 请求描述 Tooltip 时，以 Row 自身作为几何锚点和活性来源。Row 的活性状态是已存在的本地高亮状态。
2. Slider 请求数值 Tooltip 时，继续以 `nubItem` 作为几何锚点，同时以 Slider 根项作为活性来源。Slider 活性状态是 HoverHandler、DragHandler 或 activeFocus 任一成立。
3. Bridge 保存 `{ text, source, priority, activitySource }`；未指定活性来源的三参数调用不参与活性过滤，以保持既有程序化与测试调用有效。
4. Content 在 `ownedBestTooltipRequest()` 中只选择：来源仍归属本 Content、来源及活性来源可见、且活性来源没有显式报告失活的请求。
5. 当前所有者关闭后，回退会跳过旧行/旧 Slider 请求；若没有有效候选则关闭 Tooltip。高优先级接管与同优先级稳定判断不变。

## Contract

- `SettingsOverlayBridge.showTooltip(text, sourceItem, priority, activitySource)` 的第四参数可省略。
- 可参与活性校验的 QML 项公开只读 `tooltipActive` 布尔值。
- `tooltipActive === false` 的请求不得作为新 Tooltip 或回退 Tooltip 的视觉所有者。
- 未传入第四参数的既有调用视为活跃，兼容当前的外部或测试调用；显式传入的来源若没有 `tooltipActive` 属性，同样视为活跃。

## Trade-offs

- 不采用“最新同优先级请求立即接管”，因为会破坏现有相邻行短暂重叠时的稳定体验。
- 不通过全局清空 Bridge 解决，因为一个屏幕的生命周期变化不能删除另一屏仍有效的请求。
- 活性检查在 Content 选择候选时完成，而不是让 Bridge 直接管理每屏 UI 状态，保留单例传输与每屏视觉所有权的边界。

## Compatibility And Rollback

- 现有三参数 `showTooltip` 调用仍有效；不需要数据迁移。
- 改动仅限运行期 Tooltip 请求仲裁。若出现回退回归，可回滚本任务提交，不影响已持久化设置。
