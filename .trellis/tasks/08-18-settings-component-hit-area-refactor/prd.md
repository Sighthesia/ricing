# 设置面板组件交互区域重构

## Goal

让设置面板中的每个设置项成为一个清晰的一体化 Row：鼠标悬停只由 Row 区域决定，输入框、下拉框等控件只保留其真实可编辑或可点击区域，并移除描述型浮动提示，避免嵌套命中区域和跨层 tooltip 造成误触、遮挡或 hover 状态分裂。

## Confirmed Facts

- `LazerSettingsRow.qml` 当前通过 row-level `HoverHandler`、reset button hover 和 `controlItem.hovered` 合并 `rowHovered`。
- `LazerSettingsTextField.qml`、`LazerSettingsChoice.qml`、`LazerSettingsSlider.qml`、`LazerSettingsToggle.qml` 都拥有独立的 `HoverHandler`；它们的 `TapHandler` 或 `TextInput` 负责真正的操作。
- `LazerSettingsRow.qml` 当前把 Row 或控件的 hover/focus 转为 `SettingsOverlayBridge` tooltip 请求。
- `LazerSettingsContent.qml` 拥有独立的 tooltip surface、tooltip fallback、定位和生命周期管理；下拉菜单仍需要保留为选择项的操作层。
- 设置页面通过 `LazerSettingsRow` 统一组合外观、顶部栏和通知页的组件，因此 Row 和四类基础控件是主要重构边界。

## Requirements

- Row 是设置项唯一的鼠标 hover 判定区域；Row 内部的 label、空白和控件区域都属于同一个 Row hover 区域。
- 控件不得再通过独立 `HoverHandler` 参与 Row hover 判定；控件内部只保留完成实际操作所需的点击、拖拽、编辑和键盘焦点行为。
- 输入框与其 Row 视觉和交互上保持一体：Row hover 负责整卡状态，TextInput 只负责编辑和提交。
- 下拉框与其 Row 视觉和交互上保持一体：Row hover 负责整卡状态，选择控件 header 只负责打开/关闭菜单，菜单项只负责选择值。
- 滑块和开关继续支持其现有点击、拖拽、双击恢复、键盘操作和焦点行为，但这些操作不得扩大到 Row 之外。
- 禁用所有描述型浮动提示：不再由 Row、控件或 SettingsOverlayBridge 触发 tooltip；设置内容不再显示 tooltip surface。
- 保留下拉菜单这个真正用于选择值的操作层，不把它误删为 tooltip。
- 不改变持久化、reset、搜索过滤、键盘导航、下拉选择和文本提交语义。
- 遵守现有 QML 注释、动画和 PanelWindow 约定；不引入新的全屏透明鼠标捕获层。

## Acceptance Criteria

- [ ] 鼠标在任意 Row 空白、label 或控件区域内时，Row 只产生一个统一 hover/highlight 状态。
- [ ] 鼠标离开 Row 后，Row hover 状态立即消失；控件自身 hover 不会在 Row 外单独触发视觉或逻辑状态。
- [ ] TextField 只有其编辑区域可编辑/聚焦；Row 的非控件区域不会意外修改文本。
- [ ] Choice 只有其 header 可打开下拉菜单；菜单外点击仍关闭菜单，菜单项仍可选择。
- [ ] Slider 只有其 track 区域可点击/拖动；Toggle 只有其 capsule 区域可点击。
- [ ] 设置面板任何 Row hover、控件 hover 或 focus 状态都不再显示描述型浮动 tooltip。
- [ ] 搜索过滤、分类切换、reset、保存、键盘操作和下拉菜单行为保持原有语义。
- [ ] `qmllint`、相关 QML 测试和 `qs -p .` 验证无新增 WARN/ERROR。

## Out Of Scope

- 不修改设置数据结构、持久化格式或 SettingsService API。
- 不改变 Row 的布局尺寸、颜色体系或控件视觉设计，除非删除 tooltip/hover 分裂必须触及对应状态绑定。
- 不取消下拉菜单本身，也不把整个 Row 改成点击即执行控件动作。

## Resolved Interaction Decision

- Row 内部的空白区域只负责统一 hover/highlight，不转发点击、不触发控件动作。
- 实际操作仅发生在控件自身区域、输入框编辑区域、下拉菜单区域和 reset 按钮区域。
