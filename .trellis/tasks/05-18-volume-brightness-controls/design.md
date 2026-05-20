# Design: 音量亮度管理及快捷键

## 架构概述

```
┌─────────────────────────────────────────────────────────────┐
│                      niri compositor                         │
│  binds.kdl: XF86Audio* / XF86MonBrightness* / XF86AudioPlay │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Quickshell ShellRoot                       │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │VolumeService │  │BrightnessSvc │  │ MediaService │       │
│  │   (Pipewire) │  │(brightnessctl)│  │  (playerctl) │       │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘       │
│         │                 │                 │                │
│         └─────────────────┼─────────────────┘                │
│                           ▼                                  │
│                   ┌──────────────┐                           │
│                   │  OSD Window  │                           │
│                   │ (Overlay层)  │                           │
│                   └──────────────┘                           │
└─────────────────────────────────────────────────────────────┘
```

## 模块设计

### 1. MediaService (新增)

**职责**: 媒体播放控制，封装 playerctl 命令

**接口**:
```qml
pragma Singleton
Singleton {
    // 播放状态
    readonly property bool playing: false
    readonly property string title: ""
    readonly property string artist: ""

    // 控制方法
    function playPause()    // playerctl play-pause
    function previous()     // playerctl previous
    function next()         // playerctl next
}
```

**实现**:
- 使用 `Process` 执行 playerctl 命令
- 轮询或监听 playerctl 状态变化
- 注册到 `services/qmldir`

### 2. OSD Window (新增)

**职责**: 屏幕中央显示音量/亮度/媒体状态弹窗

**设计**:
- 使用 `PanelWindow` + `overlay` 层级
- 居中显示，宽度固定，高度自适应
- 显示图标 + 数值 + 进度条
- 自动隐藏 (Timer 1.5秒)

**触发机制**:
- 监听 VolumeService/BrightnessService/MediaService 状态变化
- 快捷键触发时显示 OSD

**QML 结构**:
```qml
// modules/osd/OsdWindow.qml
PanelWindow {
    // overlay 层级，不抢焦点
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.keyboardFocus: WlrLayershell.OnDemand

    // 内容
    Column {
        // 图标 + 数值
        Row { ... }
        // 进度条
        Rectangle { ... }
    }

    // 自动隐藏定时器
    Timer { interval: 1500; onTriggered: hide() }
}
```

### 3. 快捷键集成

**方案**: 修改 `~/.config/niri/binds.kdl`

**变更**:
```diff
- XF86AudioRaiseVolume allow-when-locked=true { spawn "qs" "-c" "dymicshell" "ipc" "call" "audio" "volumeUp"; }
+ XF86AudioRaiseVolume allow-when-locked=true { spawn "qs" "-c" "afloat" "ipc" "call" "VolumeService" "setSinkVolume" "+0.05"; }

- XF86AudioLowerVolume allow-when-locked=true { spawn "qs" "-c" "dymicshell" "ipc" "call" "audio" "volumeDown"; }
+ XF86AudioLowerVolume allow-when-locked=true { spawn "qs" "-c" "afloat" "ipc" "call" "VolumeService" "setSinkVolume" "-0.05"; }

- XF86AudioMute allow-when-locked=true { spawn "qs" "-c" "dymicshell" "ipc" "call" "audio" "muteOutput"; }
+ XF86AudioMute allow-when-locked=true { spawn "qs" "-c" "afloat" "ipc" "call" "VolumeService" "toggleSinkMute"; }

- XF86MonBrightnessUp allow-when-locked=true { spawn "qs" "-c" "dymicshell" "ipc" "call" "brightness" "increase"; }
+ XF86MonBrightnessUp allow-when-locked=true { spawn "qs" "-c" "afloat" "ipc" "call" "BrightnessService" "setBrightness" "+0.05"; }

- XF86MonBrightnessDown allow-when-locked=true { spawn "qs" "-c" "dymicshell" "ipc" "call" "brightness" "decrease"; }
+ XF86MonBrightnessDown allow-when-locked=true { spawn "qs" "-c" "afloat" "ipc" "call" "BrightnessService" "setBrightness" "-0.05"; }

+ XF86AudioPlay allow-when-locked=true { spawn "qs" "-c" "afloat" "ipc" "call" "MediaService" "playPause"; }
+ XF86AudioPrev allow-when-locked=true { spawn "qs" "-c" "afloat" "ipc" "call" "MediaService" "previous"; }
+ XF86AudioNext allow-when-locked=true { spawn "qs" "-c" "afloat" "ipc" "call" "MediaService" "next"; }
```

**注意**: 需要确认 Quickshell 的 IPC 调用语法。如果 `qs -c afloat ipc call` 不支持，可能需要：
- 使用 `spawn-sh` 执行复杂命令
- 或在 shell.qml 中注册 IPC 处理器

## 兼容性

- **依赖**: playerctl (媒体播放控制)
- **niri 版本**: 支持 binds.kdl 语法
- **Quickshell**: 当前版本已支持 PanelWindow/overlay

## 回滚方案

1. 备份原始 `~/.config/niri/binds.kdl`
2. 如果新方案有问题，恢复备份并重启 niri
3. MediaService 和 OSD Window 可独立移除，不影响现有功能
