# 完成 Lazer 设置面板

## Goal

为 Afloat 的 Lazer 顶部栏提供一个可用、可持久、按屏幕独立工作的设置中心，并让设置按钮与音乐覆盖层共享一致的弹出交互。用户修改设置后应立即看到对应的顶部栏、通知和外观变化，不需要重启 Quickshell。

## Background

- 当前分支已经实现设置中心的纯逻辑、可复用控件、Appearance/Bar/Notifications 页面、导航面板和模态生命周期。
- 现有实现使用 `SettingsService` 作为持久设置入口，QML singleton 通过 `services/qmldir` 注册。
- `LazerBarLogic.nextOverlay()` 已定义 `settings`、`music` 和关闭状态的互斥切换规则。
- 相关 QML 测试使用 QtTest，并且设置覆盖层测试已验证固定宿主尺寸、生命周期、Escape、Tab trap、scrim 与 reduced-motion 行为。

## Requirements

### R1. Overlay Integration

- 设置按钮与音乐按钮必须通过统一的 overlay 状态切换；再次点击当前按钮关闭，点击另一按钮切换。
- 每个 `Quickshell.screens` 实例必须拥有独立的 overlay 状态和设置窗口。
- 设置窗口关闭时释放焦点与输入捕获；Escape、scrim 和关闭按钮必须遵守 modal contract。

### R2. Live Bar Settings

- Bar 页面中的高度、位置、floating、floating margin 和 corner radius 必须实时影响顶部栏几何。
- 几何值必须经过现有逻辑 helper 的边界校验，不能产生负尺寸、绑定循环或异常 exclusive zone。

### R3. Live Notification Settings

- Notification timeout 必须影响新通知的自动消失时间。
- Notification position 必须影响每屏通知栈的四角锚点。
- 过期通知必须被确定性清理，避免重复计时器或已销毁对象继续触发。

### R4. Live Appearance Settings

- color scheme、panel opacity、blur、glass highlight、theme glow、theme adaptation 和 ripple pulse 等已暴露设置必须连接到实际消费者。
- 主题变化不得破坏现有 `ColorService` 的 palette 更新和服务 singleton 合约。

### R5. Music Overlay

- 音乐覆盖层必须使用固定宿主几何，不因内容变化驱动 layer-shell 宿主逐帧 resize。
- 播放、暂停、上一首、下一首、shuffle 等控制必须通过现有 `MediaService`/媒体接口工作；无媒体时显示稳定的空状态。
- 覆盖层的打开、关闭和 settings 互斥行为必须可测试。

### R6. Quality and Compatibility

- 保持现有 QML singleton、`qmldir`、`Variants { model: Quickshell.screens }` 和 native QML 结构。
- 所有新增或修改的 QML 主要元素遵守项目注释约定。
- QML 修改后运行相关 QtTest；最终运行完整相关回归、Python backend tests、`qs -p .` 启动检查和 `git diff --check`。

## Acceptance Criteria

- [x] 设置按钮、音乐按钮和 `TopBar` 共享且正确切换 per-screen overlay 状态。
- [x] Settings panel 能打开、关闭、重新打开，并在 settings/music 间切换而不留下输入捕获或焦点泄漏。
- [x] Bar 页面全部几何设置实时反映到顶部栏，并通过边界与回归测试。
- [x] Notification timeout/position 设置实时反映到通知服务和每屏通知栈。
- [x] Appearance 设置实时反映到对应视觉消费者，且 `ColorService` 更新无 QML WARN/ERROR。
- [x] Music overlay 控件与空状态可用，尺寸稳定，settings 互斥行为通过测试。
- [x] 相关 QML 测试重复运行稳定通过；完整验证无新增 QML WARN/ERROR。

## Out Of Scope

- 不重写 `SettingsService`、`MediaService`、`ColorService` 或通知协议。
- 不引入第三方 UI 框架、新的持久化格式或跨项目兼容层。
- 不实现未在现有设置模型中定义的新设置分类或搜索系统。
- 不修改无关的 frontend/backend 模块和用户已有的 `docs/image.png`。

## Open Questions

无阻塞性产品决策。实现遵循现有设计规格、服务 API 和已提交的设置面板代码。
