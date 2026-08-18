# Implementation Plan

1. 检查当前运行 Quickshell 实例、`qs ipc` target/function 语法、Settings debug IPC 和日志路径。
2. 设计并实现隔离的运行时采样 harness，优先复用现有 `debugSnapshot()`，不添加生产输入捕获层。
3. 增加 mask 开启/关闭的诊断对照入口，确保默认行为不变且不触碰持久化设置。
4. 运行固定坐标采样矩阵：三个分类、代表性 Row、控件内部、滚动、切换、关闭重开。
5. 记录每个实验的命中状态、scene geometry、mask 状态和结论；若无法运行，保存完整错误输出。
6. 调查并记录 `qrc:/qs-blackhole` 的测试 runner 阻断来源，必要时建立不进入生产代码的独立 QML harness。
7. 由主会话复核结果，形成按置信度排序的根因报告和下一步修复边界。

## Validation Commands

- `qs -p .`
- `qs ipc -p . list`
- `qs ipc -p . call settings debugHover true`
- `qs ipc -p . call settings snapshotHover`
- `qs ipc -p . call settings openHoverDebug <screen-name>`
- `qs -p tests/qml/tst_lazer_settings_controls.qml`
- `qs -p tests/qml/tst_lazer_settings_panel.qml`
- `git diff --check`

## Review Gates

- 未得到 mask 对照证据前，不修改生产 Row/控件命中逻辑。
- 不把 QML debug snapshot 当作 compositor 命中证据；必须明确其覆盖范围。
- 不把 QML runner 加载失败或静默退出当作测试通过。
