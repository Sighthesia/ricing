# DymicShell 设置 UI 面板设计文档

**日期**：2026-03-03  
**范围**：设置 UI 面板（颜色选择、Slider、Toggle、位置选择）  
**前提**：设置系统（SettingsService）已实现（见 2026-03-03-settings-design.md）

---

## 一、目标

在 Bar 的 SettingsToggle 基础上增加一个 Tab 切换面板，允许用户在 GUI 中直接修改颜色/尺寸/行为，修改立即通过 SettingsService 持久化写入磁盘。

---

## 二、交互状态机

```
Normal
  └──[单击齿轮]──► PanelOpen（展示 Tab 选择条）
                    ├─ Tab[布局]──► LayoutMode（DragOverlay 可见）
                    └─ Tab[设置]──► ConfigMode（SettingsPanel 可见）
  ◄──[再次单击 / Esc]──
```

### 状态字段（BarLayoutService）

```
property bool settingsMode (computed alias, backward compatible)
    readonly property bool settingsMode: activePanel === "layout"

property string activePanel: "none"   // "none" | "layout" | "config"
```

保留 `settingsMode` 作计算属性，令所有现有 DragOverlay/BarSection/BarWidgetWrapper 代码**无需改动**。

---

## 三、文件架构

```
shell.qml                              ← 挂载 SettingsPanel
modules/bar/
  SettingsPanelWindow.qml             ← 新建：PanelWindow 容器
  settings/
    SettingsPanelContent.qml          ← 新建：面板内容（三个 Section Row）
    ColorSection.qml                  ← 新建：颜色控件
    SliderSection.qml                 ← 新建：Slider 行
    BehaviorSection.qml               ← 新建：Toggle + 位置选择
  widgets/
    SettingsToggle.qml                ← 修改：三态切换 + Tab 条显示
services/
  BarLayoutService.qml                ← 修改：activePanel + computed settingsMode
```

---

## 四、SettingsPanelWindow 设计

- **类型**：`PanelWindow`，`WlrLayershell.layer: WlrLayer.Overlay`
- **可见性**：`visible: BarLayoutService.activePanel === "config"`
- **大小**：`implicitWidth: 320`，高度由内容自适应
- **定位**：`anchors.top: true; anchors.right: true`，面板出现在屏幕右上角（紧贴 Bar 右侧）
- **背景**：`Colors.background` + `Theme.cornerRadius`，轻微投影
- **动画**：`opacity` 0→1，`scale` 0.95→1.0，`OutCubic 220ms`

---

## 五、控件布局（SettingsPanelContent）

```
Section: 外观
├ ColorRow(label="强调色", key="appearance.accentColor")
├ ColorRow(label="背景色", key="appearance.backgroundColor")
└ ColorRow(label="表面色", key="appearance.surfaceColor")

Section: Bar
├ SliderRow(label="高度",     min=24, max=60, step=1, binding=SettingsService.data.bar.height)
├ SliderRow(label="透明度",   min=0,  max=1,  step=0.05, binding=SettingsService.data.bar.backgroundOpacity)
└ SliderRow(label="动画速度", min=0.2,max=3.0,step=0.1,  binding=SettingsService.data.animation.speedFactor)

Section: 行为
├ OptionRow(label="位置", options=["顶部","底部"], binding=SettingsService.data.bar.position)
└ ToggleRow(label="自动隐藏", binding=SettingsService.data.barBehavior.autoHide)
```

### ColorRow 控件设计

```
[label]          [████] [████] [████]  ← 3 preset swatches
                 [#7aa2f7    ↵]         ← hex文本框，Enter确认
```

预设颜色由每个颜色值内置 3 个 swatch，用户也可手动输入 hex。输入格式校验：`/^#[0-9a-fA-F]{6}$/`。

---

## 六、SettingsToggle 改造

### Tab 条叠加在 Bar 末端

当 `activePanel !== "none"` 时，在 SettingsToggle 左侧渐显一个 Tab 行（Inline，不新建窗口）：

```
 [布局]  [设置]  [⚙]
```

- Tab 用 `Row` + 两个 clickable `Rectangle` 实现，嵌入 BarWidgetWrapper 内
- 选中 Tab 用 `Colors.highlight` 背景，未选用 `Colors.surface`
- 点击齿轮：`activePanel = activePanel !== "none" ? "none" : "layout"` （首次打开默认 layout Tab）

---

## 七、向后兼容保证

| 组件 | 当前代码 | 变化 |
|------|----------|------|
| `DragOverlay.qml` | `visible: BarLayoutService.settingsMode` | 无需改 |
| `BarSection.qml` | `enabled: BarLayoutService.settingsMode` | 无需改 |
| `BarWidgetWrapper.qml` | `_showSettingsOutline: BarLayoutService.settingsMode` | 无需改 |
| `SettingsToggle.qml` | `BarLayoutService.settingsMode = !settingsMode` | 改为 `activePanel` 逻辑 |

---

## 八、不在本次范围内

- 颜色轮/调色板（复杂度过高）
- 字体选择器（系统字体枚举无标准 QML API）
- 实时预览动画速度（加改动量）
