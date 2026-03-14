# UI Structure Smoke Wave 3 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add low-risk structure smoke coverage for notifications and launcher UI surfaces, plus a grouped runner and agent guidance updates.

**Architecture:** Keep this wave at the structure layer only: instantiate notification and launcher surfaces inside standalone smoke harnesses, assert their stable public geometry/state contracts, and avoid live DBus, app-launch, or clipboard integration. Reuse the existing `tests/qml/` harness pattern and add a dedicated runner so agents can validate these UI modules without loading the whole shell.

**Tech Stack:** QML, Quickshell, `tests/qml/` smoke harnesses, `NotificationService`, `LauncherService`, `AnimatedPanelBase`, `AGENTS.md`.

---

### Task 1: Prove the new harnesses are missing

**Files:**
- Create: `tests/qml/NotificationStructureSmoke.qml`
- Create: `tests/qml/LauncherStructureSmoke.qml`

**Step 1: Run missing notification harness**

Run:

```bash
timeout 12 qs -p tests/qml/NotificationStructureSmoke.qml
```

Expected: FAIL because the file does not exist yet.

**Step 2: Run missing launcher harness**

Run:

```bash
timeout 12 qs -p tests/qml/LauncherStructureSmoke.qml
```

Expected: FAIL because the file does not exist yet.

---

### Task 2: Add notification structure smoke coverage

**Files:**
- Create: `tests/qml/NotificationStructureSmoke.qml`

**Step 1: Write the harness**

Create a `ShellRoot` harness that imports `qs.config`, `qs.services`, `qs.modules.notifications`, and `modules/bar` as a relative alias so it can instantiate:

- `NotificationPopupWindow`
- `NotificationHistoryPanel`

The harness should seed `NotificationService.activeList` and `NotificationService.historyList` with stable fake entries, then assert only low-risk public structure:

- popup visibility tracks `activeList.count > 0`
- popup `implicitWidth` stays positive
- popup `implicitHeight` includes the internal column height
- popup corner anchoring booleans derived from `SettingsService.data.notifications.position`
- history panel `implicitWidth === 400`
- history panel `implicitHeight === 480`
- history panel `active` follows `BarLayoutService.notificationHistoryOpen`
- `NotificationService.markAllSeen`, `clearHistory`, and `removeFromHistory` exist as functions

Finish by logging `NotificationStructure smoke test passed` and quitting.

**Step 2: Run the harness**

Run:

```bash
timeout 12 qs -p tests/qml/NotificationStructureSmoke.qml
```

Expected: PASS with `NotificationStructure smoke test passed`.

---

### Task 3: Add launcher structure smoke coverage

**Files:**
- Create: `tests/qml/LauncherStructureSmoke.qml`

**Step 1: Write the harness**

Create a `ShellRoot` harness that imports `qs.config`, `qs.services`, and `qs.modules.launcher`, then instantiates `LauncherPanel`.

Assert only low-risk structure and API contracts:

- `LauncherPanel.implicitWidth === 640`
- `LauncherPanel.implicitHeight === 480`
- `LauncherPanel.focusable === true`
- `LauncherPanel.active` follows `LauncherService.isOpen`
- `LauncherService.toggle` and `LauncherService.openClipboard` exist as functions
- toggling/opening updates `LauncherService.isOpen` and `LauncherService.prefillText` as designed

Avoid asserting live provider results because `DesktopEntries` and clipboard integration are environment-dependent.

Finish by logging `LauncherStructure smoke test passed` and quitting.

**Step 2: Run the harness**

Run:

```bash
timeout 12 qs -p tests/qml/LauncherStructureSmoke.qml
```

Expected: PASS with `LauncherStructure smoke test passed`.

---

### Task 4: Add grouped UI structure runner

**Files:**
- Create: `tests/run-ui-structure-smoke.sh`

**Step 1: Write the runner**

Create a Bash runner using the existing pattern:

```bash
#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
timeout 12 qs -p tests/qml/NotificationStructureSmoke.qml
timeout 12 qs -p tests/qml/LauncherStructureSmoke.qml
```

**Step 2: Run the grouped runner**

Run:

```bash
bash tests/run-ui-structure-smoke.sh
```

Expected: PASS and print both smoke success messages.

---

### Task 5: Update agent guidance for the new smoke path

**Files:**
- Modify: `AGENTS.md`

**Step 1: Add grouped smoke command**

Add `bash tests/run-ui-structure-smoke.sh` to the full smoke suite list.

**Step 2: Add single harness commands**

Add:

```bash
timeout 12 qs -p tests/qml/NotificationStructureSmoke.qml
timeout 12 qs -p tests/qml/LauncherStructureSmoke.qml
```

Keep the existing `tests/qml/{config,services,modules}` prerequisite note intact.

---

### Task 6: Re-verify the repo after the new guardrails

**Files:**
- Modify: `AGENTS.md`
- Create: `tests/qml/NotificationStructureSmoke.qml`
- Create: `tests/qml/LauncherStructureSmoke.qml`
- Create: `tests/run-ui-structure-smoke.sh`

**Step 1: Run grouped UI structure smoke**

```bash
bash tests/run-ui-structure-smoke.sh
```

Expected: PASS.

**Step 2: Run existing smoke suites**

```bash
bash tests/run-settings-smoke.sh
bash tests/run-super-island-smoke.sh
bash tests/run-media-control-smoke.sh
```

Expected: PASS.

**Step 3: Run full-shell load check**

```bash
timeout 10 qs --path .
```

Expected: PASS aside from pre-existing environment warnings.
