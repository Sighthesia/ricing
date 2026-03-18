
> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.




---

### Task 1: Prove the new harnesses are missing

**Files:**

**Step 1: Run missing notification harness**

Run:

```bash
```

Expected: FAIL because the file does not exist yet.

**Step 2: Run missing launcher harness**

Run:

```bash
```

Expected: FAIL because the file does not exist yet.

---


**Files:**

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


**Step 2: Run the harness**

Run:

```bash
```


---


**Files:**

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


**Step 2: Run the harness**

Run:

```bash
```


---

### Task 4: Add grouped UI structure runner

**Files:**

**Step 1: Write the runner**

Create a Bash runner using the existing pattern:

```bash
#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
```

**Step 2: Run the grouped runner**

Run:

```bash
```


---


**Files:**
- Modify: `AGENTS.md`



**Step 2: Add single harness commands**

Add:

```bash
```

Keep the existing `tests/qml/{config,services,modules}` prerequisite note intact.

---

### Task 6: Re-verify the repo after the new guardrails

**Files:**
- Modify: `AGENTS.md`


```bash
```

Expected: PASS.


```bash
```

Expected: PASS.

**Step 3: Run full-shell load check**

```bash
timeout 10 qs --path .
```

Expected: PASS aside from pre-existing environment warnings.
