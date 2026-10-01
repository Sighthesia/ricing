# 启动揭露与桌面挂载调度设计

## Status

设计已确认，待实施。

本文建立在 `2026-10-01-lock-first-startup-design.md` 之上，解决启动先锁屏
之后出现的第二类问题：壁纸圆形揭露、锁屏波幕和 chrome/bar 首次创建在同一时间窗
竞争 GUI/render 线程，导致揭露、bar 加载和波纹动画一起停顿。

## Context

当前启动路径的主要时序是：

1. `shell.qml` root eager 挂载 `WallpaperBackground` 和 `LockModule.Lock`；
2. `LockSurface.Component.onCompleted` 立即启动锁屏波幕；
3. `WallpaperBackground` 异步准备第一张壁纸，圆形揭露完成后执行
   `baseImage.source = pendingWallpaper`；
4. 壁纸报告 `bootReady`，root 立即激活 `chromeLoader`；
5. `TopBar`、多个 layer-shell `PanelWindow`、全部 bar widget loader 和服务预热
   在同一个启动窗口内开始工作；
6. palette extraction、desktop-entry icon lookup、tray/workspace 图标和首次
   scene-graph/pipeline 初始化进一步放大长帧。

这个顺序有两个结构性问题：

- 锁屏波幕与壁纸圆形揭露同时绘制全屏动画；
- 揭露结束时，已经解码的 incoming wallpaper 又被同步交给另一个全屏 `Image`，
  可能发生第二次大图解码和纹理上传，紧接着又触发 chrome 的批量创建。

独立解码基准显示，当前常用的 3600×2024 JPEG 单次解码约 47--66ms，较大的
5120×2160 WebP 约 187--213ms；这还未计入 Qt 纹理上传与合成。因此不能靠调小
`wallpaperSwap`、`waveEnter` 或更换 easing 解决，必须改变工作发生的时机和图像所有权。

## Goals

1. 保留启动先锁屏：新会话第一屏仍是锁屏，`LockModule.Lock` 仍从 root eager 挂载。
2. 保留壁纸圆形揭露：它在锁屏底板后运行，并在解锁前完成。
3. 消除启动揭露结束时的同步二次解码和大块图像交接。
4. 避免首次 chrome/bar 构建与全屏动画同时发生。
5. 将 bar widget 和低优先级服务工作分批推入空闲事件循环，避免单个长帧。
6. 保持手动壁纸切换、手动锁屏截图、运行中通知/控件 glow pulse 的现有语义。
7. 为启动时序建立可验证的纯逻辑和静态接线测试。

## Non-goals

- 不改变 Niri session-lock 协议、PAM 解锁流程或手动锁屏的截图职责。
- 不改变 bar 的视觉布局、固定 layer-shell 外边界、exclusive zone 或交互区域。
- 不在启动阶段引入新的全屏装饰 surface。
- 不把 `OpacityMask` 替换成 Qt 6.11 上不稳定的 inline `ShaderEffect`、Canvas 或
  `QtQuick.Shapes` mask。
- 不要求启动时立即完成 launcher 应用池、剪贴板索引、palette extraction 或外部
  app theme 同步；这些任务的正确性不依赖于首屏时刻完成。

## Design

### 1. 启动阶段的四个阶段

新增一个只负责启动状态推进的轻量协调层，可由 `shell.qml` 的 root 属性和少量
纯逻辑函数组成，不引入新的 layer-shell surface。

阶段定义如下：

| 阶段 | 允许的工作 | 不允许的工作 |
| --- | --- | --- |
| `locked-floor` | 创建锁屏 surface、主题底板、壁纸 incoming image、必要的键盘 owner | 锁屏波幕、chrome、bar widget、palette CPU 工作 |
| `wallpaper-reveal` | 壁纸图像异步解码、圆形 mask 动画 | 锁屏波幕、chrome 的批量 delegate 创建 |
| `chrome-staging` | 固定尺寸 surface、bar 基础几何、分批 widget loader | 全屏锁屏波幕、palette extraction、launcher 全量预热 |
| `quiet-ready` | 启动锁屏波幕、低优先级服务预热 | 再次改变启动 surface 的尺寸或批量替换模型 |

状态只能向前推进。屏幕重新 key、分辨率变化和普通 wallpaper switch 不得重新
触发启动状态机；它们继续使用已有的 live 路径。

### 2. 锁屏先显示底板，波幕延后

`LockModule.Lock` 继续在 root eager 挂载，并继续在启动请求中使用 `wallpaper`
background mode。区别是 `LockSurface` 不在 `Component.onCompleted` 无条件启动
`revealStartTimer`。

启动请求需要一个明确的 entry gate：

- surface 创建后先显示不动的主题底板，内容和键盘 owner 可以完成初始化；
- `WallpaperBackground.bootReady` 报告所有屏幕的圆形揭露已完成后，root 通知
  lock startup coordinator；
- chrome staging 完成并达到 `quiet-ready` 后，才允许每个启动锁屏 surface 开始
  `waveProgress` 的 entry animation；
- 手动锁屏不经过这个 gate，仍按当前截图准备和锁屏揭示路径运行。

这样启动时只有一套全屏动画在运行：壁纸圆形揭露先在锁屏后面完成，锁屏波幕随后
才开始。锁屏仍然是第一屏，桌面也仍然在用户解锁前完成构建。

#### Gate 接口

建议使用显式、可测试的状态接口，而不是让 `LockSurface` 直接读取
`WallpaperBackground`：

- `Lock` 暴露 `startupWallpaperReady` / `startupChromeReady` 两个启动态输入；
- `LockSurface` 暴露 `startupRevealAllowed`，仅启动请求使用它；
- `startReveal()` 只在手动请求或 `startupRevealAllowed === true` 时启动；
- 所有 surface 的 startup gate 都必须在 `Lock` 的 state machine 进入 `locked`
  后继续有效，不能因为 gate 尚未到达而释放 session lock。

如果某个启动 screen 的壁纸失败或没有配置，`WallpaperBackground` 的已有 boot
outcome 仍然报告完成；gate 必须在 error/empty/unchanged/reduced-motion 分支
同样前进，不能把锁屏永远留在静态底板。

### 3. 启动壁纸使用可晋升的图像槽位

当前 `WallpaperReveal` 内部的 `nextWallpaper` 与 `WallpaperBackground` 的
`baseImage` 是两个独立 `Image`。启动路径改为使用两个可复用的 wallpaper slots：

- `settledSlot`：当前已交接给桌面的图像；
- `incomingSlot`：正在异步解码、并由圆形 mask 使用的图像。

`WallpaperReveal` 增加可注入的 `sourceItem`/等价 source-item 接口。启动时 mask
直接采样 `incomingSlot`，揭露完成后只做 slot promotion：

1. 停止 reveal animation；
2. 关闭 mask 的可见输出；
3. 将 `incomingSlot` 标记为 `settledSlot`；
4. 保留该 `Image` 已有的 source、decoded pixels 和 texture；
5. 让旧 slot 成为下一次 live switch 的 incoming slot。

启动完成路径不得再执行 `settledImage.source = pendingWallpaper` 这种同步全屏
交接。这样 boot image 的 decode 和纹理上传只发生在它真正作为 incoming slot 准备
时，揭露结束只改变引用/可见状态。

live wallpaper switch 仍然使用双 slot 的同一套交接模型：新 source 只写入空闲
slot，等它 ready 后开始 mask；旧 slot 在 promotion 前保持可见，保证没有空帧。
如果图片失败，保留旧 slot，回到已有的 error/fallback 行为。

#### 解码尺寸策略

每个 slot 应设置不超过当前 screen 需要的 `sourceSize`，并以屏幕实际尺寸和
device pixel ratio 为上限。这样超大原图不会在首屏被完整解码到远超显示尺寸的
纹理。source size 必须在 screen geometry 稳定后设置，避免同一 transition 内因
反复 geometry binding 造成重新解码。

`cache: false` 可以继续保留，以避免 QPixmapCache 对全屏壁纸的错误命中假设；
复用依靠 slot promotion，而不是依赖全局图片缓存。

### 4. Chrome 分层和 bar widget 分批激活

`chromeLoader` 仍然只在 `WallpaperBackground.bootReady` 后激活，但其内容改为
分阶段 loader：

1. **基础阶段**：创建固定外边界的 `TopBar` 和必要的 bar geometry；不激活完整
   widget delegate。
2. **widget 阶段**：`BarContent` 保留完整 layout model，但每个 delegate 的
   `Loader.active` 受 `startupWidgetLimit` 控制。每一批只激活少量 widget，批次
   之间让出至少一个事件循环/scene-graph frame。
3. **辅助 surface 阶段**：在 bar 基础 geometry 已提交后，再创建 notification host、
   screen corner surface、overview surface、launcher owner 和 settings owner。
4. **完成阶段**：所有启动批次完成后发出 `startupChromeReady`，但不在同一回调中
   执行 palette、launcher 全量扫描或外部主题写入。

批量激活的默认顺序应稳定并可测试：先 clock/active-window 等轻量 widget，再
workspaces/media/tray 等包含 repeater、图标或图片的 widget，最后再激活其余
状态型 widget。持久化 layout 的相对顺序仍是视觉顺序，批次只是实例化调度，不得
改变 bar 中的排列。

当 startup staging 结束后，`BarContent` 回到普通模式：新增 widget、layout 修改、
屏幕热插拔和运行中更新不走启动 batch gate。默认非启动实例仍保持当前一 tick
后激活全部 widget 的行为。

### 5. 低优先级后台工作移出启动波幕

`LauncherService.primeApps()`、`ClipboardService.warmup()` 和
`WindowHintService` listener 的启动应从 chrome `Component.onCompleted` 中移出，
改为 `quiet-ready` 后的单向启动任务队列：

1. chrome 基础 surface 已提交；
2. widget batches 已结束；
3. 锁屏 entry wave 已开始或已完成首帧；
4. 每个任务之间至少让出一个事件循环 turn，必要时使用现有 `MotionTokens.slow`
   级别的延迟；
5. 任务失败不影响锁屏、bar 或壁纸状态。

其中 `LauncherService.primeApps()` 仍使用现有 pool 和 icon cache 逻辑，但不应在
首个 bar surface 创建的回调中同步执行。`ClipboardService.warmup()` 只负责启动
已有后台检查，不得阻塞 chrome ready 判定。

`AppThemeService.apply()` / `pushSystemTheme()` 继续保持延后；它们不应被重新移回
首屏路径。

### 6. Palette extraction 的启动门控

`ColorService` 保留已有 `revealStarted()` / `revealCompleted()` 机制，并增加一个
明确的 startup quiet gate：

- `Component.onCompleted` 可以读取和使用已有缓存，但不能在
  `locked-floor`、`wallpaper-reveal` 或 `chrome-staging` 启动 extraction；
- `extractColors()` 在 startup gate 未打开时只记录最新 pending path/scheme；
- `startupQuietReady()` 打开 gate 后，再使用现有 debounce 启动一次最新请求；
- cache 命中仍然直接丢弃不必要的 extraction；
- live wallpaper switch 在 startup gate 打开后保持现有 reveal gate 语义。

启动 palette 任务的开始不能决定 `bootReady`、`startupChromeReady` 或锁屏 release；
即使 Python process 失败，视觉启动也必须继续。

### 7. Glow pulse 的启动行为

`RipplePulseService` 默认 inactive 的契约保持不变。启动阶段增加一条保护：

- bar widget 第一次从默认值变成服务实际值时，不触发 glow pulse；
- startup staging 期间发生的初始 volume/brightness/network/bluetooth/battery
  状态同步只更新 widget 状态和已有 flash，不启动共享屏幕 pulse；
- startup quiet gate 打开后，真实用户操作和真实通知仍照常调用
  `RipplePulseService.trigger()`；
- 不能用全局永久禁用开关替代启动 gate，否则会吞掉用户在启动后立即发生的事件。

### 8. 启动状态机的失败和重入

- `bootReady`、`startupChromeReady` 和 `startupQuietReady` 都是幂等的；重复信号
  不得重新创建 chrome 或重启已完成的 reveal。
- wallpaper error/empty、screen list 延迟、screen re-key 都必须有有界 fallback，
  与现有 boot outcome 和 startup lock timer 一致。
- startup lock 请求在 gate 等待期间保持 `locked/preparing` 状态，不允许第二个
  startup request 创建新的 session lock。
- 手动 `lock()` 在 startup staging 期间仍由同一个 `Lock` owner 接收；它不得被
  startup gate 延后到错误的背景模式，也不得复用启动 wallpaper slot 的待处理状态。
- shell reload 的 session marker 语义保持不变；已消耗的 session 不重新启动整套
  startup choreography。

## Testing Strategy

### Pure logic

- 新增 `WallpaperSlotLogic.js` 测试：incoming/settled slot promotion、失败回退、
  不在 promotion 时重写 source、slot index 的稳定切换。
- 新增 startup coordinator 逻辑测试：阶段只能前进、重复 ready 不重入、error/empty
  结果仍能前进、startup wave 只在 wallpaper 和 chrome 两个 gate 都 ready 后允许。
- 扩展 `tst_startup_lock_logic.qml`：启动 gate 与手动 lock 的模式决策互不污染。
- 扩展 `tst_wallpaper_reveal.qml`：注入 source item 时 mask 使用同一个 Image，
  source item promotion 不触发第二次 source assignment。

### Component/harness

- 扩展 root-level startup order harness，检查：
  - `LockModule.Lock` 仍在 root；
  - `LockSurface` 不在 component 完成时无条件启动 startup wave；
  - chrome 由 boot ready 单向激活；
  - widget loader 存在 batch limit；
  - palette/launcher warmup 不在 chrome 首个完成回调直接执行。
- 增加 `BarContent` batch harness，验证所有 widget 最终 active、批次顺序稳定、
  普通非启动模式仍一次性激活。
- 运行现有 lock/backdrop/wallpaper/bar popup 测试，确保手动锁屏和 live wallpaper
  switch 不被 startup gate 改变。

### Live-session verification

不自动运行会映射真实 layer-shell 的测试。由人工在实际 Niri session 验证：

1. shell 启动或 reload 时，锁屏底板先稳定出现；
2. 壁纸圆形揭露在底板后完成，没有明显冻结；
3. bar 基础几何先出现，widget 分批补齐，但锁屏波幕不被 bar 创建卡住；
4. chrome 完成后锁屏波幕平滑开始；
5. 解锁后 bar、通知、圆角和壁纸已经就绪；
6. 手动切换壁纸仍无黑帧，手动锁屏仍使用桌面截图；
7. 启动期间 widget 初始状态不会产生多余 glow pulse，启动后的真实操作仍会产生。

可选的 `AFLOAT_STARTUP_TRACE=1` 诊断输出应只记录阶段时间点、slot promotion、
batch index 和 frame-gap summary，不打印路径中的敏感内容；验证完成后保留可控的
诊断开关，不保留临时无条件日志。

## Acceptance Criteria

1. 启动时锁屏仍是第一屏，且启动请求不截图。
2. 壁纸圆形揭露保留，并在锁屏后面完成。
3. 揭露结束不发生同步的第二次全屏壁纸解码/纹理交接。
4. 壁纸揭露期间不创建完整 chrome/widget 树，不运行 palette extraction。
5. bar、widget、通知和辅助 surface 最终全部出现，且布局顺序不变。
6. 锁屏波幕在 chrome staging 完成后才开始，不因 bar 初始化长帧而停顿。
7. launcher/clipboard/palette 等后台任务延后执行且不阻塞首屏。
8. 手动壁纸切换、手动锁屏截图、解锁流程和运行中 glow pulse 行为保持不变。
9. 现有 headless suite、Python tests 和新增回归测试通过；触及的 QML 文件通过
   `qmllint`，无新增 error 诊断。
