# 顶部栏双层悬浮菜单 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** 将 `TwoLayerPopup` 复用到系统托盘图标及音量、亮度、媒体、通知组件的悬浮菜单，并根据顶部栏位置向下或向上弹出。

**Architecture:** 新建每屏 `BarPopupHost` 作为独立 overlay surface，接收 `BarContent` 发布的 hover intent，并用垂直模式的 `TwoLayerPopup` 承载身份层与操作层。widget 只提供标题、状态和操作内容，host 负责 hover bridge、方向、锚点夹紧和生命周期；不恢复旧 `BarPopupService` 状态机。

**Tech Stack:** QML QtQuick、Quickshell.Wayland、`TwoLayerPopup`、Afloat `LazerTheme`/`MotionTokens`、QML QtTest、qs 行为 harness。

## Global Constraints

- 只接入系统托盘、音量、亮度、媒体和通知；时钟、活动窗口、工作区、启动器和设置按钮不新增悬浮菜单。
- 顶部栏时使用 `TwoLayerPopup.Direction.Down`，底部栏时使用 `TwoLayerPopup.Direction.Up`。
- 第一层通过 `sidebarData` 注入组件图标、名称、标题和状态摘要；第二层通过 `contentData` 注入已有具体操作。
- 复用 `TwoLayerPopup` 的固定 owner、stagger、opacity、Translate 和 reduced-motion 规则；不得逐帧改变 layer-shell 窗口尺寸。
- 触发 widget 和 popup 共享 hover 生命周期，离开两者后才关闭；保留原有 click/wheel 快捷操作。
- 不恢复或依赖 `BarPopupService`、`BarTrayMenu`、`BarContextMenu` 和旧 `WidgetHoverPopup` 状态机。
- 主 surface 使用直角 `settingsRail`/`settingsPanel`；按钮和控件沿用设置面板现有反馈与 MotionTokens。
- 主要 QML 元素声明前添加简短英文注释，默认使用 ASCII。

---

### Task 1: Define hover intent and geometry logic

**Files:**
- Create: `modules/bar/BarHoverLogic.js`
- Modify: `modules/bar/qmldir` only if the project registers JS modules there
- Create: `tests/qml/tst_bar_hover_logic.qml`

**Interfaces:**
- Produces `popupDirection(barPosition)`, `clampAnchor(anchorX, popupWidth, screenWidth, margin)`, `shouldClose(widgetHovered, popupHovered, closePending)`, and `hoverPayload(widgetId, instanceKey, title, iconSource, summary, actionKind)`.

- [ ] **Step 1: Write pure logic tests**

```qml
function test_topBarOpensDown() { compare(Logic.popupDirection("top"), "down") }
function test_bottomBarOpensUp() { compare(Logic.popupDirection("bottom"), "up") }
function test_anchorStaysInsideScreen() {
    compare(Logic.clampAnchor(10, 240, 1000, 12), 12)
    compare(Logic.clampAnchor(900, 240, 1000, 12), 748)
}
function test_closeWaitsForBothHoverOwners() {
    verify(!Logic.shouldClose(true, false, true))
    verify(!Logic.shouldClose(false, true, true))
    verify(Logic.shouldClose(false, false, true))
}
```

- [ ] **Step 2: Run the test and verify the missing functions fail**

Run: `QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_bar_hover_logic.qml -o -,txt`

Expected: FAIL because `BarHoverLogic.js` does not exist.

- [ ] **Step 3: Implement pure contracts**

Use normalized strings and numeric clamping. `popupDirection` returns `"up"` only for `"bottom"`, otherwise `"down"`. `clampAnchor` returns the popup's left edge clamped between `margin` and `screenWidth - popupWidth - margin`; invalid numbers resolve to zero-width safe values. `shouldClose` returns true only when both hover owners are false and close is pending. `hoverPayload` returns a plain object with normalized string fields and no QML references.

- [ ] **Step 4: Run the focused logic test**

Run the qmltestrunner command above. Expected: all tests pass with no `FAIL!`, `WARN`, or `ERROR`.

- [ ] **Step 5: Commit**

```bash
git add modules/bar/BarHoverLogic.js tests/qml/tst_bar_hover_logic.qml
git commit -m "feat(bar): define hover popup intent contracts"
```

---

### Task 2: Build the per-screen BarPopupHost

**Files:**
- Modify: `modules/bar/BarPopupHost.qml`
- Modify: `modules/bar/qmldir`
- Create: `tst_bar_popup_host.qml`

**Interfaces:**
- Consumes an intent object `{ widgetId, instanceKey, title, iconSource, summary, actionKind, anchorX, screenWidth, barPosition }`.
- Produces properties `intent`, `open`, `widgetHovered`, `popupHovered`, `direction`, `anchorX`, `screenWidth`, signals `actionRequested(string)`, `closeRequested()`, and methods `showIntent(intent)`, `requestClose()`, `cancelClose()`.

- [ ] **Step 1: Create a qs behavior harness for direction and lifecycle**

The harness must import the local bar module, inject a fake intent, call `showIntent`, assert `open`, `direction`, and `TwoLayerPopup.direction`, then call `requestClose` while `popupHovered` is true and assert it remains open; set both hover flags false, wait the close delay, and assert it closes. End with `Totals:` and `Qt.quit` as required by the QML testing skill.

- [ ] **Step 2: Implement fixed host geometry**

Use a `PanelWindow` with `exclusionMode: ExclusionMode.Ignore`, transparent background, and screen-wide implicit dimensions. Anchor its edge to the opposite side of the bar and offset it by the effective bar height plus floating margin. Keep the window size fixed. Place an inner `Item` with `TwoLayerPopup { orientation: TwoLayerPopup.Orientation.Vertical; direction: direction === "up" ? TwoLayerPopup.Direction.Up : TwoLayerPopup.Direction.Down }` and set its x from `BarHoverLogic.clampAnchor`.

- [ ] **Step 3: Implement the hover bridge and close timer**

Use non-blocking hover observation on the widget owner and popup surface. `requestClose()` starts a `MotionTokens.fast`-bounded close timer; `cancelClose()` stops it. The timer closes only if both hover flags are false. The host must disable input when no intent is open and clear intent after the exit reveal has completed.

- [ ] **Step 4: Add generic identity and content slots**

Expose `sidebarData` and `contentData` aliases through the internal `TwoLayerPopup`; the host itself only supplies the shared surface and hover lifecycle. Keep the content slot empty until Task 3 adapters provide actual operations.

- [ ] **Step 5: Run lint and the behavior harness**

Run: `/usr/lib/qt6/bin/qmllint modules/bar/BarPopupHost.qml`

Run: `qs -p tst_bar_popup_host.qml`

Expected: no QML errors; harness prints `PASS:` and a zero-failure `Totals:` line.

- [ ] **Step 6: Commit**

```bash
git add modules/bar/BarPopupHost.qml modules/bar/qmldir tst_bar_popup_host.qml
git commit -m "feat(bar): add fixed per-screen hover popup host"
```

---

### Task 3: Add reusable identity and operation content adapters

**Files:**
- Create: `modules/bar/BarPopupIdentity.qml`
- Create: `modules/bar/BarPopupActions.qml`
- Create: `modules/bar/BarPopupSlider.qml`
- Modify: `modules/bar/qmldir`
- Create: `tests/qml/tst_bar_popup_content.qml`

**Interfaces:**
- `BarPopupIdentity { title; iconSource; summary }` renders the settings-sidebar-like first layer.
- `BarPopupActions { actionKind; payload; }` renders the content body for `volume`, `brightness`, `media`, `notifications`, and `tray`.
- `BarPopupSlider { value; muted; label; valueCommitted(real); toggleRequested() }` is the shared slider/mute operation surface. Note: Qt6 forbids `property value` + `signal valueChanged(real)` on the same object (duplicate implicit notify), so the commit signal is `valueCommitted(real)`; `onValueChanged` remains the property binding notify and hosts handle `onValueCommitted`.

- [ ] **Step 1: Write content contract tests**

Test that each `actionKind` creates a visible content root, volume and brightness expose a slider, media exposes previous/play-next actions, notifications exposes DND/clear actions, and tray exposes activate/secondary action buttons. Test these components with fake callbacks or injected service objects so the test does not mutate real singleton state.

- [ ] **Step 2: Implement identity layer**

Use a straight `Rectangle` with `LazerTheme.settingsRail`, an optional 16px icon, title text with `ElideRight`, and summary text using muted color. Keep the first layer sized from explicit host width and fixed header height.

- [ ] **Step 3: Implement operation adapters**

Use existing service contracts only: `VolumeService.setSinkVolume/toggleSinkMute`, `BrightnessService.setBrightness`, `MediaService.previous/playPause/next`, and `NotificationService.dndEnabled` plus its existing clear/read operation. For tray actions, invoke the active SNI model's `activate`/`secondaryActivate`. Do not add new service methods. All click feedback uses existing settings button/control patterns and MotionTokens.

- [ ] **Step 4: Run content tests and lint**

Run: `QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_bar_popup_content.qml -o -,txt`

Run: `/usr/lib/qt6/bin/qmllint modules/bar/BarPopupIdentity.qml modules/bar/BarPopupActions.qml modules/bar/BarPopupSlider.qml`

Expected: focused tests pass and lint has no new warning/error.

- [ ] **Step 5: Commit**

```bash
git add modules/bar/BarPopupIdentity.qml modules/bar/BarPopupActions.qml modules/bar/BarPopupSlider.qml modules/bar/qmldir tests/qml/tst_bar_popup_content.qml
git commit -m "feat(bar): add two-layer popup identity and action content"
```

---

### Task 4: Publish actionable widget intents from BarContent and Tray

**Files:**
- Modify: `modules/bar/BarContent.qml`
- Modify: `modules/bar/widgets/Tray.qml`
- Modify: `modules/bar/widgets/Volume.qml`
- Modify: `modules/bar/widgets/Brightness.qml`
- Modify: `modules/bar/widgets/Media.qml`
- Modify: `modules/bar/widgets/Notifications.qml`

**Interfaces:**
- Consumes the existing widget identity properties and hover handlers.
- Produces a `popupRequested(var intent)` signal path to `BarPopupHost`, with payloads whose `actionKind` is one of `tray`, `volume`, `brightness`, `media`, `notifications`.

- [ ] **Step 1: Add intent publication without changing primary actions**

Extend `BarPill` with an opt-in hover signal or explicit callback property. Each actionable widget emits its intent on hover enter, updates the anchor while the bar layout changes, and emits close intent on hover leave. Preserve left click and wheel handlers exactly.

- [ ] **Step 2: Publish each widget's identity and state**

Use the existing `widgetId`, `instanceKey`, screen name, service state, and existing icon sources. For Tray, publish the hovered delegate's title/icon and model object reference in the payload. For the other widgets, publish their current state summary and action kind.

- [ ] **Step 3: Connect BarContent to the per-screen host**

Add one `BarPopupHost` instance alongside `BarContent` in the bar screen scope. Forward `BarContent` intents and provide screen width, effective bar position, effective height, and floating margin. Do not create a host per widget.

- [ ] **Step 4: Run lint and focused load validation**

Run: `/usr/lib/qt6/bin/qmllint modules/bar/BarContent.qml modules/bar/widgets/Tray.qml modules/bar/widgets/Volume.qml modules/bar/widgets/Brightness.qml modules/bar/widgets/Media.qml modules/bar/widgets/Notifications.qml`

Run: `qs -p shell.qml`

Expected: no `ERROR` or `Failed to load` output. Existing widget click/wheel behavior remains intact.

- [ ] **Step 5: Commit**

```bash
git add modules/bar/BarContent.qml modules/bar/widgets/Tray.qml modules/bar/widgets/Volume.qml modules/bar/widgets/Brightness.qml modules/bar/widgets/Media.qml modules/bar/widgets/Notifications.qml modules/bar/TopBar.qml
git commit -m "feat(bar): publish actionable widget hover intents"
```

---

### Task 5: Integrate slots, direction, and end-to-end verification

**Files:**
- Modify: `modules/bar/BarPopupHost.qml`
- Modify: `modules/bar/BarPopupActions.qml`
- Modify: `modules/bar/TopBar.qml`
- Create: `tst_bar_two_layer_popup.qml`

- [ ] **Step 1: Bind identity and actions to the host slots**

Set `sidebarData` to `BarPopupIdentity` using the intent's title/icon/summary. Set `contentData` to `BarPopupActions` using the intent's action kind and payload. Update the same popup instance in place when the hovered tray icon changes, so the host does not create overlapping windows.

- [ ] **Step 2: Verify top and bottom bar direction**

In the behavior harness, set `barPosition` to `top` and assert `direction === "down"` and content y is greater than identity y. Set it to `bottom` and assert `direction === "up"` and identity y is greater than content y. Also assert the popup remains inside the screen width after left and right edge anchors.

- [ ] **Step 3: Verify hover bridge and existing operations**

Exercise open, move from widget to popup, close after leaving both, and trigger representative volume/brightness/media/notification/tray action callbacks. Assert each callback fires once and primary widget click/wheel paths remain available.

- [ ] **Step 4: Run final validation**

Run: `QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_bar_hover_logic.qml -o -,txt`

Run: `QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_bar_popup_content.qml -o -,txt`

Run: `QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_two_layer_popup.qml -o -,txt`

Run: `qmllint modules/bar/BarPopupHost.qml modules/bar/BarPopupIdentity.qml modules/bar/BarPopupActions.qml modules/bar/BarPopupSlider.qml modules/bar/BarContent.qml modules/bar/TopBar.qml modules/bar/widgets/Tray.qml modules/bar/widgets/Volume.qml modules/bar/widgets/Brightness.qml modules/bar/widgets/Media.qml modules/bar/widgets/Notifications.qml`

Run: `qs -p tst_bar_two_layer_popup.qml`

Run: `git diff --check`

Expected: all pure tests pass, qs harness reports zero failures, lint has no errors, and the diff check is clean. The settings panel test remains subject to the known Quickshell plugin limitation documented in the previous abstraction work.

- [ ] **Step 5: Commit final integration**

```bash
git add modules/bar/BarPopupHost.qml modules/bar/BarPopupActions.qml modules/bar/TopBar.qml tst_bar_two_layer_popup.qml
git commit -m "feat(bar): connect actionable widgets to layered hover menus"
```

## Self-Review

- Spec coverage: actionable widget scope, identity/content layer roles, top/bottom direction, hover bridge, fixed owner geometry and tests are covered by Tasks 1-5.
- No old popup service/state machine is restored.
- The plan intentionally leaves clock and display-only widgets unchanged.
- Qt6 enum paths use `TwoLayerPopup.Orientation.*` and `TwoLayerPopup.Direction.*`.
- Existing dirty service/debug files are outside the plan and must not be staged.
