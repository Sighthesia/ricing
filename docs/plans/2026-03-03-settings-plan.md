# 设置系统实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 实现 JsonAdapter + FileView 设置系统，将主题色/尺寸/Bar 行为从硬编码转为用户可持久化配置。

**Architecture:** `SettingsService.qml`（Singleton）持有 JsonAdapter 并通过 FileView 读写 `~/.config/dymicshell/settings.json`；`Colors.qml` 和 `Theme.qml` 的可覆盖属性绑定到 SettingsService.data；组件代码无需改动。

**Tech Stack:** Quickshell (QML), `Quickshell.Io` (JsonAdapter, FileView), QML Singletons (pragma Singleton)

**Design Doc:** `docs/plans/2026-03-03-settings-design.md`

---

## Task 1: 创建 settings-default.json 默认值文件

**Files:**
- Create: `config/settings-default.json`

**Step 1: 创建 JSON 文件**

```json
{
  "appearance": {
    "accentColor": "#7aa2f7",
    "backgroundColor": "#1a1a1a",
    "surfaceColor": "#252525",
    "textColor": "#c0caf5",
    "textMutedColor": "#565f89",
    "borderColor": "#3b4261",
    "cornerRadius": 10,
    "fontFamily": "LXGW WenKai GB Screen",
    "fontMono": "JetBrainsMono Nerd Font",
    "fontSizeBody": 14,
    "fontSizeSmall": 10,
    "fontSizeIcon": 16
  },
  "bar": {
    "height": 36,
    "position": "top",
    "backgroundOpacity": 0.85,
    "padding": 8,
    "widgetSpacing": 6
  },
  "barBehavior": {
    "autoHide": false,
    "autoHideDelay": 500,
    "autoShowDelay": 150
  },
  "animation": {
    "speedFactor": 1.0
  }
}
```

**Step 2: 验证 JSON 合法性**

```bash
jq . config/settings-default.json
```

期望：完整 JSON 打印，无错误。

**Step 3: Commit**

```bash
git add config/settings-default.json
git commit -m "feat(settings): add default settings JSON template"
```

---

## Task 2: 创建 SettingsService.qml

**Files:**
- Create: `services/SettingsService.qml`

**Step 1: 创建文件**

内容如下（严格按照 JsonAdapter 文档，JsonObject 属性必须用 `property JsonObject xxx: JsonObject {}` 语法）：

```qml
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // Public API: SettingsService.data.bar.height etc.
    readonly property alias data: adapter

    // Respect XDG_CONFIG_HOME; fall back to ~/.config/dymicshell/
    readonly property string configDir:
        (Quickshell.env("XDG_CONFIG_HOME") !== ""
            ? Quickshell.env("XDG_CONFIG_HOME")
            : Quickshell.env("HOME") + "/.config")
        + "/dymicshell/"
    readonly property string settingsFile: configDir + "settings.json"

    property bool isLoaded: false

    // Emitted once on initial load, on external file change, and after each debounced write
    signal settingsLoaded
    signal settingsSaved
    signal settingsReloaded

    Component.onCompleted: {
        // Ensure directory exists before FileView attempts to read
        Quickshell.execDetached(["mkdir", "-p", configDir])
        settingsFileView.adapter = adapter
    }

    // Debounce rapid writes (e.g. slider drag) into a single disk flush
    Timer {
        id: saveTimer
        interval: 500
        onTriggered: {
            settingsFileView.writeAdapter()
            root.settingsSaved()
        }
    }

    FileView {
        id: settingsFileView
        path: root.settingsFile
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: saveTimer.restart()
        onLoaded: {
            if (!root.isLoaded) {
                root.isLoaded = true
                root.settingsLoaded()
            } else {
                root.settingsReloaded()
            }
        }
        onLoadFailed: function(error) {
            // First run: generate settings.json from current defaults
            writeAdapter()
        }
    }

    JsonAdapter {
        id: adapter

        property JsonObject appearance: JsonObject {
            property string accentColor:     "#7aa2f7"
            property string backgroundColor: "#1a1a1a"
            property string surfaceColor:    "#252525"
            property string textColor:       "#c0caf5"
            property string textMutedColor:  "#565f89"
            property string borderColor:     "#3b4261"
            property real   cornerRadius:    10
            property string fontFamily:      "LXGW WenKai GB Screen"
            property string fontMono:        "JetBrainsMono Nerd Font"
            property int    fontSizeBody:    14
            property int    fontSizeSmall:   10
            property int    fontSizeIcon:    16
        }

        property JsonObject bar: JsonObject {
            property real   height:            36
            property string position:          "top"
            property real   backgroundOpacity: 0.85
            property real   padding:           8
            property real   widgetSpacing:     6
        }

        property JsonObject barBehavior: JsonObject {
            property bool autoHide:       false
            property int  autoHideDelay:  500
            property int  autoShowDelay:  150
        }

        property JsonObject animation: JsonObject {
            property real speedFactor: 1.0
        }
    }
}
```

**Step 2: 将 SettingsService 注册到 shell.qml 的 import 路径**

检查 `shell.qml` 是否有 `Singletons {}` 块或 `import` 路径配置。  
Quickshell 的 Singleton 通过 `pragma Singleton` + 文件在同一 rootDir 下自动注册，无需手动声明，但需确保文件在 Quickshell 扫描范围内（`services/` 与 `shell.qml` 同目录，已满足）。

**Step 3: 验证 shell 能启动、不报语法错误**

```bash
quickshell -p /path/to/DymicShell 2>&1 | head -20
```

期望：无 `SettingsService` 相关 QML 错误。

**Step 4: Commit**

```bash
git add services/SettingsService.qml
git commit -m "feat(settings): add SettingsService singleton with JsonAdapter"
```

---

## Task 3: 改造 Colors.qml — 绑定到 SettingsService

**Files:**
- Modify: `config/Colors.qml`

**Step 1: 了解现状**

当前 `Colors.qml` 有以下硬编码 `readonly property color`：
- `background`, `surface`, `highlight`, `highlightAlpha`, `text`, `textMuted`, `border`

**Step 2: 改写 Colors.qml**

注意：`JsonAdapter` 中颜色存为 `string`，QML 会自动将 `string` 隐式转换为 `color`，因此直接绑定即可。

```qml
pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    // Colors are driven by SettingsService; defaults below are only used
    // before settings load (typically sub-frame, invisible to users).
    readonly property color background:     SettingsService.data.appearance.backgroundColor
    readonly property color surface:        SettingsService.data.appearance.surfaceColor
    readonly property color highlight:      SettingsService.data.appearance.accentColor
    readonly property real  highlightAlpha: 0.15
    readonly property color text:           SettingsService.data.appearance.textColor
    readonly property color textMuted:      SettingsService.data.appearance.textMutedColor
    readonly property color border:         SettingsService.data.appearance.borderColor

    // FIXME: matugen integration — watch a color JSON file for dynamic palette
}
```

**Step 3: 验证启动无报错**

```bash
quickshell -p /path/to/DymicShell 2>&1 | grep -i "error\|warning" | head -20
```

期望：无 `Colors` 相关绑定错误。

**Step 4: Commit**

```bash
git add config/Colors.qml
git commit -m "feat(settings): bind Colors.qml to SettingsService appearance"
```

---

## Task 4: 改造 Theme.qml — 绑定尺寸/字体/动画速度系数

**Files:**
- Modify: `config/Theme.qml`

**Step 1: 了解现状**

当前 `Theme.qml` 硬编码了以下需要覆盖的属性：
- `fontFamily`, `fontMono`, `fontSizeIcon`, `fontSizeBody`, `fontSizeSmall`
- `cornerRadius`, `barHeight`, `barPadding`, `widgetSpacing`
- `anim.enterDuration`, `anim.exitDuration`, `anim.moveDuration`, `anim.highlightDuration`
- `staggerDelay`

**Step 2: 改写 Theme.qml**

`speedFactor` 作为全局动画速度系数：所有 duration 乘以 `1.0 / speedFactor`（speedFactor=2 → 速度加倍）。

```qml
pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    // Animation tokens — duration scaled by user's speedFactor
    // speedFactor=1.0 → original; >1.0 → faster; <1.0 → slower
    readonly property QtObject anim: QtObject {
        readonly property int enterDuration:
            Math.round(500 / SettingsService.data.animation.speedFactor)
        readonly property int enterType:      Easing.OutElastic
        readonly property real enterAmplitude: 0.8
        readonly property real enterPeriod:   0.4

        readonly property int exitDuration:
            Math.round(220 / SettingsService.data.animation.speedFactor)
        readonly property int exitType: Easing.InExpo

        readonly property int moveDuration:
            Math.round(320 / SettingsService.data.animation.speedFactor)
        readonly property int moveType: Easing.InOutCubic

        readonly property int highlightDuration:
            Math.round(180 / SettingsService.data.animation.speedFactor)
        readonly property int highlightType: Easing.OutQuad
    }

    readonly property int staggerDelay:
        Math.round(40 / SettingsService.data.animation.speedFactor)

    // Typography — bound to settings
    readonly property string fontFamily:  SettingsService.data.appearance.fontFamily
    readonly property string fontMono:    SettingsService.data.appearance.fontMono
    readonly property int fontSizeIcon:   SettingsService.data.appearance.fontSizeIcon
    readonly property int fontSizeBody:   SettingsService.data.appearance.fontSizeBody
    readonly property int fontSizeSmall:  SettingsService.data.appearance.fontSizeSmall

    // Dimensions — bound to settings
    readonly property real cornerRadius:  SettingsService.data.appearance.cornerRadius
    readonly property real barHeight:     SettingsService.data.bar.height
    readonly property real barPadding:    SettingsService.data.bar.padding
    readonly property real widgetPadding: 12        // not user-facing, keep hardcoded
    readonly property real widgetSpacing: SettingsService.data.bar.widgetSpacing
    readonly property real iconPadding:   4         // not user-facing, keep hardcoded

    // Drag feedback — visual-only, not user-facing
    readonly property real dragScale:    1.05
    readonly property real dragOpacity:  0.9
    readonly property int pulseInterval: 3000
}
```

**Step 3: 验证启动无报错**

```bash
quickshell -p /path/to/DymicShell 2>&1 | grep -i "error\|warning" | head -20
```

**Step 4: Commit**

```bash
git add config/Theme.qml
git commit -m "feat(settings): bind Theme.qml dimensions/fonts/animation to SettingsService"
```

---

## Task 5: 手动集成测试

**Step 1: 启动 shell，确认 settings.json 自动生成**

```bash
ls -la ~/.config/dymicshell/settings.json
cat ~/.config/dymicshell/settings.json
```

期望：文件存在，内容与 `config/settings-default.json` 一致。

**Step 2: 修改颜色，验证热重载**

```bash
# 将高亮色改为红色
jq '.appearance.accentColor = "#ff0000"' ~/.config/dymicshell/settings.json > /tmp/s.json && mv /tmp/s.json ~/.config/dymicshell/settings.json
```

期望：Bar 高亮色立即变为红色，无需重启 shell。

**Step 3: 修改 Bar 高度，验证热重载**

```bash
jq '.bar.height = 48' ~/.config/dymicshell/settings.json > /tmp/s.json && mv /tmp/s.json ~/.config/dymicshell/settings.json
```

期望：Bar 高度立即更新。

**Step 4: 恢复默认**

```bash
cp config/settings-default.json ~/.config/dymicshell/settings.json
```

**Step 5: 最终 Commit**

```bash
git add -A
git commit -m "feat(settings): complete settings system integration and smoke test"
```

---

## 注意事项

1. **JsonAdapter 声明语法**：`property JsonObject xxx: JsonObject {}` 中，`JsonObject` 必须作为 property 类型和值类型同时出现。参考官方文档示例。
2. **颜色类型**：JsonAdapter 不直接支持 `color` 类型，使用 `string`，QML 自动隐式转换。
3. **SettingsService 自动注册**：Quickshell 扫描 `rootDir` 下的所有 `.qml` 文件，`pragma Singleton` 文件自动注册，可在任意地方直接引用文件名（`SettingsService.data`）。
4. **BarLayoutService 的 `position` 字段**：当前 BarLayoutService 不使用 position，BarWindow 硬编码在顶部。后续可绑定 `SettingsService.data.bar.position`，不在本计划范围。
