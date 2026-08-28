# Wave Session Lock Design

## Goal

将 Afloat 当前的 osu!lazer 风格 Wave 视觉过渡扩展为真正的 Wayland session-lock 锁屏界面：锁屏时先保留桌面视觉连续性，再由 Wave 从现有面板形态扩展至全屏，认证成功后反向收缩并恢复桌面。

## Scope

第一版包含：

- 基于 `WlSessionLock` 和 `WlSessionLockSurface` 的安全锁屏生命周期。
- 每个屏幕独立的全屏锁屏 surface。
- 锁屏前桌面快照，用于过渡期间的视觉连续性。
- 复用当前 `FullscreenWave` 的四层斜向遮盖视觉。
- 密码 PAM 认证。
- `IpcHandler` 的 `lock`、`unlock`、`isLocked`。
- `CustomShortcut` 的 `lock` 入口。
- reduced-motion 路径。

第一版不包含指纹、Howdy、锁屏媒体控制、天气、会话电源按钮或其他非认证功能。

## Architecture

新增 `modules/lock/` 模块：

- `Lock.qml`：持有唯一的 `WlSessionLock`，管理触发、快照准备、锁定和 IPC/快捷键入口。
- `LockSurface.qml`：实现每个屏幕的 `WlSessionLockSurface`，承载快照背景、Wave 遮盖和认证内容。
- `LockContext.qml`：封装 PAM 密码认证、输入状态、失败状态和认证成功信号。
- `LockSnapshot.qml`：在 session-lock 建立前请求并提供每个屏幕的桌面快照；快照不可用时提供不泄露桌面的纯色回退。
- `WaveRevealLayers.qml`：从 `WaveSurfaceHost` 抽出的通用四层 Wave 渲染组件，支持局部 viewport 和全屏 viewport。

`shell.qml` 挂载 `Lock`。锁屏模块不复用 launcher 的 route、outside close zone、普通 PanelWindow mask 或 opener focus 恢复逻辑。

## Lock Lifecycle

锁屏入口的流程：

1. 如果已锁定或正在准备，忽略重复请求。
2. 清空认证状态并请求所有屏幕的桌面快照。
3. 快照准备完成后设置 `WlSessionLock.locked = true`。
4. 每个 `WlSessionLockSurface` 以快照作为背景，立即接管键盘输入。
5. 在 surface 内播放 Wave 从隐藏位置到全屏的揭示动画。
6. Wave 达到终态后显示认证内容并确保输入获得焦点。
7. PAM 成功只触发退出动画，不立即解除 session lock。
8. Wave 反向收缩、认证内容淡出后，才设置 `locked = false`。

快照准备需要超时回退，避免快照服务异常导致无法锁屏。回退只能使用纯色背景，不依赖普通桌面窗口继续显示。

## Visual Behavior

锁屏 surface 的几何尺寸始终为 `parent.width` x `parent.height`。锁屏模式不使用当前 launcher 的 85% 宽度、顶部栏 margin 或左右关闭区域。

Wave 使用当前四层角度和 `MotionTokens` 时长/缓动。锁屏使用单独的 `waveProgress`：

- `0`：快照完全可见，Wave 处于隐藏位置。
- `1`：Wave 完成全屏遮盖。

认证内容在 Wave 接近终态后淡入。解锁时认证内容先淡出，再将 `waveProgress` 动画回 `0`，最后解除锁定。所有动画必须受 `MotionTokens.reducedMotion` 控制；reduced-motion 下直接使用终态，不产生额外位移或旋转。

大表面保持直角矩形，遵循 Afloat 的 osu!lazer sharp 语言。密码输入等内部控件可以使用现有项目的细节圆角和状态色。

## Input and Security

- `WlSessionLockSurface` 是唯一的锁屏交互表面。
- 锁定后不允许任何鼠标或键盘事件穿透到桌面。
- 未进入 session-lock 前的阶段只允许快照准备，不显示可交互的普通 overlay 锁屏界面。
- PAM 失败时保留 session lock、清空密码并恢复认证焦点。
- IPC 的 `unlock` 只能触发认证成功后的正常流程，不能绕过 PAM。
- 多屏全部 surface 都必须创建；不能只锁定主屏。

## Testing

纯逻辑测试覆盖：

- 锁屏状态机的重复触发、准备超时和锁定转换。
- Wave 全屏几何、进出场 progress 和 reduced-motion 终态。
- PAM 状态转换和失败后清空输入。
- 解锁动画完成前不释放 session lock。

现有 `tst_wave_surface_host.qml` 和 `tst_fullscreen_wave.qml` 必须保持通过。新增纯 QML/JS 测试使用 Qt6 `qmltestrunner`，不能用 `qs -p` 代替 QtTest。

## Non-Goals and Risks

- 不保证锁屏期间实时读取底层桌面内容；视觉连续性来自锁屏前快照。
- 快照 provider 的具体实现必须以当前 Quickshell 版本可用 API 为准；若该 API 不可用，使用纯色回退，但仍必须建立 session lock。
- 不修改用户当前工作区已有的无关未提交文件。
