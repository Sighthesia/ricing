# DymicShell 基础设施设计

**日期：** 2026-03-03  
**状态：** 已批准，待实现  
**前置文档：** [2026-03-01-bar-design.md](2026-03-01-bar-design.md)  
**参考项目：** [Archirithm/quickshell](https://github.com/Archirithm/quickshell)

---

## 设计目标

为 DymicShell 搭建完整的项目骨架，包含所有文件的接口定义和框架代码。
不实现业务逻辑，只建立模块边界和数据合约。

---

## 目录结构

```
shell.qml                              # ShellRoot 入口
config/
  Palette.qml                           # Singleton：暗色纯色色板
  Theme.qml                             # Singleton：动画 token + 间距 + 字体
services/
  NiriService.qml                       # Singleton：Niri IPC 工作区/窗口
  BarLayoutService.qml                  # Singleton：布局模型 + settingsMode
modules/
  bar/
    BarWindow.qml                       # PanelWindow + WlrLayershell
    BarContent.qml                      # 三段容器（Left/Center/Right）
    BarSection.qml                      # 单段：三对齐子行
    BarWidgetWrapper.qml                # 通用 wrapper：stagger + pulse
    DragOverlay.qml                     # 设置模式拖拽覆盖层（占位）
    widgets/
      SettingsToggle.qml                # 设置模式开关（占位）
      Clock.qml                         # 时钟（占位）
      WorkspaceWidget.qml              # 工作区指示器（占位）
components/                             # 可复用基础组件（暂空）
```

与 bar-design.md 的差异：顶层增加 `modules/` 命名空间，
预留 `modules/launcher/`、`modules/lock/` 等后续模块的扩展空间。

---

## 模块引用约定

QuickShell 自动按目录路径映射 QML 模块，前缀为 `qs.`：

```qml
import qs.config                        // → config/Palette, config/Theme
import qs.services                      // → services/NiriService, ...
import qs.modules.bar                   // → modules/bar/BarWindow, ...
import qs.modules.bar.widgets           // → modules/bar/widgets/Clock, ...
```

Singleton 使用 `pragma Singleton` + QuickShell 的 `Singleton` 基类型。

---

## 各文件职责与接口

### shell.qml
- 类型：`ShellRoot`
- 职责：实例化 `BarWindow`

### config/Palette.qml
- 类型：`Singleton`（`pragma Singleton`）
- 暴露属性：`background`, `surface`, `highlight`, `highlightAlpha`, `text`, `textMuted`, `border`
- 全部为 `readonly property color`
- 预留 `FileView` 热重载钩子（注释标注）

### config/Theme.qml
- 类型：`Singleton`
- 内嵌 `QtObject` 命名空间 `anim`：
  - `enter`：OutElastic, 500ms
  - `exit`：InExpo, 220ms
  - `move`：InOutCubic, 320ms
  - `highlight`：OutQuad, 180ms
- 属性：`staggerDelay: 40`（ms）
- 属性：`fontFamily`, `fontMono`, `cornerRadius`, `barHeight`

### services/NiriService.qml
- 类型：`Singleton`
- 属性：`workspaces: ListModel`, `windows: ListModel`
- 信号：`windowsUpdated()`
- 方法：`updateWorkspaces()`, `activateWorkspace()`, `updateWindows()`, `reloadWindows()`
- 内部：`Process { command: ["niri", "msg", "--json", "event-stream"] }`

### services/BarLayoutService.qml
- 类型：`Singleton`
- 属性：`settingsMode: bool`（默认 false）
- 属性：`layoutModel: ListModel`（初始化自默认布局 JSON）
- 方法：`moveWidget(id, toSection, toAlignment, toOrder)`
- 方法：`resetLayout()`
- 未来接入 `PersistentProperties` 持久化

### modules/bar/BarWindow.qml
- 类型：`PanelWindow`
- 设置：`WlrLayershell.layer: WlrLayer.Top`, `exclusiveZone: Theme.barHeight`
- 包含 `BarContent` 实例

### modules/bar/BarContent.qml
- 类型：`Item`（`RowLayout`）
- 结构：`BarSection[left]` + stretch + `BarSection[center]` + stretch + `BarSection[right]`
- 从 `BarLayoutService.layoutModel` 驱动 widget 排列

### modules/bar/BarSection.qml
- 类型：`Item`
- 属性：`required property string role`（"left"/"center"/"right"）
- 内部：三行 `Row`（alignLeft / alignCenter / alignRight）

### modules/bar/BarWidgetWrapper.qml
- 类型：`Item`
- 属性：`property int staggerIndex: 0`
- 方法：`function pulse(count: int)` — 背景 alpha 脉冲
- 入场动画：`Behavior` + `staggerIndex * Theme.staggerDelay` 延迟

### modules/bar/DragOverlay.qml
- 占位文件，标注 `// TODO: implement drag & drop`

### modules/bar/widgets/*.qml
- 占位文件，最小 `Item {}` + `// TODO`

---

## 实现顺序

详见 writing-plans 生成的实现计划。
