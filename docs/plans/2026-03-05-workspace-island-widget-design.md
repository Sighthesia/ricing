# Workspace Island Widget — Design Document

**Date:** 2026-03-05  
**Status:** Approved (v2 — Two-State Morph)

## Overview

Replace the existing numeric `WorkspaceWidget` with a two-state Dynamic Island widget:

- **Focus Mode** (default): Single pill showing focused window icon + title. Width expands to fit the title.
- **Overview Mode**: Multiple pills showing per-workspace app icons — one pill per occupied workspace.

The widget morphs between the two states via a "pills converge → single wide pill expands" animation.
Only `WorkspaceWidget.qml` is changed; `BarWindow` and `BarContent` remain untouched.

## Visual Design

```
Focus Mode (default when a window is focused):
┌────────────────────────────────────────────────────────────┐ bar
          ┌──────────────────────────────────────────┐
          │  🦊  Firefox — A Very Long Article Title  │  ← single pill, width fits title
          └──────────────────────────────────────────┘
└────────────────────────────────────────────────────────────┘

Overview Mode (hover or no focused window):
┌────────────────────────────────────────────────────────────┐ bar
          ┌─────────┐ ┌──────────┐ ┌───┐
          │ 🦊 🎵   │ │ 💻 ✏️    │ │ 3 │  ← workspace pills (3 = empty active WS)
          └─────────┘ └──────────┘ └───┘
└────────────────────────────────────────────────────────────┘

Transition (Focus → Overview on hover):
pills     ← single pill shrinks left+right toward center
pills     → workspace pills bloom outward from center
```

## State Machine

```
         ┌──────────┐
         │  [INIT]  │
         └────┬─────┘
              │ window focused?
       ┌──────┴──────┐
       │ yes         │ no
       ▼             ▼
  [FOCUS_MODE]  [OVERVIEW_MODE]   ← fallback, no focused window
       │                │
       │ hover start    │ hover start
       ▼                ▼
  [OVERVIEW_HOVER] [FOCUS_HOVER]  ← temporary toggle; reverts on hover end
       │
  workspace switch ────► [OVERVIEW_FLASH]  (1.5 s timer, then return to FOCUS_MODE)
```

| Condition | State |
|---|---|
| Focused window exists | `focus` |
| No focused window (desktop) | `overview` |
| Mouse hovering over widget | Temporary flip to opposite state |
| Workspace switch (≤1.5 s) | Temporary `overview`, then return to prior state |

## Architecture

Only one file changed:

| File | Change |
|------|--------|
| `modules/bar/widgets/WorkspaceWidget.qml` | Complete rewrite |

`BarWindow.qml` and `BarContent.qml` are **not** modified. The widget stays within `Theme.barHeight`.

## WorkspaceWidget Component Design

### Root structure

```
Item (root)
├── implicitHeight: Theme.barHeight
├── implicitWidth: _activePillWidth + _padH * 2
│
├── [State machine properties]
│   ├── property string _mode         // "focus" | "overview"
│   ├── property bool   _hoverOverride // hover triggers temp flip
│   ├── readonly bool   _showOverview  // derived: _mode === "overview" XOR _hoverOverride
│   └── Timer (_flashTimer)           // 1500ms; on triggered: _mode = "focus"
│
├── [Data properties]
│   ├── property string focusedAppId
│   ├── property string focusedWindowTitle
│   └── function _refresh()
│
│── MouseArea (hover detection, anchors.fill: parent)
│
├── Item (overviewLayer)  — opacity: _showOverview ? 1 : 0, animated
│   └── Row (pillsRow)
│       └── Repeater (NiriService.workspaces)
│           └── WorkspacePill
│               ├── Rectangle (pill bg)
│               ├── Row (iconRow) → Repeater (wsAppIds)
│               │   └── Image (Quickshell.iconPath)
│               └── MouseArea → niri msg focus-workspace
│
└── Item (focusLayer)  — opacity: _showOverview ? 0 : 1, animated
    └── Rectangle (focusPill)
        ├── implicitWidth: iconBox.width + _padH + titleText.implicitWidth + _padH
        ├── Behavior on implicitWidth { moveDuration, moveType }
        ├── Image (focusIcon)
        └── Text (titleText, elide: ElideRight, max ~240px)
```

### Dimensions (structure constants)

| Name | Value | Purpose |
|------|-------|---------|
| `_padV` | 4 | Vertical padding (pill ↔ bar edge) |
| `_padH` | 10 | Horizontal padding inside pills |
| `_iconSize` | 16 | App icon in focus pill |
| `_smallIconSize` | 13 | App icons inside workspace pills |
| `_iconSpacing` | 2 | Gap between icons in a workspace pill |
| `_pillGap` | 6 | Gap between workspace pills |
| `_pillPadH` | 8 | Horizontal padding inside each workspace pill |
| `_pillH` | `Theme.barHeight - 2 * _padV` | Pill height |
| `_titleMaxW` | 240 | Maximum title width before ElideRight kicks in |

### Reactive data model

Each workspace delegate holds a local `property var _appIds: []` refreshed on `NiriService.windowsUpdated`.
Duplicates are **not** removed (one icon per open window).

Root holds `focusedAppId` and `focusedWindowTitle`, updated by iterating `NiriService.windows` to find `isFocused === true`.

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

| Event | Token | Purpose |
|---|---|---|
| Layer cross-fade (focus ↔ overview) | `exitDuration` / `exitType` | Current layer fades out |
| Layer cross-fade (focus ↔ overview) | `enterDuration` / `enterType` | New layer fades in |
| Focus pill width (title length changes) | `moveDuration` / `moveType` | Smooth horizontal resize |
| Workspace pill width | `moveDuration` / `moveType` | Reflow when icons change |
| Overview pill color (active toggle) | `highlightDuration` | Active workspace highlight |

### Empty workspace handling

Empty workspaces are **hidden** from the overview row. Exception: the active workspace is always
shown even when empty (displays its number instead of icons).

## NiriService compatibility

No changes to `NiriService.qml` required. The existing `windowsUpdated` signal and `windows`
ListModel fields (`appId`, `workspaceId`, `isFocused`, `title`) provide all data.

NiriService field mapping:

| NiriService field | Used for |
|---|---|
| `w.isFocused` | Detect focused window for focus mode |
| `w.title` | Title text in focus pill |
| `w.appId` | Icon resolution in both modes |
| `w.workspaceId` | Match windows to workspace pills |
| `NiriService.workspaces` | Drive the overview Repeater |
| `w.isActive` (workspace) | Active workspace pill highlight |

## Edge cases

| Scenario | Behavior |
|---|---|
| No focused window (desktop) | Force `overview` mode regardless of default setting |
| Focused window, empty title | Fall back to `appId` (capitalised) |
| Icon load failure | Zero-size `Image` so `Row` layout adapts |
| Workspace switch while in focus mode | `_flashTimer` triggers 1500 ms overview flash, then returns |
| Rapid workspace switching | Timer resets on each switch (debounce) |
| Very long title (> `_titleMaxW`) | `elide: Text.ElideRight` truncates gracefully |
