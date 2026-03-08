# Bar Widget Structural Tokens Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Move WorkspaceWidget internal layout magic numbers into a reusable global Theme.barWidget token namespace and document the rule in AGENTS.md.

**Architecture:** Add a new `Theme.barWidget` token group in `config/Theme.qml`, bind `WorkspaceWidget.qml` to those tokens instead of local literals, and update root agent guidance so future bar widgets extend Theme before introducing new structural magic numbers.

**Tech Stack:** QML, Quickshell, SettingsService-backed Theme singleton, markdown agent context docs.

**Design doc:** `docs/plans/2026-03-08-bar-widget-structural-tokens-design.md`

---

### Task 1: Add reusable barWidget structural tokens

**Files:**
- Modify: `config/Theme.qml`

**Step 1: Add `Theme.barWidget` namespace**

Create a `readonly property QtObject barWidget` block near other structural Theme tokens.

**Step 2: Define scaled structural tokens**

Add these properties using `Math.round(base * uiScale)`:

- `contentPaddingH: 10`
- `primaryIconSize: 16`
- `compactIconSize: 13`
- `iconSpacing: 3`
- `pillSpacing: 8`
- `pillPaddingH: 8`
- `iconLabelSpacing: 6`
- `focusPulsePadding: 4`

**Step 3: Verify no naming conflict**

Confirm the new namespace does not overlap existing `Theme.anim` or top-level properties.

---

### Task 2: Replace WorkspaceWidget hardcoded structural values

**Files:**
- Modify: `modules/bar/widgets/WorkspaceWidget.qml`

**Step 1: Remove widget-local structural literals**

Replace the 8 readonly properties currently hardcoded in the structure constants block with bindings to `Theme.barWidget.*`.

**Step 2: Remove the obsolete FIXME**

Delete the comment that says these values should eventually be promoted to Theme tokens.

**Step 3: Keep behavior and settings bindings unchanged**

Do not move `revertDelay`, `revertCooldown`, `titleMaxW`, `hoverActive`, or `_pillH` into `Theme.barWidget`.

---

### Task 3: Update root agent guidance

**Files:**
- Modify: `AGENTS.md`

**Step 1: Extend token-system rules**

Add a short rule under Theme sizing guidance that bar widget internal micro-layout should use `Theme.barWidget.*`.

**Step 2: Add expansion guidance**

State that when a needed token does not exist, agents should extend `Theme.barWidget.*` first instead of adding local literals.

---

### Task 4: Verify implementation

**Files:**
- Verify: `config/Theme.qml`
- Verify: `modules/bar/widgets/WorkspaceWidget.qml`
- Verify: `AGENTS.md`

**Step 1: Run workspace diagnostics**

Use editor diagnostics on the touched files to catch syntax or QML binding issues.

**Step 2: Run shell load verification**

Run a Quickshell parse/load command for the repository root if available.

**Step 3: Review diff**

Confirm only the intended tokenization and documentation changes were made.