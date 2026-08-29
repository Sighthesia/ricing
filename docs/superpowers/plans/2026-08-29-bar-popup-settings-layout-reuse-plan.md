# Bar 弹出菜单复用设置布局 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** 将设置面板的双层布局复用到组件悬浮菜单和 bar 右键菜单，并保持设置面板横向入场与 bar 菜单窄型垂直入场互不干扰。

**Architecture:** `TwoLayerPopup` 继续作为纯布局容器；扩展 `BarPopupHost` 以支持通用的 identity/content slot 和 popup kind。组件悬浮菜单与右键菜单各自使用同一屏固定 owner，互斥切换 intent，不恢复旧 popup 服务状态机。设置面板保留独立的横向 host 和自身位移归属。

**Tech Stack:** QML QtQuick、Quickshell.Wayland、`TwoLayerPopup`、`LazerTheme`/`MotionTokens`、`BarLayoutService`、QtTest、qs harness。

## Global Constraints

- 第一层显示组件图标、名称、标题和状态摘要。
- 第二层显示组件已有操作或 bar 右键操作。
- 顶部栏向下，底部栏向上；组件菜单宽度约 `260px`。
- 同屏只显示一个 bar popup；组件 hover 与右键菜单互斥。
- 打开设置面板时关闭并释放 bar popup owner。
- 设置面板继续使用横向 `TwoLayerPopup`，bar 菜单使用纵向 `TwoLayerPopup`。
- 保留现有 widget click/wheel、`BarLayoutService` 状态和持久化布局模型。
- 不恢复旧 `BarPopupService`、旧 `BarTrayMenu`、旧 `BarContextMenu` 或旧 `WidgetHoverPopup` 状态机。
- 主要 surface 保持直角；动效使用 `MotionTokens` 并支持 reduced-motion。
- QML 主要元素声明前添加简短英文注释；不得提交用户已有调试文件。

---

### Task 1: Extract shared popup geometry and arbitration logic

**Files:**
- Modify: `modules/bar/BarHoverLogic.js`
- Create: `tests/qml/tst_bar_popup_routing.qml`

**Interfaces:**
- Produces `popupKind(intent)`, `isSettingsIntent(intent)`, `canReplace(current, next)`, `popupDirection(barPosition)`, and `clampAnchor(anchorX, popupWidth, screenWidth, margin)`.

- [ ] **Step 1: Add failing pure tests**

```qml
function test_hoverAndContextKindsAreDistinct() {
    compare(Logic.popupKind({ actionKind: "volume" }), "hover")
    compare(Logic.popupKind({ actionKind: "context" }), "context")
}
function test_newIntentReplacesExistingPopup() {
    verify(Logic.canReplace({ actionKind: "volume" }, { actionKind: "context" }))
}
function test_settingsIntentIsNotBarPopup() {
    verify(Logic.isSettingsIntent({ widgetId: "settings" }))
    verify(!Logic.isSettingsIntent({ widgetId: "volume" }))
}
```

- [ ] **Step 2: Implement normalized routing helpers**

Keep helpers pure. Treat `intent.kind === "context"` as the right-click menu; all actionable widget intents default to `"hover"`; settings intents are identified by widget id or explicit `kind`. `canReplace` must return false for null next intents and true for two valid different owners.

- [ ] **Step 3: Run tests and commit**

Run: `QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_bar_popup_routing.qml -o -,txt`

Expected: all tests pass with no `FAIL!`, `WARN`, or `ERROR`.

```bash
git add modules/bar/BarHoverLogic.js tests/qml/tst_bar_popup_routing.qml
git commit -m "feat(bar): define popup routing contracts"
```

---

### Task 2: Add reusable context-menu content

**Files:**
- Create: `modules/bar/BarContextPopupActions.qml`
- Modify: `modules/bar/qmldir`
- Create: `tests/qml/tst_bar_context_popup_actions.qml`

**Interfaces:**
- `BarContextPopupActions { widgetId; instanceKey; section; payload; actionRequested(string); }`.
- Actions: `moveLeft`, `moveRight`, `moveToSection`, `openSettings`, `remove`, `close`.

- [ ] **Step 1: Write isolated action tests**

Use fake callback payloads and verify each visible action calls exactly one callback with the expected command. Verify that an unsupported widget still renders section movement and remove actions, while `openSettings` is hidden when `hasSettings` is false.

- [ ] **Step 2: Implement the content surface**

Use a straight `settingsPanel` content surface with compact `settingsCard` rows and existing hover/press/click feedback. The content component must not import or mutate `BarLayoutService`; invoke only payload callbacks supplied by the host. Keep action labels and section names data-driven.

- [ ] **Step 3: Run test/lint and commit**

Run: `QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_bar_context_popup_actions.qml -o -,txt`

Run: `/usr/lib/qt6/bin/qmllint modules/bar/BarContextPopupActions.qml`

```bash
git add modules/bar/BarContextPopupActions.qml modules/bar/qmldir tests/qml/tst_bar_context_popup_actions.qml
git commit -m "feat(bar): add context popup action surface"
```

---

### Task 3: Add context intent publication from BarContent

**Files:**
- Modify: `modules/bar/BarContent.qml`
- Modify: `modules/bar/BarPill.qml` only if the current shared base owns right-click handling
- Modify: `modules/bar/widgets/Tray.qml` only if needed for existing secondary actions
- Create: `tst_bar_context_popup.qml`

**Interfaces:**
- Produces `contextPopupRequested(var intent)` and `contextPopupCloseRequested()` from the widget right-click path.
- Context intent fields: `{ kind: "context", widgetId, instanceKey, title, iconSource, summary, anchorX, section, payload }`.

- [ ] **Step 1: Add a qs harness for right-click intent**

Use a fake widget loader and fake `BarLayoutService` callbacks. Assert that a right-click emits one context intent, includes the widget identity and section, and does not emit the hover popup intent at the same time.

- [ ] **Step 2: Publish context intent without consuming left/wheel paths**

Use the existing `rightClicked` signal where available. The handler must call the existing `BarLayoutService.openContextMenu` data path only through a payload callback or forwarding signal, not duplicate layout state. Existing left click, middle click, wheel, tray secondary action and hover intent behavior remain unchanged.

- [ ] **Step 3: Run lint/harness and commit**

Run: `/usr/lib/qt6/bin/qmllint modules/bar/BarContent.qml modules/bar/BarPill.qml modules/bar/widgets/Tray.qml`

Run: `qs -p tst_bar_context_popup.qml`

```bash
git add modules/bar/BarContent.qml modules/bar/BarPill.qml modules/bar/widgets/Tray.qml tst_bar_context_popup.qml
git commit -m "feat(bar): publish context popup intents"
```

---

### Task 4: Generalize BarPopupHost for hover/context slots

**Files:**
- Modify: `modules/bar/BarPopupHost.qml`
- Modify: `modules/bar/TopBar.qml`
- Create: `tst_bar_popup_reuse.qml`

**Interfaces:**
- Host properties: `intent`, `popupKind`, `open`, `direction`, `surfaceActive`, `widgetHovered`, `popupHovered`.
- Host methods: `updateIntent(intent)`, `showIntent(intent)`, `requestClose()`, `cancelClose()`.
- Host signals: `actionRequested(string)`, `closeRequested()`.

- [ ] **Step 1: Add reuse and mutual-exclusion harness cases**

Assert that a hover intent creates identity/content layers, a context intent replaces them in the same host, settings activation closes the host, and a second host cannot remain active on the same screen.

- [ ] **Step 2: Bind context and hover content**

Keep one per-screen host in `TopBar`. Bind `BarPopupIdentity` to either hover or context intent. Bind `BarPopupActions` for hover and `BarContextPopupActions` for context. Update content in place when only intent fields change; stop old clear timers before replacement.

- [ ] **Step 3: Add settings isolation**

When `settingsOverlay.openFrom` is called or `settingsMaskActive` becomes true, close the bar popup and clear its mask. Ensure the bar popup host remains hidden while idle so it cannot cover the settings window.

- [ ] **Step 4: Run host harness/lint and commit**

Run: `qs -p tst_bar_popup_reuse.qml`

Run: `/usr/lib/qt6/bin/qmllint modules/bar/BarPopupHost.qml modules/bar/TopBar.qml`

```bash
git add modules/bar/BarPopupHost.qml modules/bar/TopBar.qml tst_bar_popup_reuse.qml
git commit -m "feat(bar): reuse layered popup host for context menus"
```

---

### Task 5: Wire layout callbacks and validate all directions

**Files:**
- Modify: `modules/bar/TopBar.qml`
- Modify: `modules/bar/BarPopupHost.qml`
- Modify: `modules/bar/BarContextPopupActions.qml`
- Create: `tst_bar_popup_settings_reuse.qml`

- [ ] **Step 1: Connect context actions to existing BarLayoutService operations**

Wrap existing service calls in the context intent payload: reorder within section, move to another section, open widget settings through the existing `openWidgetSettings`, remove by instance key, and close. Do not add new persistence APIs.

- [ ] **Step 2: Verify top and bottom geometry**

Assert top bar popup identity/content order is downward and bottom bar order is upward. Assert the popup top/bottom edge stays adjacent to the bar, x remains clamped, and settings opening releases the host surface.

- [ ] **Step 3: Verify transitions and interaction preservation**

Exercise hover-to-context replacement, context-to-settings transition, leave-popup close, reduced-motion, and representative existing widget click/wheel handlers. Assert each action callback fires once and the popup uses the same `TwoLayerPopup` instance.

- [ ] **Step 4: Run final validation**

Run: `QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_bar_popup_routing.qml -o -,txt`

Run: `QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_bar_context_popup_actions.qml -o -,txt`

Run: `QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_two_layer_popup.qml -o -,txt`

Run: `qmllint modules/bar/*.qml modules/bar/widgets/*.qml`

Run: `qs -p tst_bar_popup_settings_reuse.qml`

Run: `qs -p shell.qml`

Run: `git diff --check`

Expected: pure tests pass, qs harnesses report zero failures, shell loads with no new QML errors, and settings panel remains visible with its horizontal entrance motion.

- [ ] **Step 5: Commit final integration**

```bash
git add modules/bar/TopBar.qml modules/bar/BarPopupHost.qml modules/bar/BarContextPopupActions.qml tst_bar_popup_settings_reuse.qml
git commit -m "feat(bar): reuse settings layout for hover and context menus"
```

## Self-Review

- Covers identity/content roles, narrow vertical menus, top/down and bottom/up behavior, hover/context mutual exclusion, settings isolation, existing operations, and tests.
- Does not restore old popup state machines.
- Keeps user-created dirty and untracked files outside every staging command.
