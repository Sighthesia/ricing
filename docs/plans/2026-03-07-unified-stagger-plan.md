# Unified Stagger Animation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deliver a unified stagger animation system so every independent content unit in settings panel, widget library, right-click menu, launcher, and widget settings panel has consistent enter/exit behavior, including viewport-enter transitions.

**Architecture:** Introduce a shared stagger orchestration layer and migrate page-level animation triggers to it. Keep existing `StaggerItem` as the animation primitive, while adding reusable list/grid adapter behavior for viewport-entry and refresh transitions.

**Tech Stack:** Quickshell QML, QtQuick ListView/GridView delegates, existing `StaggerItem`, `AnimatedPanelBase`, `SettingsService` animation tokens.

---

### Task 1: Add Shared Stagger Orchestrator

**Files:**
- Create: `modules/bar/StaggerOrchestrator.qml`
- Modify: `modules/bar/CMakeLists.txt` (if module export is needed)
- Modify: `modules/bar/AnimatedPanelBase.qml` (only if orchestration hook utility is required)

**Step 1: Create orchestrator skeleton**
- Define root `Item` with API:
  - `register(node, group, order, level, kind)`
  - `unregister(node, group)`
  - `enter(group)`
  - `exit(group)`

**Step 2: Implement delay strategy**
- Use `SettingsService.data.animation.staggerLevel1BaseDelay`, `staggerLevel1Step`, `staggerLevel2BaseDelay`, `staggerLevel2Step`, `staggerExitStep`.
- Add cycle support for long lists (`index % cycle`).

**Step 3: Implement orchestration calls**
- On `enter(group)`, invoke `runEnter()` in sorted order.
- On `exit(group)`, invoke `runExit()` with configured exit policy.

**Step 4: Verify QML loadability**
Run:
```bash
qs -p . 2>&1 | rg "error|Error|ReferenceError|TypeError" -n
```
Expected: no new errors referencing `StaggerOrchestrator`.

**Step 5: Commit**
```bash
git add modules/bar/StaggerOrchestrator.qml modules/bar/CMakeLists.txt modules/bar/AnimatedPanelBase.qml
git commit -m "feat: add shared stagger orchestrator"
```

### Task 2: Integrate Settings Panel + AboutPage Full Coverage

**Files:**
- Modify: `modules/bar/settings/AboutPage.qml`
- Modify: `modules/bar/settings/SettingsPanelContent.qml`
- Modify: `modules/bar/SettingsPanelWindow.qml`

**Step 1: Add AboutPage animation hooks**
- Add `runEnterAnimation()` and `runExitAnimation()`.
- Split content into independent `StaggerItem` blocks.

**Step 2: Register AboutPage blocks to orchestrator group**
- Group name example: `settings.about`.
- Preserve existing layout and interaction behavior.

**Step 3: Wire panel open/close lifecycle**
- Ensure `panelOpening/panelClosing` routes trigger AboutPage animations when active.

**Step 4: Manual verification**
Run shell and verify:
- Open settings panel to About page.
- Each block enters with stagger.
- Close panel triggers clean exit without flicker.

**Step 5: Commit**
```bash
git add modules/bar/settings/AboutPage.qml modules/bar/settings/SettingsPanelContent.qml modules/bar/SettingsPanelWindow.qml
git commit -m "feat: add full stagger coverage for settings about page"
```

### Task 3: Integrate Widget Picker Grid Per-Card Stagger

**Files:**
- Modify: `modules/bar/WidgetPickerWindow.qml`

**Step 1: Keep structural stagger and add delegate-level stagger**
- Wrap card delegate content in `StaggerItem`.
- Compute order by visual position (`row * columns + column`).

**Step 2: Add viewport-enter behavior**
- Ensure cards entering visible area trigger from-lower-to-upper transition.
- Keep scroll performance acceptable (avoid excessive cache churn).

**Step 3: Add refresh transition behavior**
- For search filtering: old cards short exit, then new cards enter.

**Step 4: Manual verification**
- Open picker: title/search/grid and cards all stagger.
- Type query: cards transition cleanly.
- Scroll grid: newly visible cards animate upward.

**Step 5: Commit**
```bash
git add modules/bar/WidgetPickerWindow.qml
git commit -m "feat: add per-card stagger for widget picker grid"
```

### Task 4: Normalize Bar Context Menu with Orchestrator

**Files:**
- Modify: `modules/bar/BarContextMenu.qml`

**Step 1: Replace manual trigger wiring with orchestrator calls**
- Keep current item ordering and delays.
- Preserve snap close behavior (`exitDelay = 0` policy).

**Step 2: Verify interaction parity**
- Open/close menu repeatedly.
- Ensure no regressions in hover, click, and action callbacks.

**Step 3: Commit**
```bash
git add modules/bar/BarContextMenu.qml
git commit -m "refactor: route context menu stagger through orchestrator"
```

### Task 5: Add Launcher Unified Structural + Refresh Exit/Enter

**Files:**
- Modify: `modules/launcher/LauncherCore.qml`
- Modify: `modules/launcher/LauncherPanel.qml` (if lifecycle hook forwarding needed)

**Step 1: Register structural nodes**
- Search row and divider become stagger nodes.

**Step 2: Implement query refresh two-stage transition**
- old results: short exit
- swap/update model
- new results: enter stagger

**Step 3: Keep viewport-enter behavior for list items**
- Maintain per-item slide-up on visible entry.

**Step 4: Manual verification**
- Open launcher: search row + results stagger.
- Type quickly: no blank flicker; old/new transition is readable.
- Scroll long result list: new visible items animate upward.

**Step 5: Commit**
```bash
git add modules/launcher/LauncherCore.qml modules/launcher/LauncherPanel.qml
git commit -m "feat: unify launcher stagger and refresh transitions"
```

### Task 6: Align Widget Settings Panel Lifecycle

**Files:**
- Modify: `modules/bar/WidgetSettingsPanel.qml`

**Step 1: Align lifecycle semantics**
- Reuse `AnimatedPanelBase` lifecycle signals or equivalent orchestrator-compatible hooks.

**Step 2: Ensure all independent blocks are staged**
- Header, appearance, functional, and bottom delete area all enter/exit with stagger policy.

**Step 3: Manual verification**
- Open/close rapidly.
- Verify no stale opacity/offset state.
- Verify button interactions remain stable.

**Step 4: Commit**
```bash
git add modules/bar/WidgetSettingsPanel.qml
git commit -m "refactor: align widget settings panel stagger lifecycle"
```

### Task 7: Consolidation, Cleanup, and Verification

**Files:**
- Modify: `config/settings-default.json` (only if new token keys are required)
- Modify: any touched QML files for cleanup

**Step 1: Remove duplicate animation constants**
- Replace literals with shared tokens where possible.
- Mark unavoidable literals with `// FIXME:`.

**Step 2: Run project-level sanity checks**
Run:
```bash
qs -p . 2>&1 | rg "error|Error|ReferenceError|TypeError|WARN scene" -n
```
Expected: no new warnings/errors from modified files.

- Settings panel (including About) full stagger.
- Widget picker grid card stagger + viewport enter.
- Context menu unchanged behavior with orchestrated stagger.
- Launcher refresh exit/enter + viewport enter.
- Widget settings panel aligned and stable.

**Step 4: Final commit**
```bash
git add modules/bar modules/launcher config/settings-default.json
git commit -m "feat: unify stagger animations across shell panels"
```
