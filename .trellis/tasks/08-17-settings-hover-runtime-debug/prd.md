# 设置悬浮运行时调试与重构

## Goal

在真实运行的 Quickshell 设置面板中取得可审计的指针命中、坐标映射和状态日志，定位此前多轮修复均无效果的真实边界；随后只修复被日志证明的层。如果现有 Row/控件职责无法正确表达输入所有权，则实施受控组件重构。

## Background

- 用户确认此前关于 Row HoverHandler、Tooltip activity/fallback、焦点容器、卡片层级、滚动阴影和 Row 根级监听的修改均没有改善。
- 已知症状包括：壁纸路径完全无法触发悬浮；Choice 仅小块区域可触发且焦点边框被覆盖；Slider/Toggle 仅细横向区域可触发；其他分类存在相似但不稳定的问题。
- 静态源码与启动检查无法证明实际 Wayland 输入命中。当前 `qmltestrunner` 不能提供可靠 verdict，直接 `qs -p tests/qml/...` 因测试模块导入失败而不可用。
- 项目已有 `settings` IPC target，可用于触发诊断；服务层不持有每屏 Panel 实例，因此 IPC 只发布诊断命令，由真实 Settings Overlay/Panel 响应。

## Requirements

- R1: 增加默认关闭的 Settings 运行时诊断通道，可由 `scripts/afloat-ipc settings ...` 开启、关闭和请求快照；打开调试面板时显式传入屏幕名。
- R2: 诊断必须在真实 Settings `PanelWindow`/Overlay 实例中输出：screen、window/overlay/panel/content/viewport/page 几何，页面 `contentY/contentHeight`，代表 Row 与 control 的 local/mapped rect，visible/enabled/opacity/z，Row/control hover/focus，Tooltip source/visible，以及 mask 所有者状态。
- R3: 诊断必须记录状态变化而不仅是静态快照；至少记录 Overlay 生命周期、分类切换、页面滚动、Row hover、control hover/focus、Tooltip owner 变化。日志使用稳定前缀并抑制无变化重复输出。
- R4: 诊断代码默认零行为影响：不得增加全屏或全 Row 输入捕获层，不得改变正常 mask、focus、Tooltip priority 或控件交互；关闭后不持续打印。
- R5: 使用真实面板重现 Appearance、Bar、Notifications 的 Row 边缘、控件内部、相邻移动、滚动、切换和重开。修复前保存至少一个能解释原始症状的日志序列。
- R6: 若日志显示输入在 Row 之前丢失，只修改对应 Window/Overlay/Content/Flickable 边界；若 Row 收到完整输入但控件/视觉状态分裂，才重构 Row surface/layout/interaction aggregation。
- R7: 重构时保持现有页面注入和公开控件协议；Slider 保留 priority 2 与 `nubItem`，Choice 保留菜单/header，TextField 保留 editor 焦点与编辑，Toggle 保留键盘与指针行为。
- R8: 最终移除临时高频探针；只保留低成本、默认关闭且可复用的诊断入口，或在证据已捕获后完全删除诊断实现。

## Acceptance Criteria

- [ ] `afloat-ipc` 能对真实设置面板启用/关闭 Debug 并请求结构化快照，日志包含稳定前缀和当前屏幕标识。
- [ ] 修复前捕获一段能明确指出 mask、叠层、坐标、Row/control ownership、focus 或 Tooltip 生命周期中哪一层失败的日志。
- [ ] 修复后三分类代表 Row 的完整视觉矩形和控件可见区域均正确响应；相邻移动、滚动、分类切换和重开不残留旧状态。
- [ ] Choice、TextField、Slider、Toggle 的 hover/focus/tap/drag/edit 无回归，Slider Tooltip 仍以 `nubItem` 为几何 source。
- [ ] 若重构，先迁移 Appearance 代表 Row 并验证，再扩展到 Bar/Notifications；若不重构，任务记录说明局部修复为何足够。
- [ ] `qmllint`、`python3 -m pytest -q`、`git diff --check`、`timeout 15s qs -p .` 无新增 WARN/ERROR；QML runner 限制明确报告。
- [ ] 完成 `trellis-check`、规范更新、Conventional Commit 和任务归档。

## Out Of Scope

- 未取得运行日志前继续修改 Tooltip priority/activity、焦点竞争或 Row HoverHandler 层级。
- 新增透明输入捕获层来“覆盖”症状。
- 修改设置持久化、主题 token、文案或无关页面布局。
- 把静默 runner 或静态代码推断当作运行时通过证据。

## Constraints

- 不回滚并发工作区修改。
- Debug IPC 必须保持 `settings toggle` 兼容。
- 诊断输出不得包含用户设置值、壁纸路径或其他隐私数据，只输出组件名、布尔状态和几何数值。
