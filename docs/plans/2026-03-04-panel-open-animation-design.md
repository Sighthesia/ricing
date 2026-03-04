# Panel Open/Close Animation — Design Doc

**Date**: 2026-03-04  
**Status**: Approved  
**Scope**: SettingsPanelWindow, WidgetPickerWindow

---

## Background

Currently both panels are shown/hidden via a direct `visible:` binding to a service state
property. This instantly destroys/creates the Wayland surface with no animation, producing
a jarring show/hide experience.

Reference: [noctalia-dev/noctalia-shell](https://github.com/noctalia-dev/noctalia-shell)
uses `SmartPanel.qml` which keeps the surface alive during close animation and orchestrates
an opacity + size growth sequence.

---

## Core Problem

Setting `visible: false` on a `PanelWindow` immediately destroys the Wayland surface,
leaving zero time for a closing animation. A state machine is required to keep the
window alive until the animation completes.

---

## Architecture Decision

**Create `AnimatedPanelBase.qml`** (inherits `PanelWindow`) — a reusable animation base
component. Both panels change their root element from `PanelWindow` to `AnimatedPanelBase`
and bind `active:` instead of `visible:`.

**Why Scale transform over height animation**: `Scale` does not affect the layout tree,
so children with `anchors.fill: parent` are unaffected. Avoids the need to restructure
child component layouts.

---

## State Machine

```
"closed" ──(active=true)──► "opening" ──(scaleAnim.onFinished)──► "open"
  ▲                                                                    │
  └───(scaleAnim.onFinished)──── "closing" ◄──(active=false)──────────┘
```

`PanelWindow.visible = (_state !== "closed")` — window stays alive while closing.

---

## Animation Sequence

| Phase          | Property | Direction | Easing   | Duration | Delay |
|----------------|----------|-----------|----------|----------|-------|
| Opening        | scaleY   | 0 → 1     | OutBack  | 280 ms   | —     |
| Opening        | opacity  | 0 → 1     | OutQuad  | 180 ms   | 60 ms |
| Closing        | opacity  | 1 → 0     | InQuad   | 120 ms   | —     |
| Closing        | scaleY   | 1 → 0     | InBack   | 200 ms   | —     |

Transform origin: `(0, 0)` — grows downward from the bar's bottom edge.

---

## File Changes

| File | Change | Lines |
|------|--------|-------|
| `modules/bar/AnimatedPanelBase.qml` | New — ~70 lines | — |
| `modules/bar/SettingsPanelWindow.qml` | Root: `PanelWindow` → `AnimatedPanelBase`, `visible:` → `active:` | ~3 |
| `modules/bar/WidgetPickerWindow.qml` | Same as above | ~3 |

---

## Non-Goals

- No changes to animation for BarContextMenu (separate component)
- No PanelWindow surface resize — window remains at its fixed `implicitWidth/Height`
- No changes to panel content layouts
