# 执行计划：设置面板 Row 焦点命中修复

## Ordered Checklist

1. 将当前诊断假设转换为可运行的 controls 回归断言：Row 空白不聚焦控件、TextField 控件区域获得 editor focus、Choice header 获得 Choice focus 并打开菜单。
2. 运行该 QML 测试确认现状失败；若测试环境在加载阶段被 `qrc:/qs-blackhole` 阻断，记录阻断并使用静态/运行时辅助检查继续。
3. 修复 `LazerSettingsChoice.qml` 的 TapHandler focus 顺序，确保鼠标点击等价于键盘打开路径的 focus ownership。
4. 检查并修复 `LazerSettingsTextField.qml` 的 wrapper `TapHandler` 与内部 `TextInput` pointer ownership；只保留 TextField 自身区域内的 focus 行为。
5. 验证 `LazerSettingsRow.qml` 没有新增点击转发，Row 空白仍只有 hover/highlight。
6. 运行相关 QML tests、`qmllint`、`qs -p .` 和 Python tests，修复新增 WARN/ERROR。
7. 运行 Trellis validation，检查 diff，提交单一 conventional commit。

## Validation Commands

```bash
qmllint modules/lazerbar/LazerSettingsRow.qml \
  modules/lazerbar/LazerSettingsTextField.qml \
  modules/lazerbar/LazerSettingsChoice.qml \
  modules/lazerbar/LazerSettingsContent.qml \
  tests/qml/tst_lazer_settings_controls.qml

qs -p tests/qml/tst_lazer_settings_controls.qml
qs -p tests/qml/tst_lazer_settings_panel.qml
timeout 15s qs -p .
python3 -m pytest -q
```

## Risk Points

- `TextInput` 与外层 `TapHandler` 的 pointer ownership 变化可能影响点击编辑、选择文本和 focus-loss commit。
- Choice 点击顺序变化可能影响 dropdown layer 的 focus、Escape 关闭和 focus 返回。
- Row 观察型 HoverHandler 不能改成 blocking 或新增透明点击层，否则会重新阻塞控件。
- 当前 QML 测试环境的 `qrc:/qs-blackhole` 错误可能隐藏行为回归，必须在报告中明确区分环境阻塞和代码验证。

## Review Gate

- 本规划摘要需要用户批准后才能运行 `task.py start`。
- 实现完成后先验证焦点和命中区域，再验证视觉过渡和完整测试。
- 所有临时诊断输出必须在提交前移除。

## Execution Result

- Choice header `TapHandler` now acquires Choice focus before opening the dropdown.
- Added a controls regression for Choice mouse focus/menu opening and retained the TextField control-area versus Row-blank focus contract.
- `qmllint` passed for the changed QML and test files.
- `timeout 15s qs -p .` loaded the production configuration; only the existing notification-server registration warning remained.
- `python3 -m pytest -q` passed (`4 passed`).
- The QML test runner remains blocked before assertions by the existing `qrc:/qs-blackhole: No such file or directory` environment error.
