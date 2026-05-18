# Design: Center Dockzone Island 展开

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│ BarWindow (PanelWindow, Top layer, per-screen)              │
│  ├─ BarContent                                              │
│  │   ├─ BarSection[left]   (attached)                       │
│  │   ├─ BarSection[center] (attached → expanded)            │
│  │   └─ BarSection[right]  (attached)                       │
│  └─ IslandOverlay (click-away dismiss layer)                │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ IslandWindow (NEW PanelWindow, Top layer, per-screen)       │
│  exclusiveZone: -1, anchors: top+left+right                 │
│  height: screen.height                                      │
│  mask: island body region only                              │
│  ├─ Island body (animated width/height/radius)              │
│  │   ├─ collapsed: clock widget row (current center content)│
│  │   └─ expanded: search + results (launcher content)       │
│  └─ Click-away region (dismiss on click outside body)       │
└─────────────────────────────────────────────────────────────┘
```

## Key Decision: Separate Window vs In-Bar Expansion

**Chosen: Separate IslandWindow** (like the reference project)

Rationale:
- The current BarWindow has `exclusiveZone: barHeight` and `implicitHeight: barHeight`. Expanding the island to 420px would require either changing exclusiveZone (pushing windows down) or overflowing the window bounds (clipped by Wayland).
- The reference project uses a full-screen-height PanelWindow with `exclusiveZone: -1` and a mask region to only receive input on the island body.
- A separate window on `WlrLayer.Top` with `exclusiveZone: -1` can overlay content below the bar without affecting layout.

Tradeoff: Two windows need coordination. The center dockzone in BarWindow becomes hidden when IslandWindow is expanded, or the IslandWindow always owns the center content (preferred — simpler state).

**Refined approach: IslandWindow always owns center content.**
- BarWindow keeps left/right sections only.
- IslandWindow renders the center dockzone in collapsed state (same visual as today) AND the expanded state.
- This avoids cross-window state sync for the collapsed→expanded transition.

## State Machine

```
IslandService (new singleton):
  property bool expanded: false
  property string query: ""
  readonly property string mode: derived from query prefix (">clip " → clipboard, else apps)

  function toggle()
  function open()
  function close()  // resets query
```

The existing `LauncherService` IPC handler (`qs ipc call launcher.toggle`) will be rewired to call `IslandService.toggle()`.

### State → Geometry Mapping

| State     | Width  | Height          | Radius | Content           |
|-----------|--------|-----------------|--------|-------------------|
| collapsed | ~220px | barHeight (42)  | 16     | Clock widget row  |
| expanded  | 480px  | 80 + results    | 24     | Search + results  |

Height in expanded state is clamped to max 420px.

## Animation Strategy

Follow the reference project's SpringAnimation approach:

```qml
property int targetW: expanded ? 480 : collapsedW
property int targetH: expanded ? expandedH : collapsedH
property int targetR: expanded ? 24 : 16

Behavior on width  { SpringAnimation { spring: 5.0; mass: 3.6; damping: 0.75 } }
Behavior on height { SpringAnimation { spring: 5.0; mass: 3.6; damping: 0.75 } }
Behavior on radius { SpringAnimation { spring: 5.0; mass: 3.6; damping: 0.75 } }
```

Content crossfade via opacity (collapsed content fades out, expanded content fades in) with `NumberAnimation { duration: 200 }`.

## Content Architecture

Expanded content reuses existing launcher logic:
- `IslandSearchInput` — text input with mode prefix detection
- `IslandResults` — Loader switching between AppGrid and ClipboardList based on mode
- Both components already exist in `modules/launcher/`; they will be refactored to accept width/height props and work in the island context.

## Input Handling

- **Keyboard focus**: IslandWindow gets `WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive` when expanded, `None` when collapsed.
- **Mask region**: Only the island body receives pointer events. A full-window MouseArea behind the body dismisses on click (click-away).
- **Escape**: Closes expanded state.

## Module Boundaries

```
services/
  IslandService.qml          (NEW — state owner)
  qmldir                     (add IslandService)

modules/island/              (NEW module)
  IslandWindow.qml           (PanelWindow + Variants)
  IslandBody.qml             (animated body + content switching)
  IslandSearchInput.qml      (search bar)
  IslandResults.qml          (Loader: apps/clipboard)

modules/launcher/            (existing — shared components)
  AppGrid.qml                (reused as-is)
  ClipboardList.qml          (reused as-is)
```

## Compatibility & Migration

- `LauncherService.toggle()` IPC remains functional — internally delegates to `IslandService.toggle()`.
- `LauncherWindow` stays in `shell.qml` for now (can be removed later).
- Center dockzone in BarWindow becomes empty/hidden when IslandWindow is active (or we remove center section from BarWindow entirely and let IslandWindow own it permanently).

## Rollback

If the island approach doesn't work well:
- Remove `modules/island/` and `IslandService.qml`
- Restore center section in BarWindow
- Revert LauncherService IPC delegation
- All changes are additive; no destructive modifications to existing working code.
