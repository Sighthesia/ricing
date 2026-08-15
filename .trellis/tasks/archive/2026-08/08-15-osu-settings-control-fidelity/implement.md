# Settings Control Fidelity Implementation Plan

## 1. Lock Pure Contracts

- [ ] 在 `LazerSettingsLogic.js` 增加 default equality、dropdown placement 和 slider pointer/value 映射纯函数。
- [ ] 在 `MotionTokens.qml` / `LazerTheme.qml` 增加 Nub、slider、dropdown、tooltip 必要 token，保持 singleton 纯净。
- [ ] 先扩展 logic tests，覆盖浮点默认值、反向范围、菜单上下放置和窄屏 clamp。

验证：`qmltestrunner -input tests/qml/tst_lazer_settings_logic.qml`。

## 2. Build Nub And Restore Toggle

- [ ] 新增 `LazerSettingsNub.qml`，实现 checked morph、hover/glow、focus、disabled 和 reduced motion。
- [ ] 重构 `LazerSettingsToggle.qml` 使用 Nub，保留公开 API。
- [ ] 更新 control tests，断言 `50×15`、无移动 thumb、checked/unchecked 终态和键盘输入。

验证：`tst_lazer_settings_controls.qml`。

## 3. Restore Slider

- [ ] 重构 `LazerSettingsSlider.qml` 为 `5px` track + draggable Nub，移除常驻值标签。
- [ ] 实现 click、horizontal drag、keyboard、tooltip request 和 Nub double-click reset。
- [ ] 验证反向范围、step、disabled、reduced motion、拖动与 Flickable 竞争。

验证：controls tests + pages save tests。

## 4. Restore SettingsItem Flow And Defaults

- [ ] 重构 `LazerSettingsRow.qml` 为无卡片 vertical flow，增加 revert affordance、tooltip 请求、默认值契约。
- [ ] 为 Appearance、Bar、Notifications 每一行显式传入 default/current/reset callback。
- [ ] description 改由 tooltip 呈现，保留搜索匹配。
- [ ] 覆盖每种设置类型的单行恢复默认与 save count。

验证：`tst_lazer_settings_controls.qml`、`tst_lazer_settings_pages.qml`。

## 5. Implement Real Dropdown

- [ ] 重构 `LazerSettingsChoice.qml` 为 osu header，并通过信号请求 Content 菜单 owner。
- [ ] 新增 Settings dropdown menu component，支持 selected/preselected、键盘、Escape、outside close 和 focus restore。
- [ ] 在 `LazerSettingsContent.qml` 增加 overlay layer 和菜单生命周期，切页/搜索/关闭时清理。
- [ ] 更新 panel/overlay tests，验证菜单优先处理 Escape 且不破坏最终焦点恢复。

验证：controls、panel、overlay tests，overlay 顺序重复运行。

## 6. Restore TextField And Tooltips

- [ ] 将 TextField 和 Search 改为一致 outlined 视觉。
- [ ] 增加 focus-lost commit 去重，保留外部文本同步与编辑所有权。
- [ ] 新增 Content tooltip owner，显示 row description 与 slider value，hover/focus 切换无闪烁。
- [ ] 测试 tooltip 不抢 focus、description 仍可搜索、失焦只保存一次。

验证：controls、pages、panel tests。

## 7. Calibrate Action Buttons And Icons

- [ ] 新增 close、chevron、search、reset 等本地 SVG。
- [ ] 替换 Content 与 Sidebar 中的 Unicode 占位符，补齐 hover/press/focus/reduced-motion transition。
- [ ] 对照 osu 源码校准 spacing、font size、colour、disabled alpha 和 menu item states。

验证：smoke + component tests，并人工检查桌面/窄屏截图。

## 8. Regression And Real Runtime

- [ ] 顺序运行全部 Settings QML tests，Overlay 至少重复两轮。
- [ ] 运行其余可加载的 lazer QML tests、Python tests、`git diff --check`。
- [ ] 运行 `qs -p .`，确认 `Configuration Loaded` 且无新增 QML WARN/ERROR。
- [ ] 独立代码检查验证规格与真实交互，不只检查 token 值。

## Risky Files

- `LazerSettingsRow.qml`: 所有 Settings 页面共享，搜索、默认值和 tooltip 三个契约交汇。
- `LazerSettingsChoice.qml` / `LazerSettingsContent.qml`: dropdown owner、clip 和 focus/Escape 优先级。
- `LazerSettingsSlider.qml`: pointer drag 与 Flickable 竞争、实时保存频率。
- `LazerSettingsTextField.qml`: focus-lost commit 与外部更新同步。
- 三个 page 文件：只能 wiring 默认值/reset，不得改值范围或业务语义。

## Before Start Gate

- [x] 用户要求完整检查并校准 Settings 控件。
- [x] 用户选择加入 Slider 双击恢复默认和行级 revert affordance。
- [x] 用户选择 description 改为 hover/focus tooltip，仍参与搜索。
- [x] PRD、design、implementation plan 已完成。
- [ ] 用户审核最终规划摘要并在后续消息明确批准实现。
