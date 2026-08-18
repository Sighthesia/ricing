# 诊断设置面板命中链路根因

## Goal

在不继续修改产品代码的前提下，找出设置面板鼠标悬浮/聚焦区域失效的真实根因，并给出带文件、行号、运行时或测试证据的修复边界。

## Scope

- 覆盖 `PanelWindow.mask`、`LazerSettingsOverlay`、`LazerSettingsPanel`、`LazerSettingsContent.viewport`、分类 `Flickable`、`LazerSettingsRow`、TextField/Choice/Slider/Toggle 及 tooltip/dropdown overlay。
- 复核最近两次局部修复和 Row 布局重构是否真正改变了命中链路。
- 检查测试 runner 的 `qrc:/qs-blackhole` 阻断是否掩盖了可验证的 QML 行为。
- 只产生诊断报告、任务研究材料和修复建议；本阶段不修改生产 QML、服务或测试代码。

## Required Evidence

- 明确区分 compositor mask、QML scene hit-test、控件几何、焦点 ownership、Flickable clipping 和 tooltip/dropdown 生命周期问题。
- 每个结论至少提供一个代码位置或可重复命令；没有运行时证据的结论必须标记为假设。
- 检查外观、顶部栏、通知三个分类，并解释为何症状按分类/控件顺序不同。
- 记录当前可运行验证、失败输出和环境限制。

## Acceptance Criteria

- [ ] 形成一份汇总诊断报告，列出按置信度排序的根因、证据、反证和未决风险。
- [ ] 明确指出下一步应修改的最小 owner 边界，或证明需要新的运行时 harness。
- [ ] 不提交未经证据支持的透明捕获层、focus 特判或 tooltip priority 调整方案。
- [ ] 本阶段没有产品代码变更。
