# 启动锁屏与 Wave Session 菜单设计

- **日期**：2026-09-25
- **状态**：待审阅
- **目标分支**：`lazer`

## 1. 目标

让 Afloat 在 shell 启动后自动取得 Niri 的 session lock，使 Afloat 自身成为系统锁屏；同时在锁屏 surface 内提供 osu!lazer/Wave 风格的 session 菜单，允许用户执行锁定、注销、挂起、重启和关机。

现有 PAM 解锁、每屏 `WlSessionLockSurface`、截图/壁纸波幕、退场动画和 failsafe 都保留。session 菜单只负责请求系统动作，不拥有解锁或释放 session lock 的权限。

## 2. 现状与边界

### 2.1 已有能力

- `shell.qml` 已挂载 `LockModule.Lock {}`。
- `modules/lock/Lock.qml` 已拥有唯一的 `WlSessionLock`，并通过 `lock()` 进入准备、提交、锁定和退出状态。
- `LockContext.qml` 已将 PAM 对话与 surface 展示解耦；PAM 成功是正常释放锁的唯一入口。
- `LockSurface.qml` 已有延迟波幕揭示、密码输入、键盘 owner 和成功后的反向波幕。
- `modules/lazerbar` 已提供 `WaveSurfaceHost`、`WaveSurfaceLogic` 和 `MotionTokens`，但其当前内容路由主要服务 launcher。

### 2.2 不在本次范围

- 不替换 PAM 配置，不增加第二条解锁路径。
- 不改变 Niri 的锁屏协议或为每个 action 创建独立 layer-shell 窗口。
- 不重构现有锁屏截图和波幕实现。
- 不实现用户账户切换、显示器选择或远程 session 管理。

## 3. 推荐架构

### 3.1 启动锁屏编排

在 `shell.qml` 的根对象中增加一个一次性启动编排：

1. shell 完成初始化后启动短延迟 timer。
2. timer 检查 `Quickshell.screens.length`。
3. 屏幕尚未发现时，只重启同一个 timer；不调用 `lock()`。
4. 屏幕可用时调用 `Lock` 的启动入口一次。
5. `Lock` 内部继续通过现有 `Controller.canLock()` 和 `_state` 过滤重复请求。

启动入口应区分“启动请求已发出”和锁屏是否已经提交，避免 Component 完成回调、屏幕变化回调或 shell 热重载造成重复请求。现有手动 `lock` IPC 继续调用同一状态机。

启动自动锁定不应复用测试专用的 `AFLOAT_LOCK_SELFTEST` 释放逻辑。已有 self-test 环境变量和 failsafe 保持原语义，以便开发期不会把测试会话永久锁住。

### 3.2 SessionService

新增 `services/SessionService.qml` 单例，并在 `services/qmldir` 注册。它是 session action 的唯一执行 seam，负责：

- 暴露固定 action 列表及显示名称/图标标识。
- 暴露动作是否可用，以及当前执行状态和错误文本。
- 将动作映射到系统命令：
  - `lock`：调用当前 shell 的锁定入口；
  - `logout`：调用 `loginctl terminate-session` 或项目确认后的等价命令；
  - `suspend`：调用 `systemctl suspend`；
  - `reboot`：调用 `systemctl reboot`；
  - `shutdown`：调用 `systemctl poweroff`。
- 对命令执行设置单一 in-flight 门控，避免重复点击产生并发系统动作。
- 对不可用命令或非零退出码发出失败状态；失败不会销毁锁屏 surface，也不会将锁状态改为已解锁。

`lock` action 通过 `Lock` 对象入口请求锁定，而不是让 `SessionService` 直接触碰 `WlSessionLock`。其余动作启动系统级转场，真实 session 是否退出由系统处理。

### 3.3 LockSurface 内的 Wave Session 菜单

在 `LockSurface.qml` 内新增一个静态声明的菜单宿主，建议拆为：

- `LockSessionMenuLogic.js`：纯函数处理 action 列表、菜单开关、Escape 优先级、可用状态和确认状态。
- `LockSessionMenu.qml`：菜单视觉与输入。
- `LockSessionMenuItem.qml`：单个 action 行；静态声明五个 item，不使用 `Repeater`。

菜单默认关闭。锁屏 surface 显示一个 Wave 风格 session affordance；点击后以侧向遮挡揭示打开菜单。主表面使用直角矩形和色阶层次，选中使用矩形指示条/亮度变化，组件内部只保留克制的小圆角。

菜单动作：

| Action | 语义 | 默认行为 |
| --- | --- | --- |
| Lock | 重新触发锁定请求 | 保持当前锁屏，不释放 PAM lock |
| Logout | 结束当前登录 session | 需要一次确认 |
| Suspend | 挂起系统 | 需要一次确认 |
| Reboot | 重启系统 | 需要一次确认 |
| Shutdown | 关机 | 需要一次确认 |

确认采用菜单内二次状态，不创建独立弹窗 surface。首次点击进入确认态，第二次点击才调用服务；Escape 或点击菜单外区域取消确认态。执行中 action 禁用，结果由菜单内状态文本表达。

### 3.4 输入和焦点优先级

- 菜单关闭时，session affordance 只处理其命中区域；密码键盘 owner 继续接收输入。
- 菜单打开时，菜单输入层只覆盖菜单区域，不覆盖整张 surface；密码输入仍可通过既有入口工作。
- Escape 处理顺序为：取消确认态、关闭菜单、退出密码输入模式（若现有逻辑支持），最后才交给其他锁屏行为。
- 菜单打开/关闭不调用 `LockContext.reset()`，不会中断 PAM 对话；只有系统 action 或用户显式提交密码才改变锁屏状态。
- 多屏 surface 各自持有菜单视觉状态，但 action 执行通过同一个 `SessionService` 门控，避免重复系统调用。

## 4. 动画和视觉规则

- 使用 `Lazer.MotionTokens` 的 `fast`、`medium`、`slow`、`waveEnter`、`waveExit` 等已有令牌。
- 普通模式使用可中断的 OutQuint/项目已有 Wave 缓动；反向关闭从当前进度继续，不瞬移。
- `MotionTokens.reducedMotion` 开启时直接切换到打开/关闭终态，保留颜色和可用状态反馈。
- 不在 `WlSessionLockSurface` 内使用 `Repeater` 动态创建视觉子项。
- 保留安全底板、波幕层级和起播宽限；菜单不能遮挡首帧不透明 floor，也不能成为释放 session lock 的条件。

## 5. 错误处理

- `SessionService` 在命令不可执行、已在执行或退出码非零时提供稳定的错误文本。
- 错误状态只影响 session 菜单：菜单保持打开，确认态退出，用户可再次尝试或关闭菜单。
- 锁屏的 PAM 失败仍由 `LockContext` 处理，不与 session action 错误混用。
- 如果启动时屏幕永远未出现，startup timer 持续等待，不进入无 surface 的锁状态。
- 如果 shell reload 导致 callback 重复，`Lock` 状态机和 startup armed 标记共同保证最多一个请求。

## 6. 测试计划

### 6.1 纯逻辑测试

新增 `tests/qml/tst_lock_session_menu_logic.qml`，覆盖：

- 固定五项顺序和 action 元数据。
- 菜单打开/关闭和确认态转换。
- Escape 优先级。
- 禁用 action 与 in-flight 门控。
- 错误后可重试。

新增或扩展启动逻辑测试，覆盖：

- 无屏幕时等待。
- 首次可用屏幕时只请求一次。
- preparing/locked/exiting 时拒绝重复请求。

### 6.2 现有锁屏回归

运行 `tst_lock_logic.qml`、`tst_lock_controller_logic.qml`、`tst_lock_surface_logic.qml`、`tst_lock_backdrop.qml` 及新增测试。所有 QML 测试使用项目约定的 Qt6 `qmltestrunner` 命令。

### 6.3 qs-host 冒烟

从仓库根目录启动带 `AFLOAT_LOCK_SELFTEST=1` 和 `QS_DISABLE_FILE_WATCHER=1` 的隔离测试入口，确认：

- shell 能启动并创建 lock surface；
- session 菜单可见、可打开和可关闭；
- self-test/failsafe 能释放锁并结束测试；
- 没有留下需要手动 kill 的 `qs` 实例。

按 session-lock 约束，修改后完全重启 `qs` 验证，不依赖热重载。

## 7. 验收标准

- shell 启动后自动进入 Afloat 锁屏，屏幕未就绪时不会错误提交空锁。
- 正常密码认证仍是唯一解锁路径。
- 锁屏内可使用五项 session 菜单，动作有确认和失败反馈。
- 菜单开关不破坏密码输入、波幕动画或 session lock 生命周期。
- reduced-motion、重复 callback、多屏和命令失败场景均有明确行为和测试覆盖。
