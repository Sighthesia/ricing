# 设置面板命中链路诊断报告

## 结论

本次未能获得足够运行时证据把根因唯一归类为 Row、Flickable、焦点或 Wayland mask。四个诊断子代理均未返回报告或研究文件，因此不能将其状态视为完成。

当前最高优先级的未验证边界是 `TopBar.qml:110-117` 的 Settings `PanelWindow` 与 `Region` mask：窗口固定为屏幕高度、宽度最多 570，mask 直接以 `settingsOverlay` 作为 item。最近的 Row 重构没有改变这一边界，因此无法证明鼠标事件已经进入 QML scene，也无法证明问题发生在 Row 内部。

## 已确认事实

- `TopBar.qml:110-117` 创建固定本地 Settings `PanelWindow`，使用 `mask: Region { item: settingsOverlay.blocksDesktop ? settingsOverlay : null }`。
- `LazerSettingsOverlay.qml:29-31` 只在 phase 非 closed 时启用并可见；`LazerSettingsOverlay.qml:142-157` 将固定 `panelHost` 和 `LazerSettingsPanel` 挂入 overlay。
- `LazerSettingsPanel.qml:248-280` 将 Sidebar 放在 `z:1`，Content 放在 `z:0`；Content 在侧栏展开时从 x=170 开始、宽度约 400，Panel 总宽度约 570。
- `LazerSettingsContent.qml:318-326` 使用裁剪 viewport 承载当前分类 Flickable 页面；页面之外的内容依赖 viewport clip，而非独立输入区域。
- `LazerSettingsContent.qml:384-445` tooltip 明确 `enabled: false`、现在也明确 `activeFocusOnTab: false`；它不应成为普通输入 owner。
- `LazerSettingsContent.qml:332-343` 的 scroll shadow、`345-368` 的 empty state 已明确 `enabled: false`；dropdown catcher 仅在 dropdown 状态打开时启用。
- `LazerSettingsRow.qml:78-85` 的 Row hover observer 为 `blocking: false`，但用户反馈表明这项局部修复没有可感知改善。
- `LazerSettingsRow.qml:67-78` 当前由 Row 计算 presentation 高度，`238-297` 由 `contentHost/controlHost` 计算控件矩形；最近重构删除了外部控件 `y` Binding，但没有触及 PanelWindow/mask 边界。
- `qs -p tests/qml/tst_lazer_settings_controls.qml` 和 `qs -p tests/qml/tst_lazer_settings_panel.qml` 都在加载阶段失败：`qrc:/qs-blackhole: No such file or directory`，未进入断言。
- `qmllint`、Python 测试和 `timeout 15s qs -p .` 可运行；完整配置成功加载，只有已有通知服务重复注册 warning。

## 历史修复反证

- `61a34e1` 只移除了隐藏 scroll shadow 的可见输入风险。
- `c888f30` 将 Row hover 观察迁移到卡片/Row边界。
- `7de03f4` 将 Row hover 设置为非阻塞。
- `2f71311` 重构了 Row 几何和 Content 装饰层状态。
- 上述修改均没有改变 `TopBar.qml` 的 Settings `PanelWindow` mask，也没有提供可运行的实际鼠标坐标到 QML hover 状态的集成证据。因此这些提交无法证明事件已通过 compositor 输入区域。

## 当前根因候选

### 高优先级：PanelWindow mask / 输入区域未验证

支持证据：mask 直接引用一个覆盖整个 PanelWindow 高度的 QML Item；测试无法进入 QML；所有 Row 局部修复均无用户可感知效果。

反证：若 mask 完全错误，通常会表现为整个设置窗口都无法交互，而不是稳定的按控件顺序局部命中。因此需要运行时顶层命中或临时无 mask 对照实验才能确认。

### 中优先级：Flickable/viewport 与页面子树的实际命中边界

支持证据：当前页面是嵌套 Flickable，viewport 是裁剪 Item，Content 还拥有独立 overlay 层；症状按控件排列和高度变化。

反证：现有 Row/Content 单元测试设计了大量几何断言，但由于导入失败没有执行，无法证明实际 scene geometry。

### 低优先级：Row 内部布局公式

支持证据：Row 同时管理 card/content/control 三层，属于复杂几何边界。

反证：最近已删除外部控件 y Binding 并增加矩形断言，`qmllint` 无错误；单靠该问题很难解释局部修复完全没有效果。

## 必须进行的下一步验证

1. 在真实运行的设置窗口上打开现有 hover debug，记录 overlay/panel/content/page/row 的 `sceneRect`、visible/enabled/z 和 hover 状态。
2. 对同一坐标做 Settings `PanelWindow.mask` 开启/关闭对照，不能修改持久化逻辑；若无 mask 时所有控件恢复，根因属于 Region/mask owner。
3. 记录 Wayland/QML scene 的顶层命中对象或至少记录 `HoverHandler.point.scenePosition` 是否在控件上产生变化。
4. 只在确认事件已经进入 QML scene 后，继续分析 Flickable/Row；否则不要继续修改组件内部 handler 或 tooltip 仲裁。
5. 修复测试 runner 的 `qrc:/qs-blackhole` 导入环境，或建立不进入生产代码的独立 QML harness；在此之前不能把 QML 测试通过作为证据。

## 本次变更范围

- 仅新增本诊断任务的 PRD 和本报告。
- 未修改生产 QML、服务、设置 schema 或测试代码。
