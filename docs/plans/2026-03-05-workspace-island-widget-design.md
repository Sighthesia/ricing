# Workspace Island Widget — Design Document

**Date:** 2026-03-05  
**Status:** Approved

## Overview

Replace the existing numeric `WorkspaceWidget` with a "Dynamic Island" style workspace indicator that:
1. Displays per-workspace window app icons inside each workspace pill
2. Expands downward when a window is focused to reveal the focused window's title below the bar

## Visual Design

```
Normal state (each pill shows window icons):
┌────────────────────────────────────┐
│ [🦊🎵] │ [💻✏️] │ 3 │             │  ← workspace pills (3 = empty, hidden per user pref)
└────────────────────────────────────┘

Focused window (island expands downward):
┌────────────────────────────────────┐
│ [🦊🎵] │ [💻✏️] │                 │
│     Firefox — Example Tab          │  ← title row (overlay, not part of exclusiveZone)
└────────────────────────────────────┘
```

## Architecture

### Files Changed

| File | Change |
|------|--------|
| `modules/bar/BarWindow.qml` | `implicitHeight: Theme.barHeight + 30` (exclusiveZone stays `Theme.barHeight`) |
| `modules/bar/BarContent.qml` | Three BarSection `height: Theme.barHeight` (was `parent.height`) |
| `modules/bar/widgets/WorkspaceWidget.qml` | Complete rewrite |

### Why BarWindow grows but BarContent sections don't

`BarWindow.exclusiveZone` tells the compositor how much space to reserve (windows stay below this).
`BarWindow.implicitHeight` sets the actual window surface height (transparent overflow area).

The 30px delta is transparent until the island expands into it. Since `color: "transparent"` on
`BarWindow`, this area naturally overlays the desktop — identical in concept to Apple's Dynamic
Island using the device notch area.

Constraining `BarSection.height` to `Theme.barHeight` ensures the widget row stays vertically
centred in the visible bar strip, not the taller window surface.

## WorkspaceWidget Component Design

### Root structure

```
Item (root)
├── implicitHeight: Theme.barHeight        (layout height unchanged)
├── implicitWidth: islandBackground.width + 2*spacerPadding
├── clip: false                            (visual overflow allowed)
└── Rectangle (islandBackground)
    ├── y: (Theme.barHeight - _collapsedH) / 2      (vertically centred in bar)
    ├── height: _expanded ? _expandedH : _collapsedH (animated)
    ├── Behavior on height { OutElastic enter / InExpo exit }
    ├── Row (pillsRow)                     (top portion)
    │   └── Repeater (NiriService.workspaces, filtered: occupied only)
    │       └── WorkspacePill
    │           ├── Rectangle (pill bg, highlight when isActive)
    │           ├── Row (iconRow)
    │           │   └── Repeater (wsWindowAppIds array)
    │           │       └── Image (Quickshell.iconPath)
    │           └── MouseArea → niri msg focus-workspace
    └── Text (titleText)                   (bottom portion, enters when expanded)
        ├── y: _collapsedH + _titleGap
        ├── elide: Text.ElideRight
        ├── Behavior on opacity { OutQuad highlightDuration }
        └── text: root.focusedWindowTitle
```

### Dimensions (structure constants)

| Name | Value | Purpose |
|------|-------|---------|
| `_islandPadV` | 4 | Vertical inner padding (island ↔ bar edge) |
| `_islandPadH` | 10 | Horizontal inner padding (icons ↔ island edge) |
| `_iconSize` | 14 | App icon square size |
| `_pillGap` | 5 | Space between workspace pills |
| `_pillPadH` | 8 | Horizontal padding inside each pill |
| `_titleGap` | 4 | Space between pills row and title text |
| `_titleRowH` | 18 | Height of title text row |
| `_collapsedH` | `Theme.barHeight - 2 * _islandPadV` | Island height without title |
| `_expandedH` | `_collapsedH + _titleGap + _titleRowH` | Island height with title |

### Reactive data model

Each workspace delegate holds a local `property var wsWindowAppIds: []` that is refreshed via:
```qml
Connections {
    target: NiriService
    function onWindowsUpdated() { wsDelegate.refreshIcons() }
}
```
`refreshIcons()` iterates `NiriService.windows`, collecting `appId` entries where `workspaceId === wsId`.
Duplicates are **not** removed (user requirement: show one icon per open window).

Root item holds `focusedWindowTitle: string` updated the same way.

### Icon resolution

```qml
function resolveIconPath(appId) {
    if (!appId) return Quickshell.iconPath("application-x-executable")
    const entry = DesktopEntries.heuristicLookup(appId)
    if (entry && entry.icon)
        return Quickshell.iconPath(entry.icon, "application-x-executable")
    return Quickshell.iconPath("application-x-executable")
}
```

Uses Quickshell's built-in `DesktopEntries` singleton (no extra import required beyond `import Quickshell`).

### Animation tokens

| Event | Duration | Easing |
|-------|----------|--------|
| Island expand (title appears) | `Theme.anim.enterDuration` | `Theme.anim.enterType` (OutElastic) |
| Island collapse (title hides) | `Theme.anim.exitDuration` | `Theme.anim.exitType` (InExpo) |
| Title text opacity | `Theme.anim.highlightDuration` | `Theme.anim.highlightType` (OutQuad) |
| Pill width change | `Theme.anim.moveDuration` | `Theme.anim.moveType` (InOutCubic) |

### Empty workspace handling

Empty workspaces (no windows) are **hidden** entirely from the pills row. This is determined at
data refresh time: if `wsWindowAppIds.length === 0` after refresh, that workspace delegate uses
`visible: false`.

Exception: if a workspace is active (`isActive === true`), it is always shown even when empty.

## NiriService compatibility

No changes to `NiriService.qml` required. The existing `windowsUpdated` signal and `windows`
ListModel fields (`appId`, `workspaceId`, `isFocused`, `title`) provide all data.

## BarContent / BarSection wiring

`BarSection` internally uses:
```qml
widgetRow { anchors.verticalCenter: parent.verticalCenter }
```
By changing `height: parent.height → height: Theme.barHeight` in BarContent, the sections stay
at `Theme.barHeight` tall, keeping `verticalCenter` anchoring correct within the visible bar strip.

## Accessibility / edge cases

- Window with empty title: show `appId` capitalised as fallback
- Icon load failure: `Image.status === Image.Error` → hide Image (zero size)
- No focused window: island stays collapsed, title is empty string
- Workspace switch mid-animation: animation restarts via `SmoothedAnimation` reset
