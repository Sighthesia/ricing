# Implement: WidgetPickerButton as Bar Widget

## Checklist

### Step 1: Create `WidgetPickerButton.qml`
- [ ] 创建 `modules/bar/widgets/WidgetPickerButton.qml`
- [ ] 导入 `../../services` 和 `BarDockZoneBackground`
- [ ] 内容：`BarDockZoneBackground` + `Text { text: "+" }` + `MouseArea`
- [ ] 点击调用 `Services.BarLayoutService.toggleWidgetPicker()`
- [ ] 参考 `Placeholder.qml` 的结构（纯 content 组件）

### Step 2: Register in layout model
- [ ] `services/barlayout/BarLayoutLayoutModel.js`：
  - `DEFAULT_WIDGET_SOURCE_BY_ID` 新增 `"widget-picker-button": "../../modules/bar/widgets/WidgetPickerButton.qml"`
  - `AVAILABLE_WIDGETS` 新增条目（id, label, description, section: "right"）
  - `DEFAULT_LAYOUT_MODEL.widgets` 新增默认条目（section: "right", order: 0）

### Step 3: Remove inline button from `BarWindow.qml`
- [ ] 删除 `BarWindow.qml` 第 35-65 行（`BarDockZoneBackground` 加号按钮）
- [ ] 保留 `PanelWindow` 和 `BarContent` 不变

### Step 4: Clean up `shell.qml`
- [ ] 移除 `Bar.WidgetPickerWindow {}` 引用（第 17-19 行）
- [ ] 移除对应的 `import`（如果不再需要）

## Validation

- `qmllint` 通过所有修改的 QML 文件
- 右 dock zone 显示加号按钮
- 点击按钮弹出 widget 选择器
- 选择器功能正常（列表、添加 widget）
- center section 渲染不受影响

## Rollback Points

- Step 1 失败：删除 `WidgetPickerButton.qml`，无其他影响
- Step 2 失败：回退 `BarLayoutLayoutModel.js` 变更
- Step 3 失败：恢复 `BarWindow.qml` 内联按钮
- Step 4 失败：恢复 `shell.qml` 引用

## Risk Files

- `services/barlayout/BarLayoutLayoutModel.js` — layout model 变更影响所有 widget 渲染
- `modules/bar/BarWindow.qml` — 删除代码需确认无副作用
