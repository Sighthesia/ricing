# 设置悬浮运行时调试与重构设计

## Runtime Diagnostic Flow

`scripts/afloat-ipc settings debugHover true|false`、`snapshotHover` 和 `openHoverDebug <screenName>` 调用现有 `SettingsService` IPC。服务只维护 Debug 开关、目标屏幕和递增采样 token，不引用 UI。每个 `TopBar` screen scope 将状态传给自己的 `LazerSettingsOverlay`；只有目标屏幕实例响应打开请求。

稳定日志前缀为 `[afloat:SettingsHoverDebug]`，内容使用 JSON，字段只包含组件路径、screen 名称、rect、visible/enabled/opacity/z、hover/focus、scroll、Tooltip source 分类和 mask active。事件日志按签名去重。

## Observation Boundaries

1. `settingsWindow`: screen size、implicit size、mask active。
2. `settingsOverlay` 与 `panelHost`: phase/progress/blocksDesktop/requiredWidth。
3. `LazerSettingsPanel`: sidebar/content x/width、selected category、currentPage。
4. `LazerSettingsContent`: viewport rect、dropdown/Tooltip、currentPage scroll。
5. 代表 Row/control: Appearance 的 TextField、Choice、Slider、Toggle；Bar 与 Notifications 的首个代表控件。

Panel/Content 暴露只读诊断函数，不能新增输入 Handler。映射统一使用 `mapToItem(overlay, 0, 0)`，避免混用局部坐标。

## Diagnosis Decision Tree

- mask/overlay rect 不含可见 Row -> 修正窗口或 mask owner。
- viewport/page/Row mapped rect 与视觉位置不一致 -> 修正 page/Flickable geometry。
- Row hover 不变化但 control hover 变化 -> 重构 Row 状态聚合，不改 Window。
- Row hover 变化但 control hover/tap/drag 不变化 -> 检查 Row/装饰层是否拦截控件。
- 两者都变化但边框/Tooltip 不变 -> 修正视觉/Tooltip 状态 owner。
- 日志显示职责无法在一个 `LazerSettingsRow` 内保持清晰 -> 启用组件重构门槛。

## Refactor Shape

仅在门槛触发时拆分：

- `LazerSettingsRowLayout`: 标签、控件插槽、reset 预算与尺寸。
- `LazerSettingsRowSurface`: card 与 focus ring，仅绘制，不拥有输入。
- Row root: 非阻塞 hover 聚合与公开状态。
- 控件：继续独占自己的 tap/drag/edit 与 Tooltip value source。

保持 `LazerSettingsRow` 对页面的公开 API，内部替换实现，避免三分类页面同时大改。迁移顺序为 Appearance TextField -> Choice -> Slider/Toggle -> Bar/Notifications。

## Safety And Rollback

- IPC/诊断功能独立提交或清晰 diff，可单独删除。
- 先捕获修复前日志，再改产品结构。
- 每个控件批次都运行 lint、启动检查和手动真实面板验证；失败时只回退该批次。
- Debug 默认关闭，不记录设置值或文本。
