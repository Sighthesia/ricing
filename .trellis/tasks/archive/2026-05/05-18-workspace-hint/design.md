# 技术设计：Mod键工作区/窗口提示OSD弹窗

## 架构概览

```
/dev/input/*-kbd
      │
      ▼
scripts/window_hint_trigger.py   (Python, 标准库)
      │  stdout: "mod-down\n" / "mod-up\n"
      ▼
services/WindowHintTriggerService.qml  (Process + SplitParser)
      │  signal holdChanged(bool)
      ▼
services/WindowHintService.qml   (hint 快照构建)
      │  property: activeHint, hintVisible
      ▼
modules/workspace-hint/WorkspaceHintWindow.qml  (OSD UI)
```

## 模块边界

### 1. scripts/window_hint_trigger.py

从 DymicShell 移植，适配 afloat 命名：
- 环境变量前缀改为 `AFLOAT_` (AFLOAT_WINDOW_HINT_META_KEYS, AFLOAT_WINDOW_HINT_INPUT)
- 逻辑不变：selectors 轮询 /dev/input 设备，检测 meta 键状态，输出行协议

### 2. NiriService.qml 增强

当前状态：只有 windows ListModel，event-stream 只处理窗口事件。

增加：
- `property ListModel workspaces: ListModel {}`
- `signal workspacesUpdated()`
- `signal workspaceActivated()`
- 初始获取：`niri msg -j workspaces` → 填充 workspaces model
- event-stream 增加 `WorkspacesChanged` / `WorkspaceActivated` 处理
- windows model 增加 `workspaceId` 字段（从 `workspace_id` 映射）

数据模型：
```
workspaces: { wsId: string, idx: int, isActive: bool, name: string }
windows:    { winId, title, appId, isFocused, workspaceId, colIdx, rowIdx }
```

### 3. WindowHintTriggerService.qml (新建)

单例服务，职责：运行 Python 触发脚本，暴露 mod 键状态。

接口：
- `property bool active` — mod 键是否按住
- `signal holdChanged(bool active)`
- 内部 Process 运行脚本，SplitParser 解析 stdout
- 异常退出后 Timer 1s 重启

### 4. WindowHintService.qml (新建)

单例服务，职责：监听触发器 + NiriService 变化，构建 hint 快照。

接口：
- `property bool hintHeld` — 当前是否处于 hint 展示状态
- `property bool hintVisible` — hintHeld && 有有效数据
- `property var activeHint` — 完整快照对象

快照结构：
```javascript
{
    visible: bool,
    workspaceId: string,
    workspaceIndex: int,
    activeWorkspacePosition: int,
    currentWindowTitle: string,
    currentWindowAppId: string,
    currentWindowIcon: string,
    currentIndex: int,
    windows: [{ windowId, title, appId, icon, isFocused }],
    workspaces: [{ workspaceId, workspaceIndex, icons: [{ windowId, icon, isFocused }] }],
    previousWindow: { windowId, title, appId, icon },
    nextWindow: { windowId, title, appId, icon }
}
```

Connections:
- WindowHintTriggerService.holdChanged → setHintHeld
- NiriService.windowsUpdated / workspaceActivated / workspacesUpdated → 刷新快照

### 5. modules/workspace-hint/WorkspaceHintWindow.qml (新建)

OSD 弹窗 UI：
- `Variants { model: Quickshell.screens }` 每屏一个
- PanelWindow, overlay 层, exclusiveZone: -1, 居中
- visible 绑定 WindowHintService.hintVisible
- 布局：
  - 顶部：工作区横向列表（圆角胶囊，当前高亮）
  - 中部：当前工作区窗口列表（图标 + 标题，聚焦项高亮）
  - 底部：前后窗口预览（半透明，较小字号）
- 动效：opacity + scale 入场/退场，使用 Motion.popup 参数
- 配色：Color.mSurface / mOnSurface / mPrimary

## 数据流

1. 用户按住 Super → trigger.py 输出 `mod-down`
2. TriggerService.active = true → holdChanged(true)
3. HintService.setHintHeld(true) → _buildHint() 从 NiriService 读取数据
4. HintService.activeHint 更新 → hintVisible = true
5. WorkspaceHintWindow 绑定 hintVisible → 显示 OSD
6. 用户切换工作区 → NiriService.workspaceActivated → HintService 刷新快照 → UI 更新
7. 用户松开 Super → trigger.py 输出 `mod-up`
8. TriggerService.active = false → HintService.setHintHeld(false) → hintVisible = false
9. OSD 淡出消失

## 兼容性

- 与现有 OsdWindow 完全独立，不共享状态
- NiriService 增强向后兼容（新增字段/信号，不修改现有接口）
- 触发脚本需要 input 组权限，缺失时静默降级（TriggerService.available = false）

## 风险

- `/dev/input/` 权限：用户需在 input 组。降级策略：脚本等待设备可用，日志提示。
- niri API 变化：workspaces/windows JSON 结构变化需适配。使用防御性解析。
- 性能：hint 刷新使用 40ms 防抖 Timer，避免高频事件风暴。
