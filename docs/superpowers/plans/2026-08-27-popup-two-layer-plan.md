# Popup Two-Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将全部 bar 弹出（托盘一/二级、音量/亮度、日历、媒体、通知、BarContextMenu）统一为贴栏的直角垂直两层：顶部 `settingsRail` 标题层贴顶栏、底部 `settingsPanel` 内容层，复用设置面板视觉。

**Architecture:** 新增共享 `BarPopupFrame` 封装标题层与内容槽；各弹出以 frame 为根重写，外层仍由 `BarPopupHost` 的 `scale+translate` 揭示驱动。托盘二级表面亦以同 frame 重写，标题取父条目文本，走廊桥、纵轴锁、高度保持等既有契约保持不变。

**Tech Stack:** QML (QtQuick / Quickshell.Wayland / QsMenuOpener), LazerTheme / MotionTokens, BarPopupService+Host

## Global Constraints

- 复用 `LazerTheme.settingsRail / settingsPanel / popupBorder / divider / textPrimary`，标题 14 DemiBold，标题层高 48，分割线 1，主表面圆角 0，clip。
- 标题文本 `ElideRight`，图标 16 可选。
- 一/二级菜单均使用标题层（二级标题为父条目 `text`）。
- 改造 `BarPopupHost` 为贴栏、触发组件边缘对齐、单轴垂直揭示；保留输入遮罩与 `BarPopupService` 状态机。

---

### Task 1: 共享框架 BarPopupFrame

**Files:**
- Create: `modules/bar/BarPopupFrame.qml`
- Test: 手动 `qmllint modules/bar/BarPopupFrame.qml` + `qs -p shell.qml` 无 ERROR（无专用 QtTest）

**Interfaces:**
- Consumes: `LazerTheme`, `MotionTokens`
- Produces: `BarPopupFrame { property string title; property string iconSource; default property alias contentData; readonly property alias contentItem; implicitHeight = header+divider+content }` 供 Task 2-7 复用

- [ ] **Step 1: 创建 BarPopupFrame**

```qml
// modules/bar/BarPopupFrame.qml
import QtQuick
import "../lazerbar"
Rectangle {
    id: root
    property string title: ""
    property string iconSource: ""
    property int headerHeight: 48
    default property alias contentData: contentSlot.data
    readonly property alias contentItem: contentSlot
    radius: 10; color: LazerTheme.settingsPanel
    border.width: 1; border.color: LazerTheme.popupBorder
    clip: true
    // header + divider + content
}
```
完整实现：外层即自身；头部 `Rectangle color: settingsRail height: headerHeight` 顶圆角跟随外层，内部 Row(icon 16 + Text 14 DemiBold elide) 左右 16 边距；底部 `Rectangle height:1 color: divider`；内容 `Item { anchors.top: header.bottom+divider }` 承载 `contentSlot`。

- [ ] **Step 2: 校验**

Run: `/usr/lib/qt6/bin/qmllint modules/bar/BarPopupFrame.qml`

Expected: 无新增语义错误（仅允许 unqualified 警告）。

- [ ] **Step 3: Commit**

```bash
git add modules/bar/BarPopupFrame.qml
git commit -m "feat(bar): add BarPopupFrame sharing settings panel language"
```

---

### Task 2: 迁移 BarSliderPopup（Volume/Brightness）

**Files:**
- Modify: `modules/bar/BarSliderPopup.qml:1-123`
- Test: `qmllint` + hover Volume/Brightness 验证标题层贴顶

**Interfaces:**
- Consumes: `BarPopupFrame` (Task 1)
- Produces: 无

- [ ] **Step 1: 以 frame 为根重写**

保留 props `title/iconSource/value/showMute/muted` 与信号；根改为 `BarPopupFrame { title: root.title; iconSource: root.iconSource }`，内容区仅保留 `LazerSettingsSlider` 与静音块，移除原内部标题 Row。百分比仍显示于标题层右侧（frame 标题扩展 slot 或标题 `title + percent` 拼接）。

- [ ] **Step 2: 校验**

Run: `/usr/lib/qt6/bin/qmllint modules/bar/BarSliderPopup.qml`
Run: `timeout 12 qs -p shell.qml 2>&1 | grep -cE ERROR` 预期 0

- [ ] **Step 3: Commit**

```bash
git add modules/bar/BarSliderPopup.qml
git commit -m "feat(bar): slider popups use two-layer frame"
```

---

### Task 3: 迁移 BarCalendarPopup

**Files:**
- Modify: `modules/bar/BarCalendarPopup.qml:1-148`
- Test: 同 Task 2

**Interfaces:**
- Consumes: `BarPopupFrame`

- [ ] **Step 1: 重写**

根改为 `BarPopupFrame { title: "Calendar" }` 或 `Clock`，内容区保留原“年 月 + 翻月按钮、星期条、Grid 42”结构，间距与边距保持；原外层 Rectangle 属性迁移至 frame。

- [ ] **Step 2: 校验** `qmllint` + `qs -p` 无 ERROR

- [ ] **Step 3: Commit**

```bash
git add modules/bar/BarCalendarPopup.qml
git commit -m "feat(bar): calendar popup uses two-layer frame"
```

---

### Task 4: 迁移 BarMediaPopup

**Files:**
- Modify: `modules/bar/BarMediaPopup.qml:1-168`

**Interfaces:**
- Consumes: `BarPopupFrame`

- [ ] **Step 1: 重写**

`BarPopupFrame { title: "Now Playing" }`（或 `Media`），内容区保留曲名/歌手/进度条/时间/操作行，原外层 Rectangle 移除。

- [ ] **Step 2: 校验**

- [ ] **Step 3: Commit**

```bash
git add modules/bar/BarMediaPopup.qml
git commit -m "feat(bar): media popup uses two-layer frame"
```

---

### Task 5: 迁移 BarNotificationsPopup

**Files:**
- Modify: `modules/bar/BarNotificationsPopup.qml:1-139`

**Interfaces:**
- Consumes: `BarPopupFrame`

- [ ] **Step 1: 重写**

`BarPopupFrame { title: "Notifications" }`，内容区保留 DND 与 Mark all read 两行，移除原外层。

- [ ] **Step 2: 校验**

- [ ] **Step 3: Commit**

```bash
git add modules/bar/BarNotificationsPopup.qml
git commit -m "feat(bar): notifications popup uses two-layer frame"
```

---

### Task 6: 迁移 BarTrayMenu（一级与二级）

**Files:**
- Modify: `modules/bar/BarTrayMenu.qml:1-571`
- Test: 托盘 hover 触发一/二级展开，验证走廊桥、纵轴锁、高度平滑与退场仍有效

**Interfaces:**
- Consumes: `BarPopupFrame`

- [ ] **Step 1: 一级重写**

外层 `Rectangle` 改为 `BarPopupFrame`，标题绑定 `payload.title || payload.tooltipTitle || payload.id || "Tray"` 与 `payload.icon`（若可解析）。内容区为现有 `Flickable contentFlickable`，`implicitHeight = headerHeight+1 + naturalHeight`；保留 `settledHeight/naturalHeight/Behavior on implicitHeight`、`onEntriesChanged/onPayloadChanged`、submenu 状态机与 `submenuBridge/menuFace` 走廊与遮挡逻辑（`menuFace` 调整为仅遮内容区顶部或保留整体 face 但置于 header 下）。

- [ ] **Step 2: 二级重写**

`submenuSurface` 由 `Rectangle` 改为 `BarPopupFrame`（或内嵌 frame），标题取 `submenuEntry.text`，高度来源改为 `contentColumn.implicitHeight + headerHeight+1`，保持 `heldHeight/rawColumnHeight/submenuNaturalHeight` 异步保持与 `frozenX/Y`、`enterTravel`、变形 `transform`。

- [ ] **Step 3: 校验**

Run: `qmllint modules/bar/BarTrayMenu.qml`
Run: `timeout 12 qs -p shell.qml 2>&1 | grep -cE ERROR`

- [ ] **Step 4: Commit**

```bash
git add modules/bar/BarTrayMenu.qml
git commit -m "feat(bar): tray menu one- and two-level use two-layer frame"
```

---

### Task 7: 统一 BarContextMenu 顶部标题

**Files:**
- Modify: `modules/bar/BarContextMenu.qml:1-498`

**Interfaces:**
- Consumes: `BarPopupFrame` 视觉（或复用现有 headerSlot 提升）

- [ ] **Step 1: 叠加 frame 标题**

在现有 `railWidth+contentWidth` 外层顶部加入 48 高的 `settingsRail` 标题层显示 `selectedEntry.label`（复用 BarPopupFrame 标题样式或直接内联 header+divider），rail 与 contentArea 的 `anchors.top` 下移至标题底沿，圆角与边框保持外层统一；`headerSlot` 移除或降为二级分区标题。

- [ ] **Step 2: 校验**

Run: `qmllint modules/bar/BarContextMenu.qml`

- [ ] **Step 3: Commit**

```bash
git add modules/bar/BarContextMenu.qml
git commit -m "feat(bar): context menu header aligns to two-layer language"
```

---

## Self-Review

- Spec 覆盖：6 类弹出 + 一/二级 均有任务；共享框架与令牌在 Task 1 固化。
- 占位扫描：无 TBD/TODO，均为具体代码与校验命令。
- 类型一致：frame 的 `title/iconSource/contentData` 在后续任务中按同名使用；高度公式保持一致。
