# 设置悬浮问题根因诊断

## Goal

找出设置面板悬浮反馈完全没有改善的真实根因，并用可重复的运行时证据验证修复。目标是让鼠标所在 Row 的命中、卡片高亮、控件焦点和 Tooltip 所有者保持一致，而不是继续叠加未经验证的 HoverHandler 或 Tooltip 特判。

## Confirmed Context

- 用户确认此前多轮 Row HoverHandler、Tooltip activity source、焦点容器和卡片层级修改均未产生可见改善。
- 已知用户症状包括：壁纸路径无法触发悬浮；配色方案只有局部区域命中且焦点框被控件遮挡；多个 Slider/Toggle 行只有细小横向区域命中；其他分类也存在不稳定命中。
- 当前代码同时存在 Row 卡片、嵌入控件、Flickable 页面、Content overlay、PanelWindow mask 和全局 Tooltip bridge 多个输入/状态边界。
- 当前 `qmltestrunner` 对仓库测试静默退出，直接 `qs -p tests/qml/...` 又因 `qrc:/qs-blackhole` 导入失败，不能作为自动化回归证据。
- 当前工作区已清理此前临时 probe；本任务不继承任何未经验证的生产修改。

## Requirements

- R1: 建立真实运行时诊断入口，记录屏幕坐标、Row/card/control 的 mapped geometry、顶层命中对象、HoverHandler 状态、activeFocus、Content tooltip source 和 PanelWindow mask 状态。
- R2: 在 Appearance、Bar、Notifications 中覆盖 Row 顶部/中部/底部/边缘、控件内部、相邻 Row 切换、页面滚动、分类切换和关闭重开。
- R3: 诊断必须先在当前版本产生明确的红色失败或可审计的命中日志，再决定修改边界；不得把静默测试退出当作通过。
- R4: 仅修复被证据定位的层：事件命中、几何映射、层级遮挡、焦点所有权或 Tooltip 生命周期；保留 Slider 高优先级和 nub 锚点、Choice 菜单协议、TextField 编辑行为。
- R5: 将最小复现固化到可运行的集成测试、独立 harness 或明确的人工脚本；若环境阻止自动测试，提交中必须记录缺口和复现步骤。

## Acceptance Criteria

- [ ] 一个明确命令或人工脚本能稳定显示当前版本的失败位置，并在修复后显示相同坐标通过。
- [ ] 三个分类连续移动、滚动、切换和重开后，当前 Row 的高亮与 Tooltip 不停留在旧 Row 或旧坐标。
- [ ] 壁纸、Choice、Opacity、Blur、Toggle、Slider 等代表性控件的完整可见区域都有一致命中结果。
- [ ] Choice/TextField/Slider/Toggle 的编辑、菜单、拖动、键盘焦点和 Tooltip 锚点没有回归。
- [ ] 通过独立审查、`qmllint`、Python 测试、`git diff --check` 和 `qs -p .`；如 QML runner 仍不可用则明确报告。
- [ ] 更新相关前端规范，使用 Conventional Commit，并归档 Trellis 任务。

## Out Of Scope

- 未定位前不再修改 Tooltip 优先级、activity source 或添加新的焦点特判。
- 不改变设置文案、持久化字段、主题 token 或整体面板布局，除非诊断证明它们直接导致命中错误。
- 不把临时日志或无法发现的 probe 作为正式测试文件提交。

## Open Questions

- 无需用户决策；剩余未知项全部由运行时诊断解决。
