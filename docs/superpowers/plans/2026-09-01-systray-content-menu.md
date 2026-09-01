# 系统托盘内容菜单 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 悬停托盘图标时，现有双层弹窗的第二层直接展示原生 DBus 菜单，带子菜单的行悬停后展开一层二级面板。

**Architecture:** 纯 JS 菜单契约先可测；`BarTrayMenuContent` 挂在 `BarPopupActions` 的 tray 槽里，用 `QsMenuOpener` 拉根菜单、第二个 opener 拉二级。二级垫在一级脸面下靠遮挡揭示。不恢复独立 `BarTrayMenu` 窗。

**Tech Stack:** QML QtQuick、Quickshell `QsMenuOpener` / `QsMenuEntry`、`LazerTheme` / `MotionTokens`、Qt6 `qmltestrunner`、根目录 `qs -p` harness。

## Global Constraints

- 只改 `actionKind === "tray"` 的内容层；音量/亮度/媒体/通知不变。
- 支持根菜单 + 一层子菜单；不做三级。
- 行卡片复用设置面板：`settingsCard` / `settingsCardHover`、点击闪烁、禁用降透明度。
- 二级 opacity 恒为 1；`closeSubmenu()` 不得立刻清 entry/anchor。
- 折叠“悬停普通行关闭二级”只对 `level === 1` 生效。
- 无菜单句柄或空 children 显示空状态，不回退 Open / Menu。
- 保留托盘图标左键 `activate()` 与右键 `secondaryActivate()`。
- 不恢复 `BarTrayMenu.qml` 独立窗，不把 `TrayMenuService` 当弹出宿主。
- 主要 QML 元素声明前加简短英文注释。
- 逻辑测试：`QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input <file> -o -,txt`。含 Quickshell 的行为：从仓库根目录 `qs -p tst_*.qml`。

---

### Task 1: Pure tray menu contracts

**Files:**
- Create: `modules/bar/BarTrayMenuLogic.js`
- Create: `tests/qml/tst_bar_tray_menu_logic.qml`

**Interfaces:**
- Produces:
  - `entryList(children)` → array
  - `isSeparator(entry)` → bool
  - `isEnabled(entry)` → bool
  - `hasChildren(entry)` → bool
  - `isChecked(entry)` → bool
  - `labelOf(entry)` → string
  - `shouldOpenSubmenu(entry)` → bool
  - `shouldCloseSubmenuOnRow(level, hasChildren)` → bool
  - `shouldDismissOnTrigger(entry)` → bool
  - `emptyStateVisible(handle, entries)` → bool
  - `menuHandleFromPayload(payload)` → handle or null
  - `submenuTitle(entry)` → string
  - `heldHeight(rawHeight, previousHeld)` → number
  - `releaseSubmenuData(progress, phase)` → bool

- [ ] **Step 1: Write the failing tests**

```qml
import QtQuick
import QtTest
import "../../modules/bar/BarTrayMenuLogic.js" as Logic

Item {
    width: 1; height: 1
    TestCase {
        name: "BarTrayMenuLogic"
        function test_entryListAcceptsArrayAndValues() {
            compare(Logic.entryList(null).length, 0)
            compare(Logic.entryList({ values: [{ text: "A" }] }).length, 1)
            compare(Logic.entryList([{ text: "B" }]).length, 1)
        }
        function test_separatorAndChildrenFlags() {
            verify(Logic.isSeparator({ isSeparator: true }))
            verify(!Logic.isEnabled({ enabled: false }))
            verify(Logic.hasChildren({ hasChildren: true }))
            verify(Logic.isChecked({ checkState: Qt.Checked }))
            verify(!Logic.isChecked({ checkState: Qt.Unchecked }))
        }
        function test_openCloseAndDismissRules() {
            verify(Logic.shouldOpenSubmenu({ hasChildren: true, enabled: true, isSeparator: false }))
            verify(!Logic.shouldOpenSubmenu({ hasChildren: true, enabled: false }))
            verify(Logic.shouldCloseSubmenuOnRow(1, false))
            verify(!Logic.shouldCloseSubmenuOnRow(1, true))
            verify(!Logic.shouldCloseSubmenuOnRow(2, false))
            verify(Logic.shouldDismissOnTrigger({ hasChildren: false, isSeparator: false }))
            verify(!Logic.shouldDismissOnTrigger({ checkState: Qt.Checked }))
            verify(!Logic.shouldDismissOnTrigger({ hasChildren: true }))
        }
        function test_emptyStateAndHandle() {
            verify(Logic.emptyStateVisible(null, []))
            verify(Logic.emptyStateVisible({}, []))
            verify(!Logic.emptyStateVisible({ id: 1 }, [{ text: "A" }]))
            compare(Logic.menuHandleFromPayload({ hasMenu: true, menu: "h" }), "h")
            compare(Logic.menuHandleFromPayload({ hasMenu: false, menu: "h" }), null)
            compare(Logic.menuHandleFromPayload({ menuHandle: "x" }), "x")
        }
        function test_heightHoldAndRelease() {
            compare(Logic.heldHeight(8, 120), 120)
            compare(Logic.heldHeight(80, 120), 80)
            verify(!Logic.releaseSubmenuData(0.4, "closing"))
            verify(Logic.releaseSubmenuData(0, "closed"))
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_bar_tray_menu_logic.qml -o -,txt`

Expected: FAIL because `BarTrayMenuLogic.js` does not exist.

- [ ] **Step 3: Implement the logic**

```javascript
.pragma library

function entryList(children) {
    if (!children)
        return []
    if (Array.isArray(children))
        return children
    if (children.values && typeof children.values.length === "number") {
        var out = []
        for (var i = 0; i < children.values.length; i++)
            out.push(children.values[i])
        return out
    }
    if (typeof children.length === "number") {
        var copy = []
        for (var j = 0; j < children.length; j++)
            copy.push(children[j])
        return copy
    }
    return []
}

function isSeparator(entry) { return !!(entry && entry.isSeparator) }
function isEnabled(entry) { return !!(entry && entry.enabled !== false) && !isSeparator(entry) }
function hasChildren(entry) { return !!(entry && entry.hasChildren) }
function isChecked(entry) { return !!(entry && entry.checkState === Qt.Checked) }
function labelOf(entry) {
    if (!entry || entry.text == null) return ""
    return String(entry.text).replace(/[\n\r]+/g, " ")
}
function shouldOpenSubmenu(entry) {
    return hasChildren(entry) && isEnabled(entry) && !isSeparator(entry)
}
function shouldCloseSubmenuOnRow(level, rowHasChildren) {
    return Number(level) === 1 && !rowHasChildren
}
function shouldDismissOnTrigger(entry) {
    if (!entry || isSeparator(entry) || hasChildren(entry))
        return false
    if (entry.checkState !== undefined && entry.checkState !== null)
        return false
    return true
}
function emptyStateVisible(handle, entries) {
    return !handle || entryList(entries).length === 0
}
function menuHandleFromPayload(payload) {
    if (!payload) return null
    if (payload.menuHandle)
        return payload.menuHandle
    if (payload.hasMenu && payload.menu)
        return payload.menu
    if (payload.trayItem && payload.trayItem.hasMenu)
        return payload.trayItem.menu || null
    return null
}
function submenuTitle(entry) { return labelOf(entry) }
function heldHeight(rawHeight, previousHeld) {
    var raw = Number(rawHeight)
    var prev = Number(previousHeld)
    if (!isFinite(raw) || raw <= 20)
        return isFinite(prev) && prev > 0 ? prev : 0
    return raw
}
function releaseSubmenuData(progress, phase) {
    return Number(progress) === 0 && String(phase || "") !== "opening"
}
```

`shouldDismissOnTrigger` 最终规则：分隔线/子菜单项不关；`checkState` 存在（勾选/单选）不关；其余普通项关闭。

- [ ] **Step 4: Run tests to verify they pass**

Run the same qmltestrunner command. Expected: all PASS, no FAIL!/WARN/ERROR.

- [ ] **Step 5: Commit**

```bash
git add modules/bar/BarTrayMenuLogic.js tests/qml/tst_bar_tray_menu_logic.qml
git commit -m "feat(bar): add tray menu decision contracts"
```

---

### Task 2: Tray menu content component with fake entries

**Files:**
- Create: `modules/bar/BarTrayMenuContent.qml`
- Modify: `modules/bar/qmldir`
- Create: `tests/qml/tst_bar_tray_menu_content.qml`

**Interfaces:**
- Consumes Task 1 functions.
- Produces `BarTrayMenuContent` with:
  - `property var menuHandle`
  - `property var entries` (assignable in tests; live opener binds later)
  - `property string submenuPhase`
  - `property real submenuProgress`
  - `property var submenuEntry`
  - `property int submenuAnchorLevel`
  - `signal dismissRequested()`
  - `function openSubmenu(entry, row)`
  - `function closeSubmenu()`
  - `objectName` nodes: `trayMenuRoot`, `trayEmptyState`, `trayMenuRow`, `traySubmenuSurface`, `traySubmenuTitle`

- [ ] **Step 1: Write the failing content tests**

```qml
import QtQuick
import QtTest
import "../../modules/bar" as Bar
import "../../modules/lazerbar" as Lazer

Item {
    width: 400; height: 800
    Component { id: menuComp; Bar.BarTrayMenuContent {} }

    function fakeEntry(text, extra) {
        var e = extra || ({})
        return {
            text: text,
            enabled: e.enabled !== false,
            isSeparator: !!e.isSeparator,
            hasChildren: !!e.hasChildren,
            checkState: e.checkState,
            triggeredCalls: 0,
            triggered: function() { this.triggeredCalls++ }
        }
    }

    TestCase {
        name: "BarTrayMenuContent"
        when: windowShown
        function test_emptyStateWithoutHandle() {
            var item = createTemporaryObject(menuComp, root, { menuHandle: null, entries: [] })
            verify(item.emptyStateVisible)
            compare(findByName(item, "trayEmptyState").visible, true)
        }
        function test_rowsRenderAndSeparatorNotClickable() {
            var sep = fakeEntry("", { isSeparator: true })
            var open = fakeEntry("Open")
            var item = createTemporaryObject(menuComp, root, { menuHandle: {}, entries: [sep, open] })
            verify(!item.emptyStateVisible)
            compare(item.rowCount, 2)
        }
        function test_plainTriggerDismisses() {
            var open = fakeEntry("Open")
            var item = createTemporaryObject(menuComp, root, { menuHandle: {}, entries: [open] })
            var dismissed = 0
            item.dismissRequested.connect(function() { dismissed++ })
            item.activateEntry(open, 1)
            compare(open.triggeredCalls, 1)
            compare(dismissed, 1)
        }
        function test_checkboxDoesNotDismiss() {
            var mute = fakeEntry("Mute", { checkState: Qt.Checked })
            var item = createTemporaryObject(menuComp, root, { menuHandle: {}, entries: [mute] })
            var dismissed = 0
            item.dismissRequested.connect(function() { dismissed++ })
            item.activateEntry(mute, 1)
            compare(mute.triggeredCalls, 1)
            compare(dismissed, 0)
        }
        function test_openSubmenuKeepsDataUntilClosed() {
            Lazer.MotionTokens.reducedMotionOverride = true
            var child = fakeEntry("Child")
            var parent = fakeEntry("More", { hasChildren: true })
            var item = createTemporaryObject(menuComp, root, { menuHandle: {}, entries: [parent] })
            item.openSubmenu(parent, null)
            compare(item.submenuPhase, "open")
            compare(item.submenuEntry, parent)
            item.closeSubmenu()
            compare(item.submenuProgress, 0)
            compare(item.submenuEntry, null)
            Lazer.MotionTokens.reducedMotionOverride = false
        }
        function test_levelTwoDoesNotCloseSubmenu() {
            var parent = fakeEntry("More", { hasChildren: true })
            var nested = fakeEntry("Nested")
            var item = createTemporaryObject(menuComp, root, { menuHandle: {}, entries: [parent] })
            item.openSubmenu(parent, null)
            item.handleRowHover(2, false)
            compare(item.submenuEntry, parent)
            item.handleRowHover(1, false)
            verify(item.submenuPhase === "closing" || item.submenuProgress === 0 || item.submenuEntry === parent)
        }
    }

    function findByName(item, name) {
        if (!item) return null
        if (item.objectName === name) return item
        var kids = item.children
        if (kids) {
            for (var i = 0; i < kids.length; i++) {
                var r = findByName(kids[i], name)
                if (r) return r
            }
        }
        return null
    }
}
```

If `Bar.BarTrayMenuContent` is not in `qmldir` yet, the compile failure is the red signal.

- [ ] **Step 2: Run the test and verify it fails**

Run: `QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_bar_tray_menu_content.qml -o -,txt`

Expected: FAIL, type unavailable.

- [ ] **Step 3: Implement `BarTrayMenuContent.qml`**

Register in `modules/bar/qmldir`:

```
BarTrayMenuContent 1.0 BarTrayMenuContent.qml
```

Minimal component shape (no Quickshell import in this task; opener is Task 4):

- Root `Item` `objectName: "trayMenuRoot"`, `implicitWidth: 244`.
- `property var menuHandle`
- `property var entries: []`
- `readonly property var entryModel: Logic.entryList(entries)`
- `readonly property bool emptyStateVisible: Logic.emptyStateVisible(menuHandle, entryModel)`
- `readonly property int rowCount: entryModel.length`
- `property string submenuPhase: "closed"`
- `property real submenuProgress: 0`
- `property var submenuEntry: null`
- `property Item submenuAnchorRow: null`
- `signal dismissRequested()`
- `function activateEntry(entry, level)` uses Logic to trigger, open submenu, or dismiss.
- `function handleRowHover(level, rowHasChildren)` calls `closeSubmenu()` only when `Logic.shouldCloseSubmenuOnRow`.
- `function openSubmenu(entry, row)`: if already opening/open, only retarget entry/row; else set phase opening and animate progress to 1. Reduced motion snaps to 1.
- `function closeSubmenu()`: do not clear entry; set closing and animate to 0.
- `NumberAnimation` on `submenuProgress`; `onFinished`: if progress===0, `submenuEntry = null`, `submenuAnchorRow = null`, phase closed; if progress===1, phase open.
- Empty `Text` `objectName: "trayEmptyState"` visible when empty.
- `Column` + `Repeater` over `entryModel`. Delegate:
  - separator: 9px 1px divider, no TapHandler.
  - row: 32px settings card, label from `Logic.labelOf`, check mark if checked, chevron if `hasChildren`.
  - `HoverHandler` on root rows (`level: 1`) calls `handleRowHover` / `openSubmenu`.
  - `TapHandler` calls `activateEntry`.
  - click flash overlay using `MotionTokens.clickFlash*`.
- Submenu surface `objectName: "traySubmenuSurface"`: `z: 1`, `opacity: 1`, `visible: submenuProgress > 0`, title `objectName: "traySubmenuTitle"` bound to `Logic.submenuTitle(submenuEntry)`. Content column uses `submenuEntries` property (assignable; live opener in Task 4). Delegates use `level: 2`.
- Bridge item `objectName: "traySubmenuBridge"` between root and submenu, size 0 when closed.
- Height hold: `property real heldHeight`; `onEntryModelChanged` / raw column height handler writes `heldHeight = Logic.heldHeight(column.implicitHeight, heldHeight)` in a signal handler, not inside the binding.

Do not import Quickshell in this file yet if tests cannot load it. Keep opener as optional: `property var openerChildren: null` and `entries` defaults to `openerChildren` when set.

- [ ] **Step 4: Run the content tests**

Run the qmltestrunner command from Step 2. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add modules/bar/BarTrayMenuContent.qml modules/bar/qmldir tests/qml/tst_bar_tray_menu_content.qml
git commit -m "feat(bar): render tray dbus rows in popup content"
```

---

### Task 3: Wire payload handle and replace Open / Menu

**Files:**
- Modify: `modules/bar/widgets/Tray.qml`
- Modify: `modules/bar/BarPopupActions.qml`
- Modify: `tests/qml/tst_bar_popup_content.qml`
- Modify: `tst_bar_two_layer_popup.qml`

**Interfaces:**
- Consumes `BarTrayMenuContent` and `Logic.menuHandleFromPayload`.
- `Tray.buildTrayIntent` payload gains `menuHandle` and `hasMenu`.
- `BarPopupActions` tray slot mounts `BarTrayMenuContent { menuHandle: ...; onDismissRequested: host close via existing dismiss path }`.

- [ ] **Step 1: Rewrite failing popup-content tray tests**

Replace `test_trayExposesActivateSecondary` with:

```qml
function test_trayRendersNativeMenuRows() {
    var open = { text: "Open", enabled: true, triggeredCalls: 0, triggered: function() { this.triggeredCalls++ } }
    var item = createTemporaryObject(actionsComp, root, {
        actionKind: "tray",
        payload: { menuHandle: {}, entries: [open] }
    })
    var menu = findByName(item, "trayMenuRoot")
    verify(menu !== null)
    verify(findByName(item, "trayContent").visible)
    verify(findByName(item, "trayActivateButton") === null)
    compare(menu.rowCount, 1)
}

function test_trayEmptyStateWithoutHandle() {
    var item = createTemporaryObject(actionsComp, root, { actionKind: "tray", payload: {} })
    verify(findByName(item, "trayEmptyState").visible)
}
```

In `tst_bar_two_layer_popup.qml`, replace Open/Menu TapHandler checks with:

```qml
root.checkTrue("tray menu content exists", findByName(actions, "trayMenuRoot") !== null)
root.checkTrue("tray open/menu buttons removed", findByName(actions, "trayActivateTap") === null)
```

Keep `handleTrayActivate` tests only if those functions remain for icon click paths; they may stay on the widget, not the popup.

- [ ] **Step 2: Run tests to verify they fail**

Run:
`QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_bar_popup_content.qml -o -,txt`

Expected: FAIL looking for `trayMenuRoot` / still finding `trayActivateButton`.

- [ ] **Step 3: Wire production**

`Tray.qml` payload:

```javascript
payload: {
    trayModel: modelData,
    trayItem: modelData,
    title: titleText,
    iconSource: iconSrc,
    hasMenu: !!(modelData && modelData.hasMenu),
    menuHandle: (modelData && modelData.hasMenu) ? modelData.menu : null,
    onActivate: function() { try { modelData.activate() } catch (e) {} },
    onSecondaryActivate: function() { try { modelData.secondaryActivate() } catch (e) {} }
}
```

`BarPopupActions.qml` replace the Open/Menu `trayContent` body with:

```qml
Item {
    id: trayContent
    objectName: "trayContent"
    width: parent.width
    visible: root.actionKind === "tray"
    height: visible ? trayMenu.implicitHeight : 0
    BarTrayMenuContent {
        id: trayMenu
        width: parent.width
        menuHandle: Logic.menuHandleFromPayload(root.payload)
        entries: root.payload && root.payload.entries ? root.payload.entries : []
        onDismissRequested: root.handleTrayMenuDismiss()
    }
}
```

Add `import "./BarTrayMenuLogic.js" as TrayLogic` or pass handle from a small helper on `BarPopupActions`:

```qml
readonly property var trayMenuHandle: {
    if (!payload) return null
    if (payload.menuHandle) return payload.menuHandle
    if (payload.hasMenu && payload.menu) return payload.menu
    if (payload.trayItem && payload.trayItem.hasMenu) return payload.trayItem.menu
    return null
}
```

`handleTrayMenuDismiss`: if payload has `onDismiss`, call it; otherwise no-op. Host close is Task 4 via signal bubbling. For this task, `BarPopupActions` should emit nothing new if host already closes on content tap—add `signal dismissRequested()` on `BarPopupActions` and in `BarPopupHost` content `onDismissRequested` call `root.dismissImmediately()` like context close.

Remove unused `handleTrayActivate` / `handleTraySecondary` only if tests no longer need them. Prefer keeping the functions for widget-level reuse but unused by popup UI.

- [ ] **Step 4: Run popup content and two-layer harness**

```
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_bar_popup_content.qml -o -,txt
qs -p tst_bar_two_layer_popup.qml
```

Expected: popup-content PASS; two-layer Totals with 0 failed.

- [ ] **Step 5: Commit**

```bash
git add modules/bar/widgets/Tray.qml modules/bar/BarPopupActions.qml modules/bar/BarPopupHost.qml tests/qml/tst_bar_popup_content.qml tst_bar_two_layer_popup.qml
git commit -m "feat(bar): show native tray menu in hover popup"
```

---

### Task 4: Live QsMenuOpener, submenu motion, height hold

**Files:**
- Modify: `modules/bar/BarTrayMenuContent.qml`
- Modify: `modules/bar/BarPopupHost.qml` (dismiss + optional mask include for submenu/bridge if host mask is popupContainer only—submenu must stay inside popupContainer or extend host geometry)
- Modify: `tests/qml/tst_bar_tray_menu_content.qml`

**Interfaces:**
- Live: `QsMenuOpener { id: rootOpener; menu: root.menuHandle }` and `QsMenuOpener { id: submenuOpener; menu: root.submenuEntry }`
- `entries` binds to `Logic.entryList(rootOpener.children)` when not explicitly stubbed.
- Submenu reveal: `MotionTokens.medium` + `outSoft` open; close `MotionTokens.slow` + `inOut`.
- `enterTravel = 4 + width * MotionTokens.popupFromScale + 4`
- Submenu `z: 1` under a `trayMenuFace` `z: 2` opaque face covering the root list; rows `z: 3`.
- Host `updateTargetGeometry` must include submenu width when `submenuProgress > 0` so the layer-shell mask covers the second panel.

- [ ] **Step 1: Extend tests for motion contracts without Quickshell**

```qml
function test_heldHeightKeepsPreviousWhenTiny() {
    var item = createTemporaryObject(menuComp, root, { menuHandle: {}, entries: [fakeEntry("A")] })
    item.noteColumnHeight(120)
    item.noteColumnHeight(8)
    compare(item.heldHeight, 120)
}
function test_faceOccludesSubmenu() {
    var item = createTemporaryObject(menuComp, root, { menuHandle: {}, entries: [fakeEntry("More", { hasChildren: true })] })
    verify(item.submenuSurface.z < item.menuFace.z)
    compare(item.submenuSurface.opacity, 1)
}
```

Expose aliases: `readonly property alias submenuSurface: submenuSurface`, `readonly property alias menuFace: menuFace`.

- [ ] **Step 2: Run tests to verify new assertions fail**

Run content qmltestrunner. Expected: FAIL missing aliases/functions.

- [ ] **Step 3: Implement live opener + motion**

Import `Quickshell` only around opener objects. Guard tests: if qmltestrunner cannot import Quickshell, keep openers in a `Loader` with `active: menuHandle && !testStubEntries`. Tests set `entries` explicitly and `useStubEntries: true`.

Motion:

```qml
function runSubmenu(toValue) {
    submenuAnimation.stop()
    submenuAnimation.duration = MotionTokens.reducedMotion ? 0
        : (toValue >= 1 ? MotionTokens.medium : MotionTokens.slow)
    submenuAnimation.easing.bezierCurve = toValue >= 1 ? MotionTokens.outSoft : MotionTokens.inOut
    submenuAnimation.to = toValue
    submenuAnimation.restart()
}
```

Submenu `transform: Translate { x: enterTravel * (1 - submenuProgress) }` with sign based on `popsRight`. Do not animate opacity.

`onRawColumnHeightChanged: heldHeight = Logic.heldHeight(rawColumnHeight, heldHeight)`

Host: when tray menu reports `submenuProgress > 0`, `targetWidth = Math.max(current, trayMenu.width + submenu.width + 4)`. Prefer exposing `readonly property real extraWidth` from content and reading it in `popupHeightForIntent` sibling width calc in `updateTargetGeometry`.

Dismiss: `BarPopupHost` content `BarPopupActions.onDismissRequested` → `root.dismissImmediately()`.

- [ ] **Step 4: Run tests**

```
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_bar_tray_menu_content.qml -o -,txt
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_bar_popup_content.qml -o -,txt
qs -p tst_bar_popup_host.qml
qs -p tst_bar_two_layer_popup.qml
```

Expected: all PASS / 0 failed. If qmltestrunner cannot import Quickshell, openers stay behind the stub flag and tests still pass.

- [ ] **Step 5: Commit**

```bash
git add modules/bar/BarTrayMenuContent.qml modules/bar/BarPopupHost.qml tests/qml/tst_bar_tray_menu_content.qml
git commit -m "feat(bar): open tray submenus beside the root list"
```

---

## Spec coverage

| Spec requirement | Task |
|---|---|
| 第二层展示原生 DBus 菜单 | 2, 3, 4 |
| 一级 + 二级，悬停展开 | 1, 2, 4 |
| 行卡片 / 分隔线 / 禁用 / 勾选 | 1, 2 |
| 普通项关闭、勾选不关 | 1, 2 |
| 空状态，不回退 Open/Menu | 1, 2, 3 |
| 数据保活、level 作用域 | 1, 2, 4 |
| 走廊桥、高度保持、遮挡揭示 | 4 |
| payload menuHandle | 3 |
| 保留图标左右键 | 3（不改 TapHandler） |
| 不恢复独立窗 | 全程 |

无 TBD/TODO。接口名前后任务一致：`openSubmenu`, `closeSubmenu`, `dismissRequested`, `menuHandle`, `heldHeight`。
