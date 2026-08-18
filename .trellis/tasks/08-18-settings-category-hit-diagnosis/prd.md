# 诊断设置分类前段命中差异

## Goal

解释并修复设置面板中外观分类前五个 Row、顶部栏分类前四个 Row 无法触发预期 hover/focus，而通知分类 Row 正常的差异，建立可重复的分类级命中测试后再修改交互代码。

## Confirmed Facts

- 当前运行配置来自工作区 `/home/Sighthesia/0_Files/Producing/Software/Quickshell/afloat` 的 `lazer` 分支。
- tooltip 已从设置面板生产路径和渲染路径移除，不是当前症状的解释。
- `LazerSettingsRow` 的 Row hover handler 为 `blocking: false`，Row 没有点击转发。
- `LazerSettingsPanel` 同时挂载 Appearance、Bar、Notifications 三个持久页面，并通过 `enabled` 与 `opacity` 切换当前页。
- 每个页面是 `Flickable`，`contentHeight` 由 `pageColumn.implicitHeight` 决定，viewport 位于 content 的 search/header 之后。
- 运行时通知页快照显示四个 Row 均为正常尺寸和正常 control scene rect；当前快照尚未覆盖外观/顶部栏在同一 open 状态下的逐项点击结果。
- 设置 QML 测试当前在加载组件前被 `qrc:/qs-blackhole: No such file or directory` 阻断，因此不能把测试通过当作行为证据。

## Requirements

- 建立一个直接针对用户症状的分类对比反馈环，至少记录每个目标 Row 的：
  - local rect 与 scene rect
  - visible、enabled、opacity、z、clip ancestor
  - control rect、visible、enabled、activeFocus
  - Row hover、control activeFocus、focus ring 所依赖的状态
- 对比以下集合：
  - Appearance：wallpaper、color scheme、panel opacity、enable blur、blur surface opacity
  - Bar：height、position、floating、floating margin
  - Notifications：四个现有 Row
- 对每个分类分别验证：分类切换后页面 enabled/opacity、`contentY`、viewport rect、page contentHeight，以及第一项和最后一项的 pointer/focus 归属。
- 优先区分几何/裁剪问题、inactive page 仍覆盖问题、Flickable 命中问题和控件 focus ownership 问题；未取得差异证据前不修改视觉或输入层。
- 若发现共同根因，增加最小回归测试；若测试环境仍阻断，保留可执行的运行时诊断命令和日志证据。
- 不恢复 tooltip，不扩大 Row 空白点击语义，不修改 SettingsService 或持久化。

## Acceptance Criteria

- [ ] 有一条已运行的分类对比命令能够明确输出至少一个失败 Row 与一个正常 Row 的可比状态。
- [ ] 根因被归类到几何/裁剪、层级/覆盖、Flickable、focus ownership 或其它明确类别之一，并有证据支持。
- [ ] 修复后外观前五项、顶栏前四项和通知全部 Row 的 Row hover/focus 行为一致。
- [ ] Row 空白仍只触发 Row hover，不触发控件动作；控件自身区域仍可聚焦/操作。
- [ ] 相关 QML 静态检查、生产配置加载和可运行测试通过；环境阻塞被单独记录。

## Out Of Scope

- 不重新设计设置面板视觉风格。
- 不重新引入浮动 tooltip。
- 不改变设置数据、保存/reset、分类导航和 PanelWindow mask。

## Diagnosis Hypotheses

1. 页面前段的实际 scene 命中区域与绘制区域错位或被 viewport/header 覆盖；预测是失败 Row 的 scene rect/ancestor clip 与通知 Row 不一致。
2. Appearance/Bar 的 inactive 持久页面或内容层仍在前段覆盖；预测是切换后存在另一个 page 的 enabled/visible/z/opacity 组合异常。
3. `Flickable` 对可滚动页面前段拥有不同 pointer ownership；预测是禁用/替换 Flickable interaction 后失败 Row 恢复，而通知短页面不受影响。
4. 前段控件的 focus owner 与 Row/cardHighlight 层级竞争；预测是 Row hover 正常但 control activeFocus 不变，且只需调整控件点击 focus ownership。
