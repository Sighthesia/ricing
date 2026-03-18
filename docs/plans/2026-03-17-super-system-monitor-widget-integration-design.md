# Super System Monitor Widget Integration Design

## Overview

This design connects the service-heavy work from `feature/super-system-monitor`
to the current main workspace's placeholder bar widget entrypoint.

The goal is to complete the missing middle layer: keep system-monitor logic in
services, keep registry wiring in bar modules, and make the visible bar widget
render real data from `SystemMonitorService`.

## Current State

There are currently two partial implementations living in different places.

### Service Layer Work in `feature/super-system-monitor`

The dedicated branch/worktree already contains backend-oriented pieces:

- `services/SystemMetricsService.qml`
- `services/AudioDeviceService.qml`
- `services/BrightnessService.qml`
- `services/SystemMonitorService.qml`
- `services/SettingsService.qml` schema additions
- `config/settings-default.json` additions

This side already models the monitoring domain:

- metric sampling
- audio and brightness state
- pinned-metric ordering
- alert severity derivation
- flash state
- Super Island escalation

### Placeholder UI in the Current Workspace

The current workspace already contains the missing product entrypoints:

- `modules/bar/widgets/SuperSystemMonitorWidget.qml`
- registry wiring in `modules/bar/BarContent.qml`
- picker wiring in `modules/bar/WidgetPickerWindow.qml`

This side solves discoverability and insertion, but not real rendering.

## Problem

The two halves do not meet.

- The branch implements service contracts without a widget consuming them.
- The current workspace exposes a widget slot without any real monitor data.

So the feature is not actually complete. It is split into:

- backend readiness
- frontend placeholder wiring

The missing piece is a real bar widget that consumes `SystemMonitorService`
instead of hardcoded placeholder values.

## Chosen Approach

Integrate the branch service layer into the current workspace, then upgrade the
existing placeholder widget to read only from `SystemMonitorService`.

### Why `SystemMonitorService` Is the Integration Boundary

`SystemMonitorService` already acts as the orchestration layer:

- combines raw system metrics with audio and brightness state
- orders widget-facing metrics
- computes severities and top alerts
- exposes widget-safe fields

That makes it the right boundary between service logic and UI.

The widget should not pull from `SystemMetricsService`, `AudioDeviceService`, and
`BrightnessService` directly, because doing so would duplicate aggregation logic
in the UI and make future panel work harder to share.

## Widget Scope for Phase 1

This phase upgrades only the compact bar widget. It does not add a system monitor
panel yet.

### Widget Responsibilities

`modules/bar/widgets/SuperSystemMonitorWidget.qml` should:

- render the first three `SystemMonitorService.metrics`
- reflect `SystemMonitorService.highestSeverity` visually
- optionally surface concise audio/brightness status when enabled by settings
- remain compact and stable for bar layout
- avoid owning any sampling, threshold, or escalation logic

### Widget Content

The first real widget should stay intentionally small:

1. **Leading status cue**
   - an icon or severity chip reflecting `highestSeverity`
2. **Primary metrics band**
   - three short metric pills or labels from `metrics`
   - examples: `CPU 42%`, `MEM 73%`, `TEMP 61C`
3. **Optional compact tail indicators**
   - volume and brightness only if the corresponding system-monitor settings say
     they should be shown

This creates a clear first usable version without dragging panel design into the
same iteration.

## Data Flow

The data flow should be:

```text
SystemMetricsService ─┐
AudioDeviceService   ├─> SystemMonitorService ─> SuperSystemMonitorWidget
BrightnessService    ┘
```

### Responsibilities by Layer

- `SystemMetricsService`
  - sample `/proc` and temperature data
- `AudioDeviceService`
  - expose volume/mic state and write commands
- `BrightnessService`
  - expose brightness state and write commands
- `SystemMonitorService`
  - build widget-facing metrics
  - compute severities
  - manage flash event state
  - coordinate Super Island escalation
- `SuperSystemMonitorWidget.qml`
  - render already-computed state

## Files to Integrate

### Import from `feature/super-system-monitor`

- `services/SystemMetricsService.qml`
- `services/AudioDeviceService.qml`
- `services/BrightnessService.qml`
- `services/SystemMonitorService.qml`
- `services/SettingsService.qml`
- `config/settings-default.json`
- `null/dymicshell/settings.json`

### Upgrade in Current Workspace

- `modules/bar/widgets/SuperSystemMonitorWidget.qml`
  registry-first assertions
  enough to prove real service consumption

## Verification Strategy

Verification should build from service contract to widget integration.

### Service-Level Proof


These prove the backend contract before the widget tries to consume it.

### Widget-Level Proof

Add or extend a narrow harness that proves:

- the widget loads successfully through the real registry path
- the widget reads real `SystemMonitorService` state
- severity and metric labels render in a stable form

### Final Validation

The full proof set should include:

```bash
timeout 10 qs --path .
```

explicitly before making completion claims.

## Expected Outcome

After this integration:

- the current widget library entry stays intact
- the bar widget renders real monitor data instead of placeholder numbers
- monitoring logic remains centralized in `SystemMonitorService`
- the branch and current workspace stop being two disconnected halves
- the project reaches a true minimum end-to-end system monitor milestone
