# Animated Panel Exclusion Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ensure every `AnimatedPanelBase` drop-down panel behaves as a true overlay and never reserves compositor layout space.

**Architecture:** Fix the bug at the shared base by giving `AnimatedPanelBase` a default non-excluding layer-shell policy. Guard the behavior with a structure smoke assertion so future animated panels inherit the correct compositor contract automatically.

**Tech Stack:** QML, Quickshell `PanelWindow`, `Quickshell.Wayland.WlrLayershell`, existing smoke harnesses

---

### Task 1: Add a failing structural regression test

**Files:**
- Modify: `tests/qml/SettingsStructureSmoke.qml`

**Step 1: Write the failing test**

Instantiate a minimal `AnimatedPanelBase` in the smoke harness and assert it exposes the expected exclusion policy.

```qml
    BarParts.AnimatedPanelBase {
        id: animatedPanelBase
        visible: false
    }

    root._assert(animatedPanelBase.exclusionMode === ExclusionMode.Ignore,
        "AnimatedPanelBase should ignore compositor exclusion by default")
```

**Step 2: Run test to verify it fails**

Run: `timeout 12 qs -p tests/qml/SettingsStructureSmoke.qml`

Expected: FAIL on the new exclusion assertion.

**Step 3: Write minimal implementation**

Do not touch subtype panels yet. Only add the shared exclusion policy in the base component.

**Step 4: Run test to verify it passes**

Run: `timeout 12 qs -p tests/qml/SettingsStructureSmoke.qml`

Expected: PASS.

---

### Task 2: Implement the base overlay policy

**Files:**
- Modify: `modules/bar/AnimatedPanelBase.qml`

**Step 1: Import the Wayland layer-shell namespace if missing**

Add the needed import near the top of the file.

```qml
import Quickshell.Wayland
```

**Step 2: Set the shared exclusion policy**

Add the base policy near other root window properties.

```qml
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
```

**Step 3: Keep the change minimal**

Do not change anchors, animation timings, or visibility state machine logic in this task.

**Step 4: Re-run the targeted smoke**

Run: `timeout 12 qs -p tests/qml/SettingsStructureSmoke.qml`

Expected: PASS.

---

### Task 3: Verify all animated-panel overlays still load correctly

**Files:**
- Modify: none unless verification exposes a regression
- Read for context only if needed:
  - `modules/bar/SettingsPanelWindow.qml`
  - `modules/bar/WidgetPickerWindow.qml`
  - `modules/bar/NotificationHistoryPanel.qml`
  - `modules/background/WallpaperPickerWindow.qml`
  - `modules/launcher/LauncherPanel.qml`
  - `modules/bar/MediaControlPanel.qml`

**Step 1: Run the structure suites**

Run:

```bash
bash tests/run-settings-smoke.sh
bash tests/run-ui-structure-smoke.sh
```

Expected: PASS.

**Step 2: Run broader panel-adjacent regression suites**

Run:

```bash
bash tests/run-super-island-smoke.sh
bash tests/run-media-control-smoke.sh
```

Expected: PASS.

**Step 3: Run full shell load verification**

Run: `timeout 10 qs --path .`

Expected: configuration loads successfully.

**Step 4: Manual compositor sanity check**

Open these panels and confirm they overlay instead of pushing windows:
- settings panel
- widget picker
- notification history
- wallpaper picker
- launcher
- media control panel

---

### Task 4: Document outcome in git state only if requested

**Files:**
- Modify: none

**Step 1: Inspect working tree**

Run: `git status --short`

**Step 2: If the user asks for commit preparation**

Prepare a commit summary describing the architectural fix:

```text
fix(bar): make animated dropdown panels non-exclusive overlays
```

Do not create the commit unless the user explicitly asks.
