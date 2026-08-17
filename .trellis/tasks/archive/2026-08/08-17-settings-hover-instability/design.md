# 设置悬浮不稳定诊断设计

## Boundary

先验证实际指针事件的拥有者和坐标映射，再决定修改边界。候选边界依次为 `LazerSettingsRow` 的命中层、控件根与可见 surface 的尺寸/层级、Content viewport/overlay 输入区域；`SettingsOverlayBridge` 只有在探针证明请求生命周期仍然错误时才修改。

## Ranked Hypotheses

1. 可见控件、Row、`cardSurface` 与其 HoverHandler parent 的几何边界不一致，导致部分矩形没有落到预期 handler。
2. `contentHost`/Choice `headerSurface`/Slider track 的 z-order 或大小覆盖了 Row 卡片，使 Row 边框在焦点时被遮挡，或事件只落在局部子区域。
3. Flickable 的页面坐标、滚动偏移或分类切换动画与 Content overlay 的映射不同步，导致提示锚点和实际指针位置不一致。
4. 下拉菜单或其他上层输入区域在特定状态下吞掉事件。
5. Bridge 请求残留仍在事件命中修复后造成旧 Tooltip 回退；这是次要假设，不先改优先级。

## Diagnostic Loop

- 建立最小运行时探针，记录 Row、card、control root、field/header/track 的 `x/y/width/height`, `mapToItem` 结果、`hovered`, `activeFocus`, 当前 Tooltip source 和 visible 状态。
- 按用户报告的精确坐标依次移动到每个目标的顶部、中部、底部、左边缘和控件内部，要求命令或脚本在修复前对预期位置产生失败断言。
- 一次只改变一个输入层或几何绑定，重新运行同一循环，确认失败位置是否消失。
- 保留最终最小回归作为挂载 `LazerSettingsPanel` 的测试或可重复人工探针；若 QML runner 无法发现测试，保留探针输出和明确人工步骤，不伪造通过结果。

## Fix Shape

- Row 高亮只由一份完整的、与视觉卡片一致的命中区域状态驱动。
- 选择 `HoverHandler`、`MouseArea` 或输入 mask 时，以实际探针证明的事件 owner 为依据；不因猜测而添加全屏拦截层。
- Choice 的焦点边框必须在 Row 卡片之上，且 header 仍保持完整点击和下拉行为。
- 不改变 Slider 的高优先级和 `nubItem` 锚点，不改变 TextField 编辑焦点和 Choice 菜单协议。
- Tooltip Bridge 仅在探针证明生命周期仍不一致时调整，并保留现有 activity source 与优先级契约。

## Compatibility And Rollback

- 保留现有 Row presentation、页面布局、主题 token 和 Tooltip 文案。
- 每个修复步骤保持可单独回退；诊断探针不进入生产代码，除非它成为正式测试 seam。
- 若无法建立可红的自动测试，提交中明确记录 QML runner 导入/发现限制与人工验证坐标。
