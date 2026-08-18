# 执行计划

1. 加载 frontend spec 和跨层指南，确认当前工作区仅包含任务 artifacts。
2. 扩展 `SettingsService` 现有 IPC，加入 `debugHover(enabled)` 与 `snapshotHover()`；通过 TopBar 将 Debug 状态/token 传入每屏 Overlay。
3. 在 Overlay/Panel/Content 增加只读快照函数和去重日志，不增加 PointerHandler 或改变输入层级。
4. 启动真实 Shell，通过 `afloat-ipc` 打开设置并采集 Appearance/Bar/Notifications 的快照和状态变化；保存修复前关键日志到任务 `research/`。
5. 按 design decision tree 定位主导边界，更新 task research 与设计结论。
6. 实施被证据支持的最小修复；只有 decision gate 触发时按代表 Row -> 控件批次 -> 三分类进行内部组件重构。
7. 用真实面板复测完整 Row/控件区域、相邻移动、滚动、分类切换和重开；保留修复后对照日志。
8. 派发 `trellis-implement` 与 `trellis-check`，检查输入 owner、隐私、IPC 兼容、Slider/Choice/TextField/Toggle 契约和循环论证。
9. 运行 `qmllint`、`python3 -m pytest -q`、`git diff --check`、`timeout 15s qs -p .`；单独报告 QML runner 限制。
10. 使用 `trellis-update-spec` 记录已验证契约，Conventional Commit 提交，归档任务。

## Validation Commands

- `scripts/afloat-ipc settings debugHover true`
- `scripts/afloat-ipc settings snapshotHover`
- `scripts/afloat-ipc settings openHoverDebug <screenName>`
- `scripts/afloat-ipc settings debugHover false`
- `qmllint <touched-qml-files>`
- `python3 -m pytest -q`
- `git diff --check`
- `timeout 15s qs -p .`

## Rollback Points

- Debug IPC/日志：可整体删除，不影响设置行为。
- 边界修复：按单层 diff 回退。
- 组件重构：按控件迁移批次回退，保持旧 `LazerSettingsRow` API。
