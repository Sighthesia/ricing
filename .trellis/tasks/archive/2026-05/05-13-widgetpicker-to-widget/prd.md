# Convert WidgetPicker to bar widget in right dock zone

## Goal

将 WidgetPickerWindow 改造为一个 bar widget 按钮，显示在 right dock zone 中。点击该按钮后弹出 widget 选择器。

## Requirements

1. **Widget 按钮**：
   - 创建一个新的 QML widget（如 `WidgetPickerButton.qml`），作为 bar 的一部分渲染
   - 按钮应显示在 right dock zone 中
   - 点击按钮调用 `BarLayoutService.toggleWidgetPicker()`

2. **Widget 注册**：
   - 在 `services/barlayout/BarLayoutLayoutModel.js` 的 `AVAILABLE_WIDGETS` 中注册新 widget
   - 设置 `section: "right"` 作为默认位置

3. **Widget 选择器**：
   - 保留现有的独立 `PanelWindow` 实现（`WidgetPickerWindow.qml`）
   - 选择器功能不变，仅入口从 `shell.qml` 直接引用变为通过 widget 按钮触发

4. **移除 BarWindow 中的内联按钮**：
   - 删除 `BarWindow.qml` 中硬编码的 `BarDockZoneBackground` 加号按钮（第 35-65 行）
   - `WidgetPickerWindow.qml` 保留不变

## Acceptance Criteria

- [ ] 新 `WidgetPickerButton.qml` 组件封装加号按钮逻辑
- [ ] 按钮作为 bar widget 注册到 `AVAILABLE_WIDGETS`，默认在 right section
- [ ] 点击按钮后弹出 widget 选择器（独立 PanelWindow）
- [ ] 删除 `BarWindow.qml` 中内联的加号按钮
- [ ] `shell.qml` 保留 `WidgetPickerWindow` 引用（Variants 组件需在 root 实例化）
- [ ] 不影响其他 bar section 的渲染

## Technical Notes

- 参考 `Placeholder.qml` 的 widget 实现方式
- 使用 `BarWidgetWrapper.qml` 进行包装
- 通过 `BarLayoutService` 控制选择器的显示/隐藏

## Decisions

- **选择器显示形式**：保留独立 `PanelWindow`（`WidgetPickerWindow.qml`），不做 Popup 或内嵌改造
- **BarDockZoneBackground 样式**：不修改，加号按钮复用现有背景组件

## Out of Scope

- 将选择器改为 Popup 或内嵌面板
- 修改 `BarDockZoneBackground.qml` 的绘制逻辑
- 选择器 UI 重构（搜索、卡片布局等）
