# Settings Search Reorder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make settings search animate unmatched rows and empty categories out while matching rows smoothly move to the front of the visible list.

**Architecture:** Keep the current injected `Column` structure and stable setting-row instances. `LazerSettingsRow` owns row-level filter geometry and visual transitions; `LazerSettingsSection` owns category-level visibility and collapse; `LazerSettingsSections` continues deriving content height and result counts from the animated section state.

**Tech Stack:** Quickshell, QML/QtQuick, QtTest, existing `MotionTokens` and `LazerSettingsLogic.matchesSearch`.

## Global Constraints

- Preserve existing settings control instances, input state, focus, scroll behavior, and empty-result behavior.
- Use approximately `160ms` short easing for search result changes.
- Animate row and section `height`, `opacity`, and `x` together.
- Do not let an exiting row block pointer input to visible rows.
- After every QML change, run the relevant backend QML tests and resolve WARN/ERROR output.
- Keep the existing osu-style sharp settings visual language and QML declaration comments.

---

### Task 1: Add observable row exit and restoration states

**Files:**
- Modify: `modules/lazerbar/LazerSettingsRow.qml:11-97`
- Test: `tests/qml/tst_lazer_settings_panel.qml:372-395`

**Interfaces:**
- Consumes: existing `searchQuery`, `matchesSearch`, `implicitHeight`, `MotionTokens.fast`, and `MotionTokens.reducedMotion`.
- Produces: stable row properties `searchVisible` and `height` behavior that collapse unmatched rows without instantly removing their visual surface.

- [ ] **Step 1: Extend the panel test with final animated-state assertions**

Add assertions to `test_searchFiltersAllSectionsAndShowsEmptyState` after each query transition. Use `wait(250)` or `tryCompare` with a property so the assertions observe the completed `MotionTokens.fast` transition:

```qml
panel.searchQuery = "模糊"
tryCompare(panel.appearancePage.wallpaperRow, "height", 0, 500)
verify(!panel.appearancePage.wallpaperRow.searchVisible)
tryCompare(panel.barPage, "height", 0, 500)

panel.searchQuery = ""
tryVerify(function() { return panel.appearancePage.wallpaperRow.height > 0 }, 500)
tryVerify(function() { return panel.barPage.height > 0 }, 500)
```

Keep the existing result-count and empty-state assertions.

- [ ] **Step 2: Run the focused test and verify the new assertion exposes current behavior**

Run:

```bash
qs -p tests/qml/tst_lazer_settings_panel.qml
```

Expected: the test either passes if the current behavior already satisfies the state assertions, or fails only on the newly added transition/visibility contract.

- [ ] **Step 3: Implement persistent row exit state**

In `LazerSettingsRow.qml`:

- Keep `matchesSearch` as the logical match result.
- Change `searchVisible` to represent the row’s current searchable participation, not a hard visual `visible` toggle.
- Keep the row object `visible: true` while its `height` animates, so the exit can render and the column can reflow from its changing height.
- Define an explicit target geometry using `matchesSearch ? implicitHeight : 0` and a small signed horizontal offset, for example `matchesSearch ? 0 : -8`.
- Make `opacity` combine the existing disabled alpha with a search alpha, so disabled rows retain their current visual rule while unmatched rows fade out.
- Add `Behavior on x` and `Behavior on opacity` using the same duration/easing as the current height behavior. Respect `MotionTokens.reducedMotion` consistently.
- Ensure the row and its reset button cannot receive input once `matchesSearch` is false by gating the hover/reset handlers with `searchVisible` or `matchesSearch`.

Keep `visibleResultCount` semantics unchanged: a row counts only while `matchesSearch` is true, so empty-state logic updates immediately while the exit animation plays.

- [ ] **Step 4: Run the focused test and inspect warnings**

Run:

```bash
qs -p tests/qml/tst_lazer_settings_panel.qml
```

Expected: PASS with no new `WARN` or `ERROR` lines; unmatched rows collapse after the short transition and restore when the query is cleared.

- [ ] **Step 5: Commit the row animation change**

```bash
git add modules/lazerbar/LazerSettingsRow.qml tests/qml/tst_lazer_settings_panel.qml
git commit -m "feat: animate settings search row exits"
```

### Task 2: Animate empty categories without leaving gaps

**Files:**
- Modify: `modules/lazerbar/LazerSettingsSection.qml:10-43`
- Test: `tests/qml/tst_lazer_settings_panel.qml:372-395`

**Interfaces:**
- Consumes: each child row’s `searchVisible`, existing `visibleResultCount`, and `implicitHeight`.
- Produces: category `hasVisibleContent`, animated `height`, `opacity`, and `x` state used by the parent sections column.

- [ ] **Step 1: Add section-level assertions for empty and restored categories**

Extend the focused panel test with:

```qml
panel.searchQuery = "浮动"
tryCompare(panel.appearancePage, "height", 0, 500)
tryVerify(function() { return panel.barPage.height > 0 }, 500)

panel.searchQuery = ""
tryVerify(function() { return panel.appearancePage.height > 0 }, 500)
```

Use the existing section names and row counts; do not assert a hardcoded animation frame.

- [ ] **Step 2: Run the focused test to confirm the section contract**

Run:

```bash
qs -p tests/qml/tst_lazer_settings_panel.qml
```

Expected: any failure identifies the missing category collapse/restoration behavior.

- [ ] **Step 3: Implement section collapse and restoration**

In `LazerSettingsSection.qml`:

- Keep `_countVisibleRows()` based on `searchVisible === true` so the parent empty-state count remains immediate.
- Replace the hard `visible: hasVisibleContent` filter with a stable visible section while a non-empty query is transitioning; use `height`, `opacity`, and `x` as the visual/layout state.
- Define the section target height as `hasVisibleContent ? implicitHeight : 0`.
- Add synchronized `Behavior on opacity` and `Behavior on x` with the existing height animation timing.
- Preserve the section’s normal disabled alpha when content exists; combine it with search visibility rather than replacing it.
- Gate `dimArea` and section activation input when the section has no search result, so an exiting/empty category cannot intercept pointer input.
- Keep the background, header, and content in the same parent item so the title and section spacing disappear together.

If the parent’s `_totalContentHeight()` still skips a section during its transition because `visible` becomes false, remove that hard visibility dependency and let the animated numeric height contribute until the animation reaches zero.

- [ ] **Step 4: Run panel and page tests**

Run:

```bash
qs -p tests/qml/tst_lazer_settings_panel.qml
qs -p tests/qml/tst_lazer_settings_pages.qml
```

Expected: PASS with no WARN/ERROR lines. Category switching, search persistence, empty-state display, and scroll behavior remain intact.

- [ ] **Step 5: Commit the category animation change**

```bash
git add modules/lazerbar/LazerSettingsSection.qml modules/lazerbar/LazerSettingsSections.qml tests/qml/tst_lazer_settings_panel.qml
git commit -m "feat: collapse empty settings categories"
```

### Task 3: Verify rapid query changes and full backend regression

**Files:**
- Modify: only if a failing regression requires a targeted correction in `LazerSettingsRow.qml`, `LazerSettingsSection.qml`, or `LazerSettingsSections.qml`.
- Test: `tests/qml/tst_lazer_settings_panel.qml`

**Interfaces:**
- Consumes: row and section animation states from Tasks 1 and 2.
- Produces: verified behavior for repeated query changes, restoration, result counts, and parent content height.

- [ ] **Step 1: Add a rapid-query regression test**

Add a test that changes the query before the first transition finishes, then clears it:

```qml
function test_searchRapidChangesRestoreStableGeometry() {
    panel.searchQuery = "模糊"
    panel.searchQuery = "浮动"
    panel.searchQuery = "zzz-no-match"
    panel.searchQuery = ""

    tryVerify(function() { return panel.appearancePage.height > 0 }, 500)
    tryVerify(function() { return panel.barPage.height > 0 }, 500)
    compare(panel.appearancePage.visibleResultCount, 9)
    compare(panel.barPage.visibleResultCount, 5)
    verify(!panel.content.emptyStateVisible)
}
```

Use the actual current row counts if the page fixture differs; the assertion must verify restored counts rather than a stale visual property.

- [ ] **Step 2: Run the regression test**

Run:

```bash
qs -p tests/qml/tst_lazer_settings_panel.qml
```

Expected: PASS without residual zero heights, opacity values, horizontal offsets, or stale empty-state state.

- [ ] **Step 3: Run all relevant backend settings tests**

Run:

```bash
qs -p tests/qml/tst_lazer_settings_panel.qml
qs -p tests/qml/tst_lazer_settings_pages.qml
qs -p tests/qml/tst_lazer_settings_controls.qml
qs -p tests/qml/tst_lazer_settings_overlay.qml
qs -p tests/qml/tst_lazer_settings_logic.qml
```

Expected: all commands pass and Quickshell emits no new WARN/ERROR lines.

- [ ] **Step 4: Inspect the final diff and worktree**

Run:

```bash
git status --short
```

Confirm only the search animation implementation, focused tests, and approved design/plan documentation are included; leave unrelated worktree changes untouched.

- [ ] **Step 5: Commit any final targeted correction**

If Task 3 required a correction, commit only the affected files:

```bash
git add modules/lazerbar/LazerSettingsRow.qml modules/lazerbar/LazerSettingsSection.qml modules/lazerbar/LazerSettingsSections.qml tests/qml/tst_lazer_settings_panel.qml
git commit -m "fix: stabilize settings search transitions"
```

If no correction was needed, do not create an empty commit.
