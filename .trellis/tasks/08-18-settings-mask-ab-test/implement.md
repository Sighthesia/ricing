# Implementation Plan

1. 读取当前 SettingsService IPC、TopBar mask 和前端规范，确认无并发修改。
2. 在 SettingsService 增加默认 `auto` 的内存 override、IPC setter 和结构化 debug 日志。
3. 在 TopBar 将有效 override 传入 Settings Window mask，保持 auto 路径等价。
4. 每次 QML 修改后运行 `qmllint`、`qs -p .` 和相关设置测试，记录 `qrc:/qs-blackhole` 阻断。
5. 启动/连接活动 Quickshell 实例，执行 auto/on/off 调用并采集日志。
6. 尝试使用可用 Wayland pointer 注入工具完成同坐标 hover 对照；若不可用，记录精确缺口。
7. 执行独立质量检查，确认没有 persistence 或普通输入逻辑变更。
8. 更新规范/诊断结果，使用 Conventional Commit 提交。

## Validation Commands

- `qmllint services/SettingsService.qml modules/lazerbar/TopBar.qml`
- `qs -p .`
- `qs ipc -p . show`
- `qs ipc -p . call settings maskOverride auto`
- `qs ipc -p . call settings maskOverride on`
- `qs ipc -p . call settings maskOverride off`
- `qs ipc -p . call settings openHoverDebug eDP-1`
- `qs ipc -p . call settings snapshotHover`
- `git diff --check`

## Review Gates

- 不修改 Row/控件命中逻辑。
- `auto` 必须与原 mask 语义一致。
- override 不得写入 persisted settings。
- 不把没有 pointer 坐标证据的日志快照当作 hover 对照通过。
