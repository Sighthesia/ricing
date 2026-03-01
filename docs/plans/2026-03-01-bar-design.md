# DymicShell Bar 设计文档

**日期：** 2026-03-01  
**状态：** 已批准，待实现  
**合成器：** Niri  
**框架：** QuickShell v0.2.1 (QML)  

---

## 设计目标

全局统一使用非线性动画（Elastic、Exponential）并以错位延迟叠加形成复杂动画；用高亮闪烁提示；
每个组件共享相同的动画和高亮效果，形成和谐画面风格。

**第一阶段范围：** Bar 窗口 + 设置模式开关组件（SettingsToggle）。

---

## 一、文件结构

```
shell.qml
config/
  Theme.qml                 # Singleton：颜色、动画曲线、间距 token
  Palette.qml               # 色板常量（暗色纯色极简）
services/
  BarLayoutService.qml      # Singleton：持久化 JSON 布局模型 + settingsMode 状态
  NiriService.qml           # Singleton：Niri IPC 工作区数据（Process + Socket）
bar/
  BarWindow.qml             # PanelWindow + WlrLayershell（顶部 exclusive zone）
  BarContent.qml            # 三段容器（Left / Center / Right）
  BarSection.qml            # 单段：包含 left/center/right 三对齐子行
  BarWidgetWrapper.qml      # 通用 wrapper：动画合约 + 高亮 pulse() 方法
  DragOverlay.qml           # 设置模式全宽浮动层（z:999）
  widgets/
    SettingsToggle.qml      # 设置模式开关
    Clock.qml               # 时钟（示例占位）
    WorkspaceWidget.qml     # Niri 工作区（示例占位）
```

---

## 二、动画系统（Theme.qml）

### 动画 Token

| Token | 曲线 | duration | 用途 |
|---|---|---|---|
| `Theme.anim.enter` | `Easing.OutElastic` (amplitude=0.8, period=0.4) | 500ms | 入场、设置模式 ON |
| `Theme.anim.exit` | `Easing.InExpo` | 220ms | 离场、模式 OFF |
| `Theme.anim.move` | `Easing.InOutCubic` | 320ms | 位置移动、拖放飞回 |
| `Theme.anim.highlight` | `Easing.OutQuad` | 180ms | 高亮脉冲单次 |

### 错位延迟规则

每个 `BarWidgetWrapper` 持有 `property int staggerIndex`。
入场动画 delay = `staggerIndex * 40ms`。
效果：Bar 从左到右波浪式弹入。

### 高亮脉冲 API

`BarWidgetWrapper` 暴露 `function pulse(count: int)` 方法，内部使用
`SequentialAnimation` 将背景色 alpha 在 0 → `Theme.color.highlightAlpha` → 0 循环 count 次。

---

## 三、Bar 布局结构

### 窗口层

```
BarWindow (PanelWindow)
  WlrLayershell { layer: WlrLayer.Top; exclusiveZone: barHeight }
  └── BarContent
```

### BarContent — 三段容器

```
BarContent (RowLayout, anchors.fill)
├── BarSection [role="left"]
│   ├── AlignLeft subRow
│   ├── AlignCenter subRow
│   └── AlignRight subRow
├── Item { Layout.fillWidth: true }    ← 弹性间隔
├── BarSection [role="center"]
│   ├── AlignLeft subRow
│   ├── AlignCenter subRow           ← Clock 默认位置
│   └── AlignRight subRow
├── Item { Layout.fillWidth: true }
└── BarSection [role="right"]
    ├── AlignLeft subRow
    ├── AlignCenter subRow
    └── AlignRight subRow
```

### Widget 描述符结构（JSON）

```json
{
  "id": "clock",
  "section": "center",
  "alignment": "center",
  "order": 0,
  "enabled": true
}
```

默认布局：
```json
[
  { "id": "settingsToggle", "section": "left",   "alignment": "left",   "order": 0, "enabled": true },
  { "id": "clock",          "section": "center", "alignment": "center", "order": 0, "enabled": true }
]
```

---

## 四、BarLayoutService

**类型：** `Singleton`（`pragma Singleton`）

**属性：**
- `property bool settingsMode: false`
- `property ListModel layoutModel` — 内存中的可变布局模型
- `PersistentProperties` — 将 `layoutModel` JSON 序列化持久化到磁盘

**方法：**
- `function moveWidget(id, toSection, toAlignment, toOrder)` — 更新模型并触发持久化
- `function resetLayout()` — 恢复默认布局

---

## 五、设置模式 & 拖拽覆盖层（DragOverlay）

### 状态机

```
Normal ──[SettingsToggle.onClicked]──► SettingsMode
         ← Bar 背景轻微 dim + 三段投放区虚线边框显现
SettingsMode ──[再次点击 / Esc]──► Normal
         → 所有 widget 以 InOutCubic 飞回
```

### SettingsMode 激活流程

1. `BarLayoutService.settingsMode = true`
2. 所有 `BarWidgetWrapper` 自身 opacity → 0.25（`InExpo` 220ms）
3. `DragOverlay` 按各 widget 的 `mapToItem(barContent, ...)` 坐标在覆盖层实例化"拖拽副本"
4. 副本以 `OutElastic` 从占位符坐标弹出放大（scale 0.8 → 1.0）
5. 三段 section 投放区显示虚线边框 + `pulse(2)` 高亮

### 拖拽交互细节

- `DragHandler` 附加到每个浮动副本
- 拖拽中：scale 轻微放大到 1.05，当前 hover 的投放区高亮
- 松手：`mapFromItem` 命中检测目标 section + alignment
- 命中后：副本以 `InOutCubic` 飞至新占位符坐标
- 动画完成后：更新 `BarLayoutService.moveWidget()`，销毁副本
- `BarWidgetWrapper` 从新的模型位置渲染，opacity → 1（`OutElastic`）

---

## 六、SettingsToggle 组件

### 外观

纯色图标按钮，使用 Material Symbols `settings` 图标（`⚙`），
由 `BarWidgetWrapper` 包裹提供统一动画。

### 状态视觉编码

| 状态 | 图标旋转 | 背景 alpha | 特殊效果 |
|---|---|---|---|
| Normal（idle） | 0° | 0（透明） | hover → 背景 alpha 渐显 0.08 |
| Normal（hover） | 0° | 0.08 | — |
| SettingsMode 激活 | 45° | 0.15（高亮色） | 每 3s 触发一次 `pulse(1)` |

### 动画时序

**进入 SettingsMode：**
1. 背景 alpha: 0 → 0.15，`OutExpo` 180ms
2. 图标 rotation: 0° → 45°，`OutElastic` 500ms（delay=0）

**退出 SettingsMode：**
1. 图标 rotation: 45° → 0°，`InExpo` 220ms
2. 背景 alpha: 0.15 → 0，`InExpo` 180ms（delay=40ms）

### 交互

- 单击：`BarLayoutService.settingsMode = !BarLayoutService.settingsMode`
- 键盘 `Esc`（全局）：强制退出 SettingsMode

---

## 七、Niri IPC 方案

QuickShell 无原生 Niri 模块，通过以下方式集成：

```qml
// NiriService.qml (Singleton)
Process {
  id: niriProcess
  command: ["niri", "msg", "--json", "workspaces"]
  // 定期 poll 或监听 niri msg event-stream
}
```

- 工作区列表：周期性 `niri msg --json workspaces`（`Timer` interval=500ms）
- 事件监听：`niri msg event-stream` 通过 `Process` stdout 流解析 JSON 行

此方案不影响 Bar/动画架构，仅影响 `WorkspaceWidget` 内部数据绑定。

---

## 八、色彩 Token（Palette.qml）

```
background:        #1a1a1a   // Bar 背景
surface:           #252525   // widget 背景（hover 状态）
highlight:         #7aa2f7   // 高亮蓝（脉冲色）
highlightAlpha:    0.15
text:              #c0caf5
textMuted:         #565f89
border:            #3b4261   // 设置模式投放区边框
```

---

## 实现顺序（将在 writing-plans 中细化）

1. `Palette.qml` + `Theme.qml`（token 定义，无 UI）
2. `BarLayoutService.qml`（模型 + 持久化，无 UI）
3. `BarWindow.qml` + `BarContent.qml`（窗口骨架，空白）
4. `BarSection.qml` + `BarWidgetWrapper.qml`（布局 + 动画合约）
5. `SettingsToggle.qml`（第一个组件，验证整个动画系统）
6. `DragOverlay.qml`（设置模式核心交互）
7. `NiriService.qml` + `WorkspaceWidget.qml`（数据层）
8. `Clock.qml` 及其他占位组件
