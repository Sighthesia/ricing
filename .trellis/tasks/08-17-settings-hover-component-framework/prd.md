# 设置悬浮根因与组件框架评估

## Goal

找出设置面板悬浮失效的真实根因，并评估是否需要重构设置 Row/控件组件框架。最终结果必须让指针所在 Row 的卡片高亮、控件自身 hover/focus 和 Tooltip 状态一致，不再依赖未经验证的透明捕获层或重复特判。

## Background

- 用户确认此前多轮 Row HoverHandler、Tooltip activity source、焦点容器、卡片层级和滚动阴影修复均没有可感知改善。
- 已确认 `qmltestrunner` 当前安装不可作为证据：故意通过和故意失败的 root `TestCase` 都以 exit 1 静默退出且没有有效 JUnit 输出；直接 `qs -p tests/qml/...` 也因 `Type Lazer unavailable` / `qrc:/qs-blackhole` 失败。
- 设置输入链路跨越 `PanelWindow.mask`、`LazerSettingsOverlay`、`LazerSettingsContent.viewport`、Flickable 页面、`LazerSettingsRow` 和 Choice/TextField/Slider/Toggle 控件。
- 当前实现把 Row 卡片、嵌入控件和 Tooltip 生命周期分散在多个兄弟/父子层级中，曾出现高层捕获器遮挡控件以及透明滚动阴影覆盖底部输入区域的问题。

## Requirements

- R1: 建立可审计的运行时诊断入口，记录屏幕坐标、本地/映射矩形、顶层命中对象、`visible`/`enabled`/`opacity`/`z`、hover/focus、Tooltip source 和 Settings mask 状态。
- R2: 诊断必须覆盖 Appearance、Bar、Notifications，包含 Row 边缘、控件内部、相邻 Row、滚动、分类切换和关闭重开；修复前必须产生明确失败或环境不可用信号。
- R3: 先验证现有组件框架的输入所有权：确认是否为 mask、viewport 叠层、坐标映射、Row/控件层级或 Tooltip bridge 生命周期问题；未被证据定位的层不得修改。
- R4: 若现有框架可以通过局部修复表达正确边界，采用最小修复；若无法稳定表达，则设计并实施组件重构，将视觉卡片、Row 命中状态、控件交互和 Tooltip 几何所有权拆成明确契约。
- R5: 保留 Slider priority 2 和 `nubItem` 锚点、Choice 下拉菜单协议、TextField 编辑器焦点、Toggle 键盘与 hover 行为。
- R6: 禁止全屏或全 Row 的透明高层输入拦截器，除非诊断证明其必要且同时验证所有嵌入控件仍能收到 hover/focus/tap/drag。
- R7: 自动 QML runner 不可用时，必须使用 qmlscene/qs harness、手工坐标脚本或其他可审计方式记录测试缺口，不得把静默退出算作通过。

## Acceptance Criteria

- [ ] 有明确的诊断命令或人工脚本能够稳定复现至少一个原始症状，并输出可审计结果。
- [ ] 根因归属于明确的输入、几何、层级或生命周期边界，而不是未经验证的猜测。
- [ ] 修复后三个分类的 Row 边缘和代表性控件完整可见区域均可触发正确高亮；相邻移动、滚动、切换和重开不残留旧状态。
- [ ] Choice、TextField、Slider、Toggle 的自身 hover/focus/编辑/拖动行为无回归，Slider Tooltip 仍锚定 `nubItem`。
- [ ] 若实施重构，组件职责、输入所有权和迁移边界有设计文档与回归覆盖；若不重构，记录为何局部修复足够。
- [ ] `qmllint`、`python3 -m pytest -q`、`git diff --check` 和 `qs -p .` 完成，新增 QML WARN/ERROR 为零；QML runner 限制单独记录。
- [ ] 完成独立审查、规范更新、Conventional Commit 和任务归档。

## Out Of Scope

- 在根因定位前继续调整 Tooltip priority/activity/focus 特判。
- 修改 Tooltip 文案、设置持久化语义、主题 token 或无关页面布局。
- 以临时 probe 替代正式测试，或提交无法复现/无法解释的输入拦截层。

## Constraints

- 不回滚其他并发工作区修改；只处理本任务明确涉及的设置输入链路。
- 任何组件框架重构必须保留现有公开属性、信号和页面注入方式，或在设计中列出迁移与兼容策略。
- 规划阶段不修改产品代码；实现必须在本计划获批准并执行 `task.py start` 后进行。
