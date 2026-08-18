# 验证设置面板 mask 运行时命中

## Goal

通过可重复的运行时对照实验确认鼠标事件是否真正进入 Settings `PanelWindow` 的 QML scene，区分 Wayland `Region` mask 问题与 Content/Row/Flickable 内部命中问题。

## Confirmed Context

- `TopBar.qml:110-117` 创建固定左侧 Settings `PanelWindow`，并使用 `mask: Region { item: settingsOverlay.blocksDesktop ? settingsOverlay : null }`。
- `LazerSettingsOverlay.qml` 提供 `debugSnapshot()`，但当前快照只包含 QML item 几何、visible/enabled/opacity/z、页面和 tooltip 状态，不能证明 compositor 的实际输入命中。
- 最近的 Row/Content 重构没有改变 `PanelWindow.mask`，用户仍报告没有改善。
- 设置 QML 测试入口在加载阶段报 `qrc:/qs-blackhole: No such file or directory`，必须单独处理或明确记录，不能作为运行时命中证据。

## Requirements

### R1. 运行时坐标证据

- 能打开设置面板并输出 overlay、panel、content、viewport、代表性 Row/control 的本地和 scene 矩形。
- 对鼠标位于 Row 顶部/中部/底部、控件内部、相邻 Row 和滚动后位置时，记录 `HoverHandler.point.scenePosition`、hover/focus 和当前 tooltip source。
- 日志必须包含屏幕标识和实验模式，避免混淆多屏实例。

### R2. mask 对照实验

- 在不改变设置持久化和页面组件的前提下，对同一坐标执行 mask 开启与 mask 关闭两组实验。
- 实验结果必须能区分：事件未进入 PanelWindow、事件进入但被 QML 层截获、或事件进入且控件自身状态异常。
- 对照开关必须是诊断专用、默认关闭，不进入持久化设置语义。

### R3. 验证基础设施

- 确认 `qs ipc` 的真实 target/function 调用方式及当前运行实例是否存在。
- 确认设置 QML 测试 `qrc:/qs-blackhole` 错误的来源、可行修复或替代 harness。
- 任何替代 harness 必须输出可审计的 pass/fail 或坐标状态，不接受静默退出。

## Out Of Scope

- 本任务不修改 Row、控件、tooltip priority、焦点特判或设置服务。
- 本任务不提交长期生产诊断捕获层；临时 harness 必须与产品代码隔离，或明确标记为后续移除。
- 本任务不根据未完成实验直接提出最终 UI 修复。

## Acceptance Criteria

- [ ] 有明确命令可以启动/连接目标并打开 Settings debug 实验。
- [ ] 至少记录一组 mask 开启和关闭的相同坐标结果。
- [ ] 报告明确指出事件在 compositor、PanelWindow、QML overlay、viewport/Flickable 或控件层的边界位置。
- [ ] 记录 `qrc:/qs-blackhole` 测试限制及其对证据强度的影响。
- [ ] 本任务完成前不修改生产组件逻辑。
