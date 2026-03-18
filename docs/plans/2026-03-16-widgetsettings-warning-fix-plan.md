# WidgetSettings Warning Fix Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove the `widget-settings` module-name warning and keep widget-settings smoke working through the repository-root harness runner.

**Architecture:** Rename `modules/bar/widget-settings` to `modules/bar/widgetsettings`, update the few runtime and harness imports that reference it, and verify that both widget-settings smoke and root shell load remain clean.

**Tech Stack:** QML, Quickshell, shell smoke scripts, widget settings sections under `modules/bar/`.

---

### Task 1: Add a failing proof for the current widget-settings harness entry

**Files:**
- Verify: `tests/qml/MediaControlSettingsSmoke.qml`

**Step 1: Run the root-runner harness before the rename**

Run:

```bash
bash tests/run-qml-harness.sh MediaControlSettingsSmoke
```

Expected: FAIL on the mirrored `widget-settings` import chain.

**Step 2: Run the root shell load check before the rename**

Run:

```bash
timeout 10 qs --path .
```

Expected: warning mentions `modules/bar/widget-settings` as an invalid module
name.

---

### Task 2: Rename the widget settings directory

**Files:**
- Move: `modules/bar/widgetsettings/AppearanceSection.qml` -> `modules/bar/widgetsettings/AppearanceSection.qml`
- Move: `modules/bar/widgetsettings/MediaControlSection.qml` -> `modules/bar/widgetsettings/MediaControlSection.qml`
- Move: `modules/bar/widgetsettings/SuperIslandSection.qml` -> `modules/bar/widgetsettings/SuperIslandSection.qml`
- Move: `modules/bar/widgetsettings/WorkspaceWidgetSection.qml` -> `modules/bar/widgetsettings/WorkspaceWidgetSection.qml`

**Step 1: Move the directory contents without changing behavior**

Keep file contents unchanged unless import paths require a small local update.

**Step 2: Verify no files still depend on the old directory layout internally**

Check that `../settings` imports still resolve from the renamed directory.

---

### Task 3: Update runtime and smoke imports

**Files:**
- Modify: `modules/bar/WidgetSettingsPanel.qml`
- Modify: `tests/qml/MediaControlSettingsSmoke.qml`
- Modify: `tests/run-media-control-smoke.sh` only if the runner entry should be updated now

**Step 1: Update runtime panel import**

Replace:

```qml
import "widgetsettings"
```

with:

```qml
import "widgetsettings"
```

**Step 2: Update the widget-settings smoke import**

Point the harness at the renamed real source directory or an equivalent
runner-safe import path.

**Step 3: Run the narrow smoke to verify it passes**

Run:

```bash
bash tests/run-qml-harness.sh MediaControlSettingsSmoke
```

Expected: PASS.

---

### Task 4: Update documentation references

**Files:**
- Modify: docs under `docs/plans/` that reference `modules/bar/widgetsettings/`

**Step 1: Replace old path references with `modules/bar/widgetsettings/`**

Only update path references; do not rewrite unrelated plan content.

---

### Task 5: Run verification

**Files:**
- Verify: all touched files

**Step 1: Run the narrow widget-settings smoke**

```bash
bash tests/run-qml-harness.sh MediaControlSettingsSmoke
```

Expected: PASS.

**Step 2: Run the media smoke suite**

```bash
bash tests/run-media-control-smoke.sh
```

Expected: PASS.

**Step 3: Run the settings smoke suite**

```bash
bash tests/run-settings-smoke.sh
```

Expected: PASS.

**Step 4: Run the full shell load check**

```bash
timeout 10 qs --path .
```

Expected: PASS and the `widget-settings` invalid module-name warning is gone.

---

## Execution Notes

This plan's proof commands were run in the active migration workspace.

- `bash tests/run-qml-harness.sh MediaControlSettingsSmoke` -> PASS
- `bash tests/run-media-control-smoke.sh` -> PASS
- `bash tests/run-settings-smoke.sh` -> PASS
- `timeout 10 qs --path .` -> PASS, with no `widget-settings` invalid
  module-name warning
