# 重构设置面板交互组件

## Goal

重建设置面板的组件边界，使可见卡片、控件自身交互、滚动裁剪和 tooltip/dropdown 覆盖层各自只有一个明确 owner，彻底消除当前外观与顶部栏分类中局部、失效或不稳定的鼠标悬浮/聚焦区域。

用户应能在三个分类中稳定地：

- 悬浮任意可见设置卡片并看到当前卡片反馈；
- 在 TextField、Choice、Slider、Toggle 的完整可见控件区域内编辑或操作；
- 滚动、切换分类、关闭并重新打开后，不残留旧卡片、焦点或 tooltip 状态。

## Background

- 用户确认前一轮 `LazerSettingsRow` 的局部 `HoverHandler` 修复没有任何可感知效果，因此本任务不再以修改单个 handler 作为主要方案。
- 当前链路跨越 `PanelWindow.mask`、`LazerSettingsOverlay`、`LazerSettingsPanel`、`LazerSettingsContent.viewport`、分类 `Flickable`、`LazerSettingsRow`、四类控件以及 `SettingsOverlayBridge`。
- 当前 Row 同时计算卡片高度、嵌入控件位置、控件宽度、恢复按钮、hover 聚合和 tooltip 请求；控件自身又包含独立的 Hover/Tap/Drag/Focus 处理器，造成多个重叠输入边界。
- 当前 Content 将持久化页面放进裁剪 viewport，同时在同一 Content 中放置 tooltip、dropdown 和外部点击 catcher；这些覆盖层必须与普通卡片命中严格隔离。
- 既有历史任务已确认 QML 测试 runner 存在环境限制：`qs -p tests/qml/...` 会在导入阶段报 `qrc:/qs-blackhole`，不能把静默或加载失败当作通过证据。

## Requirements

### R1. 建立单一卡片交互宿主

- 每个设置项由一个明确的卡片宿主拥有完整可见卡片矩形、卡片 hover/focus/highlight 状态和描述 tooltip 的活跃状态。
- 卡片背景、焦点边框、恢复默认按钮和控件布局不得通过多个重叠透明输入层竞争命中。
- 卡片宿主的命中矩形必须等于其实际绘制矩形，并随搜索过滤、页面滚动和尺寸变化同步。

### R2. 隔离控件交互所有权

- TextField 只拥有文本编辑器焦点、输入和提交；Choice 只拥有 header focus、菜单打开和选择；Slider 只拥有轨道点击、拖动、键盘和 thumb tooltip 锚点；Toggle 只拥有开关点击和键盘操作。
- 控件不再通过改变父卡片几何或创建额外覆盖面来扩大自身命中区域。
- 卡片宿主可以观察控件状态，但观察不得阻塞或抢占控件输入。
- 禁用设置项的卡片仍可显示禁用态，但控件和恢复按钮不得响应鼠标或键盘。

### R3. 统一布局模型

- Row 使用一个明确的卡片内容区域和稳定的 presentation contract，控件的可见矩形、命中矩形和焦点矩形使用同一坐标域。
- standard、inline、split、choice 四种布局的高度、水平内边距、恢复按钮预留区和控件位置必须由同一布局计算路径产生。
- 不能用父 Row 高度绑定、子控件 `y` 二次 Binding 和动态 `Flickable` 裁剪共同反推同一几何属性。
- 保持现有 570/170/400 设置面板结构与页面滚动能力，除非测试证明某个边界必须迁移。

### R4. 明确覆盖层和生命周期

- 普通状态下 tooltip、dropdown、外部点击 catcher 和 empty state 不得参与卡片命中。
- dropdown 打开时只有菜单及其必要的 outside-click owner 参与输入；关闭时整个覆盖层从命中树移除。
- tooltip 只负责视觉呈现，不能获取焦点或拦截普通卡片输入。
- 分类切换、搜索变更、页面滚动、关闭和重开必须清理属于当前 Content owner 的临时状态。

### R5. 保持外部兼容契约

- 保留页面注入的 settings object、defaults、save/reset callback 和 wallpaper service，不改变持久化字段或服务调用。
- 保留控件已有公开属性、信号和关键语义：Slider `priority 2` 与 `nubItem`，Choice 的 bridge dropdown，TextField editor focus/commit，Toggle keyboard/toggle。
- 保留搜索、分类导航、侧栏折叠、Escape、恢复默认和滚动位置行为。

## Technical Constraints

- 不新增全屏或全 Row 透明捕获器作为通用修复。
- 不以调整 tooltip priority/activity 或增加焦点特判替代输入所有权重构。
- 不修改后端 service singleton、设置 schema、主题 token 或无关 overlay。
- 临时诊断 harness 不进入生产代码；测试失败时必须区分代码失败与环境导入失败。

## Acceptance Criteria

- [ ] 外观、顶部栏、通知三个分类的每个可见 Row 卡片，在顶部、中部、底部和左右边缘都能稳定触发卡片反馈。
- [ ] 壁纸输入框、配色下拉框、面板不透明度、启用模糊和模糊表面不透明度的完整可见控件区域都能稳定 hover/focus/tap；顶部栏前四项同样通过。
- [ ] TextField 编辑、Choice 打开/选择/关闭、Slider 点击/拖动/键盘、Toggle 点击/键盘均保持有效；禁用项不响应。
- [ ] 滚动到 viewport 边界、切换分类、输入搜索、关闭并重开后，卡片高亮、焦点、tooltip 和 dropdown 不残留旧来源。
- [ ] tooltip 仅视觉呈现，Slider tooltip 仍锚定 `nubItem`，dropdown 仅在打开时拥有 outside-click 输入。
- [ ] 测试覆盖布局矩形与卡片/控件命中矩形一致、三分类代表性控件和生命周期转换；不接受只验证颜色或父 Row 状态的 tautological 测试。
- [ ] `qmllint`、`git diff --check` 和可用的 QML/配置验证完成；`qrc:/qs-blackhole` 等环境限制单独记录，不伪装为通过。
- [ ] 完成规范更新、独立质量检查、Conventional Commit，并保持工作树清洁。

## Out Of Scope

- 不重做设置面板整体视觉风格、文案、颜色 token 或动画设计。
- 不改变设置持久化接口、默认值语义、服务调用和后端行为。
- 不把临时诊断输出、人工 probe 或无法复现的输入 workaround 作为生产组件。
