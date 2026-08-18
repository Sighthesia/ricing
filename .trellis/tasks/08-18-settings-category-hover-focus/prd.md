# 设置分类悬浮与聚焦命中修复

## Goal

解释并修复设置面板中外观分类前五项、顶部栏分类前四项的设置控件悬浮/聚焦命中区域异常，使它们与通知分类的控件行为一致，并建立可复现的分类对比回归。

## Confirmed Facts

- 当前问题集中在设置控件自身的悬浮/点击聚焦命中，不是单纯的 Row 背景绘制问题。
- 外观分类的复现矩阵：`面板不透明度` 和 `启用模糊` 只有约控件高度的 `2/3` 横向细区域可触发；`模糊表面不透明度` 只有约 `1/2` 区域可触发；`壁纸路径`、`配色方案` 始终无法触发。
- 顶部栏分类的复现矩阵：`顶部栏高度`、`栏位置` 只有控件下边缘细横向区域可触发；`浮动边距`、`浮动模式` 无法触发。
- 通知分类的现有控件均可正常触发。
- 外观和顶部栏页面的 Row 均位于 `Flickable` 的 `Column` 中，并通过 `LazerSettingsRow.controlHost` 承载控件；通知页面使用相同的 Row/控件组件族。
- `LazerSettingsPanel` 同时挂载三个持久页面，通过 `enabled` 和 `opacity` 切换页面；当前页位于 `LazerSettingsContent.viewport` 的裁剪区域内。
- `LazerSettingsRow` 的 Row `HoverHandler` 设置为 `blocking: false`，Row 不把空白区域的点击转发为控件动作。
- 控件自身的宽高由控件内部的 `requestedWidth`/`availableWidth` 绑定和 Row 对 `controlHost` 的几何计算共同决定；这使控件实际命中高度与卡片高度可能不同，必须区分“整张 Row hover”与“控件 surface focus”。
- 工作区已有多次相关诊断提交和一个未跟踪的最小焦点测试文件；不能重复引入 tooltip、mask 或 Row 空白点击语义。

## Requirements

- 建立直接覆盖上述失败矩阵和通知正常矩阵的分类对比诊断，记录每个目标 Row/control 的 local rect、scene rect、visible、enabled、opacity、z、clip ancestor、hover、activeFocus 和 focus ring 依赖状态。
- 明确验证控件的视觉 surface、控件 Item 实际边界、Row 卡片边界三者是否一致；不得把 Row hover 正常误判为控件 focus 正常。
- 验证分类切换后的所有页面 `enabled`、`visible`、`opacity`、`z`、`contentY`、`contentHeight`，以及 `viewport` 的 scene rect 和 clip 状态。
- 优先区分控件自身几何错误、页面/祖先裁剪、inactive page 覆盖、Flickable pointer ownership、以及控件 focus ownership；取得差异证据后才修改生产组件。
- 修复范围限于命中/聚焦行为与必要的回归测试；不修改设置持久化、保存/reset、分类导航、PanelWindow mask 或 tooltip。
- 若测试运行环境仍受 `qrc:/qs-blackhole` 阻断，保留可执行的运行时诊断和静态验证证据，并单独记录环境限制。

## Acceptance Criteria

- [ ] 有一条已运行的分类对比命令能够同时输出至少一个失败控件和一个通知正常控件的可比几何/层级/focus 状态。
- [ ] 根因被明确归类并由 scene rect、祖先 clip、页面状态或 pointer/focus ownership 证据支持。
- [ ] 外观前五项、顶部栏前四项和通知全部 Row 的可见卡片背景均能在完整 Row 矩形内触发背景 hover/focus；不能只在底部细带响应。
- [ ] Row 背景区域只触发背景 hover/focus，不扩大控件动作区域；控件区域仍可操作。
- [ ] 相关 QML 静态检查、生产配置加载和可运行测试通过；无法运行的测试有明确记录。

## Out Of Scope

- 不重新设计设置面板视觉风格或控件尺寸，除非现有尺寸与交互命中契约不一致且是根因。
- 不重新引入浮动 tooltip。
- 不改变设置数据、保存/reset、分类导航和 PanelWindow mask。

## Key Product Decision

- 已确认整张设置卡片的背景区域应能够触发背景聚焦框；鼠标只需移动到卡片背景而非控件视觉 surface 上，就应显示该 Row 的 focus/highlight 状态。
- 该决定只扩大背景 hover/focus 的可感知区域，不扩大控件动作区域。文本框编辑、选择框开菜单、滑块调值、开关切换和恢复默认仍由各自的现有控件/按钮区域负责。
