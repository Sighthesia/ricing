# Media Control Widget — Design

## Overview

Add a dedicated bar media control widget that stays visible during normal use,
borrows SuperIsland's transient visual language for new-media announcements,
and opens a compact detail panel when the user clicks the non-control area.

The widget has four simultaneous responsibilities:

- present stable playback state in the bar
- provide direct transport controls without opening another surface
- briefly amplify new-media events with a downward flash extension
- expose a richer panel with large artwork and denser controls on demand

Real cava data is required for the background visualization.

---

## Goals

- Keep a stable, always-available media entry point in the bar.
- Reuse SuperIsland motion language without merging the feature into
  SuperIsland's event queue.
- Make new-media events feel special without hijacking the center slot.
- Preserve the existing three-layer architecture:
  `services/` -> `config/` -> `modules/`.

---

## Current Constraints

### Existing Media State

`services/MediaService.qml` already exposes:

- active player presence
- title / artist / artwork
- playback state
- a `mediaChanged()` signal

It does not currently expose track position, track length, or transport helper
methods.

### Existing Motion Language

`modules/bar/widgets/SuperIslandWidget.qml` already defines the desired motion
grammar for event emphasis:

- stable primary surface
- downward flash extension
- pulse highlight on new content
- spring-based geometry transitions

The new media widget should reuse that language, but not reuse the SuperIsland
service queue directly.

### Existing Panel Pattern

`modules/bar/AnimatedPanelBase.qml` already provides the right open/close model
for the expanded media detail panel:

- top-edge anchored downward growth
- non-destructive open/close state machine
- child content isolated from transform side effects

---

## Architecture Overview

### Service Layer

Introduce two focused services and keep MPRIS responsibilities explicit.

1. `services/CavaService.qml`
   - owns the external `cava` process
   - manages config generation and process lifecycle
   - parses raw ascii bar frames into a normalized numeric array
   - exposes health state and fallback state when cava is unavailable

2. `services/MediaControlService.qml`
   - aggregates `MediaService` and `CavaService`
   - exposes the widget-facing session model
   - owns announcement lifecycle and detail-panel open state
   - keeps UI code free from multi-source synchronization logic

`MediaService.qml` remains the MPRIS gateway. It may be extended with position,
length, and transport helpers, but it should not absorb cava concerns.

### Module Layer

Use one stable widget plus one dedicated panel.

1. `modules/bar/widgets/MediaControlWidget.qml`
   - always-visible bar widget
   - left circular artwork, right title block, bottom progress line
   - background cava visualization clipped to the widget shape
   - transient flash extension rendered below the stable surface

2. `modules/bar/MediaControlPanel.qml`
   - `AnimatedPanelBase` window declared in `shell.qml`
   - opens when the widget's blank area is clicked
   - shows larger artwork and denser playback metadata/controls

3. `modules/bar/media/*`
   - focused subcomponents for artwork, cava background, progress strip,
     flash controls, and expanded panel body

### Config Layer

Extend `Theme.barWidget.*` and settings defaults rather than introducing local
magic numbers.

Needed tokens/settings:

- media widget compact width bounds
- flash extension height / control spacing
- expanded panel artwork size
- cava bar count and smoothing defaults
- media announcement duration

---

## Component Hierarchy

```text
shell.qml
├── BarWindow
│   └── BarContent
│       └── MediaControlWidget
└── MediaControlPanel

services/
├── MediaService.qml
├── CavaService.qml
└── MediaControlService.qml

modules/bar/media/
├── MediaArtwork.qml
├── MediaVisualizerBackground.qml
├── MediaProgressStrip.qml
├── MediaFlashControls.qml
└── MediaPanelContent.qml
```

This keeps the stable control surface inside the bar and the heavier detail
surface in a window that matches the shell's existing panel architecture.

---

## Session Model

`MediaControlService` should expose a single widget-oriented snapshot.

### Public State

- `hasMedia: bool`
- `title: string`
- `artist: string`
- `artUrl: string`
- `playerName: string`
- `playbackState: string`
- `positionMs: int`
- `lengthMs: int`
- `progress: real` in `[0, 1]`
- `durationLabel: string`
- `positionLabel: string`
- `visualizerBars: var`
- `visualizerHealthy: bool`
- `announcementState: string` -> `idle | announce | hold | dismiss`
- `panelOpen: bool`
- `canGoPrevious: bool`
- `canTogglePlayback: bool`
- `canGoNext: bool`

### Public Actions

- `togglePanel()`
- `openPanel()`
- `closePanel()`
- `playPause()`
- `previous()`
- `next()`
- `acknowledgeAnnouncement()`

The module layer should consume only this service snapshot and these actions.

---

## Interaction Model

### Stable Widget

Default bar layout:

- left: circular artwork
- right: track title, optional artist subtitle
- bottom edge: thin progress line close to the widget boundary
- full background: cava visualization under a tinted mask

The stable widget remains visible throughout announcement playback.

### New-Media Announcement

When title, artwork, or active player changes in a way that constitutes a new
media session:

1. pulse the stable widget background
2. extend a flash band downward below the widget
3. render flash content from left to right:
   - progress preview
   - previous button
   - play/pause button
   - next button
   - total duration
4. hold briefly
5. retract back to the compact stable widget

The flash band is interactive during the hold window.

### Expand Detail Panel

Click behavior is split deliberately:

- clicking transport controls triggers transport only
- clicking blank space toggles the panel

The expanded panel displays:

- large artwork
- title and artist
- large progress bar with elapsed and total time
- duplicated transport controls
- optional player/app identity line

This mirrors the shell's existing panel behavior and avoids accidental panel
open events when the user intends to control playback.

---

## Animation Rules

All durations and easings must come from `Theme.anim.*`.

### Stable Surface

- width and content layout transitions use `Theme.anim.move*`
- subtle settle after content swaps uses `Theme.anim.spring*`

### Announcement Layer

- background pulse uses the same visual intent as SuperIsland highlight pulses
- flash extension grows downward rather than replacing the stable widget
- flash controls fade and settle using the same spring vocabulary as the shell's
  expressive resizing behavior

### Panel

- reuse `AnimatedPanelBase` open/close mechanics
- panel content may stagger internal children, but should not invent unrelated
  motion timing

---

## Cava Integration

Use `cava` raw ascii output mode via a managed `Process`.

### Data Path

1. generate a local cava config in shell state/cache
2. run `cava` with raw ascii output to stdout
3. parse each frame into a JS array of bar heights
4. normalize values once in `CavaService`
5. expose normalized bars to the widget and panel

### Why Raw ASCII

- easy to parse with existing `SplitParser`-style service patterns
- no binary decoding path needed in QML
- predictable failure mode when `cava` is missing or stops producing output

### Failure Handling

If cava is missing, crashes, or produces no frames:

- keep the widget usable
- replace the live background with a subtle animated fallback texture
- do not block transport controls or panel behavior

---

## Event Detection Rules

An announcement should trigger when one of these changes indicates a new media
session rather than a minor state flip:

- active player identity changes
- track title changes
- artwork URL changes significantly

Pause/resume alone should not retrigger the full announcement sequence.
Instead, it should update stable controls and optionally apply a much lighter
micro-pulse.

---

## Degraded States

### No Artwork

- keep the circular slot
- fall back to a resolved application/media icon

### No Duration / Position

- hide exact time labels
- preserve layout with title and controls only

### No Cava

- show non-reactive ambient background
- keep the same component geometry so the UI does not collapse

### No Active Player

- show an idle placeholder state or allow the widget to collapse based on the
  chosen settings default

---

## Testing Strategy

### Service-Level

- verify cava frame parsing
- verify progress normalization from raw MPRIS values
- verify announcement detection does not retrigger on pause/resume

### Widget-Level

- verify stable widget size remains bounded across title lengths
- verify flash extension opens and retracts without leaving stale height in the
  bar layout extension
- verify control hit areas do not open the panel

### Panel-Level

- verify blank-space click opens panel
- verify panel closes cleanly and preserves playback controls



- stable media render
- new-media announcement lifecycle
- interactive flash control availability
- panel open/close state

---

## Out of Scope

- lyrics view
- device switching
- queue browsing
- album-color theming beyond existing color tokens
- waveform scrubbing

Those can be added later through the expanded panel without changing the compact
widget contract.