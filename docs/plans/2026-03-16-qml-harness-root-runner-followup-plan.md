# QML Harness Root Runner Follow-up Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Standardize the broken QML structure harness entrypoints on a repository-root runner and repair the settings harness import path.

**Architecture:** Add a root-level `TestHarnessRunner.qml` plus a shell wrapper that loads `tests/qml/<Harness>.qml` by name. Keep harness-specific fixes narrow: move structure harnesses to `qs.modules.*` imports where available, and point settings smoke at the real `modules/bar/settings` tree so its internal `import ".."` chain resolves correctly.

**Tech Stack:** QML, Quickshell, shell smoke scripts, structure harnesses in `tests/qml/`.

---

### Task 1: Add the root harness runner

**Files:**
- Create: `TestHarnessRunner.qml`
- Create: `tests/run-qml-harness.sh`

**Step 1: Create the root-level QML loader**

Load `tests/qml/<Harness>.qml` via the `DYMICSHELL_TEST_HARNESS` environment
variable while keeping the repository root as the config root.

**Step 2: Create the shell wrapper**

Expose a stable command:

```bash
bash tests/run-qml-harness.sh <HarnessBaseName>
```

**Step 3: Verify the wrapper loads at least one structure harness**

Run:

```bash
bash tests/run-qml-harness.sh NotificationStructureSmoke
```

Expected: the harness reaches its own assertions instead of failing on `qs.*`
bootstrap imports.

---

### Task 2: Move verified structure harnesses to root-runner-compatible imports

**Files:**
- Modify: `tests/qml/NotificationStructureSmoke.qml`
- Modify: `tests/qml/LauncherStructureSmoke.qml`

**Step 1: Replace mirrored relative module imports**

Use `qs.modules.notifications`, `qs.modules.bar`, and `qs.modules.launcher`
instead of `tests/qml/modules/...` aliases.

**Step 2: Verify both harnesses through the runner**

Run:

```bash
bash tests/run-qml-harness.sh NotificationStructureSmoke
bash tests/run-qml-harness.sh LauncherStructureSmoke
```

Expected: PASS.

---

### Task 3: Repair the settings harness import path

**Files:**
- Modify: `tests/qml/SettingsStructureSmoke.qml`
- Modify: `tests/run-settings-smoke.sh`

**Step 1: Point the bar import at the real module URI**

Use `qs.modules.bar as BarParts`.

**Step 2: Point settings parts at the real source directory**

Import:

```qml
import "../../modules/bar/settings" as SettingsParts
```

so the settings subtree's internal `import ".."` resolves back into the real
`modules/bar` directory.

**Step 3: Move the settings smoke runner to the root wrapper**

Use:

```bash
bash tests/run-qml-harness.sh SettingsStructureSmoke
```

**Step 4: Verify the settings harness**

Run:

```bash
bash tests/run-qml-harness.sh SettingsStructureSmoke
bash tests/run-settings-smoke.sh
```

Expected: PASS.

---

### Task 4: Update grouped smoke scripts and guidance

**Files:**
- Modify: `tests/run-ui-structure-smoke.sh`
- Modify: `AGENTS.md`

**Step 1: Update grouped UI smoke**

Run structure harnesses through `tests/run-qml-harness.sh`.

**Step 2: Update documented single-harness commands**

Document the verified root-runner commands for:

- `SettingsStructureSmoke`
- `NotificationStructureSmoke`
- `LauncherStructureSmoke`
- `BarLayoutGeometrySmoke`

**Step 3: Verify the grouped suite and full shell load**

Run:

```bash
bash tests/run-ui-structure-smoke.sh
timeout 10 qs --path .
```

Expected: PASS.
