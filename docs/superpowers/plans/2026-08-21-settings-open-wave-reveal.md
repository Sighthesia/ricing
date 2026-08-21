# Settings Open Wave Reveal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On settings-panel open, reveal every row in one top-to-bottom wave using the existing search-exit geometry language reversed.

**Architecture:** Row and section gain a shared "reveal hold" state with identical collapsed geometry as search hiding (height 0, opacity 0, x -8). `LazerSettingsSections.playEntranceWave()` arms all holders instantly (transitions snapped), assigns static per-slot delays (18ms per row, 120ms base), and releases them; releases reuse the existing `slow` easing. Panel `beginSession()` triggers the wave; `endSession()` cancels any unfinished wave instantly.

**Tech Stack:** Quickshell, QML/QtQuick, QtTest, MotionTokens.

## Global Constraints

- Only `beginSession()` plays the wave; category switches, search, and sidebar collapse do not.
- `MotionTokens.reducedMotion` skips the wave entirely.
- Final states match today's contract; no persisted values, focus, or scroll targets change.
- Run relevant QML tests after each QML change; resolve WARN/ERROR.

---

### Task 1: Row and section reveal-hold plumbing

**Files:**
- Modify: `modules/lazerbar/LazerSettingsRow.qml`
- Modify: `modules/lazerbar/LazerSettingsSection.qml`

**Interfaces:**
- Produces per item: `revealHeld`, `snapTransitions`, `holdInstantly()`, `playReveal(delayMs)`, unified `geometryHeld` used by height/opacity/x/visible bindings; Behaviors gate on `snapTransitions` and pick pause delay by target direction.

- [ ] Add `revealHeld`, `snapTransitions`, `geometryHeld` properties; unify height/opacity/x/visible bindings on `geometryHeld`.
- [ ] Gate all three Behaviors on `!snapTransitions`; choose pause delay `searchExitDelay` when entering held state, `revealDelay` when leaving.
- [ ] Add `holdInstantly()` (stop timer, snap, hold) and `playReveal(delayMs)` (schedule unsnap+release).
- [ ] Mirror the same set on the section, keyed off `searchEmpty || revealHeld`.

### Task 2: Wave orchestration and session hooks

**Files:**
- Modify: `modules/lazerbar/LazerSettingsSections.qml`
- Modify: `modules/lazerbar/LazerSettingsPanel.qml`
- Test: `tests/qml/tst_lazer_settings_panel.qml`

**Interfaces:**
- Consumes: `contentRows` alias on sections, row/section `holdInstantly`/`playReveal`.
- Produces: `sectionsItem.playEntranceWave()`, `sectionsItem.cancelEntranceWave()`.

- [ ] Expose `contentRows` alias on `LazerSettingsSection`.
- [ ] Implement `playEntranceWave()` walking sections then rows, assigning `baseDelay(120) + slot*18`; skip entirely under reduced motion.
- [ ] Implement `cancelEntranceWave()` releasing all holders instantly; call from `endSession()`; call `playEntranceWave()` from `beginSession()` after `resetScrollState()`.
- [ ] Add tests: wave completes to full geometry; reduced-motion open shows rows immediately; rapid double-open converges; `init()` calls `endSession()` to isolate tests.
- [ ] Run `qs -p tests/qml/tst_lazer_settings_panel.qml` (if harness loads) and `qmllint`; fix WARN/ERROR.
- [ ] Commit: `feat: add settings open wave reveal`.
