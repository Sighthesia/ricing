# 设置行即时 Tooltip 状态设计

## Boundary

`LazerSettingsRow` 继续拥有卡片高亮状态；`SettingsOverlayBridge` 与 `LazerSettingsContent` 继续负责跨组件请求和可见 Tooltip。修复只改变 Row 在交互通知时计算请求状态的方式。

## Data Flow

1. 保留声明式 `rowHighlighted`，供卡片颜色、边框和 `tooltipActive` 绑定使用。
2. 增加 Row 内部即时判定函数，直接读取 `rowHover.hovered`、`revertHover.hovered`、`controlItem.hovered` 和 `controlItem.activeFocus`。
3. `refreshTooltip()` 使用该即时判定函数：活跃时调用 `showTooltip`，否则调用 `hideTooltip`。
4. 每个输入源的通知仍调用同一 `refreshTooltip()`，因此离开源会立即撤销旧请求，进入新源会提交新请求。
5. `LazerSettingsContent` 保留优先级与 fallback 规则；它只接收准确的当前活跃请求，不需要为 Row 增加新的仲裁分支。

## Compatibility

- `rowHighlighted` 的视觉表达、色彩和现有动画不变。
- Slider 保留直接读取原始状态的实现及 `nubItem` 几何锚点。
- 三参数 Bridge 调用与前一任务中的显式 `activitySource` 合约不变。
- 不引入新的输入覆盖层、MouseArea 或焦点所有者。

## Risks And Rollback

- 风险：多个源在同一事件循环内短暂重叠时可能额外调用一次 `showTooltip`。现有 Bridge 按 source 更新请求，Content 对同优先级保持稳定，可消除可见跳动。
- 回滚：该改动局限于 Row 的状态判定函数与其测试，可独立回退，不影响控件布局与 Bridge 数据结构。
