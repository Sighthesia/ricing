# QML Harness Root Runner Follow-up Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Standardize the broken QML structure harness entrypoints on a repository-root runner and repair the settings harness import path.



---

### Task 1: Add the root harness runner

**Files:**
- Create: `tests/run-qml-harness.sh`

**Step 1: Create the root-level QML loader**

variable while keeping the repository root as the config root.

**Step 2: Create the shell wrapper**

Expose a stable command:

```bash
bash tests/run-qml-harness.sh <HarnessBaseName>
```

**Step 3: Verify the wrapper loads at least one structure harness**

Run:

```bash
```

Expected: the harness reaches its own assertions instead of failing on `qs.*`
bootstrap imports.

---

### Task 2: Move verified structure harnesses to root-runner-compatible imports

**Files:**

**Step 1: Replace mirrored relative module imports**

Use `qs.modules.notifications`, `qs.modules.bar`, and `qs.modules.launcher`
instead of `tests/qml/modules/...` aliases.

**Step 2: Verify both harnesses through the runner**

Run:

```bash
```

Expected: PASS.

---

### Task 3: Repair the settings harness import path

**Files:**

**Step 1: Point the bar import at the real module URI**

Use `qs.modules.bar as BarParts`.

**Step 2: Point settings parts at the real source directory**

Import:

```qml
import "../../modules/bar/settings" as SettingsParts
```

so the settings subtree's internal `import ".."` resolves back into the real
`modules/bar` directory.


Use:

```bash
```

**Step 4: Verify the settings harness**

Run:

```bash
```

Expected: PASS.

---


**Files:**
- Modify: `AGENTS.md`


Run structure harnesses through `tests/run-qml-harness.sh`.

**Step 2: Update documented single-harness commands**

Document the verified root-runner commands for:


**Step 3: Verify the grouped suite and full shell load**

Run:

```bash
timeout 10 qs --path .
```

Expected: PASS.
