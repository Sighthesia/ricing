# 执行计划：设置分类前段命中诊断

## Ordered Checklist

1. 检查当前 task 规范和已提交的设置 hover/focus 诊断历史，确认不重复引入旧 tooltip 或 mask 逻辑。
2. 扩展 `LazerSettingsContent`/`LazerSettingsPanel` debug snapshot，支持完整目标 Row 列表和 page/viewport 状态。
3. 暴露最小 IPC 分类选择或按分类采样入口；不得添加生产鼠标捕获层。
4. 运行一条分类对比命令，输出 Appearance 前五、Bar 前四、Notifications 全部 Row 的 JSON 状态。
5. 如果环境允许，使用固定坐标对 Row 与 control 做 hover/click/focus 采样；否则记录无法进行 compositor pointer 注入。
6. 生成 3-5 个假设的证据矩阵，并针对最高排名假设做单变量 probe。
7. 只有根因确认后，补充最小生产修复和对应回归测试；否则停在诊断报告，不盲改。
8. 运行 `qmllint`、相关 `qs -p tests/qml/...`、`timeout 15s qs -p .`、Python tests、`git diff --check`。
9. 更新 `runtime-results.md`，运行 Trellis validation，并提交诊断或修复结果。

## Validation Commands

```bash
qs ipc -p . call settings debugHover true
qs ipc -p . call settings openHoverDebug eDP-1
qs ipc -p . call settings snapshotHover
qs log --id <current-id> -t 120

qmllint modules/lazerbar/LazerSettingsPanel.qml \
  modules/lazerbar/LazerSettingsContent.qml \
  modules/lazerbar/LazerSettingsRow.qml

timeout 15s qs -p .
python3 -m pytest -q
```

## Risks

- 当前 snapshot 的前四 Row 上限会遗漏外观第五项和其它分类尾项，必须先解除或显式说明。
- 多个持久 page 同时挂载，单看 opacity 不能证明 pointer ownership；必须同时检查 enabled/visible/z/clip。
- QML test runner 的 `qrc:/qs-blackhole` 错误会阻断行为断言。
- 没有可靠 Wayland pointer injection 时，运行时只能证明几何和状态，不能证明真实 compositor click 命中。

## Review Gate

- 诊断阶段完成后先提交证据和根因结论，不在同一阶段未经批准直接实施大范围修复。
- 若需要修改生产代码，基于证据更新设计和验收标准后再次请求实施批准。

## Execution Result

- Expanded the runtime row collector from four rows to all rows on the selected page.
- Added page-state and control-focus fields to the diagnostic snapshot.
- Added process-local `settings.debugCategory(category)` IPC to reopen the debug panel on Appearance, Bar, or Notifications using the same probe flow.
- Appearance and Bar snapshots show normal row/control geometry and enabled state for the reported active rows; Bar's floating-margin row is disabled as expected while floating mode is off.
- Notifications has the same geometry contract with a shorter content height.
- No production behavior fix was applied because the structural probe did not yet prove a single root cause.
- `qmllint` passed for the changed QML files.
- The production configuration loaded with the existing notification-server registration warning.
- `python3 -m pytest -q` passed (`4 passed`).
- Settings QML tests remain blocked at load time by `qrc:/qs-blackhole: No such file or directory`.
