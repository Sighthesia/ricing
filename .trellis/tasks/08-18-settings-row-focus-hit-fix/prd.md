# 修复设置面板 Row 焦点命中

## Goal

修复设置面板中输入框和下拉框在鼠标交互后无法显示预期 focus ring 的问题，同时保持 Row 统一 hover 和控件局部操作区域的边界。

## Confirmed Facts

- 当前分支为 `lazer`，前一轮重构提交为 `df1e14b`。
- `LazerSettingsRow` 的 Row hover 由 `HoverHandler` 观察，`blocking: false`；Row 空白没有点击转发逻辑。
- Row 的整卡高亮由 `rowHighlighted = rowHovered || controlItem.activeFocus` 驱动。
- `LazerSettingsTextField` 的 focus ring 只由内部 `TextInput.activeFocus` 驱动；自身 `TapHandler` 点击后调用 `editor.forceActiveFocus()`。
- `LazerSettingsChoice` 的 focus ring 只由 Choice root 的 `activeFocus` 驱动；自身 `TapHandler` 只调用 `openMenu()`，不会先调用 `forceActiveFocus()`。
- 当前设置面板没有 tooltip 生产或渲染路径，tooltip 缺失不是本次焦点框问题的原因。
- 现有 QML 测试包含 Row hover 和 TextField focus 的断言，但由于环境缺少 `qrc:/qs-blackhole`，无法加载到断言阶段。

## Requirements

- 鼠标进入任意设置 Row 时，Row 必须产生稳定、可见的统一 hover/focus-style 外框。
- 鼠标进入输入框自身区域时，输入框必须获得编辑焦点并显示 focus ring；点击 Row 空白区域不得聚焦输入框。
- 鼠标点击下拉框自身 header 区域时，下拉框必须先获得 active focus 并显示 focus ring，再打开菜单。
- 下拉菜单打开后，菜单项选择、外部点击关闭和键盘 Escape 行为保持不变。
- 不恢复 tooltip，不引入全屏透明捕获层，不扩大控件实际操作区域到 Row 空白区域。
- 不改变保存、reset、搜索、分类切换和键盘导航语义。

## Acceptance Criteria

- [ ] 鼠标在 Row 空白或 label 区域时，Row 外框可见，输入框/下拉框不会获得 focus。
- [ ] 鼠标点击 TextField 自身区域后，`editor.activeFocus === true` 且 field focus ring 可见。
- [ ] 鼠标点击 Choice header 后，`choice.activeFocus === true`、header focus ring 可见且菜单打开。
- [ ] 键盘 Enter/Space 打开 Choice 时仍保持 focus 和菜单行为。
- [ ] Slider、Toggle、reset 按钮原有点击、拖拽、键盘和 focus 行为不回归。
- [ ] 没有 tooltip 请求、tooltip surface 或 tooltip fallback。
- [ ] `qmllint`、相关 QML 测试、`qs -p .` 和 Python tests 通过，且无新增 WARN/ERROR。

## Out Of Scope

- 不重新设计 Row 或控件视觉风格。
- 不让 Row 空白点击转发为控件操作。
- 不修改 PanelWindow mask、SettingsService 或持久化数据。

## Diagnosis Hypotheses

1. Choice 的 `TapHandler` 没有调用 `forceActiveFocus()`，因此点击下拉 header 只开菜单而不显示 Choice focus ring。
2. TextField 的 `TapHandler` 与内部 `TextInput` 存在 pointer gesture 竞争，点击字段时 wrapper handler 可能无法稳定完成 focus；将 focus ownership 明确收敛到 `TextInput`/FocusScope 是候选修复。
3. 用户所称的“聚焦框”实际指 Row hover 外框；当前 Row 只有 hover 状态，不存在将 Row hover 显式命名为 focus-visible 的独立契约，可能导致观察和验收目标不一致。
