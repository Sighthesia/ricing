# 修复设置面板交互与视觉细节

## Goal

让设置面板的开关、滑条、分类侧栏和下拉框在打开、关闭及交互过程中保持稳定、清晰且符合用户预期，不改变现有设置值、重置和键盘操作契约。

## Background

- 设置面板由 `LazerSettingsOverlay.qml`、`LazerSettingsPanel.qml`、`LazerSettingsSidebar.qml` 和 `LazerSettingsContent.qml` 组成；侧栏与内容层独立平移并共享 `progress`。
- 关闭流程在 `LazerSettingsOverlay.qml:44-51` 先调用 `panel.endSession()`，而 `LazerSettingsSidebar.qml:43-50` 会把导航条目透明度清零；当前关闭动画期间分类侧栏因此直接消失。
- `LazerSettingsChoice.qml:65-77` 的 `openMenu()` 在 `menuOpen` 时直接返回，`LazerSettingsChoice.qml:161-165` 的 TapHandler 始终调用 `openMenu()`，所以再次点击无法收起。
- `LazerSettingsContent.qml:354-379` 将下拉菜单放在内容层最上方并由独立 overlay 承载，当前菜单不会参与页面布局，因此会覆盖下方设置项。
- `LazerSettingsSlider.qml:185-199` 的默认值提示线宽度为 `3px`，`LazerSettingsSlider.qml:217-226` 的滑条头宽度为 `6px`。
- `LazerSettingsRow.qml:65` 与 `LazerSettingsToggle.qml:30` 使用透明度表达禁用状态；本次要求只移除开关交互过程中的透明度过渡，不改变禁用态可见性。

## Requirements

1. Toggle 的状态变化和交互不使用透明度动画；开关仍保留必要的颜色、位置或其他既有过渡，禁用态透明度仍正确表达。
2. 设置面板关闭时，分类侧栏在关闭动画完成前保持可见，不能在关闭开始时瞬间消失；打开和重新打开时导航状态仍能正常初始化。
3. 增大滑条手柄和默认值提示线的视觉宽度，同时保持轨道范围、值映射、拖拽和默认值定位正确。
4. 下拉框展开后，下方设置项应在布局中向下移动并保留可见空间，不由浮层覆盖；收起后恢复原有位置。
5. 再次点击当前已展开的下拉框标题可收起菜单；选择选项、点击外部区域、Escape、Tab 和键盘确认行为继续有效。
6. 保持现有设置面板尺寸、搜索、分类切换、重置按钮、无障碍角色及键盘焦点契约，除上述视觉和布局行为外不扩展范围。

## Acceptance Criteria

- [ ] Toggle 开关在点击、状态切换和禁用/启用过程中没有透明度动画闪烁；禁用态仍使用既有透明度值。
- [ ] 关闭设置面板时，分类侧栏条目与返回按钮持续显示到面板退出动画结束；面板完全关闭后不可见，重新打开后可正常显示。
- [ ] 滑条手柄和默认值提示线明显比当前 `6px`/`3px` 更宽，且点击、拖拽、键盘调节及默认值定位无回归。
- [ ] 下拉框展开会增加对应设置项所占高度并推挤后续设置项；菜单项不会覆盖后续设置内容。
- [ ] 再次点击展开中的下拉框标题可以收起；选项选择、外部点击、Escape、Tab 和键盘操作均可关闭或提交。
- [ ] 相关 QML 通过 `qmllint`，Python 测试通过，`git diff --check` 无错误，`qs -p .` 能加载配置且无新的 WARN/ERROR。

## Out Of Scope

- 不重做设置面板整体视觉主题，不调整面板固定尺寸或分类信息架构。
- 不改变设置默认值、持久化格式、设置服务 API 或非设置面板控件的动画。
- 不引入新的第三方组件或依赖。

## Decisions

- 下拉菜单的推挤效果优先通过设置页内容布局占位实现；菜单仍可由内容层统一管理，但不再以覆盖后续行作为最终呈现。
- 关闭动画期间保留侧栏可见性，生命周期清理延迟到关闭完成或仅清理动画状态，不改变最终 closed 状态。

## Risks And Deferred Items

- 下拉菜单的实际高度需要结合当前 `Flickable`/页面布局实现确认，可能需要调整分类页的内容高度与滚动边界；不改变菜单选项模型。
- 当前环境的 QML 测试运行器可能静默退出，除 `qmllint`、Python 测试与配置启动外，需记录可执行的测试结果而不虚报 QML assertion 通过。
