# Settings Tooltip Layout And Follow Design

## Measurement Model

Tooltip 尺寸拆成明确的测量域：

- `naturalTextWidth`: 文本不换行时的自然宽度。
- `availableTextWidth`: 当前 Content 宽度减去左右安全边距与 tooltip 内边距。
- `targetTextWidth`: `min(naturalTextWidth, themeMaxTextWidth, availableTextWidth)`。
- `wrappedTextHeight`: Text 在 `targetTextWidth` 下的 `implicitHeight`。
- `tooltipWidth`: `targetTextWidth + horizontalPadding`。
- `tooltipHeight`: `wrappedTextHeight + verticalPadding`。

Text 自己提供自然 `implicitWidth/implicitHeight`；Rectangle 只跟随 Tooltip 尺寸，不参与反向测量。Text 不再 `anchors.fill` 到尚未测量的父级，而是显式设置 `width` 并根据 wrapped `implicitHeight` 决定父高度。

最小宽度只用于空值保护，不强迫正常短文本变宽。可用宽度小于主题最大宽度时，优先保证 Content 安全边距，再通过换行增加高度。

## Active Tooltip State

`LazerSettingsContent` 持有：

- `activeTooltipSource: Item | null`
- `activeTooltipText: string`
- `activeTooltipPriority: int`
- `tooltipVisible: bool`

Bridge 仍只传输请求；Content 继续使用 `ownsOverlaySource()` 过滤多屏 owner。收到更高优先级或同优先级更新时替换 active source。dismiss 只在 source 与 active source 相同时关闭或回退到 bridge 当前有效请求。

## Positioning

新增纯函数 `tooltipPlacement(sourceRect, tooltipSize, boundsRect, gap)`，输出 `{ x, y, side }`：

- X 默认以 source 中心对齐 tooltip 中心，然后夹紧到 Content 左右安全边界。
- 上方空间足够时放上方。
- 上方不足、下方足够时放下方。
- 两侧都不足时选择可用空间更大的一侧，并将 Y 夹紧到 viewport/Content 边界。
- Row description 的 bounds 使用 Settings viewport，避免压到 header/footer。
- Slider Nub 的 tooltip 可使用 Content 可视边界，但 source 必须仍与 viewport 相交。

坐标全部通过 `source.mapToItem(root, 0, 0)` 进入 Content 局部坐标域。

## Follow Triggers

`repositionTooltip()` 在以下变化后执行：

- active source `x/y/width/height/visible` 变化。
- 当前页面 `contentY` 变化。
- Content `width/height`、viewport geometry 变化。
- Sidebar collapse 导致 Content width 或边界变化。
- active tooltip 文本、测量宽高变化。
- Slider Nub `x` 变化。

动态 source 通过 `Connections { target: root.activeTooltipSource }` 监听自身几何与 visible。父级滚动不会改变 source 自身 `y`，因此必须保留 currentPage `contentY` 监听，但由“关闭”改为“重定位并检查相交”。不使用逐帧 Timer。

## Visibility Contract

每次重定位先验证：

- source 存在且仍属于当前 Content。
- source 与其所有必要视觉祖先可见。
- source 映射矩形与 viewport 矩形存在交集。
- Content interactive/contentReady。

若失败，关闭 active tooltip。source 部分可见时继续跟随；完全离开 viewport 后关闭。Tooltip 自身不获取 focus、不接收 pointer。

## Slider Anchor

`LazerSettingsSlider` 暴露只读 `nubItem`，Tooltip 请求使用 Nub 而不是 Slider root。display text 更新时仍用相同 Nub source 重发请求，因此 bridge priority 和 owner 过滤不变。拖动导致 Nub `x` 改变，Content 的 dynamic Connections 立即重定位。

## Compatibility

- 不改变 `SettingsOverlayBridge.showTooltip/hideTooltip` 外部调用形态。
- 不改变 dropdown overlay、Settings owner 或配置数据。
- 保留 Row description priority `1`、Slider value priority `2`。
- reduced motion 只缩短/取消 opacity motion；位置始终准确更新。

## Test Seams

- Logic tests：自然尺寸 clamp、上下 placement、边缘 clamp、部分/完全相交。
- Content/Panel tests：短文本宽度、长文本换行高度、source 移动、滚动跟随、离开 viewport 关闭、外部 owner 忽略。
- Controls tests：Slider tooltip source 等于 `nubItem`，Nub X 变化。
- Overlay tests：tooltip 不抢 focus，关闭生命周期不残留。
