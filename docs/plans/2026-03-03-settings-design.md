# DymicShell 设置系统设计文档

**日期**：2026-03-03  
**范围**：外观 Token、Bar 外观、Bar 行为、动画速度系数  
**参考**：noctalia-dev/noctalia-shell（JsonAdapter + FileView 模式）

---

## 一、目标

为 DymicShell 提供一个用户可配置、磁盘持久化的设置系统，满足：

1. 用户可通过编辑 `~/.config/dymicshell/settings.json` 直接改配置，修改后立即热重载生效。
2. 组件代码零改动：现有组件继续使用 `Theme.xxx`，Theme.qml 内部绑定到 SettingsService。
3. 防止高频 IO：slider 操作等导致的连续属性变更，通过 500ms 防抖定时器批量写入磁盘。
4. 首次安装自动生成 `settings.json`，避免空文件报错。

---

## 二、架构

### 组件职责

| 文件 | 职责 |
|------|------|
| `services/SettingsService.qml` | 新建 Singleton；JsonAdapter + FileView 数据层；防抖写入；三个信号 |
| `config/Theme.qml` | 已有；可覆盖属性改为绑定到 `SettingsService.data.xxx`；动画 token 通过 `speedFactor` 缩放 |
| `config/settings-default.json` | 新建；默认值快照，作为文档和首次写入的来源 |

### 数据流

```
~/.config/dymicshell/settings.json
       ↕  FileView (watchChanges + writeAdapter)
 SettingsService.data  (JsonAdapter 树)
       ↕  QML 属性绑定 (binding)
   Theme.qml 属性
       ↕  所有 Bar 组件
```

### 依赖关系

```
shell.qml
  └── SettingsService (services/)  ← 最先初始化
  └── Theme (config/)              ← 绑定 SettingsService.data
  └── BarLayoutService (services/) ← 读 SettingsService.data.bar.position
  └── BarWindow / BarContent ...
```

---

## 三、设置 Schema

### `appearance` 组（外观 Token）

| 键 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `accentColor` | string | `"#7aa2f7"` | 高亮色、脉冲色 |
| `backgroundColor` | string | `"#1a1a1a"` | Bar 背景 |
| `surfaceColor` | string | `"#252525"` | widget hover 背景 |
| `textColor` | string | `"#c0caf5"` | 主文字色 |
| `textMutedColor` | string | `"#565f89"` | 次要文字色 |
| `borderColor` | string | `"#3b4261"` | 投放区边框（设置模式） |
| `cornerRadius` | real | `10` | 全局圆角半径 |
| `fontFamily` | string | `"LXGW WenKai GB Screen"` | 正文字体 |
| `fontMono` | string | `"JetBrainsMono Nerd Font"` | 等宽字体 |
| `fontSizeBody` | int | `14` | 正文字号 |
| `fontSizeSmall` | int | `10` | 小字号 |
| `fontSizeIcon` | int | `16` | 图标字号 |

### `bar` 组（Bar 外观）

| 键 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `height` | real | `36` | Bar 高度 (px) |
| `position` | string | `"top"` | `"top"` \| `"bottom"` |
| `backgroundOpacity` | real | `0.85` | Bar 背景透明度 0~1 |
| `padding` | real | `8` | 内边距 |
| `widgetSpacing` | real | `6` | widget 间距 |

### `barBehavior` 组（Bar 行为）

| 键 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `autoHide` | bool | `false` | 是否启用自动隐藏 |
| `autoHideDelay` | int | `500` | 鼠标离开后多少 ms 隐藏 |
| `autoShowDelay` | int | `150` | 鼠标进入后多少 ms 显示 |

### `animation` 组（动画参数）

| 键 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `speedFactor` | real | `1.0` | 全局动画速度系数；Theme 中所有 duration 除以此值 |

---

## 四、SettingsService.qml 详细设计

```qml
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  // Public API: components read settings via SettingsService.data.xxx.yyy
  readonly property alias data: adapter

  // Config path: respects XDG_CONFIG_HOME
  readonly property string configDir:
    (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config")
    + "/dymicshell/"
  readonly property string settingsFile: configDir + "settings.json"

  property bool isLoaded: false

  signal settingsLoaded
  signal settingsSaved
  signal settingsReloaded

  Component.onCompleted: {
    // Ensure config directory exists before FileView reads
    Quickshell.execDetached(["mkdir", "-p", configDir])
    settingsFileView.adapter = adapter
  }

  // Debounce: batch rapid writes (e.g. sliders) into a single disk write
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
      // Fresh install: generate settings.json from current defaults
      writeAdapter()
    }
  }

  JsonAdapter {
    id: adapter

    property JsonObject appearance: JsonObject { ... }
    property JsonObject bar: JsonObject { ... }
    property JsonObject barBehavior: JsonObject { ... }
    property JsonObject animation: JsonObject { ... }
  }
}
```

---

## 五、Theme.qml 改造策略

只有**可被用户覆盖**的属性改为绑定，纯计算/动画参数保留 `readonly`：

```qml
// 颜色 token → 全部绑定
readonly property color colorAccent:     SettingsService.data.appearance.accentColor
readonly property color colorBackground: SettingsService.data.appearance.backgroundColor
readonly property color colorSurface:    SettingsService.data.appearance.surfaceColor
readonly property color colorText:       SettingsService.data.appearance.textColor
readonly property color colorTextMuted:  SettingsService.data.appearance.textMutedColor
readonly property color colorBorder:     SettingsService.data.appearance.borderColor

// 尺寸 token → 绑定
readonly property real cornerRadius: SettingsService.data.appearance.cornerRadius
readonly property real barHeight:    SettingsService.data.bar.height
readonly property real barPadding:   SettingsService.data.bar.padding
readonly property real widgetSpacing: SettingsService.data.bar.widgetSpacing

// 字体 → 绑定
readonly property string fontFamily: SettingsService.data.appearance.fontFamily
readonly property string fontMono:   SettingsService.data.appearance.fontMono
readonly property int fontSizeBody:  SettingsService.data.appearance.fontSizeBody
readonly property int fontSizeSmall: SettingsService.data.appearance.fontSizeSmall
readonly property int fontSizeIcon:  SettingsService.data.appearance.fontSizeIcon

// 动画 → duration 乘以 speedFactor，保持 token 命名不变
readonly property int staggerDelay: Math.round(40 / SettingsService.data.animation.speedFactor)
readonly property QtObject anim: QtObject {
  readonly property int enterDuration: Math.round(500 / SettingsService.data.animation.speedFactor)
  // ... 其他 token 同理
}
```

**已有组件无需任何改动**。

---

## 六、文件变化热重载

`FileView.watchChanges: true` + `onFileChanged: reload()` 实现：用户用文本编辑器保存 `settings.json` 后，FileView 检测到变化，重新加载 JsonAdapter，绑定的属性自动更新，BarWindow 等组件实时响应。

---

## 七、新增文件清单

| 文件 | 状态 | 说明 |
|------|------|------|
| `services/SettingsService.qml` | 新建 | 设置系统核心 |
| `config/settings-default.json` | 新建 | 默认值文档 + 模板 |
| `config/Theme.qml` | 修改 | 属性绑定到 SettingsService |

---

## 八、不在本次范围内

- 设置 UI 面板（交互界面）
- 迁移/版本化（`settingsVersion` 字段）
- 多显示器覆盖
- 插件级别设置
