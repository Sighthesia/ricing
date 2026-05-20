# Design: WidgetPickerButton as Bar Widget

## Architecture

将 `BarWindow.qml` 中内联的加号按钮抽取为 `modules/bar/widgets/WidgetPickerButton.qml`，注册到 bar layout 系统，通过 `BarSection` + `BarWidgetWrapper` 自动渲染在 right dock zone。

```
shell.qml
├── BarWindow (PanelWindow per screen)
│   └── BarContent
│       ├── BarSection "left"
│       ├── BarSection "center"   → Placeholder widget
│       └── BarSection "right"    → WidgetPickerButton widget (new)
└── WidgetPickerWindow (独立 PanelWindow，保留不变)
```

## Data Flow

1. `BarLayoutLayoutModel.js` 注册 `widget-picker-button` 到 `AVAILABLE_WIDGETS`（section: "right"）
2. `DEFAULT_LAYOUT_MODEL` 包含该 widget，确保默认显示
3. `BarSection` 渲染 right section 时，`BarWidgetWrapper` 加载 `WidgetPickerButton.qml`
4. 按钮点击 → `BarLayoutService.toggleWidgetPicker("center")` → `WidgetPickerVisible` 翻转
5. `WidgetPickerWindow` 监听 `widgetPickerVisible`，独立 PanelWindow 显示/隐藏

## Contracts

### WidgetPickerButton.qml
- 纯 content 组件，不包含窗口管理
- 复用 `BarDockZoneBackground` 作为背景
- 内部 `Text { text: "+" }` + `MouseArea`
- 点击调用 `Services.BarLayoutService.toggleWidgetPicker()`

### BarLayoutLayoutModel.js 变更
- `AVAILABLE_WIDGETS` 新增条目：`{ id: "widget-picker-button", label: "Widget Picker", section: "right", source: "...WidgetPickerButton.qml" }`
- `DEFAULT_WIDGET_SOURCE_BY_ID` 新增映射
- `DEFAULT_LAYOUT_MODEL.widgets` 新增默认条目

### BarWindow.qml 变更
- 删除第 35-65 行内联的 `BarDockZoneBackground` 加号按钮

### shell.qml 变更
- 移除 `Bar.WidgetPickerWindow {}` 引用（选择器由 widget 按钮按需触发，不再需要在 shell root 显式实例化）

## Trade-offs

| 决策 | 收益 | 代价 |
|------|------|------|
| 保留独立 PanelWindow | 改动最小，Wayland 兼容性好 | 选择器仍是独立窗口层，非 bar 内嵌 |
| 复用 BarDockZoneBackground | 视觉一致性，零新增 UI 代码 | 按钮样式受背景组件约束 |
| 注册为 layout widget | 用户可通过布局系统管理位置 | 需维护 AVAILABLE_WIDGETS 条目 |

## Compatibility

- `BarWidgetWrapper` 已支持动态 `source` 加载，无需修改
- `BarSection` 的 `Repeater` 基于 `sectionModel` 驱动，新增 widget 自动生效
- `WidgetPickerWindow` 的 `visible` 绑定不变，行为一致
