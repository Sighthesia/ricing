# Animated Panel Exclusion Design

**Date:** 2026-03-14
**Status:** Approved

## Overview

Several drop-down panels are implemented with `AnimatedPanelBase`, which inherits `PanelWindow`.
Unlike the main bar, these panels are overlays and should not reserve layout space from the compositor.
When `SettingsPanelWindow` opened without an explicit exclusion policy, the compositor treated it like a space-reserving layer surface and pushed normal windows downward.

## Root Cause

- `modules/bar/BarWindow.qml` intentionally reserves space with `exclusiveZone: Theme.barHeight`.
- `modules/bar/AnimatedPanelBase.qml` did not declare a non-reserving exclusion policy.
- Some `AnimatedPanelBase` users already worked around this individually:
  - `modules/launcher/LauncherPanel.qml`
  - `modules/bar/MediaControlPanel.qml`
- Other `AnimatedPanelBase` users inherited the default compositor behavior and could reserve space unexpectedly:
  - `modules/bar/SettingsPanelWindow.qml`
  - `modules/bar/WidgetPickerWindow.qml`
  - `modules/bar/NotificationHistoryPanel.qml`
  - `modules/background/WallpaperPickerWindow.qml`

## Decision

Set `AnimatedPanelBase` to ignore compositor exclusion by default.

```qml
WlrLayershell.exclusionMode: ExclusionMode.Ignore
```

This makes every animated drop-down panel behave like an overlay unless a future subtype explicitly opts into a different policy.

## Why This Approach

### Recommended: Default ignore on `AnimatedPanelBase`

Pros:
- Fixes the current settings-panel bug at the architectural root.
- Makes all animated drop-down panels consistent.
- Prevents future regressions when new `AnimatedPanelBase` panels are added.
- Matches existing overlay behavior already chosen for launcher and media panel.

Cons:
- A future subtype that truly needs reserved space must override the default explicitly.

### Rejected: Patch each panel individually

Pros:
- Small, local diffs.

Cons:
- Easy to forget on future panels.
- Repeats policy in multiple files.
- Leaves the base abstraction semantically incomplete.

### Rejected: Add a new opt-in property now

Pros:
- Maximum explicitness.

Cons:
- More API surface than needed for the current bug.
- Solves a future flexibility problem that does not exist today.

## Affected Components

- `modules/bar/AnimatedPanelBase.qml`
- `modules/bar/SettingsPanelWindow.qml`
- `modules/bar/WidgetPickerWindow.qml`
- `modules/bar/NotificationHistoryPanel.qml`
- `modules/background/WallpaperPickerWindow.qml`
- `modules/launcher/LauncherPanel.qml`
- `modules/bar/MediaControlPanel.qml`

## Testing Strategy


Then verify:
- settings panel opens without pushing tiled windows down
- widget picker opens without reserving screen space
- notification history and wallpaper picker follow the same overlay rule
- launcher and media panel behavior remain unchanged
- `timeout 10 qs --path .` still loads cleanly

## Non-Goals

- Changing the main bar exclusion policy
- Reworking panel anchoring or animation timing
- Introducing a generalized panel policy API unless a real need appears later
