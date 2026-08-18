# 执行计划：设置分类背景聚焦命中修复

## Ordered Checklist

1. 读取 frontend/QML 规范和当前设置诊断历史，确认不重复引入 tooltip、mask 或 Row 点击转发。
2. 运行现有分类 snapshot，补齐 Appearance 前五、Bar 前四和 Notifications 全部 Row 的几何、层级和 focus 字段。
3. 以一个失败 Row 和一个通知正常 Row 做 scene rect 对比，确认是背景 hover 边界、页面覆盖、祖先裁剪或 focus ownership 问题。
4. 只在证据支持时修改 `LazerSettingsRow` 的背景 hover 几何或相关状态来源；不改变控件内部尺寸和 handlers。
5. 增加最小回归测试，覆盖四种 presentation、整张 Row 背景边界、非阻塞 hover、disabled Row 和 reset button 边界。
6. 运行相关 QML 测试、`qmllint`、生产配置加载、Python 测试和 `git diff --check`。
7. 若 QML runner 仍被 `qrc:/qs-blackhole` 阻断，记录阻断日志并保留可运行的静态/runtime 验证；不得把阻断视为通过。
8. 更新项目 spec/经验记录（仅在确认出现可复用的新约束时），运行 Trellis validation。
9. 检查 diff，仅提交本任务相关文件。

## Validation Commands

```bash
qs ipc -p . call settings debugHover true
qs ipc -p . call settings openHoverDebug eDP-1
qs ipc -p . call settings snapshotHover
qmllint modules/lazerbar/LazerSettingsRow.qml modules/lazerbar/LazerSettingsContent.qml
qs -p tests/qml/tst_lazer_settings_controls.qml
qs -p tests/qml/tst_lazer_settings_panel.qml
timeout 15s qs -p .
python3 -m pytest -q
git diff --check
```

## Risky Files And Rollback Points

- Primary implementation file: `modules/lazerbar/LazerSettingsRow.qml`.
- Diagnostic/test files: `modules/lazerbar/LazerSettingsContent.qml`, relevant `tests/qml/tst_lazer_settings_*.qml`.
- Rollback point: if snapshot evidence does not show a Row/background geometry mismatch, stop before production edits and retain only diagnostic/test changes.
- Do not modify `SettingsService.qml`, persistence code, overlay mask code, or category page declarations unless a concrete evidence path requires it.

## Completion Gate

Before starting execution, the user must approve the final planning summary. After implementation, all acceptance criteria in `prd.md` must be checked with evidence, including the full-card background hover behavior and preservation of child control input.
