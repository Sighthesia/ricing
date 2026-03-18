# Media Control Widget Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a persistent bar media control widget with real cava background visualization, a SuperIsland-style interactive flash announcement band, and an expandable detail panel.

**Architecture:** Extend the current MPRIS path with a dedicated `CavaService` and a widget-facing `MediaControlService`. Render the stable playback surface inside the bar as a new widget, while mounting the expanded detail panel as a separate `AnimatedPanelBase` window declared in `shell.qml`. Keep announcement behavior local to the media widget so SuperIsland remains focused on center-slot events.


---

## Context for Implementer

- Bar widgets are registered in `modules/bar/BarContent.qml` and mirrored in `modules/bar/WidgetPickerWindow.qml`.
- Top-level windows are declared in `shell.qml` only.
- External process patterns already exist in `services/ClipboardService.qml`, `services/FontService.qml`, and `services/BarLayoutService.qml`.
- SuperIsland motion vocabulary lives in `modules/bar/widgets/SuperIslandWidget.qml` and should be borrowed, not duplicated blindly.
- New hardcoded dimensions or timings are not allowed; extend `Theme.barWidget.*` and settings defaults instead.

---

### Task 1: Extend MPRIS data to support real transport UI

**Files:**
- Modify: `services/MediaService.qml`


Assert that media state now exposes:

- track position
- track length
- helper actions for play/pause, previous, next

The test should fail because these properties/actions do not exist yet.



Expected: property/action lookup failure tied to the new API.

**Step 3: Implement the minimal MediaService extension**

Add only the data and actions needed by the new widget:

- `positionMs`
- `lengthMs`
- `canGoPrevious`
- `canTogglePlayback`
- `canGoNext`
- `playPause()`
- `previous()`
- `next()`




---

### Task 2: Add a dedicated cava ingestion service

**Files:**
- Create: `services/CavaService.qml`
- Modify: `config/settings-default.json`
- Modify: `services/SettingsService.qml` if adapter defaults need schema exposure


Create a harness that feeds representative raw ascii frames and expects:

- parsed numeric bars
- normalized values
- a degraded state when no data is available



Expected: import or property failures because `CavaService` does not exist.

**Step 3: Implement `CavaService.qml`**

Responsibilities:

- generate or reference a local cava config
- launch `cava` via `Process`
- parse raw ascii frames from stdout
- expose `bars`, `healthy`, and fallback state

Keep parsing isolated in this service; do not leak process concerns to widgets.

**Step 4: Add settings defaults for cava behavior**

Introduce only the settings that affect runtime behavior, such as:

- enabled flag
- bar count
- framerate or smoothing factor



Expected: parser and degraded-state checks pass.

---

### Task 3: Create the widget-facing media session aggregator

**Files:**
- Create: `services/MediaControlService.qml`
- Modify: `services/MediaService.qml`
- Modify: `services/CavaService.qml`


Assert that a single service snapshot exists for:

- display fields
- progress labels
- normalized progress
- announcement state
- panel open state
- transport action forwarding



Expected: missing singleton/service API failure.

**Step 3: Implement `MediaControlService.qml`**

Responsibilities:

- merge MPRIS + cava into one stable UI contract
- detect new-media announcements without retriggering on pause/resume
- manage `panelOpen`
- expose formatted position/duration labels



Expected: aggregated state and announcement lifecycle checks pass.

---

### Task 4: Add shared media widget building blocks

**Files:**
- Create: `modules/bar/media/MediaArtwork.qml`
- Create: `modules/bar/media/MediaVisualizerBackground.qml`
- Create: `modules/bar/media/MediaProgressStrip.qml`
- Create: `modules/bar/media/MediaFlashControls.qml`
- Modify: `config/Theme.qml`


Assert that the new parts can render with stub data and respect theme tokens.



Expected: missing component import failures.

**Step 3: Add the minimal shared components**

Each file should have one responsibility only:

- artwork crop / fallback icon
- cava background rendering
- bottom-edge progress strip
- flash control row

**Step 4: Add missing `Theme.barWidget.*` tokens**

Introduce structural tokens for:

- media compact width bounds
- flash row spacing
- panel artwork size
- progress strip thickness



Expected: shared components render and size correctly.

---

### Task 5: Implement the persistent bar widget with flash announcement

**Files:**
- Create: `modules/bar/widgets/MediaControlWidget.qml`
- Modify: `modules/bar/BarContent.qml`
- Modify: `modules/bar/WidgetPickerWindow.qml`
- Modify: `services/BarLayoutService.qml` only if a dedicated flash extension channel is required


Validate:

- stable compact layout renders with artwork/title/progress
- flash extension opens on announcement state
- flash controls are clickable
- widget does not lose stable content during announcement



Expected: missing widget registration or rendering failures.

**Step 3: Implement `MediaControlWidget.qml`**

Use `MediaControlService` only. Do not directly mix `MediaService` and
`CavaService` in the widget.

**Step 4: Register the widget in bar registry and picker UI**

Add:

- widget registry path in `BarContent.qml`
- display name in `BarContent.qml`
- mirrored registry/name entry in `WidgetPickerWindow.qml`



Expected: stable and announcement states both pass.

---

### Task 6: Implement the expandable detail panel

**Files:**
- Create: `modules/bar/media/MediaPanelContent.qml`
- Create: `modules/bar/MediaControlPanel.qml`
- Modify: `shell.qml`


Validate:

- blank-space click opens panel
- panel uses `AnimatedPanelBase`
- controls inside the panel still work
- close path returns to idle cleanly



Expected: missing panel component or shell mount failure.

**Step 3: Implement panel content and panel window**

Keep the heavy content in `MediaPanelContent.qml` and the window shell in
`MediaControlPanel.qml`.

**Step 4: Mount the panel in `shell.qml`**

Declare it alongside the other top-level windows.



Expected: panel open/close flow passes.

---

### Task 7: Add widget settings and sane runtime defaults

**Files:**
- Modify: `modules/bar/WidgetSettingsPanel.qml`
- Create: `modules/bar/widgetsettings/MediaControlSection.qml`
- Modify: `config/settings-default.json`
- Modify: `services/SettingsService.qml`


Assert that widget settings expose only the functional toggles needed for v1:

- show when idle
- announcement enabled
- cava enabled



Expected: settings section missing.

**Step 3: Implement the settings section and bind it to defaults**

Keep settings minimal. Do not add speculative options.



Expected: settings section renders and persists.

---

### Task 8: Run end-to-end verification

**Files:**
- Wire: relevant `tests/qml/*.qml` harnesses

**Step 1: Write the verification runner**


**Step 2: Run the full verification suite**


Expected:

- no unresolved import/property errors

**Step 3: Run workspace error scan**


Expected: no new QML errors tied to the media widget feature.

---

## Suggested Task Order

1. extend MPRIS data
2. add cava ingestion
3. aggregate into `MediaControlService`
4. build shared media parts
5. build the compact widget
6. build and mount the panel
7. expose minimal settings

This order keeps transport data and visualization stable before any UI is built.