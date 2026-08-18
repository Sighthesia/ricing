# 技术设计：设置面板组件交互区域重构

## Boundary

本任务只调整 `modules/lazerbar` 中设置面板的鼠标命中和 tooltip 生命周期，不修改设置数据、服务 API 或持久化流程。

主要边界：

- `LazerSettingsRow.qml`: 统一拥有 Row hover/highlight，移除 tooltip 产生逻辑。
- `LazerSettingsTextField.qml`: 移除独立 hover 状态及其视觉依赖，保留 `TextInput` focus、提交和清空契约。
- `LazerSettingsChoice.qml`: 移除独立 hover 状态及其视觉依赖，保留 header 点击、键盘打开和菜单选择契约。
- `LazerSettingsSlider.qml`: 移除独立 hover 状态和数值 tooltip，保留 track 点击、拖拽、键盘、focus 和 default reset。
- `LazerSettingsToggle.qml`: 移除独立 hover 状态及 scale hover 反馈，保留 capsule 点击和键盘操作。
- `SettingsOverlayBridge.qml`: 删除 tooltip signal、请求列表和相关 helper；保留下拉菜单 signal。
- `LazerSettingsContent.qml`: 删除 tooltip state、surface、定位、fallback、Connections 与公开 alias；保留下拉菜单 owner 和 outside-click catcher。

## Interaction Contract

```text
pointer enters Row
  -> rowHover.hovered
  -> rowHovered / rowHighlighted
  -> card highlight only

pointer enters control
  -> Row hover remains the owner
  -> control handles only its own click/edit/drag gesture
  -> no tooltip request

pointer enters Row blank area
  -> Row highlight only
  -> no forwarded control action
```

`LazerSettingsRow` 的 `rowHovered` 不再依赖 `controlItem.hovered`。Row-level `HoverHandler` 继续使用 `blocking: false`，避免观察型 handler 阻塞嵌套控件的实际手势；控件仍可接收自己的 `TapHandler`、`DragHandler`、`TextInput` 和键盘事件，但不再暴露或驱动独立 hover 视觉状态。

## Component Details

### TextField

- 删除 `fieldHover`、`hovered` 和 `debugHoverScenePoint`。
- `fieldSurface.border.color` 只根据编辑器 focus 渲染，不再因字段 hover 改变。
- 保留 `TapHandler` 以便点击编辑区域聚焦；Row 空白不触发 `focusEditor()`。

### Choice

- 删除 `headerHover`、`hovered` 和 `debugHoverScenePoint`。
- header surface 颜色只根据 `menuOpen` 与 focus 状态决定，Row card 负责整卡 hover。
- 保留 header 的 `TapHandler` 和键盘 `Keys`，下拉菜单继续通过 bridge 单独管理。

### Slider

- 删除 `hoverHandler`、`hovered` 和所有 tooltip refresh/fallback 逻辑。
- thumb scale 仅由 dragging/press 状态驱动，不因鼠标悬停产生独立反馈。
- 保留 track `TapHandler`、`DragHandler`、keyboard handlers 和 double-tap reset。

### Toggle

- 删除 `hoverHandler`、`hovered` 和 `debugHoverScenePoint`。
- capsule scale 仅由 pressed 状态驱动；Row card 负责 hover/highlight。
- 保留 `TapHandler`、Space/Return 和 focus contract。

## Tooltip Removal

设置面板内 tooltip 是纯描述性 UI，本任务完全移除其生产和渲染路径：

- Row 不再读取 `descriptionText` 来请求 tooltip；`descriptionText` 仍保留用于搜索匹配。
- Slider 不再以 Nub 为 source 发送数值 tooltip。
- Bridge 不再维护 tooltip request registry。
- Content 不再挂载 tooltip surface，也不再响应 tooltip bridge signals。
- `LazerSettingsContent` 的 tooltip alias 和 debug snapshot 字段删除或固定为无 tooltip 状态；优先删除无用字段，避免保留伪兼容接口。

## Compatibility

- 页面中的 `descriptionText`、搜索匹配和 visible result count 不变。
- 下拉菜单的 `dropdownRequested` / `dropdownDismissed`、外部点击关闭和键盘导航不变。
- 设置保存、reset、focus、分类切换和 overlay close 不变。
- 由于 tooltip 是本任务明确取消的用户行为，不提供旧 tooltip API 的兼容层。

## Rollback

若验证发现控件实际操作被 Row-level observer 阻塞，只调整 Row hover observer 的 `blocking` 和层级，不恢复 tooltip；若下拉菜单失效，回滚仅限 dropdown layer 相关改动，不恢复描述 tooltip。
