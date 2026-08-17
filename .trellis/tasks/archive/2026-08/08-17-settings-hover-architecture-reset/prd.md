# 设置悬浮根因与组件框架评估

## Goal

解决设置面板悬浮状态长期不生效的问题，并在证据支持时重构 Row/控件的输入与视觉所有权。用户需要看到当前指针所在 Row 的完整卡片高亮，控件自身的 hover/focus/tap/drag 仍然可用，Tooltip 的内容和几何位置与当前交互对象一致。

## Background

- 用户已确认此前多轮 Row HoverHandler、Tooltip activity、焦点容器、卡片层级和滚动阴影修复都没有可感知改善。
- 已记录症状包括：壁纸路径无法触发悬浮；下拉框仅局部命中且焦点框被遮挡；滑条和开关只有细横向区域命中；其他分类也存在不稳定的局部命中。
- 输入链路跨越 `TopBar` 的 Settings `PanelWindow.mask`、`LazerSettingsOverlay`、`LazerSettingsContent.viewport`、分类 Flickable、`LazerSettingsRow` 及 Choice/TextField/Slider/Toggle 控件。
- 既往尝试曾引入高层透明捕获器和 Tooltip 状态特判，后续检查发现它们可能遮挡控件自身事件或只修复了单一层，因此本任务禁止继续无证据叠加同类补丁。
- 当前 QML runner 的已知限制必须保留在验收记录中：`qmltestrunner` 无法提供可靠的 pass/fail 输出，直接用 `qs -p tests/qml/...` 也会因测试模块导入失败而退出。

## Requirements

- R1: 建立可审计的运行时诊断入口，记录 screen/local/mapped geometry、可见和启用状态、opacity/z、实际输入所有者、Row/control hover/focus、Tooltip source 和 Settings mask 状态。
- R2: 诊断覆盖 Appearance、Bar、Notifications；至少包含 Row 边缘、控件内部、相邻 Row、滚动、分类切换和关闭重开，并在修复前产生明确失败信号或明确的环境不可用记录。
- R3: 按 `PanelWindow.mask -> Overlay -> Content viewport/叠层 -> Flickable -> Row surface -> control` 顺序验证输入所有权、坐标映射和生命周期；未被证据定位的层不得修改。
- R4: 若现有结构能够表达完整 Row 命中、控件独立交互和 Tooltip 几何，实施最小修复；若不能，设计并迁移到职责明确的组件结构，而不是新增全屏或全 Row 透明拦截层。
- R5: 保留公开页面注入方式和现有控件协议；Slider 保留 priority 2 与 `nubItem` 锚点，Choice 保留下拉菜单/header，TextField 保留 editor 焦点与编辑，Toggle 保留键盘和 hover 行为。
- R6: 任何结构重构必须先定义视觉卡片、Row 命中聚合、控件交互 owner、Tooltip 几何 owner 的契约，并先迁移一个代表性 Row，再扩展到三个分类。
- R7: 临时诊断 harness 不进入生产代码；自动 runner 不可用时使用可输出的 qmlscene/qs harness、人工坐标脚本或启动日志，并在任务记录中明确缺口。

## Acceptance Criteria

- [ ] 存在一个已运行的诊断命令或人工脚本，能够稳定复现至少一个原始症状并输出可审计的几何/命中/状态信息。
- [ ] 根因被归属于明确的 mask、叠层、坐标、组件命中、焦点或 Tooltip 生命周期边界，而非猜测性解释。
- [ ] 修复后三个分类中，Row 完整视觉矩形和代表性控件完整可见区域均能产生正确高亮；相邻移动、滚动、切换和关闭重开不残留旧状态。
- [ ] Choice、TextField、Slider、Toggle 的 hover/focus/edit/drag 行为无回归，Slider Tooltip 仍定位到 `nubItem`。
- [ ] 若实施重构，职责、公开属性/信号、层级与迁移边界写入设计文档，并有代表性 Row 和三分类回归覆盖；若不重构，记录局部修复足够的证据。
- [ ] `qmllint`、`python3 -m pytest -q`、`git diff --check`、`timeout 15s qs -p .` 完成且无新增 QML WARN/ERROR；QML runner 限制单独报告。
- [ ] 完成 `trellis-check`、必要的规范更新、Conventional Commit 和任务归档。

## Out Of Scope

- 根因定位前继续调整 Tooltip priority/activity、焦点竞争或添加透明捕获层。
- 修改 Tooltip 文案、设置持久化、主题 token、无关页面布局或 compositor mask 的既有契约。
- 把静默或无法发现的 QML 测试结果当作通过。

## Constraints

- 不回滚并发工作区修改；只处理设置输入链路和本任务产生的诊断/测试文件。
- 重构必须尽量保持现有公开属性、信号和页面注入方式；无法保持时必须在设计中列出迁移方案与回滚点。
- 规划阶段不修改产品代码；须在本计划获得用户批准并执行 `task.py start` 后实现。
