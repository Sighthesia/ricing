# Harness Closeout Verification Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Verify and close out the current root-runner and `widgetsettings` migration with the smallest possible set of follow-up fixes.

**Architecture:** Start from proof commands instead of more refactoring. Use the repository-root harness runner and the renamed `modules/bar/widgetsettings/` tree as the system under test, then patch only the files directly involved in failures that those commands reveal.

**Tech Stack:** QML, Quickshell, repository-root smoke harness runner, shell smoke scripts, docs under `docs/plans/`.

---

### Task 1: Prove the narrow widget settings harness path

**Files:**
- Verify: `tests/run-qml-harness.sh`
- Verify: `TestHarnessRunner.qml`
- Verify: `tests/qml/MediaControlSettingsSmoke.qml`

**Step 1: Run the narrow harness proof**

Run:

```bash
bash tests/run-qml-harness.sh MediaControlSettingsSmoke
```

Expected: PASS, or a failure that points directly at the root runner or the
`widgetsettings` import chain.

**Step 2: If it fails, make the smallest possible fix**

Touch only one of:

- `tests/run-qml-harness.sh`
- `TestHarnessRunner.qml`
- `tests/qml/MediaControlSettingsSmoke.qml`
- `modules/bar/WidgetSettingsPanel.qml`
- `modules/bar/widgetsettings/*.qml`

Keep the change narrowly tied to the observed failure.

**Step 3: Re-run the narrow harness proof**

Run:

```bash
bash tests/run-qml-harness.sh MediaControlSettingsSmoke
```

Expected: PASS.

---

### Task 2: Prove the grouped media smoke entrypoint

**Files:**
- Verify: `tests/run-media-control-smoke.sh`
- Verify: `tests/qml/MediaServiceSmoke.qml`
- Verify: `tests/qml/CavaServiceSmoke.qml`
- Verify: `tests/qml/MediaControlServiceSmoke.qml`
- Verify: `tests/qml/MediaVisualPartsSmoke.qml`
- Verify: `tests/qml/MediaControlWidgetSmoke.qml`
- Verify: `tests/qml/MediaControlPanelSmoke.qml`
- Verify: `tests/qml/MediaControlSettingsSmoke.qml`

**Step 1: Run the grouped media suite**

Run:

```bash
bash tests/run-media-control-smoke.sh
```

Expected: PASS, or a failure isolated to a single harness now running through
the root runner.

**Step 2: If it fails, patch only the failing media harness path**

Modify only the harness, script, or `widgetsettings`/root-runner file implicated
by the failure.

**Step 3: Re-run the grouped media suite**

Run:

```bash
bash tests/run-media-control-smoke.sh
```

Expected: PASS.

---

### Task 3: Prove the grouped settings smoke entrypoint

**Files:**
- Verify: `tests/run-settings-smoke.sh`
- Verify: `tests/qml/SettingsStructureSmoke.qml`

**Step 1: Run the settings suite**

Run:

```bash
bash tests/run-settings-smoke.sh
```

Expected: PASS.

**Step 2: If it fails, make the smallest settings-path fix**

Limit edits to:

- `tests/run-settings-smoke.sh`
- `tests/qml/SettingsStructureSmoke.qml`
- `TestHarnessRunner.qml`
- directly related QML imports used by the settings harness

**Step 3: Re-run the settings suite**

Run:

```bash
bash tests/run-settings-smoke.sh
```

Expected: PASS.

---

### Task 4: Prove the full-shell warning is gone

**Files:**
- Verify: `modules/bar/widgetsettings/AppearanceSection.qml`
- Verify: `modules/bar/widgetsettings/MediaControlSection.qml`
- Verify: `modules/bar/widgetsettings/SuperIslandSection.qml`
- Verify: `modules/bar/widgetsettings/WorkspaceWidgetSection.qml`
- Verify: `modules/bar/WidgetSettingsPanel.qml`

**Step 1: Run the root shell load check**

Run:

```bash
timeout 10 qs --path .
```

Expected: no invalid module-name warning for `modules/bar/widget-settings`.

**Step 2: If the warning persists, fix only the residual path or import source**

Do not broaden scope into unrelated warning cleanup.

**Step 3: Re-run the root shell load check**

Run:

```bash
timeout 10 qs --path .
```

Expected: the `widget-settings` invalid module-name warning is gone.

---

### Task 5: Align the active migration docs with the verified outcome

**Files:**
- Modify: `docs/plans/2026-03-16-widgetsettings-warning-fix-design.md`
- Modify: `docs/plans/2026-03-16-widgetsettings-warning-fix-plan.md`
- Modify: `docs/plans/2026-03-16-harness-closeout-verification-design.md`
- Modify: `docs/plans/2026-03-16-harness-closeout-verification-plan.md`

**Step 1: Update only the docs that describe this migration wave**

Keep edits factual: commands used, scope boundaries, and verified outcomes.

**Step 2: Avoid rewriting unrelated historical plan docs**

Older docs can keep historical `widget-settings` wording when it describes past
feature names or commit messages.

---

### Task 6: Prepare a clean handoff

**Files:**
- Verify: all touched files

**Step 1: Inspect the final diff**

Run:

```bash
git status --short
```

Expected: only the migration-related files and docs are changed.

**Step 2: Summarize the stop point**

Record whether the migration is now ready for commit, or whether one specific
blocker remains.

---

## Execution Notes

The planned verification set was executed in the current workspace.

- `bash tests/run-qml-harness.sh MediaControlSettingsSmoke` -> PASS
- `bash tests/run-media-control-smoke.sh` -> PASS
- `bash tests/run-settings-smoke.sh` -> PASS
- `timeout 10 qs --path .` -> PASS

Observed non-blocking warnings during verification:

- `QSettings::value: Empty key passed`
- notification service registration warning when another notification server is
  already active

The targeted `modules/bar/widget-settings` invalid module-name warning did not
reappear.
