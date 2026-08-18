# Settings Category Background Focus Hit Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the full visible background rectangle of every targeted settings Row trigger its background hover/focus ring while preserving the existing control and reset-button input areas.

**Architecture:** Use `LazerSettingsRow` as the single owner of card-background hover/highlight state. First compare runtime scene geometry and page ownership across Appearance, Bar, and Notifications; only then make the smallest evidence-backed change to the Row background observation/drawing boundary. Keep control handlers, settings persistence, category pages, overlay menus, and masks unchanged.

**Tech Stack:** Quickshell, QtQuick/QML, QtTest, `qmllint`, existing settings IPC diagnostics, Python pytest.

## Global Constraints

- The Row background observes without blocking child controls: `HoverHandler.blocking` remains `false`.
- `cardHighlight` remains visual-only with `enabled: false`.
- Background hover/focus does not activate or resize text fields, choices, sliders, toggles, or reset buttons.
- Do not reintroduce tooltips, transparent input-catcher layers, Row click forwarding, persistence changes, category navigation changes, or PanelWindow mask changes.
- After every QML change, run the relevant backend QML tests and resolve WARN/ERROR output before completion.
- QML behavior tests blocked by `qrc:/qs-blackhole` must be reported as blocked, never counted as passing.

---

### Task 1: Capture Category-Level Geometry Evidence

**Files:**
- Modify: `modules/lazerbar/LazerSettingsContent.qml:44-112` for complete Row/background/control snapshot fields if the existing snapshot omits them.
- Modify: `modules/lazerbar/LazerSettingsPanel.qml:86-94` for page and layer state fields if the existing panel snapshot omits them.
- Modify: the existing settings diagnostic IPC/service entry point identified by `settings snapshotHover` only if the current command cannot select all three categories.
- Test/diagnostic: `.trellis/tasks/08-18-settings-category-hover-focus/runtime-results.md`.

**Interfaces:**
- Consumes: current `debugSnapshot()` functions from `LazerSettingsPanel.qml` and `LazerSettingsContent.qml`.
- Produces: one comparable JSON snapshot for Appearance rows 1-5, Bar rows 1-4, and all Notification rows, including Row/background/control scene geometry and page state.

- [ ] **Step 1: Run the existing diagnostic path before changing code**

Run:

```bash
qs ipc -p . call settings debugHover true
qs ipc -p . call settings debugCategory appearance
qs ipc -p . call settings snapshotHover
qs ipc -p . call settings debugCategory bar
qs ipc -p . call settings snapshotHover
qs ipc -p . call settings debugCategory notifications
qs ipc -p . call settings snapshotHover
```

Record whether each command exists and capture stdout/stderr. Do not infer pointer behavior from a snapshot that lacks scene rectangles or page ownership fields.

- [ ] **Step 2: Add only missing snapshot fields**

For each collected Row, expose the following shape without adding a mouse-capturing item:

```qml
"row": {
    "rect": _rect(row),
    "sceneRect": _sceneRect(row),
    "visible": row.visible,
    "enabled": row.enabled,
    "opacity": Number(row.opacity),
    "z": Number(row.z),
    "hover": row.rowHovered === true,
    "highlighted": row.rowHighlighted === true,
    "backgroundRect": row.cardItem ? _rect(row.cardItem) : null,
    "backgroundSceneRect": row.cardItem ? _sceneRect(row.cardItem) : null,
    "highlightEnabled": row.highlightItem ? row.highlightItem.enabled : false,
    "control": control ? {
        "rect": _rect(control),
        "sceneRect": _sceneRect(control),
        "visible": control.visible,
        "enabled": control.enabled,
        "activeFocus": control.activeFocus === true,
        "focusVisible": control.focusVisible === true
    } : null
}
```

Use the actual aliases/properties available in the Row; expose `cardHighlight` through a read-only alias if the snapshot cannot reach it. Keep `rowHoverBlocking` in the snapshot and assert it is `false`.

- [ ] **Step 3: Run the diagnostic again and write the evidence matrix**

Run the same three-category sequence. For every target, compare:

```text
row.sceneRect == backgroundSceneRect
row.sceneRect contains the visible card background
control.sceneRect is limited to the visual control
highlightEnabled == false
rowHoverBlocking == false
inactive pages are not enabled
```

Write the observed failure/normal comparison and command output summary to `.trellis/tasks/08-18-settings-category-hover-focus/runtime-results.md`. If no geometry/layer difference is found, stop this implementation plan at Task 1 and report that the remaining root cause requires real compositor pointer tracing rather than modifying `LazerSettingsRow` speculatively.

- [ ] **Step 4: Validate diagnostic-only changes**

Run:

```bash
qmllint modules/lazerbar/LazerSettingsPanel.qml modules/lazerbar/LazerSettingsContent.qml modules/lazerbar/LazerSettingsRow.qml
timeout 15s qs -p .
git diff --check
```

Expected: no new QML warnings/errors. If startup emits the known notification-server warning, record it separately from new diagnostics failures.

- [ ] **Step 5: Commit the evidence checkpoint**

```bash
git add modules/lazerbar/LazerSettingsPanel.qml modules/lazerbar/LazerSettingsContent.qml .trellis/tasks/08-18-settings-category-hover-focus/runtime-results.md
git commit -m "test: capture settings category hit geometry"
```

Do not stage unrelated worktree files.

---

### Task 2: Correct the Row Background Hover Boundary

**Files:**
- Modify: `modules/lazerbar/LazerSettingsRow.qml:77-111` only after Task 1 proves a Row/background boundary mismatch.
- Test: `tests/qml/tst_lazer_settings_controls.qml` or the smallest existing settings Row test file that can instantiate all four presentations.

**Interfaces:**
- Consumes: Task 1 evidence and the existing Row properties `rowHovered`, `rowHighlighted`, `cardItem`, `contentItem`, and `revertButtonItem`.
- Produces: a Row whose background visual layers and hover observer cover the full Row root rect without capturing child input.

- [ ] **Step 1: Add a failing geometry contract test**

Instantiate a representative `LazerSettingsRow` with one control for each presentation and assert the intended contract after layout settles:

```qml
tryVerify(function() { return row.cardItem.width === row.width }, 200)
tryVerify(function() { return row.cardItem.height === row.height }, 200)
verify(!row.cardHighlightItem.enabled)
verify(!row.rowHoverBlocking)
```

Add a test that moves/clicks the background point outside the child control's visual rect and verifies the Row highlight changes without changing the control's value or focus. Use existing QtTest helpers and the current test harness conventions.

- [ ] **Step 2: Run the focused test and confirm the failure or environment block**

Run:

```bash
qs -p tests/qml/tst_lazer_settings_controls.qml
```

Expected before the fix: the geometry or background-hover assertion fails if the runner starts. If the runner stops at `qrc:/qs-blackhole: No such file or directory`, record that exact blocker and use static/runtime evidence from Task 1; do not weaken the assertion.

- [ ] **Step 3: Implement the smallest Row-only correction**

Keep the following structure intact:

```qml
HoverHandler {
    id: rowHover
    enabled: root.enabled
    blocking: false
}

Rectangle {
    id: cardSurface
    anchors.fill: parent
}

Rectangle {
    id: cardHighlight
    anchors.fill: parent
    enabled: false
}
```

Correct only the binding/geometry that Task 1 identified. Do not add `MouseArea`, a transparent overlay, a Row-level `TapHandler`, or a binding that changes the child control's `height` or `width`.

- [ ] **Step 4: Run focused validation and inspect warnings**

Run:

```bash
qmllint modules/lazerbar/LazerSettingsRow.qml tests/qml/tst_lazer_settings_controls.qml
qs -p tests/qml/tst_lazer_settings_controls.qml
```

Expected: focused assertions pass, or the known test-runner blocker is recorded with no new WARN/ERROR lines from the changed QML.

- [ ] **Step 5: Commit the production fix checkpoint**

```bash
git add modules/lazerbar/LazerSettingsRow.qml tests/qml/tst_lazer_settings_controls.qml
git commit -m "fix: restore full settings row background hover"
```

---

### Task 3: Verify Category Regression Coverage

**Files:**
- Modify: `tests/qml/tst_lazer_settings_panel.qml` and/or `tests/qml/tst_lazer_settings_pages.qml` for category matrix coverage.
- Modify: `.trellis/tasks/08-18-settings-category-hover-focus/runtime-results.md` with final evidence.
- Modify: `.trellis/spec/frontend` only if the verified fix establishes a reusable QML interaction rule not already documented.

**Interfaces:**
- Consumes: Task 2 Row background contract and the category snapshot fields from Task 1.
- Produces: repeatable regression coverage for the three category pages and final validation evidence.

- [ ] **Step 1: Add category matrix assertions**

Cover these exact targets:

```text
Appearance: wallpaper, color scheme, panel opacity, enable blur, blur surface opacity
Bar: height, position, floating, floating margin
Notifications: dnd, max visible, timeout, position
```

For each active category, assert that each Row is visible/enabled as expected, its background rect matches its Row rect, and its hover handler remains non-blocking. Assert disabled rows remain visually disabled without making the background layer capture input.

- [ ] **Step 2: Exercise category transitions and scroll state**

Select Appearance, Bar, and Notifications through the existing panel API. Wait for page opacity/transition completion, then assert the active page is enabled and inactive pages are disabled. Scroll the longer Appearance/Bar pages enough to cover both the initial and later rows, then repeat the background geometry assertions.

- [ ] **Step 3: Run all relevant QML tests**

Run:

```bash
qs -p tests/qml/tst_lazer_settings_controls.qml
qs -p tests/qml/tst_lazer_settings_pages.qml
qs -p tests/qml/tst_lazer_settings_panel.qml
qs -p tests/qml/tst_settings_minimal_focus.qml
```

Expected: all runnable tests pass without WARN/ERROR. If blocked by `qrc:/qs-blackhole`, list each blocked test and retain the assertions for later environment recovery.

- [ ] **Step 4: Run project-level checks**

```bash
qmllint modules/lazerbar/LazerSettingsRow.qml modules/lazerbar/LazerSettingsContent.qml modules/lazerbar/LazerSettingsPanel.qml tests/qml/tst_lazer_settings_controls.qml tests/qml/tst_lazer_settings_pages.qml tests/qml/tst_lazer_settings_panel.qml
timeout 15s qs -p .
python3 -m pytest -q
git diff --check
```

Review all output for new warnings, especially deprecated `width`/`height` usage, invalid bindings, and pointer-handler warnings.

- [ ] **Step 5: Update final evidence and commit**

Record the final command results, known environment blockers, and acceptance-criteria mapping in `.trellis/tasks/08-18-settings-category-hover-focus/runtime-results.md`. Then commit only the task files:

```bash
git add tests/qml/tst_lazer_settings_panel.qml tests/qml/tst_lazer_settings_pages.qml .trellis/tasks/08-18-settings-category-hover-focus/runtime-results.md
git commit -m "test: cover settings category background focus"
```

---

## Plan Self-Review

- Spec coverage: the plan covers full-card background focus, preserved child-control input, diagnostic evidence, all target categories, page transitions, scroll state, QML validation, production loading, and the known test-runner blocker.
- Placeholder scan: no `TBD`, `TODO`, or deferred implementation step is used; the only conditional stop is an explicit safety gate when evidence does not support a production edit.
- Interface consistency: Row aliases and properties referenced in the plan are existing properties or are explicitly added as read-only diagnostic aliases in Task 1; later tasks consume only the resulting snapshot and Row geometry contract.
- Scope: the work remains within one settings interaction subsystem and has three independently testable checkpoints.
