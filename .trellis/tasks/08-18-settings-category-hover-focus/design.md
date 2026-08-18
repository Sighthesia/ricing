# 技术设计：设置分类背景聚焦命中修复

## Architecture

修复边界集中在 `LazerSettingsRow`。Row 是设置卡片背景状态的唯一拥有者；外观、顶部栏和通知页面继续复用同一 Row，不在各分类页面分别添加命中逻辑。

每个 Row 保持三个独立区域：

1. Row 背景区域：覆盖完整卡片矩形，只负责 hover/highlight 状态观察与绘制。
2. 控件区域：保持现有控件的视觉尺寸和输入处理，负责文本编辑、选择菜单、滑块调值或开关切换。
3. 恢复默认区域：保持独立的按钮 hover/focus/click 行为。

`cardSurface` 和 `cardHighlight` 都是纯视觉层。`cardHighlight` 必须继续 `enabled: false`，不成为新的 PointerHandler 命中层。Row 的 `HoverHandler` 继续 `blocking: false`，确保控件和恢复按钮不被背景观察器阻断。

## Geometry Contract

- Row 的背景 hover 边界使用 Row 根 Item 的实际 `width` 和 `height`。
- `cardSurface` 与 Row 根 Item 同尺寸，不能从 `controlHost` 或控件的 `implicitHeight` 推导边界。
- `cardHighlight` 与 `cardSurface` 同尺寸，只绘制背景 focus ring。
- 控件自身的 `sceneRect` 只代表控件视觉/操作区域，不被扩大到整张卡片。
- 不修改 `Flickable` 的滚动与 viewport clipping，除非诊断证明 Row 根高度或祖先 clip 本身错误。
- 对 `standard`、`inline`、`split`、`choice` 四种 presentation 分别验证几何契约。

## Interaction Flow

```text
pointer enters Row background or child area
  -> Row HoverHandler observes without blocking
  -> rowHovered
  -> rowHighlighted
  -> cardSurface/cardHighlight render background state

control activeFocus
  -> rowHighlighted
  -> cardSurface/cardHighlight render background focus state

pointer enters/clicks control
  -> existing control PointerHandler/TapHandler

pointer enters/clicks reset button
  -> existing reset button handlers
```

Row 不把背景点击转发给控件，也不根据 `rowPresentation` 模拟控件动作。用户确认的行为是背景区域触发背景聚焦框，而不是扩大控件操作区域。

## Diagnostic Contract

使用现有设置 snapshot 入口，补充或校正以下字段：

- 页面：`enabled`、`visible`、`opacity`、`z`、`contentY`、`contentHeight`。
- Row：local/scene rect、`visible`、`enabled`、`opacity`、`z`、`rowHovered`、`rowHighlighted`。
- 背景层：surface/highlight local/scene rect、`enabled`、border width。
- 控件：local/scene rect、`visible`、`enabled`、`opacity`、`z`、`activeFocus`、`focusVisible`。
- Hover handler：`blocking` 和实际 hover 状态。

对比目标为 Appearance 前五项、Bar 前四项和 Notifications 全部 Row。分类切换后必须等待当前页稳定，再采集状态，避免把页面过渡期间的 opacity/x 当作命中结论。

## Compatibility And Rollback

不改变设置数据模型、保存/reset、分类导航、下拉菜单、Flickable 滚动或 PanelWindow mask。若运行时证据显示根因不在 Row 背景边界，应回滚生产修复部分，保留诊断 snapshot 和测试，不引入未证实的透明捕获层。

## Risks

- `Flickable` 或 inactive page 仍可能在视觉相同位置参与命中；必须同时检查 `enabled`、`visible`、`opacity`、`z` 和 ancestor clip。
- QML 测试环境可能被 `qrc:/qs-blackhole` 阻断；此时只能把 snapshot、qmllint 和生产加载作为已验证证据，不能声称行为测试通过。
- Row 的 reset button 可能在可见时覆盖右侧区域；它必须继续优先拥有自己的交互。
