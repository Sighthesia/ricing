# 锁屏优先启动设计（Lock-First Startup）

## Status

已实现。本文修正 `2026-09-27-wallpaper-first-startup-design.md` §1 中关于
`LockModule.Lock` 挂载位置的决定，并说明启动锁不再截图的原因。

## Context

壁纸优先启动把 `LockModule.Lock` 和其余 chrome 一起放进了 `Loader`，并从 chrome 的
完成回调里调用启动锁。结果是每次新会话的顺序变成：

1. 壁纸圆形揭露跑完（480ms）；
2. `bootReady` 触发，chrome 挂载，bar / 通知 / 圆角 surface 刚创建；
3. 同一轮事件循环里调用 `startupLock()` → grim 截图 → 提交 session lock。

第 3 步的截图落在 bar 刚创建、还没走过一次合成器映射的时刻，截到的是一张半成品桌面；
而锁屏波幕的终点是它自己绘制的壁纸图层（不含 bar）。于是揭露前看到的截图与揭露后的画面
必然对不上——这正是「启动时锁屏揭露的是半成品截图界面」的成因。

更根本的问题是：截图在设计里的唯一职责是与用户刚才看到的桌面保持视觉连续性
（见 `2026-08-28-wave-session-lock-design.md`）。会话刚开始时并不存在这样一个桌面，
截图在这里只能制造噪音，没有任何连续性可以保留。

## Design

### 1. 锁屏成为会话的第一屏

`shell.qml` 把 `LockModule.Lock` 从 chrome `Component` 移回根对象，与
`WallpaperBackground` 并列成为两个 eager surface，并在根对象的完成回调里调用
`startupLock()`。

- 壁纸优先的契约不变：壁纸仍是第一个被构建并开始揭露的视觉 surface。
- 壁纸揭露照常在锁屏背后跑完，因此用户认证通过时桌面已经就绪，解锁瞬间没有空窗。
- chrome（bar / 通知 / 圆角）与 `LauncherService`、`ClipboardService`、
  `WindowHintService` 的预热仍在 `bootReady` 之后，但现在是在锁屏背后完成。
- 锁屏从第一轮就拥有 `lock` 这个 IPC target。原来那个只存在于 bootstrap 期间的
  `bootstrapLockBridge`（负责排队并重放锁屏请求）连同 `lockOwner` /
  `queuedLockRequest` / `adoptLockOwner` 一起删除：真实 owner 始终存在，bootstrap
  期间的 `lock` keybind 或 `afloat-ipc lock` 直接命中它，不再需要排队。
- 启动锁仍然按原有 marker 语义每个 niri session 只自动锁一次；shell 在已使用过的
  session 内 reload 依旧不会重新锁屏。

### 2. 启动请求跳过截图

`Lock.lock(startup)` 接受一个启动标记，背景模式由
`StartupLockLogic.backgroundModeFor(configuredMode, startup)` 决定：启动请求恒为
`wallpaper`，其余请求沿用 `AFLOAT_LOCK_BACKGROUND` 配置的默认值。

没有 provider 时 `LockSnapshot.request()` 立即完成而不是等待 fallback 窗口——否则桌面
会在整个宽限期内继续留在锁屏底下。

### 3. 不为不存在的截图阻塞揭露

`LockSurface` 把本次请求是否预期有截图传给 `LockBackdrop.captureExpected`。
`LockBackdrop.imagesReady` 过去同时等待截图与壁纸两张图；当请求根本没有截图时，截图槽
永远是空的，`imagesReady` 恒为 false，揭露会白白耗尽 12 × 250ms 的宽限计数才开演。
现在预期外的截图不参与该门控，而**预期有却失败的截图仍然保留同一段有界等待**，
因此 grim 失败时不会在 surface 出现的瞬间就暴露壁纸。

## Testing

纯逻辑 seam：

- `tests/qml/tst_startup_lock_logic.qml`
  - 启动请求在任何配置下都解析为 `wallpaper`；
  - 手动请求保留配置的截图模式。

组件行为：

- `tests/qml/tst_lock_snapshot.qml`
  - 无 provider 的请求同一轮即就绪，并回报自身 generation；
  - 沉默的 provider 仍走 fallback；
  - 每个屏幕只写入自己的槽位，陈旧 generation 的 URL 会被下一次请求清空。
- `tests/qml/tst_lock_backdrop.qml`
  - 预期无截图时揭露不被一张永不到来的图片阻塞，起点是主题底板、终点是壁纸；
  - 预期有却缺失的截图仍然阻塞。

`Lock.qml` 与 `LockSurface.qml` 需要 `WlSessionLock`，无法在 offscreen 下加载，因此它们
与 `shell.qml` 的接线由静态检查与人工复核保证。

## Acceptance Criteria

1. 新会话的第一屏是锁屏，不再出现「先组装桌面再立刻锁上」的过程。
2. 启动锁屏不显示任何截图，揭露前是主题底板，揭露后是壁纸，两者一致。
3. 壁纸圆形揭露保留；解锁瞬间桌面已就绪。
4. 会话中途手动锁屏仍然使用桌面截图，视觉连续性不变。
5. `AFLOAT_LOCK_BACKGROUND=wallpaper` 与手动 `lock` IPC 的既有语义不变。
6. shell reload 不会在已使用过的 session 内重新锁屏。
7. `scripts/run-tests.sh` 全绿，`qmllint` 无新增诊断。
