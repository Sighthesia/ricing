# Bar Transient Y-Reveal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build one shared bar-local Y-axis reveal contract so `SystemTrayWidget`, `WorkspaceWidget`, and `SuperIslandWidget` stop owning their own vertical reveal geometry and instead use one reusable host plus one registry-based bar extension path.

**Architecture:** Reuse the existing `BarExpandTransition.qml` as the expressive surface-height engine inside a new `BarTransientRevealHost.qml`, then add a registry-based transient extension API in `BarLayoutService.qml`. Migrate widgets one by one so semantic triggers remain local while `surfaceHeight`, `clipHeight`, and downward bar reservation become shared. Keep `MediaControlWidget.qml` on a temporary legacy extension bridge because it is outside this migration wave.

**Tech Stack:** Quickshell, QML, `BarExpandTransition.qml`, `BarLayoutService.qml`, bar widget components, QML harness verification, `timeout 5 qs --path .`

---

## File Structure

### New files

- `modules/bar/BarTransientRevealHost.qml`
  - Shared Y-axis geometry owner for transient bar reveal.
  - Wraps `BarExpandTransition.qml` for surface motion and owns `clipHeight`, `reservedExtension`, and host state.
- `tests/qml/bar/BarTransientRevealHostHarness.qml`
  - Mode-driven harness for registry, host, and migrated-widget contracts.
- `tests/run-bar-transient-reveal-harness.sh`
  - Thin runner for the bar transient reveal harness.

### Modified files

- `services/BarLayoutService.qml`
  - Add transient extension registry APIs and temporary legacy bridge behavior.
- `modules/bar/BarWindow.qml`
  - Consume `barTransientExtension` instead of the old aggregate field.
- `modules/bar/widgets/SystemTrayWidget.qml`
  - First migrated widget; adopts `BarTransientRevealHost.qml` for Y-axis reveal.
- `modules/bar/widgets/WorkspaceWidget.qml`
  - Moves clip/background/bar-extension ownership into the shared host while keeping horizontal identity.
- `modules/bar/widgets/SuperIslandWidget.qml`
  - Moves Y-axis reveal ownership into the shared host while preserving semantic phases and content replacement.

### Verified-but-not-modified unless the harness proves otherwise

- `modules/bar/BarExpandTransition.qml`
  - Reused internally by the new host; do not fork its motion math unless the harness exposes a real gap.
- `config/Theme.qml`
  - Existing `Theme.anim.barExpand*` tokens should remain the motion root for the shared host.
- `modules/bar/widgets/MediaControlWidget.qml`
  - Remains on the temporary legacy extension bridge in this wave.
- `modules/bar/widgets/SuperSystemMonitorWidget.qml`
  - Explicitly stays out of scope for this wave.

### Verification targets

- `tests/qml/bar/BarTransientRevealHostHarness.qml`
- `tests/run-bar-transient-reveal-harness.sh`
- `modules/bar/BarTransientRevealHost.qml`
- `services/BarLayoutService.qml`
- `modules/bar/BarWindow.qml`
- `modules/bar/widgets/SystemTrayWidget.qml`
- `modules/bar/widgets/WorkspaceWidget.qml`
- `modules/bar/widgets/SuperIslandWidget.qml`

---

### Task 1: Establish the harness and transient extension registry contract

**Files:**
- Create: `tests/qml/bar/BarTransientRevealHostHarness.qml`
- Create: `tests/run-bar-transient-reveal-harness.sh`
- Modify: `services/BarLayoutService.qml`
- Modify: `modules/bar/BarWindow.qml`

- [ ] **Step 1: Write the failing `registry` harness mode**

Create `tests/qml/bar/BarTransientRevealHostHarness.qml` with a mode switch and an initial `registry` contract. Start from this skeleton:

```qml
import Quickshell
import QtQuick
import qs.services

Item {
    id: root

    readonly property string mode:
        Quickshell.args.length > 0 ? String(Quickshell.args[0]) : "all"

    function assertTrue(condition, message) {
        if (!condition)
            throw new Error(message)
    }

    function runRegistryMode() {
        BarLayoutService.clearTransientExtension("tray")
        BarLayoutService.clearTransientExtension("workspace")
        BarLayoutService.setTransientExtension("tray", 10)
        BarLayoutService.setTransientExtension("workspace", 18)

        assertTrue(BarLayoutService.barTransientExtension === 18,
            "barTransientExtension should use the max registered height")

        BarLayoutService.clearTransientExtension("workspace")
        assertTrue(BarLayoutService.barTransientExtension === 10,
            "clearing one owner should expose the next registered height")

        BarLayoutService.clearTransientExtension("tray")
        assertTrue(BarLayoutService.barTransientExtension === 0,
            "clearing all owners should drop the aggregate extension to zero")
    }

    Component.onCompleted: {
        if (mode === "registry" || mode === "all")
            runRegistryMode()
        Qt.quit()
    }
}
```

- [ ] **Step 2: Add the concrete harness runner**

Create `tests/run-bar-transient-reveal-harness.sh`:

```bash
#!/usr/bin/env sh
set -eu

timeout 5 qs -p tests/qml/bar/BarTransientRevealHostHarness.qml -- "$@"
```

- [ ] **Step 3: Run the harness to verify the registry contract fails first**

Run:

```bash
sh tests/run-bar-transient-reveal-harness.sh registry
```

Expected: FAIL because `BarLayoutService.qml` does not yet expose `setTransientExtension()`, `clearTransientExtension()`, or `barTransientExtension`.

- [ ] **Step 4: Add registry-backed transient extension APIs to `BarLayoutService.qml`**

Add a focused registry section near the existing transient extension properties. Use concrete functions like:

```qml
property var _transientExtensions: ({})
readonly property var transientExtensions: _transientExtensions
readonly property int barTransientExtension:
    Math.max(_maxRegisteredTransientExtension(), mediaControlFlashExtension)

function setTransientExtension(ownerKey, height) {
    if (!ownerKey)
        return false

    const nextHeight = Math.max(0, Math.round(Number(height) || 0))
    const nextRegistry = Object.assign({}, _transientExtensions)

    if (nextHeight <= 0)
        delete nextRegistry[ownerKey]
    else
        nextRegistry[ownerKey] = nextHeight

    _transientExtensions = nextRegistry
    return true
}

function clearTransientExtension(ownerKey) {
    if (!ownerKey || _transientExtensions[ownerKey] === undefined)
        return false

    const nextRegistry = Object.assign({}, _transientExtensions)
    delete nextRegistry[ownerKey]
    _transientExtensions = nextRegistry
    return true
}
```

Also add one private helper that returns the maximum registered value without mutating service state.

- [ ] **Step 5: Keep a narrow legacy bridge for `MediaControlWidget.qml` only**

Do not migrate `MediaControlWidget.qml` in this wave. Keep `mediaControlFlashExtension` as the only temporary legacy contributor included in `barTransientExtension`.

Do not re-add `workspaceFlashExtension`, `superIslandFlashExtension`, or `systemTrayFlashExtension` once the registry exists.

- [ ] **Step 6: Update `modules/bar/BarWindow.qml` to consume the new aggregate**

Change the window height binding to:

```qml
implicitHeight: Theme.barHeight + BarLayoutService.barTransientExtension
```

Leave `exclusiveZone: Theme.barHeight` unchanged.

- [ ] **Step 7: Re-run the registry harness**

Run:

```bash
sh tests/run-bar-transient-reveal-harness.sh registry
```

Expected: PASS.

- [ ] **Step 8: Run the shell load check**

Run:

```bash
timeout 5 qs --path .
```

Expected: PASS aside from known environment warnings.

- [ ] **Step 9: Commit the registry foundation**

```bash
git add tests/qml/bar/BarTransientRevealHostHarness.qml tests/run-bar-transient-reveal-harness.sh services/BarLayoutService.qml modules/bar/BarWindow.qml
git commit -m "feat: add bar transient extension registry"
```

---

### Task 2: Add `BarTransientRevealHost.qml` on top of `BarExpandTransition.qml`

**Files:**
- Create: `modules/bar/BarTransientRevealHost.qml`
- Modify: `tests/qml/bar/BarTransientRevealHostHarness.qml`
- Verify: `modules/bar/BarExpandTransition.qml`

- [ ] **Step 1: Extend the harness with failing `host-open-close` and `host-retarget` modes**

Add two host-focused modes to `tests/qml/bar/BarTransientRevealHostHarness.qml`.

`host-open-close` should verify:

- first sync starts at the collapsed state without animation
- setting `expanded = true` snaps `clipHeight` to `expandedHeight`
- opening raises `reservedExtension` immediately to `expandedHeight - collapsedHeight`
- setting `expanded = false` leaves `reservedExtension` non-zero until close finishes
- the final closed state returns `surfaceHeight`, `clipHeight`, and `reservedExtension` to collapsed truth

`host-retarget` should verify:

- changing `expanded` while the host is running does not leave stale extension behind
- the host ends in the newest requested state instead of the earlier one

- [ ] **Step 2: Run the host harness to verify it fails before the component exists**

Run:

```bash
sh tests/run-bar-transient-reveal-harness.sh host-open-close
sh tests/run-bar-transient-reveal-harness.sh host-retarget
```

Expected: FAIL because `modules/bar/BarTransientRevealHost.qml` does not exist yet.

- [ ] **Step 3: Create `modules/bar/BarTransientRevealHost.qml` as an output-only geometry host**

Use this API shape exactly:

```qml
Item {
    required property real collapsedHeight
    required property real expandedHeight
    required property bool expanded
    required property string extensionOwnerKey

    property bool animateSurface: true

    readonly property string state
    readonly property real surfaceHeight
    readonly property real clipHeight
    readonly property real reservedExtension
    readonly property bool running
}
```

Implementation rules:

- first sync must be non-animated and immediately reflect the current `expanded` truth
- the host does not own caller `height` or `implicitHeight`; callers bind those from `surfaceHeight` and `clipHeight`
- `surfaceHeight` is driven by an internal `BarExpandTransition.qml` instance with `animateWidth: false`, `collapsedWidth: 1`, and `expandedWidth: 1`
- `clipHeight` snaps open to `expandedHeight` and closes back to `collapsedHeight` with one simple `NumberAnimation` using `Theme.anim.moveDuration` and `Theme.anim.moveType`
- `reservedExtension` becomes `Math.max(0, expandedHeight - collapsedHeight)` immediately when opening begins
- `reservedExtension` stays at the expanded reservation until the host finishes closing, then clears through `BarLayoutService.clearTransientExtension(extensionOwnerKey)` immediately before entering `closed`

- [ ] **Step 4: Encode the host state machine with only geometry states**

Implement and expose only these host states:

- `closed`
- `opening`
- `open`
- `closing`

Do not mirror widget-specific semantic phases inside the host.

- [ ] **Step 5: Write the registry side effects inside the host itself**

Whenever the host changes the effective reservation, call the service directly:

```qml
BarLayoutService.setTransientExtension(root.extensionOwnerKey, root.reservedExtension)
```

Guard every write with early returns so empty owner keys or unchanged values do not churn the service registry.

- [ ] **Step 6: Re-run the host harness modes**

Run:

```bash
sh tests/run-bar-transient-reveal-harness.sh host-open-close
sh tests/run-bar-transient-reveal-harness.sh host-retarget
```

Expected: PASS.

- [ ] **Step 7: Re-run the shell load check**

Run:

```bash
timeout 5 qs --path .
```

Expected: PASS aside from known environment warnings.

- [ ] **Step 8: Commit the shared host**

```bash
git add modules/bar/BarTransientRevealHost.qml tests/qml/bar/BarTransientRevealHostHarness.qml
git commit -m "feat: add shared bar transient reveal host"
```

---

### Task 3: Migrate `SystemTrayWidget.qml` as the first acceptance widget

**Files:**
- Modify: `modules/bar/widgets/SystemTrayWidget.qml`
- Modify: `tests/qml/bar/BarTransientRevealHostHarness.qml`
- Verify: `services/BarLayoutService.qml`
- Verify: `modules/bar/BarTransientRevealHost.qml`

- [ ] **Step 1: Extend the harness with a failing `tray` mode**

Add a `tray` mode that mounts `modules/bar/widgets/SystemTrayWidget.qml` and drives a reveal through widget-local semantics. The mode should verify:

- entering reveal causes `BarLayoutService.transientExtensions["system-tray"]` to become positive
- the widget's background height is sourced from the host's `surfaceHeight`
- hover reveal and flash reveal share the same Y-axis contract
- leaving reveal returns the registry entry to `undefined`

Use a direct method call if needed, for example:

```qml
trayWidget._enterHoverOpen()
```

because the goal is to verify geometry ownership, not pointer handling.

- [ ] **Step 2: Run the tray harness to verify it fails before migration**

Run:

```bash
sh tests/run-bar-transient-reveal-harness.sh tray
```

Expected: FAIL because `SystemTrayWidget.qml` still owns `implicitHeight`, background height, and legacy extension binding locally.

- [ ] **Step 3: Add `BarTransientRevealHost.qml` to `SystemTrayWidget.qml`**

Instantiate the host with these exact geometry inputs:

```qml
BarComponents.BarTransientRevealHost {
    id: _verticalReveal
    collapsedHeight: root._pillH
    expandedHeight: root._pillH + root._flashGap + root._flashRowH
    expanded: root._state !== "idle"
    extensionOwnerKey: root.liveInstance ? "system-tray" : ""
}
```

- [ ] **Step 4: Move all adopted Y-axis bindings onto the host outputs**

Update the widget so:

- pill clip height follows `_verticalReveal.clipHeight`
- pill background height follows `_verticalReveal.surfaceHeight`
- no local binding writes `systemTrayFlashExtension`
- local `Behavior on implicitHeight` and `Behavior on height` on the reveal path are removed

Keep width behavior and hover/flash timers because those are still semantic triggers and X-axis layout choices.

- [ ] **Step 5: Re-run the tray harness and shell load check**

Run:

```bash
sh tests/run-bar-transient-reveal-harness.sh tray
timeout 5 qs --path .
```

Expected: PASS.

- [ ] **Step 6: Commit the tray migration**

```bash
git add modules/bar/widgets/SystemTrayWidget.qml tests/qml/bar/BarTransientRevealHostHarness.qml
git commit -m "feat: migrate system tray to shared y-reveal host"
```

---

### Task 4: Migrate `WorkspaceWidget.qml` and simplify the Y-axis reveal path

**Files:**
- Modify: `modules/bar/widgets/WorkspaceWidget.qml`
- Modify: `tests/qml/bar/BarTransientRevealHostHarness.qml`
- Verify: `modules/bar/BarTransientRevealHost.qml`
- Verify: `services/BarLayoutService.qml`

- [ ] **Step 1: Extend the harness with a failing `workspace` mode**

The `workspace` mode should instantiate `modules/bar/widgets/WorkspaceWidget.qml` and verify:

- workspace switch reveal registers a positive transient extension under a workspace owner key
- the flash strip becomes visible by clip reveal, not by child-owned Y travel
- closing clears the registry entry only after the reveal completes
- width changes may still happen independently of the Y-axis path

- [ ] **Step 2: Run the workspace harness to verify it fails before migration**

Run:

```bash
sh tests/run-bar-transient-reveal-harness.sh workspace
```

Expected: FAIL because `WorkspaceWidget.qml` still owns Y-axis geometry through its clip shell, background, and legacy extension lock.

- [ ] **Step 3: Add `liveInstance` to `WorkspaceWidget.qml` if the file lacks it**

Match the existing `SystemTrayWidget.qml` and `SuperIslandWidget.qml` pattern so only the live bar instance can reserve downward bar space:

```qml
property bool liveInstance: false
```

Use `extensionOwnerKey: root.liveInstance ? "workspace-widget" : ""` in the shared host.

- [ ] **Step 4: Replace the legacy extension binding and local height-hold path**

Delete the `Binding` that writes `workspaceFlashExtension`.

Also remove `_holdFlashExtension` and any close-only geometry lock that exists solely to protect bar extension timing. That responsibility now belongs to the shared host.

- [ ] **Step 5: Pre-layout the transient strip and bind reveal geometry through the host**

Refactor the pill shell so:

- the stable pill row remains at the top of the clip shell
- the transient row stays laid out underneath from the start
- pill background height binds to `surfaceHeight`
- clip shell height binds to `clipHeight`

Keep the horizontal pill morph and content replacement semantics. Remove row travel that was only present to create or protect Y-axis reveal.

- [ ] **Step 6: Re-run the workspace harness and shell load check**

Run:

```bash
sh tests/run-bar-transient-reveal-harness.sh workspace
timeout 5 qs --path .
```

Expected: PASS.

- [ ] **Step 7: Commit the workspace migration**

```bash
git add modules/bar/widgets/WorkspaceWidget.qml tests/qml/bar/BarTransientRevealHostHarness.qml
git commit -m "feat: migrate workspace widget to shared y-reveal host"
```

---

### Task 5: Migrate `SuperIslandWidget.qml` without flattening semantic phases

**Files:**
- Modify: `modules/bar/widgets/SuperIslandWidget.qml`
- Modify: `tests/qml/bar/BarTransientRevealHostHarness.qml`
- Verify: `modules/bar/BarTransientRevealHost.qml`
- Verify: `services/BarLayoutService.qml`

- [ ] **Step 1: Extend the harness with a failing `super-island` mode**

The `super-island` mode should verify:

- entering a transient phase registers a positive extension under the super island owner key
- `surfaceHeight` and `clipHeight` come from the shared host instead of local phase-owned geometry
- semantic phase changes still determine content selection and emphasis
- closing clears the registry entry only after the host finishes closing

- [ ] **Step 2: Run the super-island harness to verify it fails before migration**

Run:

```bash
sh tests/run-bar-transient-reveal-harness.sh super-island
```

Expected: FAIL because `SuperIslandWidget.qml` still binds `superIslandFlashExtension` directly and owns Y-axis geometry in local phase logic.

- [ ] **Step 3: Add the shared host and route the existing height inputs through it**

Use the existing collapsed and expanded pill heights already computed by the widget:

```qml
BarComponents.BarTransientRevealHost {
    id: _verticalReveal
    collapsedHeight: root._collapsedPillHeight
    expandedHeight: root._expandedPillHeight
    expanded: root._pillExpanded
    extensionOwnerKey: root.liveInstance ? "super-island" : ""
}
```

- [ ] **Step 4: Move Y-axis ownership out of `_phase` and into the host outputs**

Specifically:

- remove the `Binding` that writes `superIslandFlashExtension`
- bind the visible pill shell and background heights to the host outputs
- keep `_phase` as the semantic driver for content choice, pulse, and replacement timing only
- remove or neutralize any local Y-axis binding that still changes final reveal height after the host is mounted

- [ ] **Step 5: Preserve semantic identity without reclaiming Y-axis geometry**

Keep these widget-local effects if they are still needed and do not own final reveal height:

- flash/main track opacity
- pulse overlays
- content replacement timing
- width personality

Do not keep local row travel or container height changes that would compete with the host.

- [ ] **Step 6: Re-run the super-island harness and shell load check**

Run:

```bash
sh tests/run-bar-transient-reveal-harness.sh super-island
timeout 5 qs --path .
```

Expected: PASS.

- [ ] **Step 7: Commit the super island migration**

```bash
git add modules/bar/widgets/SuperIslandWidget.qml tests/qml/bar/BarTransientRevealHostHarness.qml
git commit -m "feat: migrate super island to shared y-reveal host"
```

---

### Task 6: Remove migrated legacy extension fields and keep only the media bridge

**Files:**
- Modify: `services/BarLayoutService.qml`
- Modify: `tests/qml/bar/BarTransientRevealHostHarness.qml`
- Verify: `modules/bar/widgets/SystemTrayWidget.qml`
- Verify: `modules/bar/widgets/WorkspaceWidget.qml`
- Verify: `modules/bar/widgets/SuperIslandWidget.qml`
- Verify: `modules/bar/widgets/MediaControlWidget.qml`

- [ ] **Step 1: Extend the harness with a failing `cleanup` mode**

The `cleanup` mode should verify:

- the registry still aggregates correctly
- `mediaControlFlashExtension` remains available as the only temporary legacy bridge
- the service no longer exposes or depends on `workspaceFlashExtension`, `superIslandFlashExtension`, or `systemTrayFlashExtension`

- [ ] **Step 2: Run the cleanup harness to verify it fails before service cleanup**

Run:

```bash
sh tests/run-bar-transient-reveal-harness.sh cleanup
```

Expected: FAIL because the migrated widget-specific legacy fields still exist.

- [ ] **Step 3: Remove the migrated widget-specific legacy fields from `BarLayoutService.qml`**

Delete:

- `workspaceFlashExtension`
- `superIslandFlashExtension`
- `systemTrayFlashExtension`

Keep `mediaControlFlashExtension` and fold it into `barTransientExtension` until media control gets its own migration wave.

- [ ] **Step 4: Verify no runtime code still references the removed fields**

Run:

```bash
rg "workspaceFlashExtension|superIslandFlashExtension|systemTrayFlashExtension" modules services tests shell.qml config
```

Expected: no matches.

- [ ] **Step 5: Re-run the cleanup harness and shell load check**

Run:

```bash
sh tests/run-bar-transient-reveal-harness.sh cleanup
timeout 5 qs --path .
```

Expected: PASS.

- [ ] **Step 6: Commit the legacy cleanup**

```bash
git add services/BarLayoutService.qml tests/qml/bar/BarTransientRevealHostHarness.qml
git commit -m "refactor: remove migrated bar flash extension fields"
```

---

### Task 7: Final verification sweep and scope guard

**Files:**
- Verify: `tests/qml/bar/BarTransientRevealHostHarness.qml`
- Verify: `tests/run-bar-transient-reveal-harness.sh`
- Verify: `modules/bar/BarTransientRevealHost.qml`
- Verify: `services/BarLayoutService.qml`
- Verify: `modules/bar/BarWindow.qml`
- Verify: `modules/bar/widgets/SystemTrayWidget.qml`
- Verify: `modules/bar/widgets/WorkspaceWidget.qml`
- Verify: `modules/bar/widgets/SuperIslandWidget.qml`
- Verify: `modules/bar/widgets/MediaControlWidget.qml`
- Verify: `modules/bar/widgets/SuperSystemMonitorWidget.qml`

- [ ] **Step 1: Run the full transient reveal harness**

Run:

```bash
sh tests/run-bar-transient-reveal-harness.sh all
```

Expected: PASS.

- [ ] **Step 2: Run the shell load checks**

Run:

```bash
timeout 5 qs --path .
timeout 5 qs -p .
```

Expected: PASS aside from known environment warnings.

- [ ] **Step 3: Manually verify the first-wave acceptance criteria**

Check all of these in a live shell session:

- system tray flash reveal and hover reveal share one vertical reveal language
- workspace switch reveal no longer causes visible outer resize churn
- super island keeps semantic identity while its Y-axis reveal feels consistent with the other migrated widgets
- closing any migrated widget does not leave stale bar extension behind

- [ ] **Step 4: Confirm deferred scope stayed deferred**

Verify:

- `modules/bar/widgets/MediaControlWidget.qml` still uses the temporary bridge and was not otherwise redesigned in this wave
- `modules/bar/widgets/SuperSystemMonitorWidget.qml` was not given new reveal behavior just to widen the abstraction

- [ ] **Step 5: Write the execution handoff summary**

Record in the implementation PR or session handoff:

- which harness modes were added
- which widgets migrated successfully
- that media control remains the only temporary legacy bridge
- what future wave should migrate `MediaControlWidget.qml` and any new hover-reveal widgets
