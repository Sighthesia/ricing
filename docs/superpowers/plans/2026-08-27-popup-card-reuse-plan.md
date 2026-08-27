# Popup Card Reuse Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将全部 bar 弹出统一为两张独立直角卡片（headerCard + contentCard），复用设置面板的 surface/卡片配方与 500+200ms 错位时序。

**Architecture:** `BarPopupFrame` 由单 `Rectangle` 重构为固定 `Item` 承载两张兄弟 `Rectangle` 卡片，各自绑定 `BarPopupMotion.headerProgress/contentProgress/offset`；各弹出以 frame 为根或同构双卡重写，`BarPopupHost` 保持单 `deformProgress` 驱动与固定几何；行卡片统一为 `radius 6 / settingsCardHover / accent 1.5 / clickFlash` 配方。

**Tech Stack:** QML (QtQuick / Quickshell / QsMenuOpener), LazerTheme / MotionTokens, BarPopupService+Host, BarPopupMotion.js

## Global Constraints

- 复用 `LazerTheme.settingsRail / settingsPanel / settingsSection / settingsCard / settingsCardHover / settingsAccent / divider / textPrimary / textMuted` 与 `MotionTokens.settingsSidebarFade 500 / settingsContentDelay 200 / settingsSidebarStagger 40 / slow 240 / fast 100 / pressScale 0.985 / clickFlashOpacity 0.3 / clickFlashDuration 800 / clickFlashEasing OutQuint`，禁止魔法数。
- 形状：外层直角 `radius 0`，卡片 `radius 6`，分割线 `1px divider`，无 `popupBorder`。
- 动效：进入 `OutQuint 700ms`，退出 `InQuad 700ms`，标题立即、内容延迟 200ms，位移 12px/14px，受 `reducedMotion` 门控。
- 根固定、`Item` owner，不对 `Loader` 宽高做 `Behavior`，不使用 `Scale`。

---

### Task 1: 共享时序与双卡框架 BarPopupFrame

**Files:**
- Modify: `modules/bar/BarPopupMotion.js:1-25`
- Modify: `modules/bar/BarPopupFrame.qml:1-138`
- Test: `qmllint modules/bar/BarPopupFrame.qml`

**Interfaces:**
- Consumes: `LazerTheme`, `MotionTokens`
- Produces: `BarPopupMotion.headerProgress(value,total,fade)` / `contentProgress(value,total,delay,fade)` / `offset(value,distance)`；`BarPopupFrame { property string title; property string iconSource; property string extraText; property int headerHeight; property real revealProgress; readonly int revealDuration; readonly real headerProgress; readonly real contentProgress; default property alias contentData; readonly alias contentItem }`，内部 `headerCard/contentCard/divider` 双层暴露。

- [ ] **Step 1: 校验 BarPopupMotion 契约**

```js
// modules/bar/BarPopupMotion.js 已满足契约，仅需确认导出
.pragma library
function progress(value,start,end){ /* existing */ }
function headerProgress(value,totalDuration,fadeDuration){ return progress(value,0, Number(fadeDuration)/Number(totalDuration)) }
function contentProgress(value,totalDuration,delay,fadeDuration){ var s=Number(delay)/Number(totalDuration); return progress(value,s,s+Number(fadeDuration)/Number(totalDuration)) }
function offset(value,distance){ return Number(distance)*(1-Math.max(0,Math.min(1,Number(value)))) }
```

- [ ] **Step 2: 重构 BarPopupFrame 为双卡 Item**

```qml
// modules/bar/BarPopupFrame.qml
import QtQuick
import "../lazerbar"
import "BarPopupMotion.js" as PopupMotion
Item {
    id: root
    property string title: ""
    property string iconSource: ""
    property string extraText: ""
    property int headerHeight: 48
    property real revealProgress: 1
    readonly property int revealDuration: MotionTokens.settingsSidebarFade + MotionTokens.settingsContentDelay
    readonly property real headerProgress: PopupMotion.headerProgress(revealProgress, revealDuration, MotionTokens.settingsSidebarFade)
    readonly property real contentProgress: PopupMotion.contentProgress(revealProgress, revealDuration, MotionTokens.settingsContentDelay, MotionTokens.settingsSidebarFade)
    default property alias contentData: contentCard.data
    readonly property alias contentItem: contentCard
    readonly property alias headerCard: headerCard
    implicitWidth: Math.max(headerRow.implicitWidth + 32, contentCard.implicitWidth + 24)
    implicitHeight: headerCard.height + divider.height + contentCard.implicitHeight
    clip: true
    Rectangle { id: headerCard; width: parent.width; height: root.headerHeight; color: LazerTheme.settingsRail; opacity: root.headerProgress; transform: Translate { y: -PopupMotion.offset(root.headerProgress, 12) } /* Row icon16 + Text 14 DemiBold + extraLabel */ }
    Rectangle { id: divider; width: parent.width; height: 1; color: LazerTheme.divider; y: headerCard.height }
    Rectangle { id: contentCard; width: parent.width; y: headerCard.height + 1; height: childrenRect.height; color: LazerTheme.settingsPanel; opacity: root.contentProgress; transform: Translate { y: PopupMotion.offset(root.contentProgress, 14) } }
}
```

关键点：根 `Item` 非 `Rectangle`，两张兄弟卡各自拥有背景与独立 `opacity/Translate`，`divider` 置于 header 底沿，`contentCard` 承载 `default property`。

- [ ] **Step 3: 校验**

Run: `/usr/lib/qt6/bin/qmllint modules/bar/BarPopupFrame.qml`
Expected: 无 Error

- [ ] **Step 4: Commit**

```bash
git add modules/bar/BarPopupFrame.qml modules/bar/BarPopupMotion.js
git commit -m "feat(bar): BarPopupFrame as two independent card surfaces"
```

---

### Task 2: 托盘菜单一/二级双卡与行卡片统一

**Files:**
- Modify: `modules/bar/BarTrayMenu.qml:1-717`
- Test: `qmllint modules/bar/BarTrayMenu.qml` + `qs -p shell.qml` 无 ERROR

**Interfaces:**
- Consumes: `BarPopupFrame` 双卡与 `BarPopupMotion`（Task 1），`LazerTheme/MotionTokens`, `QsMenuOpener`
- Produces: 一级 `headerCard/contentCard` 与二级 `submenuSurface { headerCard/contentCard }` 同构，`MenuEntryRow` 卡片配方对齐 `LazerSettingsRow`。

- [ ] **Step 1: 一级重构为 Item 双卡**

```qml
// BarTrayMenu.qml root 由 Rectangle 改为 Item，内部 headerCard/contentCard 同 Task1 结构
Item {
    id: root
    // 保留 payload/menuHandle/entries/maxHeight/settledHeight/naturalHeight/headerTitle/headerIconSource/revealProgress/headerProgress/contentRevealProgress
    implicitWidth: menuWidth; implicitHeight: entries.length>0||settledHeight===0 ? naturalHeight : Math.max(settledHeight,naturalHeight)
    clip: true
    Rectangle { id: headerCard; width: parent.width; height: headerHeight; color: LazerTheme.settingsRail; opacity: root.headerProgress; transform: Translate{y: -PopupMotion.offset(root.headerProgress,12)} }
    Rectangle { id: divider; width: parent.width; height: 1; color: LazerTheme.divider; y: headerCard.height }
    Rectangle { id: contentCard; width: parent.width; y: headerCard.height+1; height: contentFlickable.contentHeight+16; color: LazerTheme.settingsPanel; opacity: root.contentRevealProgress; transform: Translate{y: PopupMotion.offset(root.contentRevealProgress,14)} }
    Flickable { id: contentFlickable; anchors.fill: contentCard; anchors.margins: 8; /* Column contentColumn */ }
}
```

保留 `submenuOpener/opener/submenuPhase/submenuProgress/yLocked/heldHeight` 等契约不变。

- [ ] **Step 2: 二级 submenuSurface 同构双卡**

```qml
Rectangle {
    id: submenuSurface
    // 保留 width/height/frozenX/frozenY/dockedX/dockedY/enterTravel/transform Translate x
    Item {
        id: submenuHeaderCard
        width: parent.width; height: 48; color: LazerTheme.settingsRail; opacity: submenuSurface.headerRevealProgress; transform: Translate{y: -PopupMotion.offset(submenuSurface.headerRevealProgress,12)}
    }
    Rectangle { id: submenuDivider; width: parent.width; height: 1; color: LazerTheme.divider; y: 48 }
    Rectangle {
        id: submenuContentCard
        width: parent.width; y: 49; height: parent.height-49; color: LazerTheme.settingsPanel; opacity: submenuSurface.contentRevealProgress; transform: Translate{y: PopupMotion.offset(submenuSurface.contentRevealProgress,14)}
        Column { id: submenuColumn; /* Repeater MenuEntryRow level 2 */ }
    }
}
```

`menuFace` 保持 `z:2 Rectangle anchors.fill: parent` 遮挡二级，仅当需要时调整为遮 header+content。

- [ ] **Step 3: 行卡片配方对齐 LazerSettingsRow**

```qml
component MenuEntryRow: Item {
    width: parent ? parent.width : menuWidth; implicitHeight: isSeparator ? 9 : 40
    Rectangle { anchors.fill: parent; anchors.margins: 2; radius: 6; color: (entryHover.hovered||root.submenuAnchorRow===entryRow)&&!isSeparator ? LazerTheme.settingsCardHover : LazerTheme.settingsCard; border.width: (entryHover.hovered||root.submenuAnchorRow===entryRow)&&!isSeparator ? 1.5 : 0; border.color: LazerTheme.settingsAccent; Behavior on color { ColorAnimation{duration: MotionTokens.fast} } }
    Rectangle { z:1; anchors.fill: parent; radius: 6; color: LazerTheme.textPrimary; opacity: 0; enabled: false; id: flashOverlay }
    // checkIndicator / entryIcon / Text / chevron 保持，仅表面改为上述卡片
    NumberAnimation { id: flashAnim; target: flashOverlay; property:"opacity"; from: MotionTokens.clickFlashOpacity; to:0; duration: MotionTokens.clickFlashDuration; easing.type: MotionTokens.clickFlashEasing }
    function activate(){ if(!entryEnabled) return; if(!MotionTokens.reducedMotion) flashAnim.restart(); /* triggered */ }
}
```

- [ ] **Step 4: 校验**

Run: `/usr/lib/qt6/bin/qmllint modules/bar/BarTrayMenu.qml`
Run: `timeout 12 qs -p shell.qml 2>&1 | grep -E "ERROR|Failed to load"`
Expected: 0

- [ ] **Step 5: Commit**

```bash
git add modules/bar/BarTrayMenu.qml
git commit -m "feat(bar): tray menu two-card surfaces with settings row recipe"
```

---

### Task 3: 上下文菜单双卡与 rail/content 复用

**Files:**
- Modify: `modules/bar/BarContextMenu.qml:1-528`
- Test: `qmllint modules/bar/BarContextMenu.qml`

**Interfaces:**
- Consumes: Task 1 契约
- Produces: `BarContextMenu` 外层双卡：`headerCard` + 下分 `railCard/railFlickable` 与 `contentCard/contentFlickable`，行复用 `RailRow/ActionRow` 卡片配方。

- [ ] **Step 1: 外层改为 Item 双卡**

```qml
Item {
    id: root
    implicitWidth: railWidth + contentWidth; implicitHeight: Math.max(240, availHeight-8); clip: true
    Rectangle { id: headerCard; width: parent.width; height: 48; color: LazerTheme.settingsRail; opacity: root.headerProgress; transform: Translate{y:-PopupMotion.offset(root.headerProgress,12)} }
    Rectangle { id: divider; width: parent.width; height:1; color: LazerTheme.divider; y:48 }
    // 下层左右分栏均置于 y:49 起，两侧各为独立 card
    Rectangle { id: railCard; x:0; y:49; width: railWidth; height: parent.height-49; color: LazerTheme.settingsPanel; opacity: root.contentProgress; transform: Translate{y: PopupMotion.offset(root.contentProgress,14)} }
    Rectangle { id: contentCard; x: railWidth; y:49; width: contentWidth; height: parent.height-49; color: LazerTheme.settingsSection; opacity: root.contentProgress; transform: Translate{y: PopupMotion.offset(root.contentProgress,14)} }
    Flickable { /* railColumn */ anchors.fill: railCard; anchors.margins: 6 }
    Flickable { /* contentColumn */ anchors.fill: contentCard; anchors.margins: 8 }
}
```

- [ ] **Step 2: 行配方对齐**

`RailRow` 与 `ActionRow` 的 `cardSurface` 改为 `radius 6 / settingsCardHover / accent 1.5 + flashOverlay + pressScale`，与 Task2 一致。

- [ ] **Step 3: 校验**

Run: `/usr/lib/qt6/bin/qmllint modules/bar/BarContextMenu.qml`
Expected: 无 Error

- [ ] **Step 4: Commit**

```bash
git add modules/bar/BarContextMenu.qml
git commit -m "feat(bar): context menu two-card surfaces"
```

---

### Task 4: 滑条/日历/媒体/通知 4 弹窗内容卡片收敛

**Files:**
- Modify: `modules/bar/BarSliderPopup.qml:1-92`
- Modify: `modules/bar/BarCalendarPopup.qml:1-150`
- Modify: `modules/bar/BarMediaPopup.qml:1-169`
- Modify: `modules/bar/BarNotificationsPopup.qml:1-139`
- Test: `qmllint modules/bar/BarSliderPopup.qml modules/bar/BarCalendarPopup.qml modules/bar/BarMediaPopup.qml modules/bar/BarNotificationsPopup.qml`

**Interfaces:**
- Consumes: Task1 `BarPopupFrame`
- Produces: 4 弹窗内容区内部不再自建大圆角容器，统一由 frame 的 `contentCard` 承载，内部行/块必要时套 `settingsCard` 小卡。

- [ ] **Step 1: 移除内容区自建大圆角，保留控件**

```qml
// 以 BarSliderPopup 为例，其余同理
BarPopupFrame {
    title: "Volume"; iconSource: "icons/volume.svg"; extraText: (muted?"—":percentValue)+"%"
    Column {
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 14; spacing: 10
        LazerSettingsSlider { width: parent.width; from:0; to:100; stepSize:5; value: root.percentValue }
        // mute 块保留 radius 5 但视为小卡，不影响外层双卡
    }
}
```

日历翻月按钮、媒体 transport 按钮、通知 DND/Mark 行保持 `radius 5-6` 小卡，颜色沿用 `settingsResetSurface / settingsCard`。

- [ ] **Step 2: 校验**

Run: `/usr/lib/qt6/bin/qmllint modules/bar/BarSliderPopup.qml modules/bar/BarCalendarPopup.qml modules/bar/BarMediaPopup.qml modules/bar/BarNotificationsPopup.qml`
Expected: 无 Error

- [ ] **Step 3: Commit**

```bash
git add modules/bar/BarSliderPopup.qml modules/bar/BarCalendarPopup.qml modules/bar/BarMediaPopup.qml modules/bar/BarNotificationsPopup.qml
git commit -m "feat(bar): simple popups align to two-card content"
```

---

### Task 5: 宿主与全局校验

**Files:**
- Modify: `modules/bar/BarPopupHost.qml:1-333`（如需）
- Test: `qmllint modules/bar/*.qml` + `qs -p shell.qml` + `git diff --check`

**Interfaces:**
- Consumes: Tasks 1-4 产出
- Produces: 固定几何与单进度驱动验证通过。

- [ ] **Step 1: 确认宿主无逐帧几何动画**

检查 `surfaceLoader` 仅 `x/y` 有 `Behavior on ... enabled: morphReady`，无 `Behavior on width/height`；`deformAnimation.duration = settingsContentDelay+settingsSidebarFade`，`easing OutQuint/InQuad`，`reducedMotion` 时为 0。

- [ ] **Step 2: 全量校验**

Run: `/usr/lib/qt6/bin/qmllint modules/bar/BarPopupFrame.qml modules/bar/BarPopupHost.qml modules/bar/BarTrayMenu.qml modules/bar/BarContextMenu.qml modules/bar/BarSliderPopup.qml modules/bar/BarCalendarPopup.qml modules/bar/BarMediaPopup.qml modules/bar/BarNotificationsPopup.qml 2>&1 | grep -E "Error"`
Expected: 空

Run: `timeout 12 qs -p shell.qml 2>&1 | grep -E "ERROR|Failed to load"`
Expected: 空

Run: `git diff --check`
Expected: 空

- [ ] **Step 3: Commit（如有改动）**

```bash
git add modules/bar/BarPopupHost.qml
git commit -m "fix(bar): host keeps fixed geometry for two-card reveal" || true
```

---

## Self-Review

- Spec 覆盖：双卡 surface、令牌时序、行卡片配方、6 类弹出 + 二级、宿主固定几何均有任务（Task1-5）。
- 占位扫描：无 TBD/TODO，均为具体 QML 与校验命令。
- 类型一致：Task1 定义的 `revealProgress/headerProgress/contentProgress/revealDuration` 在 Task2/3 按同名复用；`BarPopupMotion` 签名一致。
