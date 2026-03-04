# Settings Panel Content Stagger Animation — Design Doc

**Date**: 2026-03-04  
**Status**: Approved  
**Scope**: SettingsPanelContent, SettingsSidebar, AnimatedPanelBase, SettingsPanelWindow

---

## Background

The panel window itself already has a drop-down scaleY animation (AnimatedPanelBase).
This document covers the **secondary content stagger** — each structural item inside the
settings panel slides in from below with an increasing delay, creating the osu!lazer-style
cascaded entrance/exit effect.

---

## Signal Architecture

```
AnimatedPanelBase
    signal panelOpening   ← emitted when _state → "opening"
    signal panelClosing   ← emitted when _state → "closing"

SettingsPanelWindow (Connections)
    panelOpening  → content.runEnterAnimation()
    panelClosing  → content.runExitAnimation()

SettingsPanelContent
    function runEnterAnimation()   → starts searchBar + mainRow timers, calls sidebar.runEnterAnimation()
    function runExitAnimation()    → starts searchBar + mainRow timers, calls sidebar.runExitAnimation()

SettingsSidebar
    signal enterAnimationTriggered
    signal exitAnimationTriggered
    function runEnterAnimation()   → emit enterAnimationTriggered
    function runExitAnimation()    → emit exitAnimationTriggered
    Delegate items receive signal, start Timer(baseDelay + index * stepMs)
```

---

## Per-Item Animation Properties

Each staggerable item holds two animated properties:
- `opacity` — 0.0 ↔ 1.0
- `_offsetY` — drives a `Translate { y: _offsetY }` transform

Initial state (before any enter): `opacity = 0.0`, `_offsetY = 20`.

---

## Enter Timing (relative to `panelOpening`)

| Item           | Delay         | Duration | Easing   |
| -------------- | ------------- | -------- | -------- |
| Panel scaleY   | 0 ms          | 280 ms   | OutBack  |
| searchBar      | 80 ms         | 280 ms   | OutCubic |
| sidebar nav[0] | 120 ms        | 280 ms   | OutCubic |
| sidebar nav[1] | 155 ms        | 280 ms   | OutCubic |
| sidebar nav[n] | 120 + n×35 ms | 280 ms   | OutCubic |
| contentItem    | 160 ms        | 280 ms   | OutCubic |

---

## Exit Timing (relative to `panelClosing`)

Exit is fast and overlaps with panel scaleY close (200 ms InBack).

| Item           | Delay     | Duration | Easing  |
| -------------- | --------- | -------- | ------- |
| Panel scaleY   | 0 ms      | 200 ms   | InBack  |
| searchBar      | 0 ms      | 100 ms   | InCubic |
| contentItem    | 0 ms      | 100 ms   | InCubic |
| sidebar nav[n] | n × 15 ms | 100 ms   | InCubic |

Exit animation: `opacity → 0`, `_offsetY → 10` (slide down slightly, then disappear).

---

## Reset Rule

`runEnterAnimation()` always resets opacity/offsetY instantly (Behavior disabled with a
flag) before restarting Timers, so rapid open→close→open cycles start clean.

---

## File Changes

| File                       | Change                                                                                                |
| -------------------------- | ----------------------------------------------------------------------------------------------------- |
| `AnimatedPanelBase.qml`    | Add `signal panelOpening` / `signal panelClosing`                                                     |
| `SettingsPanelWindow.qml`  | Add `Connections` forwarding signals to `content`                                                     |
| `SettingsPanelContent.qml` | Add `_offsetY` + opacity animation + Timer to searchBar and contentItem wrapper; add public functions |
| `SettingsSidebar.qml`      | Add signals + delegate-level stagger Timers + PropertyAnimations                                      |
