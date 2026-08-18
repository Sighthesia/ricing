# 实现设置面板 mask 对照实验

## Goal

增加一个默认关闭、非持久化的诊断开关，使 Settings `PanelWindow` 可以在相同布局和相同鼠标坐标下切换 `Region` mask，获得 `mask=true/false` 的真实运行时对照证据。

## Background

- 当前 Settings `PanelWindow` 使用 `mask: Region { item: settingsOverlay.blocksDesktop ? settingsOverlay : null }`。
- 现有 debug IPC 可以打开面板并输出 QML 几何，但不能切换 mask，也没有自动 pointer 坐标注入。
- 之前 Row、Content 和 tooltip 局部修复均未改变用户反馈，因此本实验必须隔离 mask 变量，不再修改组件交互逻辑。
- 设置 QML 测试当前因 `qrc:/qs-blackhole` 在加载阶段失败，不能作为本实验的唯一验证来源。

## Requirements

### R1. 诊断开关

- 增加 `settings` IPC 诊断函数，用于设置 mask override：`auto`、`on`、`off` 三种状态。
- 默认值为 `auto`，完全保持当前生产行为。
- 状态只存在于当前 Quickshell 进程，不写入设置 JSON、不触发 `save()`、不影响普通设置服务。
- IPC 日志必须输出 override、screen、mask effective state 和实验 token。

### R2. PanelWindow mask 对照

- `auto` 使用现有 `settingsOverlay.blocksDesktop` 作为 mask owner。
- `on` 强制使用现有 overlay 作为 mask owner。
- `off` 暂时移除 Settings Window mask，但不改变 overlay/page 的 visible、enabled、opacity、geometry 或 persistence。
- 关闭或重启 shell 后 override 恢复 `auto`。

### R3. 可审计验证

- 提供可重复命令打开面板、切换 override、打印 QML snapshot 和读取日志。
- 记录同一屏幕、同一坐标、同一分类和同一控件在三种 mask 状态下的结果。
- 优先使用 Wayland 可用的 pointer 坐标注入工具；如果环境不具备，必须明确报告无法取得 hover 对照，而不是伪造结果。

## Out Of Scope

- 不修改 Row、TextField、Choice、Slider、Toggle、Flickable、tooltip priority 或焦点逻辑。
- 不改变持久化设置、主题、后端服务或生产 UI 行为。
- 不把诊断 override 作为长期用户设置暴露给 UI。

## Acceptance Criteria

- [ ] `qs ipc -p . show` 暴露 mask override 诊断函数。
- [ ] `auto/on/off` 调用均有日志和有效状态变化，非法值被拒绝或归一化为 `auto`。
- [ ] `auto` 的 mask 行为与改动前一致。
- [ ] 至少完成一组同屏幕、同坐标、同控件的 mask on/off 对照，或完整记录环境阻塞。
- [ ] 对照结果能明确判断事件未进入 PanelWindow、进入 QML 但被内部层截获，或控件自身状态异常。
- [ ] 相关 QML 静态检查、配置启动和 `git diff --check` 通过；不新增 QML WARN/ERROR。
