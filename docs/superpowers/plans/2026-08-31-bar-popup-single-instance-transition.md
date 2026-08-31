# Bar Popup Single-Instance Transition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reuse one per-screen popup instance for hover and context intents while smoothly moving and resizing it, with old content fading out before the latest content fades in.

**Architecture:** Keep `BarPopupHost` as the sole popup owner and keep both content components mounted. `BarPopupHost` will own a small replacement state machine, separating the latest intent and target geometry from the currently displayed geometry. The full-screen `PanelWindow` stays fixed; interruptible animations run only on the inner `popupContainer`, and a host-owned opacity layer gates content during replacement.

**Tech Stack:** Quickshell `PanelWindow`, QtQuick QML `NumberAnimation`/`Timer`, existing `MotionTokens`, existing QtTest/QML harnesses.

## Global Constraints

- `BarPopupHost` remains the only per-screen popup owner.
- Hover and context intents use the same update path and content owner.
- The outer `PanelWindow` remains full-screen and fixed-size.
- Only the inner popup container geometry is animated.
- Use `MotionTokens.fast`, `MotionTokens.settingsSidebarFade`, and existing `Easing.OutQuint`/`Easing.InQuad`; do not add literal motion durations.
- Every new QML animation must honor `MotionTokens.reducedMotion`.
- Keep popup hover input non-blocking and disable menu interaction while replacement content is not fully visible.
- Preserve existing settings rail/section/card colors and reveal/close behavior.
- Do not modify unrelated worktree changes or temporary files.

## File Map

- Modify `modules/bar/BarPopupHost.qml`: own intent replacement sequencing, target/displayed geometry, content opacity, and retargetable animations.
- Do not modify `modules/bar/BarContent.qml`; its existing forwarding path already preserves one active intent during cross-type switching.
- Modify `tst_bar_popup_host.qml`: add behavior assertions for host reuse, replacement sequencing, geometry targets, opacity, and reduced motion.
- Do not modify `tests/qml/tst_bar_popup_content.qml`; the host harness owns the active-menu height contract for this feature.
- Do not modify `tests/qml/tst_bar_hover_logic.qml`; geometry and intent replacement remain host-owned behavior.
- Do not modify `modules/lazerbar/TwoLayerPopup.qml` unless tests prove its existing sibling-slot geometry cannot support the host-owned transition; it already keeps both layers mounted.

## Task 1: Establish Intent And Geometry Contracts

**Files:**
- Modify: `modules/bar/BarPopupHost.qml:20-70,142-168,265-365`
- Test: `tst_bar_popup_host.qml`

**Interfaces:**
- Consumes: existing `updateIntent(intentObj)`, `root.intent`, `root.anchorX`, `root.direction`, and popup slot implicit dimensions.
- Produces: `currentIntent`, `pendingIntent`, `transitionSerial`, `targetX`, `targetY`, `targetWidth`, and `targetHeight` properties; `updateTargetGeometry()` function used by later animation tasks.

- [ ] **Step 1: Add failing harness assertions for single-owner replacement.**

Add checks to the existing `TestCase` after the current popup host setup. The checks should call `host.updateIntent(volumeIntent)` and then `host.updateIntent(contextIntent)` without calling `dismissImmediately()`, and assert:

```qml
verify(host.open)
verify(host.surfaceActive)
compare(host.intent.widgetId, "notifications")
verify(host.popupItem === originalPopupItem)
```

Use two plain intent objects with valid `anchorX`, `screenWidth`, `screenHeight`, `effectiveBarHeight`, and `barPosition` fields so the test does not depend on live bar widgets.

- [ ] **Step 2: Run the focused harness and confirm the contract currently fails.**

Run:

```bash
timeout 25 qs -p tst_bar_popup_host.qml
```

Expected: the new replacement assertion fails because `root.intent` is still overwritten synchronously and no transition state exists.

- [ ] **Step 3: Add intent replacement state without changing visible behavior yet.**

Declare QML properties near the existing intent properties:

```qml
property var currentIntent: null
property var pendingIntent: null
property int transitionSerial: 0
property bool replacingContent: false
```

Add a helper that compares the meaningful target identity, including widget instance and menu kind:

```qml
function sameIntent(left, right) {
    if (!left || !right) return false
    return String(left.widgetId || "") === String(right.widgetId || "")
        && String(left.instanceKey || "") === String(right.instanceKey || "")
        && String(left.kind || "hover") === String(right.kind || "hover")
        && String(left.actionKind || "") === String(right.actionKind || "")
}
```

Update initial open bookkeeping so `currentIntent` is set on the first intent. During an already-open replacement, preserve the currently displayed intent until the content transition applies the pending target.

- [ ] **Step 4: Add pure target geometry calculation.**

Keep the existing horizontal clamp and top/bottom placement rules, but calculate them from explicit dimensions rather than directly binding `popupContainer` geometry. The helper contract is:

```qml
function popupHeightForIntent(intentObj) {
    return intentObj && String(intentObj.kind || "") === "context"
        ? contextPopupActions.implicitHeight
        : popupActions.implicitHeight
}
function targetGeometryFor(intentObj, width, height) {
    var left = BarHoverLogic.clampAnchor(anchorXForIntent(intentObj) - width / 2,
            width, activeScreenWidthForIntent(intentObj), 8)
    var top = directionForIntent(intentObj) === "down"
        ? barHeightForIntent(intentObj) + floatingMarginForIntent(intentObj)
        : Math.max(0, screenHeightForIntent(intentObj) - barHeightForIntent(intentObj)
            - floatingMarginForIntent(intentObj) - height)
    return { x: left, y: top, width: width, height: height }
}
```

`popupHeightForIntent()` must select `BarPopupActions.implicitHeight` for hover intents and `BarContextPopupActions.implicitHeight` for context intents, with the existing minimum width of `240` and the content slot width of `260`. It must not use `Math.max()` across both menus.

The `anchorXForIntent()`, `activeScreenWidthForIntent()`,
`directionForIntent()`, `barHeightForIntent()`, `floatingMarginForIntent()`,
and `screenHeightForIntent()` helpers must read validated values from the
intent object, falling back to the host's existing active values when a field
is absent or invalid.

- [ ] **Step 5: Run the focused harness and commit the contract change.**

Run:

```bash
timeout 25 qs -p tst_bar_popup_host.qml
```

Expected: the new ownership assertion passes, while animation-specific assertions remain pending. Commit only the host and harness changes:

```bash
git add modules/bar/BarPopupHost.qml tst_bar_popup_host.qml
git commit -m "feat(bar): track popup replacement intent separately"
```

## Task 2: Animate Popup Geometry Without Resizing The Surface

**Files:**
- Modify: `modules/bar/BarPopupHost.qml:265-307`
- Test: `tst_bar_popup_host.qml`

**Interfaces:**
- Consumes: `targetGeometryFor(intentObj, width, height)` and `currentIntent` from Task 1.
- Produces: `displayX`, `displayY`, `displayWidth`, `displayHeight`, plus retargetable geometry animations.

- [ ] **Step 1: Add failing geometry assertions.**

Capture the fixed outer host dimensions, send two intents with distinct anchors and menu kinds, then assert that target geometry changes while the outer host remains screen-sized:

```qml
var outerWidth = host.width
var outerHeight = host.height
host.updateIntent(firstIntent)
var firstX = host.popupContainerItem.x
host.updateIntent(secondIntent)
verify(host.targetX !== firstX)
compare(host.width, outerWidth)
compare(host.height, outerHeight)
```

The test should also assert that bottom-bar target Y uses the target height, not the old displayed height.

- [ ] **Step 2: Run the test and confirm direct bindings do not satisfy it.**

Run:

```bash
timeout 25 qs -p tst_bar_popup_host.qml
```

Expected: the new target/displayed geometry assertions fail because the current container has no separate target properties or animation retargeting.

- [ ] **Step 3: Replace direct container geometry bindings with displayed properties.**

Add properties initialized from the current container geometry:

```qml
property real displayX: 0
property real displayY: 0
property real displayWidth: 240
property real displayHeight: 1
property real targetX: 0
property real targetY: 0
property real targetWidth: 240
property real targetHeight: 1
```

Bind the container to displayed properties only:

```qml
x: root.displayX
width: root.displayWidth
height: root.displayHeight
```

Set `targetWidth` from the actual popup slot width and `targetHeight` from the selected menu’s measured implicit height plus the existing layer divider geometry. Keep a minimum width of `240`.

- [ ] **Step 4: Add interruptible animations and a target retarget function.**

Create one `NumberAnimation` per displayed geometry property, all with `target: root`, `property` set to the matching displayed property, and duration `MotionTokens.reducedMotion ? 0 : MotionTokens.medium` using `Easing.OutQuint`. Add:

```qml
function retargetGeometry() {
    var geometry = targetGeometryFor(currentIntent || root.intent,
            targetWidth, targetHeight)
    targetX = geometry.x
    targetY = geometry.y
    if (MotionTokens.reducedMotion) {
        displayX = targetX
        displayY = targetY
        displayWidth = targetWidth
        displayHeight = targetHeight
        return
    }
    xMotion.to = targetX
    yMotion.to = targetY
    widthMotion.to = targetWidth
    heightMotion.to = targetHeight
    xMotion.restart()
    yMotion.restart()
    widthMotion.restart()
    heightMotion.restart()
}
```

Use the current animation value when retargeting; do not reset displayed properties to the old target. Keep the outer `PanelWindow` `implicitWidth` and `implicitHeight` unchanged.

- [ ] **Step 5: Run geometry tests and commit.**

Run:

```bash
timeout 25 qs -p tst_bar_popup_host.qml
```

Expected: all existing checks plus the new target/outer-surface checks pass. Commit:

```bash
```

## Task 3: Implement Interruptible Content Crossfade

**Files:**
- Modify: `modules/bar/BarPopupHost.qml:142-168,319-365`
- Test: `tst_bar_popup_host.qml`

**Interfaces:**
- Consumes: `pendingIntent`, `transitionSerial`, `currentIntent`, and geometry retargeting from Tasks 1-2.
- Produces: `contentOpacity`, `contentInteractive`, `beginIntentReplacement(intentObj)`, and a single fade-out completion path.

- [ ] **Step 1: Add failing tests for hover/context and rapid replacement.**

Add harness tests that:

```qml
host.updateIntent(hoverIntent)
host.updateIntent(contextIntent)
verify(host.open)
verify(host.replacingContent)
compare(host.pendingIntent.kind, "context")
```

Then send a third intent before the fade completes and verify that the latest intent is the only pending target. Add a reduced-motion case that verifies `root.intent` changes immediately and `contentOpacity === 1`.

- [ ] **Step 2: Run focused tests and confirm they fail.**

Run:

```bash
timeout 25 qs -p tst_bar_popup_host.qml
```

Expected: `replacingContent`, `pendingIntent`, and `contentOpacity` do not yet implement the required behavior.

- [ ] **Step 3: Add a host-owned content opacity layer.**

Set the existing `popupContentSlot` opacity to `root.contentOpacity` and its `enabled` property to `contentInteractive`; do not add another wrapper that could alter `TwoLayerPopup` childrenRect measurement. Keep `popupActions` and `contextPopupActions` mounted exactly once. Set `contentInteractive` true only when opacity is effectively one and the popup is fully revealed.

Add:

```qml
property real contentOpacity: 1
readonly property bool contentInteractive:
    contentOpacity > 0.99 && popup.interactable
```

Do not use `visible` as the crossfade state; preserve the effective-visibility cycle fix.

- [ ] **Step 4: Implement serialised fade-out, replacement, and fade-in.**

Use a single `NumberAnimation` on `contentOpacity` with `MotionTokens.fast`. The replacement function must increment `transitionSerial`, store the latest `pendingIntent`, stop/restart the current fade, and capture the serial locally:

```qml
function beginIntentReplacement(intentObj) {
    pendingIntent = intentObj
    transitionSerial += 1
    var serial = transitionSerial
    if (MotionTokens.reducedMotion) {
        applyPendingIntent(serial)
        return
    }
    replacingContent = true
    contentFade.to = 0
    contentFade.restart()
    replacementTimer.restart()
}
```

At timer completion, call `applyPendingIntent(serial)`. It must return when the serial is stale, assign `currentIntent` and `root.intent` only for the newest target, clear `pendingIntent`, call `retargetGeometry()`, then animate opacity back to one. This prevents an old fade completion from writing stale menu data.

- [ ] **Step 5: Route `updateIntent()` through the replacement state machine.**

The first intent sets `currentIntent`, `root.intent`, activates the host, and starts the existing reveal. A meaningful change while open calls `beginIntentReplacement()`. An anchor-only update for the same widget instance updates `root.intent` and calls `retargetGeometry()` without crossfading content. Both hover and context intents must use this same branch.

- [ ] **Step 6: Run the crossfade tests and commit.**

Run:

```bash
timeout 25 qs -p tst_bar_popup_host.qml
```

Expected: zero failures and no QML warnings/errors. Commit:

```bash
```

## Task 4: Preserve Close, Reopen, And Context Action Behavior

**Files:**
- Modify: `modules/bar/BarPopupHost.qml:136-197,221-263`
- Verify: `modules/bar/BarContent.qml` remains unchanged; its forwarding path must continue to feed both intent types into the host.
- Test: `tst_bar_popup_host.qml`, `tst_bar_two_layer_popup.qml`, `tst_bar_context_popup_actions.qml`

**Interfaces:**
- Consumes: the replacement state machine and geometry animation APIs from Tasks 1-3.
- Produces: stable close/reopen behavior and explicit regression coverage for both menu kinds.

- [ ] **Step 1: Add close/reopen regression scenarios.**

Verify that an intent arriving while `closeTimer` or exit reveal is active cancels the pending close and keeps the same `popupItem` object. Verify that `dismissImmediately()` still clears all intent and transition state immediately.

- [ ] **Step 2: Ensure close retains content until exit reveal completes.**

Do not clear `currentIntent` or `root.intent` from `requestClose()` or the close timer. Clear `pendingIntent`, stop content fade, and reset content opacity only in `dismissImmediately()` or after `clearIntentTimer` completes with `open === false`. An incoming intent must call `cancelClose()` before replacement logic.

- [ ] **Step 3: Verify context action callbacks still operate during the reused instance.**

Exercise context menu actions after a hover-to-context replacement and after a context-to-context replacement. The action callback must still receive the latest `instanceKey`, section, and widget ID, and `close` must still invoke `dismissImmediately()`.

- [ ] **Step 4: Run the full focused popup suite and commit.**

Run:

```bash
timeout 25 qs -p tst_bar_popup_host.qml
```

Expected: all checks pass with no WARN/ERROR output. Commit:

```bash
```

## Task 5: Final Static And Runtime Verification

**Files:**
- Verify: `modules/bar/BarPopupHost.qml`, `modules/bar/BarContent.qml`, `tst_bar_popup_host.qml`, `tst_bar_two_layer_popup.qml`

- [ ] **Step 1: Run static checks on every changed QML file.**

Run:

```bash
qmllint modules/bar/BarPopupHost.qml modules/bar/BarContent.qml
```

Expected: no warnings or errors.

- [ ] **Step 2: Run all relevant tests again from a clean process.**

Run:

```bash
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_bar_hover_logic.qml -o -,txt
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_bar_popup_content.qml -o -,txt
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_bar_context_popup_actions.qml -o -,txt
timeout 25 qs -p tst_bar_popup_host.qml
```

Expected: zero failures, zero warnings/errors.

- [ ] **Step 3: Verify shell startup without modifying unrelated files.**

Run:

```bash
```

Expected: `Configuration Loaded` and no QML `ERROR`/`WARN` lines.

- [ ] **Step 4: Manually verify interaction.**

With the shell running, sweep the pointer across volume, brightness, media, notifications, and tray. Confirm one popup moves continuously, its body morphs to each menu’s required height, old content fades before new content appears, and no second popup surface flashes. Repeat for right-click context menus and for a bottom-positioned bar.

- [ ] **Step 5: Inspect status and commit any final test-only adjustment separately.**

Run:

```bash
```

Only intended files may be included in any final adjustment commit. Do not stage the pre-existing Active Window change or temporary media/debug files.

## Self-Review

- Initial open, replacement, rapid latest-wins behavior, reduced motion, close/reopen, and hard dismissal are covered by Tasks 1-4.
- Geometry is separated into target and displayed domains, and the outer layer-shell surface remains fixed in Task 2.
- Both hover and context paths share `updateIntent()` and the same content owner in Task 3.
- The plan contains no new popup owner, no extra window, no spring/bounce, and no unrelated styling changes.
- No placeholder steps or undefined helper names remain; helper names and property names are introduced before later tasks consume them.
