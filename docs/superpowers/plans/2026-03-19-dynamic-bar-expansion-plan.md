# Dynamic Bar Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build one reusable expand/collapse motion layer for dynamic bar widgets so `SuperIsland` and `WorkspaceWidget` share the same reverse-preload, overshoot, settle, and pulse language in the first execution wave.

**Architecture:** Keep business state in existing widgets and services, but move geometry ownership for adopted axes into a new bar-local transition component. Derive all shared motion semantics from `Theme.anim.*` plus a small global `barMotion` settings section, then migrate widgets one by one starting with `SuperIslandWidget.qml`.

**Tech Stack:** Quickshell, QML, `Theme.qml`, `SettingsService.qml`, bar widget components, QML harness verification, `timeout 5 qs --path .`

---

## File Structure

### New files

- `modules/bar/BarExpandTransition.qml`
  - Shared expand/collapse motion driver for bar widgets.
  - Owns width/height overshoot choreography and pulse timing.
- `modules/bar/widgetsettings/BarMotionSection.qml`
  - Global widget-settings section for motion preset, intensity, speed, and pulse toggle.
- `tests/qml/bar/BarExpandTransitionHarness.qml`
  - Minimal QML harness that exercises expand/collapse phases and assertions.
- `tests/run-bar-motion-harness.sh`
  - Thin runner script for local bar-motion harness execution.

### Modified files

- `config/Theme.qml`
  - Add semantic `Theme.anim.barExpand*` tokens derived from existing `Theme.anim.*`.
- `config/settings-default.json`
  - Add default `barMotion` settings.
- `services/SettingsService.qml`
  - Add `barMotion` schema fields and persistence.
- `modules/bar/WidgetSettingsPanel.qml`
  - Insert a cross-widget shared motion section into the functional settings group.
- `modules/bar/widgets/SuperIslandWidget.qml`
  - Hand pill width/height and pulse ownership to `BarExpandTransition.qml`.
- `modules/bar/widgets/WorkspaceWidget.qml`
  - Hand morph width and any adopted pulse behavior to `BarExpandTransition.qml`.
- `modules/bar/widgets/SuperSystemMonitorWidget.qml`
  - Remains unchanged in the first execution wave because it does not yet have real expand/collapse geometry to migrate.

### Verification targets

- `tests/qml/bar/BarExpandTransitionHarness.qml`
- `tests/run-bar-motion-harness.sh`
- `modules/bar/widgets/SuperIslandWidget.qml`
- `modules/bar/widgets/WorkspaceWidget.qml`
- `modules/bar/WidgetSettingsPanel.qml`
- `config/Theme.qml`
- `services/SettingsService.qml`
- `config/settings-default.json`

---

### Task 1: Formalize the harness contract and add shared motion tokens and persisted settings

**Files:**
- Modify: `config/Theme.qml`
- Modify: `config/settings-default.json`
- Modify: `services/SettingsService.qml`

- [ ] **Step 1: Write the failing harness expectation for missing bar-motion tokens and settings**

Create `tests/qml/bar/BarExpandTransitionHarness.qml` with an initial assertion block that reads:

```qml
import QtQuick
import "../../../modules/bar"
import qs.config
import qs.services

Item {
    Component.onCompleted: {
        if (Theme.anim.barExpandExpandOvershootRatio === undefined)
            throw new Error("missing Theme.anim.barExpand* tokens")

        if (!SettingsService.data.barMotion)
            throw new Error("missing SettingsService.data.barMotion")

        Qt.quit()
    }
}
```

- [ ] **Step 2: Add the concrete harness runner script**

Create `tests/run-bar-motion-harness.sh` so the harness can be run from repo root with a named mode:

```bash
#!/usr/bin/env sh
set -eu
timeout 5 qs -p tests/qml/bar/BarExpandTransitionHarness.qml -- "$@"
```

Inside `BarExpandTransitionHarness.qml`, read the requested mode from `Quickshell.args` and branch assertions by mode such as `settings`, `timeline`, `super-island`, `workspace`, and `all`.

- [ ] **Step 3: Run the harness to verify it fails for the expected reason**

Run:

```bash
sh tests/run-bar-motion-harness.sh settings
```

Expected: FAIL with missing `Theme.anim.barExpand*` or missing `SettingsService.data.barMotion`.

- [ ] **Step 4: Add default `barMotion` settings to `config/settings-default.json`**

Add:

```json
"barMotion": {
  "preset": "balanced",
  "intensity": 1.0,
  "speedMultiplier": 1.0,
  "pulseEnabled": true
}
```

- [ ] **Step 5: Add persisted `barMotion` fields to `services/SettingsService.qml`**

Update both the serialized write object and the `JsonAdapter` defaults so these exact fields exist:

```qml
property JsonObject barMotion: JsonObject {
    property string preset: "balanced"
    property real intensity: 1.0
    property real speedMultiplier: 1.0
    property bool pulseEnabled: true
}
```

- [ ] **Step 6: Add semantic `Theme.anim.barExpand*` tokens to `config/Theme.qml`**

Derive the new tokens from the existing animation root. Add only semantic aliases and ratios, for example:

```qml
readonly property int barExpandPreloadDuration:
    Math.max(1, Math.round(moveDuration * 0.28 / SettingsService.data.barMotion.speedMultiplier))
readonly property int barExpandOvershootDuration:
    Math.max(1, Math.round(springDuration * 0.52 / SettingsService.data.barMotion.speedMultiplier))
readonly property int barExpandSettleDuration:
    Math.max(1, Math.round(moveDuration * 0.36 / SettingsService.data.barMotion.speedMultiplier))
readonly property real barExpandExpandPreloadRatio: 0.06 * SettingsService.data.barMotion.intensity
readonly property real barExpandExpandOvershootRatio: 0.12 * SettingsService.data.barMotion.intensity
readonly property real barExpandCollapsePreloadRatio: 0.05 * SettingsService.data.barMotion.intensity
readonly property real barExpandCollapseOvershootRatio: 0.08 * SettingsService.data.barMotion.intensity
```

Use existing `moveType`, `springType`, `highlightType`, and overshoot values as the root semantics unless a clearly named derived alias is needed.

- [ ] **Step 7: Re-run the harness to verify the new tokens and settings exist**

Run:

```bash
sh tests/run-bar-motion-harness.sh settings
```

Expected: PASS.

- [ ] **Step 8: Commit the token/settings foundation**

```bash
git add tests/qml/bar/BarExpandTransitionHarness.qml tests/run-bar-motion-harness.sh config/Theme.qml config/settings-default.json services/SettingsService.qml
git commit -m "feat: add shared bar motion tokens and settings"
```

---

### Task 2: Add the global motion settings section before widget migration

**Files:**
- Create: `modules/bar/widgetsettings/BarMotionSection.qml`
- Modify: `modules/bar/WidgetSettingsPanel.qml`
- Verify: `services/SettingsService.qml`
- Modify: `tests/qml/bar/BarExpandTransitionHarness.qml`

- [ ] **Step 1: Extend the failing `settings` harness mode with UI-level expectations**

Encode these expected shared controls in the `settings` mode:

- preset selector
- intensity slider
- speed slider
- pulse toggle

- [ ] **Step 2: Run the `settings` harness to verify the shared motion section is still absent**

Run:

```bash
sh tests/run-bar-motion-harness.sh settings
```

Expected: FAIL because the shared motion section is not mounted yet.

- [ ] **Step 3: Create `modules/bar/widgetsettings/BarMotionSection.qml`**

Follow existing widget-settings conventions and bind directly to:

```qml
SettingsService.data.barMotion.preset
SettingsService.data.barMotion.intensity
SettingsService.data.barMotion.speedMultiplier
SettingsService.data.barMotion.pulseEnabled
```

- [ ] **Step 4: Mount the new shared section in `modules/bar/WidgetSettingsPanel.qml`**

Place it in the functional group as a cross-widget block, not behind a widget-specific loader.

- [ ] **Step 5: Re-run the `settings` harness**

Run:

```bash
sh tests/run-bar-motion-harness.sh settings
```

Expected: PASS.

- [ ] **Step 6: Run the repo load check**

Run:

```bash
timeout 5 qs --path .
```

Expected: PASS aside from known environment warnings.

- [ ] **Step 7: Commit the settings panel work**

```bash
git add modules/bar/widgetsettings/BarMotionSection.qml modules/bar/WidgetSettingsPanel.qml services/SettingsService.qml tests/qml/bar/BarExpandTransitionHarness.qml tests/run-bar-motion-harness.sh
git commit -m "feat: add shared bar motion settings section"
```

---

### Task 3: Build the shared transition component and prove its phases

**Files:**
- Create: `modules/bar/BarExpandTransition.qml`
- Modify: `tests/qml/bar/BarExpandTransitionHarness.qml`
- Verify: `tests/run-bar-motion-harness.sh`

- [ ] **Step 1: Extend the harness with a failing expand/collapse phase test**

Expand the harness so it mounts `BarExpandTransition.qml` with simple geometry targets:

```qml
BarExpandTransition {
    id: transition
    collapsedWidth: 100
    expandedWidth: 160
    collapsedHeight: 32
    expandedHeight: 64
    expanded: false
    animateWidth: true
    animateHeight: true
}
```

Add timed assertions that expect:

- width briefly goes below `100` before expansion
- width later exceeds `160` before settling
- height briefly exceeds `64` before collapse starts to shrink
- collapse briefly goes below `100` and `32` before settling back

- [ ] **Step 2: Run the `timeline` harness to verify it fails because the shared component does not exist yet**

Run:

```bash
sh tests/run-bar-motion-harness.sh timeline
```

Expected: FAIL with missing component or missing animated property assertions.

- [ ] **Step 3: Implement the minimal shared component in `modules/bar/BarExpandTransition.qml`**

Create a focused component that:

- exposes the geometry-first API from the spec
- treats `expanded` as the only normal runtime truth source
- outputs `animatedWidth`, `animatedHeight`, `pulseOpacity`, `pulseScale`, and `running`
- uses a three-phase timeline for expand and collapse
- uses `snapToExpanded()` and `snapToCollapsed()` only as lifecycle escape hatches

Recommended structure:

```qml
import QtQuick
import qs.config

QtObject {
    id: root
    required property real collapsedWidth
    required property real expandedWidth
    required property real collapsedHeight
    required property real expandedHeight
    property bool expanded: false
    property bool animateWidth: true
    property bool animateHeight: true
    readonly property real animatedWidth: _animatedWidth
    readonly property real animatedHeight: _animatedHeight
    readonly property real pulseOpacity: _pulseOpacity
    readonly property real pulseScale: _pulseScale
    readonly property bool running: _timeline.running
    property real _animatedWidth: collapsedWidth
    property real _animatedHeight: collapsedHeight
    property real _pulseOpacity: 0
    property real _pulseScale: 1
}
```

Use `SequentialAnimation` and `ParallelAnimation` internally, and keep the file focused on geometry ownership only.

- [ ] **Step 4: Re-run the `timeline` harness to verify the shared component passes**

Run:

```bash
sh tests/run-bar-motion-harness.sh timeline
```

Expected: PASS.

- [ ] **Step 5: Refactor only if the shared component has duplicate phase math**

If needed, extract tiny internal helpers for:

- target interpolation
- phase ratio calculation
- pulse reset

Do not add widget-specific conditionals.

- [ ] **Step 6: Commit the shared transition layer**

```bash
git add modules/bar/BarExpandTransition.qml tests/qml/bar/BarExpandTransitionHarness.qml tests/run-bar-motion-harness.sh
git commit -m "feat: add reusable bar expansion transition"
```

---

### Task 4: Migrate `SuperIslandWidget.qml` to shared geometry ownership

**Files:**
- Modify: `modules/bar/widgets/SuperIslandWidget.qml`
- Verify: `modules/bar/BarExpandTransition.qml`
- Verify: `tests/qml/bar/BarExpandTransitionHarness.qml`

- [ ] **Step 1: Add a failing `super-island` harness mode**

Extend `tests/qml/bar/BarExpandTransitionHarness.qml` with a dedicated `super-island` mode that instantiates `modules/bar/widgets/SuperIslandWidget.qml` and encodes the critical regression expectation:

- restore width and height start together
- the pill still performs reverse preload and overshoot
- flash-track content choreography remains separate from geometry ownership

- [ ] **Step 2: Run the `super-island` harness to verify current `SuperIslandWidget.qml` still owns conflicting geometry paths**

Run:

```bash
sh tests/run-bar-motion-harness.sh super-island
```

Expected: FAIL because `SuperIslandWidget.qml` still owns local width/height animation contracts.

- [ ] **Step 3: Replace pill geometry ownership with `BarExpandTransition.qml`**

In `modules/bar/widgets/SuperIslandWidget.qml`:

- feed collapsed and expanded pill dimensions into the shared transition layer
- use the transition output for pill width and pill background height
- route shared pulse output into the existing pulse/highlight surface
- keep flash-track, replacement, and content handoff animations widget-local

- [ ] **Step 4: Remove duplicated local geometry animations for adopted axes**

Specifically remove or disable any local owner for the adopted width and height paths, such as:

- `Behavior on implicitWidth`
- `Behavior on width`
- `_pillExpandAnim` / `_pillCollapseAnim` if replaced by shared ownership
- any conflicting geometry writes during restore/collapse

Do not remove flash-track content animations that do not own final widget geometry.

- [ ] **Step 5: Run the `super-island` harness again**

Run:

```bash
sh tests/run-bar-motion-harness.sh super-island
```

Expected: PASS.

- [ ] **Step 6: Run the repo load check**

Run:

```bash
timeout 5 qs --path .
```

Expected: PASS aside from known environment warnings.

- [ ] **Step 7: Commit the SuperIsland migration**

```bash
git add modules/bar/widgets/SuperIslandWidget.qml modules/bar/BarExpandTransition.qml tests/qml/bar/BarExpandTransitionHarness.qml tests/run-bar-motion-harness.sh
git commit -m "feat: migrate super island to shared bar motion"
```

---

### Task 5: Migrate `WorkspaceWidget.qml` with horizontal bias

**Files:**
- Modify: `modules/bar/widgets/WorkspaceWidget.qml`
- Verify: `modules/bar/BarExpandTransition.qml`
- Verify: `tests/qml/bar/BarExpandTransitionHarness.qml`

- [ ] **Step 1: Add a failing `workspace` harness mode**

Capture the intended behavior:

- width uses reverse preload and overshoot
- height stays fixed unless explicitly adopted
- pulse remains synchronized with the forward beat

Keep this in `tests/qml/bar/BarExpandTransitionHarness.qml` as a dedicated `workspace` mode so the verification path stays fixed.

- [ ] **Step 2: Run the `workspace` harness to confirm it fails before migration**

Run:

```bash
sh tests/run-bar-motion-harness.sh workspace
```

Expected: FAIL because width animation is still local to `WorkspaceWidget.qml`.

- [ ] **Step 3: Route workspace morph geometry through `BarExpandTransition.qml`**

In `modules/bar/widgets/WorkspaceWidget.qml`:

- compute collapsed and expanded targets from the existing focus/overview pill logic
- adopt shared width animation ownership
- keep height fixed unless the implementation clearly benefits from shared height ownership
- wire pulse output into the existing focus pulse or a shared highlight layer

- [ ] **Step 4: Remove the local width-owner path for the adopted axis**

Remove or disable the existing `Behavior` / explicit width animations that would double-drive the same width path.

- [ ] **Step 5: Re-run the `workspace` harness**

Run:

```bash
sh tests/run-bar-motion-harness.sh workspace
```

Expected: PASS.

- [ ] **Step 6: Re-run the repo load check**

Run:

```bash
timeout 5 qs --path .
```

Expected: PASS aside from known environment warnings.

- [ ] **Step 7: Commit the Workspace migration**

```bash
git add modules/bar/widgets/WorkspaceWidget.qml modules/bar/BarExpandTransition.qml tests/qml/bar/BarExpandTransitionHarness.qml tests/run-bar-motion-harness.sh
git commit -m "feat: migrate workspace widget to shared bar motion"
```

---

### Task 6: Record `SuperSystemMonitorWidget.qml` as deferred follow-up

**Files:**
- Verify: `modules/bar/widgets/SuperSystemMonitorWidget.qml`
- Verify: `docs/superpowers/specs/2026-03-19-dynamic-bar-expansion-design.md`
- Modify: `docs/superpowers/plans/2026-03-19-dynamic-bar-expansion-plan.md`

- [ ] **Step 1: Verify the current widget is static and has no expand/collapse state to migrate**

Inspect `modules/bar/widgets/SuperSystemMonitorWidget.qml` and confirm it currently has:

- no expanded/collapsed state
- no width/height transition ownership
- no existing geometry-based dynamic behavior

- [ ] **Step 2: Keep the first execution wave scoped to real dynamic widgets only**

Document that `SuperSystemMonitorWidget.qml` stays out of this execution wave and becomes a later adoption task only after a separate product decision introduces real geometry transitions.

- [ ] **Step 3: Do not invent new product behavior in this plan**

Ensure no implementation task in this plan adds expansion behavior to `SuperSystemMonitorWidget.qml` just to satisfy abstraction breadth.

---

### Task 7: Final verification sweep

**Files:**
- Verify: `modules/bar/BarExpandTransition.qml`
- Verify: `modules/bar/widgets/SuperIslandWidget.qml`
- Verify: `modules/bar/widgets/WorkspaceWidget.qml`
- Verify: `modules/bar/widgetsettings/BarMotionSection.qml`
- Verify: `modules/bar/WidgetSettingsPanel.qml`
- Verify: `config/Theme.qml`
- Verify: `services/SettingsService.qml`
- Verify: `config/settings-default.json`
- Verify: `tests/qml/bar/BarExpandTransitionHarness.qml`
- Verify: `tests/run-bar-motion-harness.sh`

- [ ] **Step 1: Run the shared harness**

Run:

```bash
sh tests/run-bar-motion-harness.sh all
```

Expected: PASS.

- [ ] **Step 2: Run the full shell load check**

Run:

```bash
timeout 5 qs --path .
```

Expected: PASS aside from known environment warnings.

- [ ] **Step 3: Manually inspect the three migrated widgets**

Confirm:

- expand shows reverse preload, overshoot, and settle
- collapse shows reverse preload, inward overshoot, and settle
- pulse starts with the forward beat
- no width/height desynchronization appears in `SuperIsland`
- `WorkspaceWidget` remains lighter and mostly horizontal

- [ ] **Step 4: Confirm the deferred scope stayed deferred**

Verify `modules/bar/widgets/SuperSystemMonitorWidget.qml` was not modified as part of this execution wave.

- [ ] **Step 5: Commit the final verification state if any follow-up edits were needed**

```bash
git add modules/bar/BarExpandTransition.qml modules/bar/widgets/SuperIslandWidget.qml modules/bar/widgets/WorkspaceWidget.qml modules/bar/widgetsettings/BarMotionSection.qml modules/bar/WidgetSettingsPanel.qml config/Theme.qml services/SettingsService.qml config/settings-default.json tests/qml/bar/BarExpandTransitionHarness.qml tests/run-bar-motion-harness.sh docs/superpowers/plans/2026-03-19-dynamic-bar-expansion-plan.md
git commit -m "test: verify shared dynamic bar expansion motion"
```
