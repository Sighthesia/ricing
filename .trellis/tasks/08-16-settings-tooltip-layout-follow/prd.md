# 修复设置悬浮提示布局与跟随

## Goal

修复 Settings tooltip 尺寸退化、文本裁切和定位不同步问题，使设置说明与 Slider 数值能够完整显示、稳定跟随其来源控件，并始终保持在当前 Settings Content 可视边界内。

## Confirmed Root Causes

- `modules/lazerbar/LazerSettingsContent.qml:396-423` 的 tooltip 宽度读取 `tooltipSurface.implicitWidth`，高度读取 `tooltipSurface.implicitHeight`。
- `tooltipSurface` 是 `Rectangle`，其内部 Text 使用 `anchors.fill: parent`；子 Text 不会反向给 Rectangle 提供自然 implicit size。
- 因此 tooltip 宽度退化到 `Math.max(24, 0 + 20) = 24px` 左右，高度退化到 `0 + 12 = 12px` 左右，文本必然换行并被父级裁切。
- Text 同时被 `anchors.fill` 限制，却又承担 wrap 后的自然高度，形成“先由错误父尺寸约束，再尝试测量文本”的循环布局。
- `showTooltipAt()` 只在 bridge request 时调用一次并写入固定 `x/y`；source 后续移动不会触发重新定位。
- Slider drag、Sidebar collapse、Content 入退场、窗口尺寸变化和其他 source geometry 变化都不会更新 tooltip 坐标。
- 当前页面 `contentY` 改变时直接调用 `hideTooltip()`，因此滚动时 tooltip 消失而不是跟随。
- 多屏 owner 过滤已经存在，修复必须保留 `ownsOverlaySource()` 隔离。

## Requirements

- Tooltip 尺寸必须由 Text 的自然内容尺寸驱动，不再由无 implicit size 的 Rectangle 反向测量。
- 短文本保持单行自然宽度；长文本在可用 Content 宽度内换行，并根据 wrapped implicit height 完整扩高。
- Tooltip 宽度必须受最小宽度、主题最大宽度和当前 Content 可用宽度共同约束。
- Tooltip 高度必须完整容纳所有换行文本与内边距，不得裁切。
- Tooltip 必须保存当前 source Item，并在 source 或 Content 几何变化时重新计算位置。
- 定位使用同一坐标域：source 通过 `mapToItem(root, ...)` 映射到当前 Content，不能混用屏幕坐标和局部坐标。
- Tooltip 优先显示在 source 上方；上方空间不足时放在下方；最终 X/Y 均夹紧在当前 Content 可视范围内。
- Slider 数值 tooltip 必须在 Nub 拖动时连续跟随 Nub，而不是只跟随整个 Slider 根节点。
- Row description tooltip 必须跟随对应行或其 label/control anchor。
- Source 离开当前 Content、被过滤隐藏、销毁或不可见时必须关闭 tooltip，不能停留在旧坐标。
- 页面滚动时，只要 source 仍与 viewport 相交，Tooltip 必须持续跟随；source 完全离开 viewport 后关闭，不吸附到 Content 边缘。
- 保留多屏 visual-owner 过滤、tooltip priority 和不获取键盘焦点的行为。
- reduced motion 只影响淡入淡出动画，不降低位置跟随准确度。

## Out of Scope

- 修改 tooltip 文案内容。
- 重做 dropdown menu 定位或 Settings owner 架构。
- 新增独立 PopupWindow / PanelWindow。
- 修改非 Settings 区域的 tooltip。

## Acceptance Criteria

- [ ] 短 description tooltip 宽度明显大于 `24px`，文本单行时完整显示。
- [ ] 超长 description 在最大宽度内换行，tooltip 高度完整容纳所有行，无裁切或重叠。
- [ ] Tooltip 在 Content 左右边缘不会越界。
- [ ] Source 靠近顶部时 tooltip 自动放在下方；靠近底部时优先放在上方。
- [ ] Slider 拖动期间数值 tooltip 与 Nub 同步移动。
- [ ] Sidebar 折叠、Content 几何变化和 source 移动时 tooltip 重新定位。
- [ ] 页面滚动时行为符合用户选择的跟随策略，不出现悬空旧位置。
- [ ] 页面滚动时可见 source 的 Tooltip 连续跟随，完全滚出 viewport 后自动关闭。
- [ ] 多屏 owner 隔离、tooltip priority、搜索、dropdown 和 Overlay 生命周期测试继续通过。

## Decisions

- 页面滚动时持续跟随仍与 viewport 相交的 source；source 完全离开后关闭，不做边缘吸附。
