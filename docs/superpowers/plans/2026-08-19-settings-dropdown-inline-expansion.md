# Inline Settings Dropdown Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the settings Choice overlay with an inline downward-opening menu that animates its Row taller, pushes following settings down, and keeps the focus ring over the complete expanded Row.

**Architecture:** `LazerSettingsChoice` owns the title, option list, menu state, and expanded content height. `LazerSettingsRow` consumes the control's actual height as its card height and remains the sole visual owner of the card and focus ring. `LazerSettingsContent` keeps its existing layout and Flickable, reacting to Row height changes through normal QML layout bindings.

**Tech Stack:** QML/QtQuick, Quickshell, QtTest, existing `MotionTokens`, existing `LazerTheme` and `SettingsOverlayBridge` APIs only where still required by unrelated surfaces.

## Global Constraints

- The menu always opens downward.
- The Row grows through an animated height change and pushes following settings downward.
- The focus ring covers the complete expanded Row, including the title and options.
- Selecting an option updates the value and immediately closes the menu.
- Clicking the title again, clicking outside the Row, or pressing `Escape` closes the menu without changing the current value.
- Keep existing Choice width, keyboard access, reset controls, page switching, and scroll persistence.
- Inactive settings pages remain `visible: false` while their objects and scroll state stay mounted.
- Use existing `MotionTokens`; reduced motion applies final geometry immediately.
- After every QML change, run the relevant QML tests and fix WARN/ERROR output before completion.
- Use `apply_patch` for manual edits and commit each completed task with a conventional commit message.

---

## File Map

- Modify `modules/lazerbar/LazerSettingsChoice.qml`: replace the runtime dropdown overlay with an embedded option list and expose its actual expanded height.
- Modify `modules/lazerbar/LazerSettingsRow.qml`: make Choice height the Row's authoritative expanded geometry and animate the Row height without changing control input boundaries.
- Modify `modules/lazerbar/LazerSettingsContent.qml`: verify or minimally adjust the content layout/Flickable bindings so changing Row height updates content height and supports scrolling to the expanded menu.
- Modify `tests/qml/tst_lazer_settings_panel.qml`: add panel-level regression coverage for expansion, following-row displacement, focus-ring bounds, closing, and reduced motion.
- Modify or create the focused Choice test file under `tests/qml/` only if the existing test layout has no suitable control-level fixture; keep tests in the existing project style.

## Interfaces Between Tasks

- `LazerSettingsChoice.menuOpen: bool` remains the expansion state.
- `LazerSettingsChoice.menuReservedHeight: real` becomes the expanded option-list height used by the Row.
- `LazerSettingsChoice.implicitHeight: real` represents the full title-plus-list height while open and the title height while closed.
- `LazerSettingsRow.choiceMenuReservedHeight: real` reads `controlItem.menuReservedHeight` and participates in `cardContentHeight`.
- `LazerSettingsRow.controlItem.height` is the actual control height used by Row layout; no separate overlay geometry is authoritative.

## Task 1: Add Failing Geometry and State Tests

**Files:**
- Modify: `tests/qml/tst_lazer_settings_panel.qml`
- Test fixture: existing `LazerSettingsPanel` fixture and current Appearance/Bar Choice rows

**Interfaces:**
- Consumes the current `menuOpen`, `menuReservedHeight`, Row `implicitHeight`, `cardHighlight`, and following-row geometry.
- Produces executable regression expectations for the inline menu behavior before implementation changes.

- [ ] **Step 1: Inspect the existing test fixture and identify a Choice Row with a following Row.**

  Use the existing panel fixture and locate the first Choice row in Appearance or Bar. Record the object aliases needed for the Choice, its Row, the next Row, and the Row focus ring. Do not create a second panel fixture unless the current fixture cannot expose these objects.

- [ ] **Step 2: Add a test for the closed baseline.**

  Add a test equivalent to:

  ```qml
  function test_choiceStartsCollapsed() {
      var row = panel.appearancePage.colorSchemeRow
      var choice = row.controlItem
      verify(choice !== null)
      compare(choice.menuOpen, false)
      compare(choice.menuReservedHeight, 0)
      compare(row.implicitHeight, row.cardContentHeight)
  }
  ```

  Use the actual existing row alias and retain the same assertion intent if the row name differs.

- [ ] **Step 3: Add a failing expansion geometry test.**

  Add a test that opens the Choice, waits for the layout to settle, and asserts the following-row position and focus-ring height change:

  ```qml
  function test_choiceExpansionPushesFollowingRowAndFocusRing() {
      var row = panel.appearancePage.colorSchemeRow
      var choice = row.controlItem
      var following = panel.appearancePage.panelOpacityRow
      var closedY = following.y
      var closedHeight = row.height

      choice.openMenu()
      tryCompare(choice, "menuOpen", true)
      tryCompare(row, "height", row.cardContentHeight, 500)
      verify(row.height > closedHeight)
      verify(following.y > closedY)
      verify(row.cardHighlight.height >= row.height - 1)
  }
  ```

  Adapt aliases only to the existing test fixture. The test must fail against the current overlay implementation because the overlay does not own Row layout height.

- [ ] **Step 4: Add selection and dismissal tests.**

  Cover selection, Escape, title toggle, and outside-click dismissal. Preserve the value for dismissal-only paths and assert `menuOpen === false` after each path. Use `Qt.Key_Escape` through the existing test key event helper and click the next Row or its background for outside dismissal.

- [ ] **Step 5: Run the focused test and confirm it fails for the intended geometry reason.**

  Run:

  ```bash
  qs -p tests/qml/tst_lazer_settings_panel.qml
  ```

  Expected result: the new expansion assertion fails or the current test runner reports the known `qrc:/qs-blackhole` environment blocker. Do not weaken the assertions to accommodate the overlay behavior.

- [ ] **Step 6: Commit the test changes.**

  ```bash
  git add tests/qml/tst_lazer_settings_panel.qml
  git commit -m "test: specify inline settings dropdown geometry"
  ```

## Task 2: Embed the Choice Menu and Own Its Height

**Files:**
- Modify: `modules/lazerbar/LazerSettingsChoice.qml`

**Interfaces:**
- Consumes the existing `model`, `currentValue`, `effectiveEnabled`, `menuOpen`, `LazerTheme.dropdownMaxHeight`, and keyboard/pointer handlers.
- Produces an embedded option list, a stable `menuReservedHeight`, and a full `implicitHeight` that Row can consume.

- [ ] **Step 1: Remove the external overlay calls from open and close.**

  Change `openMenu()` and `closeMenu()` so they only update `menuOpen` and local input/focus state. Remove calls to `SettingsOverlayBridge.showDropdown(root)` and `SettingsOverlayBridge.hideDropdown(root)` from this control. Do not remove bridge code used by unrelated settings surfaces.

- [ ] **Step 2: Define authoritative title, option, and expanded heights.**

  Keep the existing closed height as the title height. Calculate the option list height from the model, the existing option row height (`30`), list padding (`8`), and `LazerTheme.dropdownMaxHeight`, but return `0` for an empty model. Make `menuReservedHeight` represent only the list portion and `implicitHeight` represent the title plus list spacing plus list height:

  ```qml
  readonly property real optionListHeight: menuOpen && effectiveEnabled
      ? Math.min(LazerTheme.dropdownMaxHeight, model.length * 30 + 8) : 0
  readonly property real menuReservedHeight: optionListHeight
  implicitHeight: LazerTheme.settingsChoiceHeight + (optionListHeight > 0 ? 4 + optionListHeight : 0)
  ```

  Preserve the empty-model no-op behavior.

- [ ] **Step 3: Replace the single header-only surface with an inline column.**

  Keep `headerSurface` as the title surface, then add an `Item`/`Column` below it for options. Each option must have a stable height, display its label, expose selected and hover state, and call `selectValue(model[index].value)` on activation. The option list must be `visible` only when `optionListHeight > 0` and must not be positioned outside the Choice root.

- [ ] **Step 4: Add local open/close animation bindings.**

  Animate `height` or the parent Row's height through the Row geometry, not by scaling the option list. The option list can animate opacity/reveal if existing visual rules permit, but its final geometry must be available to layout immediately. Use the project MotionTokens and ensure a second open/close reverses the current transition without stale reserved height.

- [ ] **Step 5: Preserve keyboard semantics and add Escape handling.**

  Keep `Enter`, `Space`, and `Alt+Down` opening/toggling the menu. While open, allow option activation and close on `Escape` without changing `currentValue`. Ensure focus does not remain on an option after the list becomes invisible.

- [ ] **Step 6: Make disabled and hidden states close the menu.**

  Extend the existing `onEffectiveEnabledChanged` behavior so disabled controls close the menu. Add the minimum visibility/lifecycle hook needed for a page switch or hidden page to close the menu; do not introduce a global singleton state for this.

- [ ] **Step 7: Run lint and the focused tests.**

  Run:

  ```bash
  qmllint modules/lazerbar/LazerSettingsChoice.qml
  qs -p tests/qml/tst_lazer_settings_panel.qml
  ```

  Expected: lint passes; the focused test progresses past the Choice geometry assertions or remains blocked only by the documented Quickshell `qrc:/qs-blackhole` issue.

- [ ] **Step 8: Commit the embedded Choice implementation.**

  ```bash
  git add modules/lazerbar/LazerSettingsChoice.qml
  git commit -m "feat: embed settings choice menu in row"
  ```

## Task 3: Make Row Geometry Follow the Embedded Choice

**Files:**
- Modify: `modules/lazerbar/LazerSettingsRow.qml`

**Interfaces:**
- Consumes Choice `implicitHeight`, `menuReservedHeight`, and existing control height properties.
- Produces one animated Row height used by the card surface, focus ring, reset zone, and parent layout.

- [ ] **Step 1: Separate control height from the old overlay reservation.**

  Update `safeControlHeight` and `cardContentHeight` so the Choice's actual `implicitHeight` is used as the control height, while `menuReservedHeight` is not double-counted. For non-Choice controls preserve the current formulas exactly.

- [ ] **Step 2: Keep the Row card and focus ring anchored to actual height.**

  Ensure `cardSurface` and `cardHighlight` remain `anchors.fill: parent`, with the focus ring above visual children and `enabled: false`. Do not add a pointer-catching layer to solve the z-order problem.

- [ ] **Step 3: Add the existing motion behavior to Row height.**

  Add a `Behavior on height` or equivalent project-consistent animation using `MotionTokens` only where the Row is not already animated by its parent. Avoid competing animations that independently animate both `implicitHeight` and `height`; one property must own the transition.

- [ ] **Step 4: Recheck reset-button positioning for expanded Choice rows.**

  Keep the reset zone in its fixed right-side slot and verify its vertical position remains aligned with the Choice title/control rather than the option list. The reset button must remain clickable and must not overlap option rows.

- [ ] **Step 5: Run QML lint and focused tests.**

  ```bash
  qmllint modules/lazerbar/LazerSettingsRow.qml modules/lazerbar/LazerSettingsChoice.qml
  qs -p tests/qml/tst_lazer_settings_panel.qml
  ```

- [ ] **Step 6: Commit Row geometry changes.**

  ```bash
  git add modules/lazerbar/LazerSettingsRow.qml
  git commit -m "fix: animate settings row for inline choice menu"
  ```

## Task 4: Verify Content Layout and Outside Dismissal

**Files:**
- Inspect and modify only if required: `modules/lazerbar/LazerSettingsContent.qml`
- Inspect existing page/layout owner files under `modules/lazerbar/`
- Modify: `modules/lazerbar/LazerSettingsChoice.qml` if outside-click routing needs the existing content owner

**Interfaces:**
- Consumes changing Row heights from Task 3.
- Produces updated Flickable content height, bottom scrolling, and outside-click dismissal without a fullscreen dropdown overlay.

- [ ] **Step 1: Trace the current content layout owner.**

  Confirm which `Column`, `Flickable`, or layout item owns the settings rows and how `contentHeight` is derived. Do not replace the existing page architecture if its bindings already react to child height changes.

- [ ] **Step 2: Add only the missing reactive content-height binding.**

  If the current layout uses a fixed content height or excludes dynamic Row height, bind it to the layout's actual implicit height. Keep the outer Flickable responsible for scrolling and do not add a second nested scroll container unless the existing dropdown maximum requires one.

- [ ] **Step 3: Implement outside-click dismissal at the existing content owner.**

  Use the current page/content pointer-routing mechanism to close the open Choice when a click lands outside the active Row. The catcher must not cover the Choice options or steal normal Row/control hover; it should be active only while a menu is open and should call the Choice's close method for outside coordinates.

- [ ] **Step 4: Close menus during category and panel lifecycle changes.**

  On category switch, panel close, hidden page, or disabled state, invoke the existing Choice close path. Keep page objects mounted and preserve their scroll positions.

- [ ] **Step 5: Verify bottom expansion manually through the persistent shell.**

  Open the settings panel, select a Choice near the bottom of the content, expand it, and confirm the outer Flickable can scroll to the full option list. Inspect the Quickshell log for new WARN/ERROR lines.

- [ ] **Step 6: Commit only if this task required changes.**

  ```bash
  git add modules/lazerbar/LazerSettingsContent.qml modules/lazerbar/LazerSettingsChoice.qml
  git commit -m "fix: route inline dropdown dismissal through settings content"
  ```

  If inspection proves no content code needs modification, do not create an empty commit; record the verification in the final validation task.

## Task 5: Add Reduced-Motion and Regression Coverage

**Files:**
- Modify: `tests/qml/tst_lazer_settings_panel.qml`
- Modify: an existing focused Choice test file if one exists after inspection

**Interfaces:**
- Consumes the final Choice/Row/content interfaces from Tasks 2-4.
- Produces coverage for animation interruption, reduced motion, page switching, and preserved unrelated behavior.

- [ ] **Step 1: Add reduced-motion geometry assertions.**

  Set `Lazer.MotionTokens.reducedMotionOverride = true`, open and close the Choice, and assert the final Choice/Row height, following-row position, focus-ring bounds, and `menuOpen` state. Restore the override in the test cleanup path.

- [ ] **Step 2: Add rapid-toggle assertions.**

  Open, close, open, and close the same Choice before the first animation completes. After settling, assert the final height exactly matches the closed state and no option remains visible. Repeat with the final state open and assert the expanded height is stable.

- [ ] **Step 3: Add page-switch and scroll-persistence assertions.**

  Open the Choice, switch category, return to the original category, and assert the menu is closed, the original page remains `visible` only when selected, and its previous `contentY` is preserved.

- [ ] **Step 4: Run the complete available validation set.**

  ```bash
  qmllint modules/lazerbar/LazerSettingsChoice.qml modules/lazerbar/LazerSettingsRow.qml modules/lazerbar/LazerSettingsContent.qml tests/qml/tst_lazer_settings_panel.qml
  git diff --check
  python3 -m pytest -q
  qs -p tests/qml/tst_lazer_settings_panel.qml
  ```

  If `qs` is blocked by `qrc:/qs-blackhole`, record the exact error and complete the persistent-shell validation instead. Any new QML WARN/ERROR must be investigated and fixed.

- [ ] **Step 5: Remove temporary diagnostics.**

  Search for temporary dropdown/hover debug tags and remove them before the final commit:

  ```bash
  rg "DEBUG-settings-hit|DEBUG-dropdown" modules tests
  ```

  Expected: no matches.

- [ ] **Step 6: Commit final tests and validation changes.**

  ```bash
  git add tests/qml/tst_lazer_settings_panel.qml
  git commit -m "test: cover inline settings dropdown lifecycle"
  ```

## Final Review Checklist

- [ ] Confirm `SettingsOverlayBridge.showDropdown(root)` and `hideDropdown(root)` are no longer called by `LazerSettingsChoice`.
- [ ] Confirm the Choice option list is a child of the Row's visual/layout tree, not a cross-Row overlay.
- [ ] Confirm Row `implicitHeight`, actual `height`, card surface, focus ring, and following-row position agree during and after animation.
- [ ] Confirm the reset zone remains usable and does not overlap option rows.
- [ ] Confirm only the current settings page is visible and hit-testable.
- [ ] Confirm no temporary diagnostics remain.
- [ ] Confirm all available validation commands and runtime log checks have been run.
- [ ] Review `git status --short` and ensure only intended files are changed.
