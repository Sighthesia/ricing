# Skill: Session Lock Surface Constraints

修改 Afloat 锁屏（`modules/lazerbar/LockScreen.qml` / `LockSurface.qml`、`services/LockService.qml`）时必须加载。固化在 niri + quickshell 0.3.1 上用血泪换来的渲染与生命周期约束，违反任何一条都会复现"锁屏静止无动画"或"粉屏冻结"。

## 渲染约束

1. **禁止 Repeater 动态创建视觉子项**：`Repeater` delegate 在 `WlSessionLockSurface` 内不进入渲染场景（对象存在、属性正确，但永不上屏）。所有层（波幕等）必须**静态逐个声明**。已验证：静态声明同组件立即可见。
2. **全宽不透明 body 会终身遮挡 z0 背景层**：波幕必须放在 body 之上（如 `z: 10`），并用 `opacity: 1 - bodyProgress` 随面板落位淡出、解锁时自动重现。否则扫入完全不可见。
3. 安全底板（opaque floor）从第一帧起必须有：session-lock surface 在首帧提交前不能透出桌面。

## 生命周期约束

4. `visible` 永远不会变 false（文档明示"only be destroyed"）；surface 解锁即销毁、每次锁屏新建。入场编排必须在 `Component.onCompleted` 与 `onVisibleChanged(true)` 双路径武装（`revealStarted` 去重），隐藏重置由"销毁"天然完成。
5. 动画起播要留 ~250ms 宽限：客户端属性动画早于合成器真正显示首帧运行会被整个吞掉。

## 测试与运维约束

6. quickshell 进程名是 **`qs`**（不是 `quickshell`）。清理用 `pkill -x qs; pkill -x quickshell`。`pkill -f quickshell` 会误杀自身 shell。
7. **配置热重载会给锁屏留下重复/冻结实例**（上游 Reloadable 复用缺陷，issue #972 同族）。改完锁屏代码必须完全重启 qs 再测；测试期间禁止编辑文件。
8. 开发期保留 LockService 的 10 秒 failsafe（超时走正常解锁流程），防止冻结把会话困死；稳定后移除。另建议 niri 绑定 `Mod+Shift+Esc { spawn "pkill" "-x" "qs"; }` 作 TTY 外的逃生门。
9. 锁屏期间 niri 禁止截图动作，无法像素级验证——显示端验证只能靠人眼（HITL），客户端侧用探针日志 + WAYLAND_DEBUG 协议轨迹。
