# 执行计划

1. 在挂载的设置面板测试中建立行交互状态转换回归：首行离开后旧请求消失，下一行可成为提示所有者；控件焦点保持行高亮。
2. 调整 `LazerSettingsRow`，让 `refreshTooltip()` 从原始输入源计算即时活性，同时保留 `rowHighlighted` 作为声明式视觉状态。
3. 检查 Appearance、Bar、Notifications 的代表性行及四种控件是否共享同一状态路径。
4. 运行 `qmllint`、`git diff --check`、Python 测试和 `qs -p .` 启动检查；尝试相关 QtTest 并记录测试发现限制。
5. 主会话派发 `trellis-implement` 与 `trellis-check` 审查；根据最终发现更新前端质量规范，提交 Conventional Commit 并归档任务。

## Validation

- `qmllint modules/lazerbar/LazerSettingsRow.qml tests/qml/tst_lazer_settings_panel.qml`
- `QT_QPA_PLATFORM=offscreen qmltestrunner -input tests/qml/tst_lazer_settings_panel.qml -v2`
- `python3 -m pytest -q`
- `git diff --check`
- `timeout 15s qs -p .`

## Rollback Point

仅回退本任务对 `LazerSettingsRow.qml` 与其测试/规范的提交；不触碰已提交的 Tooltip bridge 活性来源修复。
