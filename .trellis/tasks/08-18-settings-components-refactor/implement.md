# Implementation Plan

1. 建立基线：读取相关组件和测试，运行 `qmllint`、`git diff --check`、设置 QML 测试入口，并记录环境失败与现有行为。
2. 重构 `LazerSettingsRow`：将卡片矩形、content rect、control rect、恢复按钮预留和四种布局模式收敛到单一路径；移除会反向改变控件几何的重复 Binding。
3. 迁移 TextField/Choice/Slider/Toggle 的 root bounds 和交互 owner 契约，保持已有信号、公开属性、焦点和 tooltip/dropdown source identity。
4. 重构 `LazerSettingsContent` 的 viewport 与 overlay 命中边界：装饰层禁用输入，dropdown catcher 仅打开时启用，tooltip 保持视觉-only。
5. 为三个分类增加代表性集成测试和几何断言，覆盖边缘、中部、控件内部、滚动、搜索、分类切换、关闭重开及禁用项。
6. 每次 QML 修改后运行相关 QML 测试和 `qmllint`，修复所有新增 WARN/ERROR；若 runner 仍被环境阻断，使用静态验证和配置启动检查并记录。
7. 执行独立质量检查，确认持久化接口、overlay bridge 和页面注入 API 无非预期变更。
8. 更新前端质量规范，运行最终检查并以 Conventional Commit 提交。

## Validation Commands

- `qmllint modules/lazerbar/LazerSettingsRow.qml modules/lazerbar/LazerSettingsTextField.qml modules/lazerbar/LazerSettingsChoice.qml modules/lazerbar/LazerSettingsSlider.qml modules/lazerbar/LazerSettingsToggle.qml modules/lazerbar/LazerSettingsContent.qml`
- `qs -p tests/qml/tst_lazer_settings_controls.qml`
- `qs -p tests/qml/tst_lazer_settings_panel.qml`
- `timeout 15s qs -p .`
- `git diff --check`
- `git status --short`

## Risky Files And Rollback Points

- Row/layout migration: `modules/lazerbar/LazerSettingsRow.qml`; rollback before changing control contracts.
- Overlay migration: `modules/lazerbar/LazerSettingsContent.qml`; rollback without touching `SettingsOverlayBridge` protocol.
- Control migration: four control QML files; rollback one control at a time while keeping page declarations unchanged.
- Test migration: `tests/qml/tst_lazer_settings_controls.qml`, `tests/qml/tst_lazer_settings_panel.qml`.
