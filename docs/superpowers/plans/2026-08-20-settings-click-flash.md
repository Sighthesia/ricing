# Settings And Common Control Click Flash Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the verified osu-style click flash to selected settings controls and common buttons while preserving existing geometry, input ownership, state transitions, and reduced-motion behavior.

**Architecture:** Keep each component's overlay and trigger local because controls have different surfaces and delegate lifetimes. Store the shared opacity and timing values in `MotionTokens.qml`; route pointer and keyboard activation through each component's existing action path, then trigger the overlay only after an accepted action.

**Tech Stack:** Quickshell QML, QtQuick `NumberAnimation`, `MotionTokens`, QtTest QML tests, `qmllint`, pytest.

## Global Constraints

- Use white overlay opacity `0.3`, duration `800ms`, and `Easing.OutQuint`.
- Overlays are visual-only and must not receive pointer events, change layout dimensions, or alter hit targets.
- Disabled, rejected, empty, duplicate, and focus-only actions must not flash.
- `MotionTokens.reducedMotion` must stop animations and force flash opacity to `0`.
- Preserve existing hover, press-scale, focus, selection, menu, and pseudo-crescent reset behavior.
- Do not add click flash to text-field focus, search clearing, settings navigation, fullscreen navigation, or close actions in this change.
- After every QML change run the relevant `qmllint` and backend tests; record the existing `qrc:/qs-blackhole` blocker if QML tests cannot start.

---

### Task 1: Add Shared Click-Flash Tokens

**Files:**
- Modify: `modules/lazerbar/MotionTokens.qml`
- Test: `tests/qml/tst_lazer_settings_controls.qml`

**Interfaces:**
- Produces `MotionTokens.clickFlashOpacity`, `MotionTokens.clickFlashDuration`, and `MotionTokens.clickFlashEasing` for all controls.
- Existing slider feedback must migrate to the shared opacity and duration tokens without changing its visible behavior.

- [ ] **Step 1: Add token assertions to the existing control test.**

```qml
function test_clickFlashTokens() {
    compare(Lazer.MotionTokens.clickFlashOpacity, 0.3)
    compare(Lazer.MotionTokens.clickFlashDuration, 800)
    compare(Lazer.MotionTokens.clickFlashEasing, Easing.OutQuint)
}
```

- [ ] **Step 2: Run the focused test and record the expected failure or environment blocker.**

Run: `timeout 20 qs -p tests/qml/tst_lazer_settings_controls.qml`

Expected: the new properties fail until implemented; if startup fails first, it reports the known missing `qrc:/qs-blackhole` resource.

- [ ] **Step 3: Add the shared tokens and point `LazerSettingsSlider` at them.**

Add the three read-only properties to `MotionTokens.qml`. Replace the slider's literal `0.3` and `800` values with the shared tokens. Keep `Easing.OutQuint` as the QML easing type because the token stores the enum value for testable consistency.

- [ ] **Step 4: Run static and unit checks.**

Run: `qmllint modules/lazerbar/MotionTokens.qml modules/lazerbar/LazerSettingsSlider.qml tests/qml/tst_lazer_settings_controls.qml`

Run: `pytest -q`

Expected: no lint errors and all Python tests pass; QML execution remains subject to the `qrc:/qs-blackhole` environment resource.

- [ ] **Step 5: Commit the token change.**

```bash
git add modules/lazerbar/MotionTokens.qml modules/lazerbar/LazerSettingsSlider.qml tests/qml/tst_lazer_settings_controls.qml
git commit -m "refactor: share click flash motion tokens"
```

### Task 2: Add Flash To Settings Controls

**Files:**
- Modify: `modules/lazerbar/LazerSettingsToggle.qml`
- Modify: `modules/lazerbar/LazerSettingsChoice.qml`
- Modify: `modules/lazerbar/LazerSettingsRow.qml`
- Test: `tests/qml/tst_lazer_settings_controls.qml`

**Interfaces:**
- Each control exposes read-only test aliases for its flash overlay and animation.
- `LazerSettingsToggle.activate()` triggers its flash after emitting `toggled`.
- `LazerSettingsChoice.openMenu()` flashes the header; changed option selection flashes the selected option and header once.
- `LazerSettingsRow.activateReset()` triggers its reset overlay after invoking `resetCallback`.

- [ ] **Step 1: Add failing assertions for accepted and rejected settings actions.**

Cover these cases in `tst_lazer_settings_controls.qml`:

```qml
toggle.activate()
verify(toggle.flashActive)
toggle.flashAnimationItem.stop()
toggle.flashOverlayItem.opacity = 0
toggle.checked = toggle.checked
compare(toggle.flashActive, false)

choice.openMenu()
verify(choice.flashActive)
choice.flashAnimationItem.stop()
choice.flashOverlayItem.opacity = 0
choice.selectValue(choice.currentValue)
compare(choice.flashActive, false)

resetRow.activateReset()
verify(resetRow.flashActive)
```

Also assert each overlay is non-interactive, has the expected geometry, and reduced motion leaves opacity at `0`.

- [ ] **Step 2: Run the focused QML test before implementation.**

Run: `timeout 20 qs -p tests/qml/tst_lazer_settings_controls.qml`

Expected: assertions fail if the test runtime starts; otherwise the known `qrc:/qs-blackhole` startup error is recorded.

- [ ] **Step 3: Implement toggle flash.**

Add a non-interactive overlay above `capsule`, a `NumberAnimation` from `MotionTokens.clickFlashOpacity` to `0`, and `restartFlash()`. Call it from `activate()` only after the enabled guard and `toggled()` emission. Stop and clear it from reduced-motion handling and expose `flashActive`, `flashOverlayItem`, and `flashAnimationItem` for tests.

- [ ] **Step 4: Implement Choice header and option flash.**

Add a header overlay and a per-delegate option overlay. `openMenu()` restarts the header flash after opening. In `selectValue()`, flash the selected option only when the candidate differs from `currentValue`; then emit `valueSelected()` and restart the header flash once. Ensure a closed or empty menu cannot trigger an overlay.

- [ ] **Step 5: Implement restore-default flash.**

Add a non-interactive overlay inside `revertButton` above its surface and below the icon, and call `restartFlash()` only after `resetCallback()` is invoked. Keep `revertButton.z`, its `x` behavior, geometry, and pseudo-crescent clipping unchanged.

- [ ] **Step 6: Add reduced-motion cleanup and geometry aliases.**

For all three controls, stop the animation and set opacity to `0` when `MotionTokens.reducedMotion` becomes true. Expose only read-only test aliases needed for assertions; do not expose production mutation APIs.

- [ ] **Step 7: Run verification for the settings controls.**

Run: `qmllint modules/lazerbar/LazerSettingsToggle.qml modules/lazerbar/LazerSettingsChoice.qml modules/lazerbar/LazerSettingsRow.qml tests/qml/tst_lazer_settings_controls.qml`

Run: `pytest -q`

Run: `timeout 20 qs -p tests/qml/tst_lazer_settings_controls.qml`

- [ ] **Step 8: Commit settings control feedback.**

```bash
git add modules/lazerbar/LazerSettingsToggle.qml modules/lazerbar/LazerSettingsChoice.qml modules/lazerbar/LazerSettingsRow.qml tests/qml/tst_lazer_settings_controls.qml
git commit -m "feat: add settings control click flash"
```

### Task 3: Add Flash To Common Buttons And Menu Items

**Files:**
- Modify: `modules/lazerbar/IconButton.qml`
- Modify: `modules/lazerbar/MusicControlButton.qml`
- Modify: `modules/lazerbar/MenuItem.qml`
- Test: `tests/qml/tst_osu_top_bar_button.qml` or a focused new QML control test if the existing fixtures cannot host these components

**Interfaces:**
- `IconButton`, `MusicControlButton`, and `MenuItem` expose `flashActive`, `flashOverlayItem`, and `flashAnimationItem` read-only aliases for tests.
- Pointer and keyboard activation trigger the same flash exactly once per accepted activation.

- [ ] **Step 1: Add failing common-button assertions.**

For each component, invoke its existing pointer-equivalent activation path and keyboard path, then assert `flashActive`, token values, overlay bounds, and no flash when disabled. For `IconButton`, preserve the existing `clicked` signal assertions; for `MusicControlButton` and `MenuItem`, preserve their existing signals.

- [ ] **Step 2: Run the focused test before implementation.**

Run: `timeout 20 qs -p tests/qml/tst_osu_top_bar_button.qml`

Expected: new aliases/assertions fail if the runtime starts; otherwise record the existing `qrc:/qs-blackhole` blocker.

- [ ] **Step 3: Implement `IconButton` feedback.**

Add a full-surface non-interactive white overlay and `restartFlash()`. Call it in `activate()`-equivalent paths so keyboard and pointer actions both trigger once. Since `IconButton` currently has separate pointer and keyboard handlers, route both through one internal activation function before emitting `clicked`.

- [ ] **Step 4: Implement `MusicControlButton` feedback.**

Add a full button overlay, internal `activate()` function, and keyboard handlers that call it. The function must guard `enabled`, restart the flash, then emit `clicked`; preserve outlined dimensions, active color, and focus behavior.

- [ ] **Step 5: Implement `MenuItem` feedback.**

Add a full-row non-interactive overlay and internal `activate()` function. Route Return, Enter, Space, and `TapHandler` through it, with an enabled guard before flashing and emitting `triggered`.

- [ ] **Step 6: Add reduced-motion cleanup.**

Connect each component to `MotionTokens.reducedMotionChanged` or use an equivalent local binding so a mode switch immediately stops its animation and clears opacity.

- [ ] **Step 7: Run verification for common buttons.**

Run: `qmllint modules/lazerbar/IconButton.qml modules/lazerbar/MusicControlButton.qml modules/lazerbar/MenuItem.qml tests/qml/tst_osu_top_bar_button.qml`

Run: `pytest -q`

Run: `timeout 20 qs -p tests/qml/tst_osu_top_bar_button.qml`

- [ ] **Step 8: Commit common-button feedback.**

```bash
git add modules/lazerbar/IconButton.qml modules/lazerbar/MusicControlButton.qml modules/lazerbar/MenuItem.qml tests/qml/tst_osu_top_bar_button.qml
git commit -m "feat: add common control click flash"
```

### Task 4: Full Verification And Documentation Alignment

**Files:**
- Modify: `.agents/skills/lazer-settings-surface-details/SKILL.md`
- Test: `tests/qml/tst_lazer_settings_controls.qml`, `tests/qml/tst_osu_top_bar_button.qml`

**Interfaces:**
- The project skill records the final shared token names and the expanded component list.

- [ ] **Step 1: Update the settings skill with the common-control rules.**

Document that click flash is now shared by settings controls, `IconButton`, `MusicControlButton`, and `MenuItem`; keep the exclusions for focus, navigation, search clearing, and close actions.

- [ ] **Step 2: Run lint and Python tests across the changed surface.**

Run: `qmllint modules/lazerbar/MotionTokens.qml modules/lazerbar/LazerSettingsSlider.qml modules/lazerbar/LazerSettingsToggle.qml modules/lazerbar/LazerSettingsChoice.qml modules/lazerbar/LazerSettingsRow.qml modules/lazerbar/IconButton.qml modules/lazerbar/MusicControlButton.qml modules/lazerbar/MenuItem.qml tests/qml/tst_lazer_settings_controls.qml tests/qml/tst_osu_top_bar_button.qml`

Run: `pytest -q`

- [ ] **Step 3: Attempt the project smoke load and focused QML tests.**

Run: `qs -p .`

Run: `timeout 20 qs -p tests/qml/tst_lazer_settings_controls.qml`

Run: `timeout 20 qs -p tests/qml/tst_osu_top_bar_button.qml`

Expected: configuration loads with only existing unrelated warnings; QML tests either pass or explicitly report the missing `qrc:/qs-blackhole` runtime resource.

- [ ] **Step 4: Review the final diff and status.**

Run: `git diff HEAD~3..HEAD --check`

Run: `git status --short`

Confirm no overlay is interactive, no control's layout dimensions are animated by flash, and no excluded action gained flash behavior.

- [ ] **Step 5: Commit the documentation alignment.**

```bash
git add .agents/skills/lazer-settings-surface-details/SKILL.md
git commit -m "docs: document expanded click flash coverage"
```
