# Fix settings toggle and choice alignment

## Goal

修复设置面板中 Toggle 的实际垂直定位，以及 Choice 下拉控件可见表面、焦点背景和弹出菜单之间的水平几何不一致。用户应看到 Toggle 在设置卡片中稳定居中，Choice 的真实控件表面与其他 Row 内容左边界一致，打开菜单后弹出层也从同一权威表面位置开始。

## Confirmed Background

- `LazerSettingsToggle.qml` 本身是 `44x20` 的单层 capsule；当前症状更可能来自 `LazerSettingsRow` 的 inline host 高度和实际页面坐标，而不是 Toggle 内部绘制。
- `LazerSettingsChoice.qml` 暴露 `headerItem`，`LazerSettingsContent.qml` 的 `showDropdownFor()` 使用该 item 映射位置和宽度创建菜单；可见 Choice 表面与菜单必须继续使用同一个 header 几何源。
- Choice 是 label-owning presentation，Row 隐藏外部 label；固定设置面板宽度、per-screen ownership、键盘/焦点、菜单交互和 tooltip 合同均需保留。

## Requirements

- R1: Inline Toggle 的实际 capsule 中心与所属 Row 内容区域中心一致，保持 `44x20`、右侧 reset slot、disabled/focus/keyboard/accessibility 和现有 transitions。
- R2: Choice 的真实可见 `headerSurface`、Choice root 和 Row 的 content host 使用同一左侧内容基准；不得通过第二层 hover/focus 表面制造视觉偏移。
- R3: Choice popup 继续以 `headerItem` 为唯一定位和宽度来源，popup 左边界和宽度与实际 Choice surface 在 Content 坐标系中一致。
- R4: 保留 Choice 的 embedded label/value、下拉打开/关闭、键盘选择、焦点和多屏 Content owner 行为，不改变 settings model、默认值、持久化或 tooltip ownership。
- R5: 增加坐标级回归测试，覆盖 Row -> content host -> control root -> capsule/header surface 的实际映射，而非只比较局部 `x/y` 属性。

## Acceptance Criteria

- [ ] Toggle capsule 的映射中心与 inline Row content 区中心误差小于 `0.1px`，尺寸仍为 `44x20`。
- [ ] Toggle 右侧边界仍处于 Row 的 reset slot 左侧，不会覆盖恢复按钮或吞掉其输入。
- [ ] Choice root、`headerItem`/`headerSurface` 和 Row content host 在 Content/Row 坐标系中的左边界一致，宽度一致且没有额外偏移层。
- [ ] Choice popup 的 mapped `x` 和 `width` 与同一 `headerItem` 的 mapped geometry 一致；打开、关闭和选择行为保持工作。
- [ ] 相关 controls/pages/panel QML 测试、`qmllint`、`python3 -m pytest -q`、`git diff --check` 和 `timeout 15s qs -p .` 完成；只允许已知环境 D-Bus notification ownership warning。

## Out Of Scope

- 不改 Toggle/Choice 的业务模型、持久化、默认值、保存时机或 settings data flow。
- 不改固定 `570px` surface、Sidebar `70/170px`、Content `400px`、多屏 owner、tooltip owner 或全局 `osuPink`。
- 不引入独立 `OsuToggle.qml`、`OsuDropdown.qml` 或第二套 popup 定位系统。
- 不重做无关控件的颜色、尺寸或交互。

## Technical Notes

- Inline geometry must be corrected at the Row/content-host boundary so the Toggle component remains reusable and its `44x20` contract stays explicit.
- Choice surface and popup should share one authoritative mapped source, preferably the existing `headerItem`, and tests should compare `mapToItem()` results rather than unrelated local coordinates.
- Any visible geometry or surface state change must retain the project's QML transition conventions.
- QML test runner availability is an environment risk; if it remains silent, report it explicitly rather than treating exit status as passing.
