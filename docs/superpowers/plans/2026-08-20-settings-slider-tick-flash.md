# Settings Slider Tick Flash Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an osu-authoritative flash overlay to `LazerSettingsSlider` whenever a user-driven value change lands on a new discrete step.

**Architecture:** Keep `setValue()` as the single normalized mutation path and add a private flash trigger beside the existing slider state. Render one non-interactive overlay between the track/fill and the thumb/default marker; restart its opacity animation on each changed user step without changing slider geometry or input ownership. Expose only the minimum read-only aliases needed by QML tests.

**Tech Stack:** QtQuick/QML, Quickshell, `NumberAnimation`, `Easing.OutQuint`, existing `MotionTokens` and `LazerTheme` tokens, QtTest QML tests, `qmllint`, Python `pytest`.

## Global Constraints

- Match osu's authoritative click flash: white at `0.3` opacity, `800ms`, `Easing.OutQuint`.
- Trigger only from user interaction paths that change the normalized value; initialization and external property synchronization do not flash.
- Pointer taps, pointer dragging, keyboard left/right movement, and reset-to-default use the same `setValue()` trigger path.
- Repeated assignment of the current normalized value does not retrigger the flash.
- The overlay is non-interactive and must not alter the slider's geometry or input boundary.
- `MotionTokens.reducedMotion` keeps the overlay invisible and disables time-based animation.
- Do not change step rounding, persistence, hover focus glow, thumb motion, default marker, or row layout.
- After every QML change, run the relevant QML checks and fix all QML warnings/errors that are attributable to the change.

---

### Task 1: Add failing slider flash tests

**Files:**
- Modify: `tests/qml/tst_lazer_settings_controls.qml` in the slider control test case.
- Reference: `modules/lazerbar/LazerSettingsSlider.qml` for existing `valueModified`, `displayFraction`, `dragging`, and `rangePadding` seams.

**Interfaces:**
- Consumes: the existing slider fixture and its `setValue()`, `increase()`, `resetToDefault()`, and exposed child aliases.
- Produces: regression tests expecting `slider.flashOverlayItem`, `slider.flashAnimationItem`, and `slider.flashActive` to exist after implementation.

- [ ] **Step 1: Inspect the existing slider fixture and test naming.**

  Locate the current `LazerSettingsSlider` fixture and keep all new assertions in that existing test case so the test uses the repository's current import and theme setup.

- [ ] **Step 2: Add a geometry and input-isolation test.**

  Add assertions in the existing style:

  ```qml
  function test_sliderFlashOverlayPreservesGeometryAndInputIsolation() {
      var slider = createSlider({ from: 0, to: 10, stepSize: 1, value: 2 })
      var width = slider.width
      var height = slider.height
      verify(slider.flashOverlayItem)
      verify(slider.flashAnimationItem)
      verify(!slider.flashOverlayItem.enabled)
      compare(slider.flashOverlayItem.width, slider.trackRectItem.width)
      compare(slider.flashOverlayItem.height, slider.trackRectItem.height)
      compare(slider.width, width)
      compare(slider.height, height)
  }
  ```

  Adapt only the fixture construction and existing child alias names to match the file's current helpers; do not introduce a second slider fixture abstraction.

- [ ] **Step 3: Add changed-step and repeated-step tests.**

  Verify a changed normalized value activates the flash and assigning the same value does not increment a trigger counter or restart the animation. Use the existing `valueModified` spy/counter pattern if present; otherwise add a local counter connected to `valueModified`.

  ```qml
  function test_sliderFlashStartsOnlyForChangedStep() {
      var slider = createSlider({ from: 0, to: 10, stepSize: 1, value: 2 })
      compare(slider.flashActive, false)
      slider.setValue(3)
      compare(slider.flashActive, true)
      slider.setValue(3)
      compare(slider.flashActive, true)
  }
  ```

- [ ] **Step 4: Add reset and reduced-motion tests.**

  Confirm `resetToDefault()` uses the same flash path when it changes the value, and confirm the reduced-motion branch leaves the overlay invisible and the animation stopped. Set and restore `MotionTokens.reducedMotion` using the existing test convention so the test cannot leak global state.

- [ ] **Step 5: Run the focused test file before implementation.**

  Run:

  ```bash
  timeout 20 qs -p tests/qml/tst_lazer_settings_controls.qml
  ```

  Expected: the test configuration may fail before execution if `qrc:/qs-blackhole` is unavailable; otherwise the new assertions fail because the flash aliases/state do not yet exist.

- [ ] **Step 6: Commit the failing tests.**

  ```bash
  git add tests/qml/tst_lazer_settings_controls.qml
  git commit -m "test: define settings slider tick flash behavior"
  ```

### Task 2: Implement the osu-style flash overlay

**Files:**
- Modify: `modules/lazerbar/LazerSettingsSlider.qml` around the root properties, `setValue()`, and track visual layers.

**Interfaces:**
- Consumes: `setValue(candidate)`, `effectiveEnabled`, `MotionTokens.reducedMotion`, `LazerTheme.textPrimary`, `trackHost`, `trackRect`, and existing slider value paths.
- Produces: read-only aliases `flashOverlayItem`, `flashAnimationItem`, boolean `flashActive`, and a user-step flash restart from `setValue()`.

- [ ] **Step 1: Add private flash state and test aliases.**

  Add the following root state near the existing read-only slider state:

  ```qml
  readonly property bool flashActive: flashAnimation.running || flashOverlay.opacity > 0
  property alias flashOverlayItem: flashOverlay
  property alias flashAnimationItem: flashAnimation
  ```

  Keep the public behavior limited to these read-only/test-facing signals; do not add a new public value API.

- [ ] **Step 2: Restart the flash only after a changed normalized value.**

  Update `setValue()` without changing normalization or `valueModified` semantics:

  ```qml
  function setValue(candidate) {
      var next = normalized(candidate)
      if (next === Number(value))
          return
      valueModified(next)
      restartFlash()
  }

  function restartFlash() {
      if (!root.effectiveEnabled || MotionTokens.reducedMotion)
          return
      flashAnimation.restart()
  }
  ```

  If the existing QML runtime requires a stopped animation to be re-armed explicitly, set the overlay opacity to `0` before `restart()` only when the animation is not running; do not add timers or delayed callbacks.

- [ ] **Step 3: Add the non-interactive additive-style overlay.**

  Place this visual layer after `fillRect` and before `defaultMarker`/`thumb`, preserving the current z ordering. It must cover `trackRect`, use `LazerTheme.textPrimary`, and not receive pointer input:

  ```qml
  Rectangle {
      id: flashOverlay
      z: 2
      anchors.fill: trackRect
      radius: trackRect.radius
      color: LazerTheme.textPrimary
      opacity: 0
      enabled: false
  }
  ```

  Use the repository's available QML composition mechanism to approximate osu's additive overlay without introducing a dependency. If the project already uses `MultiEffect` for colour blending, use that existing mechanism; otherwise preserve the flat overlay and document the chosen blend behavior in the code comment.

- [ ] **Step 4: Add the authoritative `800ms` `OutQuint` fade.**

  Add an animation that starts at full osu-equivalent flash strength and decays to zero:

  ```qml
  NumberAnimation {
      id: flashAnimation
      target: flashOverlay
      property: "opacity"
      from: 0.3
      to: 0
      duration: 800
      easing.type: Easing.OutQuint
      running: false
      enabled: !MotionTokens.reducedMotion
  }
  ```

  Ensure `restartFlash()` makes a new flash visibly begin even while the previous fade is active. With reduced motion, force opacity to zero and keep the animation stopped.

- [ ] **Step 5: Run lint and the focused controls tests.**

  Run:

  ```bash
  qmllint modules/lazerbar/LazerSettingsSlider.qml tests/qml/tst_lazer_settings_controls.qml
  timeout 20 qs -p tests/qml/tst_lazer_settings_controls.qml
  ```

  Expected: `qmllint` passes. The QML test may still stop at the known missing `qrc:/qs-blackhole` resource; if it executes, all new flash assertions pass.

- [ ] **Step 6: Commit the slider implementation.**

  ```bash
  git add modules/lazerbar/LazerSettingsSlider.qml tests/qml/tst_lazer_settings_controls.qml
  git commit -m "feat: flash settings slider tick changes"
  ```

### Task 3: Run the full verification set and close the change

**Files:**
- Verify: `modules/lazerbar/LazerSettingsSlider.qml`
- Verify: `tests/qml/tst_lazer_settings_controls.qml`
- Verify: `docs/superpowers/specs/2026-08-20-settings-slider-tick-flash-design.md`

**Interfaces:**
- Consumes: the completed slider overlay and test contract from Tasks 1-2.
- Produces: a clean, committed implementation with recorded environment limitations.

- [ ] **Step 1: Run repository Python tests.**

  ```bash
  pytest -q
  ```

  Expected: all existing Python tests pass.

- [ ] **Step 2: Run QML lint across the modified settings controls.**

  ```bash
  qmllint modules/lazerbar/LazerSettingsSlider.qml tests/qml/tst_lazer_settings_controls.qml
  ```

  Expected: no warnings or errors attributable to the flash implementation.

- [ ] **Step 3: Launch the config.**

  ```bash
  timeout 12 qs -p .
  ```

  Expected: `Configuration Loaded`; the pre-existing notification-server warning is acceptable.

- [ ] **Step 4: Attempt the focused and panel QML tests.**

  ```bash
  timeout 20 qs -p tests/qml/tst_lazer_settings_controls.qml
  timeout 20 qs -p tests/qml/tst_lazer_settings_panel.qml
  ```

  Expected: tests execute and pass when `qrc:/qs-blackhole` is available. If the resource is missing, record the exact loader error and do not misclassify it as a slider failure.

- [ ] **Step 5: Review the final diff.**

  ```bash
  git diff --check HEAD~2..HEAD
  git status --short
  ```

  Confirm only the slider implementation and focused tests changed after the plan/spec commits, with no generated files or unrelated edits.

- [ ] **Step 6: Commit any verification-only correction.**

  If verification finds a real implementation issue, fix it and commit with a focused conventional message such as:

  ```bash
  git add modules/lazerbar/LazerSettingsSlider.qml tests/qml/tst_lazer_settings_controls.qml
  git commit -m "fix: correct settings slider tick flash"
  ```
