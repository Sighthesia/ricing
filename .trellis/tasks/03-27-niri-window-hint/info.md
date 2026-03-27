# Niri Window Hint Mixed Design

## Overview

This design uses a mixed ownership model for the `niri` window hint.

- `WorkspaceWidget` owns the stable, always-on workspace summary in the bar.
- `SuperIsland` owns the temporary floating hint that appears while the hint trigger is active.
- A dedicated derived-state service owns all window-hint data preparation.

The goal is to keep steady-state workspace UI and transient spatial-preview UI separate while reusing the existing center-lane animation shell.

## Design Principles

### 1. Stable and transient UI must not share rendering ownership

`WorkspaceWidget` should stay lightweight and predictable. It is the bar's long-lived workspace affordance.

`SuperIsland` should stay responsible for temporary, center-focused, animated surfaces.

### 2. Workspace relationships must be computed once

Window ordering, current index, neighboring titles, and adjacent workspace icon strips must come from one shared source.

### 3. The hint is a preview, not a switcher

The UI should explain spatial structure without taking over navigation semantics.

### 4. The hint should feel attached to the bar center, not replace the bar

The floating surface appears below the center section and visually extends the existing center affordance.

## External Constraints

### `niri` data model

The current shell already reads the following from `niri` IPC through `NiriService`:

- workspace list
- active workspace changes
- window list
- focused window changes
- horizontal layout coordinates via `pos_in_scrolling_layout`

This is enough to derive the current workspace window order and adjacent workspace summaries.

### `Mod` hold behavior

The current codebase does not expose a shared modifier-held state.

Based on `niri` key-binding documentation, binds are action-oriented and repeat-oriented, but there is no existing in-repo proof that a bare `Mod` press and release can be observed directly inside the shell UI.

Therefore the design should treat the trigger mechanism as a replaceable input source.

## Ownership Model

## 1. `NiriService`

Keep `NiriService` as the raw compositor adapter.

Responsibilities:

- fetch and normalize workspaces
- fetch and normalize windows
- emit source update signals

Non-responsibilities:

- do not embed presentation-specific hint layout logic
- do not compute UI-only slices such as `prevTitle` or icon-strip display models

## 2. `WindowHintService` (new)

Create a new singleton service dedicated to transient window-hint state.

Suggested file:

- `services/WindowHintService.qml`

Responsibilities:

- derive current workspace windows in horizontal order
- identify the currently focused window inside the active workspace
- derive previous and next window metadata
- derive previous and next workspace icon-strip summaries
- expose whether hint mode is active
- expose a snapshot payload that can be rendered by `SuperIsland`

Non-responsibilities:

- do not own heavy animation state
- do not render UI
- do not replace `WorkspaceWidget` summary logic

## 3. `WorkspaceWidget`

Keep `WorkspaceWidget` as the always-on center widget for workspace status.

Responsibilities:

- present the normal workspace/focus summary
- optionally dim, compress, or visually yield when hint mode is active
- remain the stable center anchor when no hint is shown

Non-responsibilities:

- do not render the full two-row hint
- do not duplicate the adjacent workspace icon strips
- do not own trigger lifecycle for the floating preview

## 4. `SuperIslandService`

Extend `SuperIslandService` so it can host a persistent-for-hold transient event type.

Suggested behavior:

- add a `window-hint` event type or dedicated hold-mode state
- suspend normal transient replacement while hold hint is active
- restore previous baseline state when the hint closes

## 5. `SuperIslandWidget`

Let `SuperIslandWidget` render the floating hint surface.

Responsibilities:

- reuse center expansion and reveal choreography
- render a dedicated `window-hint` card
- place the surface below the bar center visual anchor
- animate enter and exit without affecting bar layout width contracts

## Data Contract

`WindowHintService` should expose one normalized payload for rendering.

Suggested shape:

```qml
property var activeHint: ({
    visible: false,
    workspaceId: "",
    workspaceIndex: -1,
    currentWindowId: "",
    currentWindowTitle: "",
    currentWindowIcon: "",
    currentIndex: -1,
    windows: [
        {
            windowId: "",
            title: "",
            appId: "",
            icon: "",
            isFocused: false,
            columnIndex: 0
        }
    ],
    previousWindow: ({
        windowId: "",
        title: "",
        icon: ""
    }),
    nextWindow: ({
        windowId: "",
        title: "",
        icon: ""
    }),
    previousWorkspace: ({
        workspaceId: "",
        workspaceIndex: -1,
        icons: []
    }),
    nextWorkspace: ({
        workspaceId: "",
        workspaceIndex: -1,
        icons: []
    })
})
```

Notes:

- `windows` is the first-row source of truth.
- `previousWindow` and `nextWindow` power the second row.
- `previousWorkspace.icons` and `nextWorkspace.icons` power the upper and lower translucent icon strips.

## Interaction Flow

## Idle

- `WorkspaceWidget` shows the current steady-state summary.
- `SuperIsland` behaves normally.
- `WindowHintService.activeHint.visible` is `false`.

## Trigger Active

- input bridge sets `WindowHintService.hintHeld = true`
- `WindowHintService` snapshots the current derived hint payload
- `SuperIslandService` enters `window-hint` hold mode
- `WorkspaceWidget` shifts into a yielded state
- `SuperIslandWidget` expands and renders the hint card

## Trigger Released

- input bridge sets `WindowHintService.hintHeld = false`
- `SuperIslandWidget` animates out
- `SuperIslandService` restores normal baseline or queued transient state
- `WorkspaceWidget` returns to its default visible weight

## During Workspace or Focus Changes While Held

Recommended behavior:

- keep the hint live-updating while the trigger remains active
- reuse one stable card instance instead of rebuilding the whole event chain
- animate local element changes lightly, but do not replay the full entrance animation

This keeps the preview feeling like a live lens rather than a notification.

## Visual Structure

## Placement

- anchor to the bar center lane
- place below the bar center, not inside the bar height
- maintain a small gap so the hint reads as a floating extension

## Row 1: Current workspace strip

- show all windows in current workspace in horizontal order
- use compact icons with optional focused-title emphasis on the active item
- focused item uses strongest contrast and background support
- immediate neighbors use medium emphasis
- distant items stay compact and low-noise

## Row 2: Previous / Current / Next titles

- left cell: previous window title
- center cell: current window title
- right cell: next window title

Rules:

- center cell gets the widest allocation
- left and right cells use muted color and harder elision
- empty neighbor states show nothing or a subtle placeholder, not fake labels

## Upper and lower translucent strips

- upper strip represents the previous workspace
- lower strip represents the next workspace
- only show icons, not titles
- crop opacity and size so these strips remain contextual, not primary
- if adjacent workspace has no windows, hide the strip entirely

## Component Plan

Suggested new files:

- `services/WindowHintService.qml`
- `modules/bar/superisland/IslandWindowHintCard.qml`

Suggested touched files:

- `services/SuperIslandService.qml`
- `modules/bar/widgets/SuperIslandWidget.qml`
- `modules/bar/widgets/WorkspaceWidget.qml`
- `modules/bar/BarContent.qml`

## Anti-Duplication Rules

To preserve the mixed design, keep these rules strict:

- only `WindowHintService` computes window-order relationships
- only `WorkspaceWidget` renders the always-on workspace summary
- only `SuperIsland` renders the floating hold hint
- only one place owns trigger-to-visibility bridging

If any second implementation of workspace ordering appears in `WorkspaceWidget` or `SuperIslandWidget`, the design has drifted.

## Trigger Strategy

Because bare `Mod` hold may require compositor-side or helper-side integration, define the trigger behind an abstraction.

Suggested contract:

- `WindowHintService.setHintHeld(bool active)`

Possible future trigger sources:

- compositor-integrated helper
- external small daemon that emits press/release
- fallback composite shortcut flow such as `Mod+Tab` session preview

This keeps UI architecture stable even if the input source changes.

## Failure and Edge Cases

### No focused window

- show current workspace strip
- second row center falls back to workspace name or remains empty

### Empty active workspace

- first row collapses to an empty state
- adjacent strips can still appear if neighbors contain windows

### Single window in workspace

- highlight the only window
- hide previous and next title cells

### Adjacent workspace missing

- hide the corresponding upper or lower strip

### Floating windows or unknown ordering

- sort tiled windows by `colIdx`
- place unpositioned or floating windows after tiled windows
- keep this consistent with existing `NiriService` sentinel logic

## Recommended Implementation Phases

### Phase 1: Data layer

- add `WindowHintService`
- derive normalized hint payload from `NiriService`
- add trigger API only

### Phase 2: Rendering layer

- create `IslandWindowHintCard`
- teach `SuperIslandWidget` to render the new card type
- keep trigger mocked if needed

### Phase 3: Integration layer

- connect trigger source to `WindowHintService.setHintHeld()`
- make `WorkspaceWidget` yield visually during hold
- tune motion and spacing

### Phase 4: Validation

- verify the shell still loads with `qs --path .`
- verify no layout shift in the bar center at idle
- verify focus/workspace changes update the hint correctly while active

## Final Recommendation

Use the mixed model as the long-term architecture.

It keeps the system readable:

- `NiriService` answers: what does the compositor know?
- `WindowHintService` answers: what should the hint show?
- `WorkspaceWidget` answers: what should the bar always show?
- `SuperIsland` answers: how should the temporary hint appear and disappear?

This gives the feature a clean growth path without turning either `WorkspaceWidget` or `SuperIsland` into an oversized catch-all component.
