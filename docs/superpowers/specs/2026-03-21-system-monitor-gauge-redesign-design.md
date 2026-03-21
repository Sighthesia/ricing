# System Monitor Gauge Redesign Design

**Date:** 2026-03-21  
**Status:** Proposed

## Goal

Refactor the bar system monitor into a compact gauge-driven widget that always shows `CPU`, `Memory`, and `CPU Temperature` as icon-centered three-quarter ring indicators, then expands on hover to reveal `Volume`, `Brightness`, and `Battery` using the shared `BarExpandTransition.qml` motion language.

The redesign removes the current text-heavy layout and replaces it with one standardized metric contract so display, severity, hover expansion, and scroll adjustment all flow through the same structure.

## Related Work

This design builds directly on `docs/superpowers/specs/2026-03-19-dynamic-bar-expansion-design.md`.

That spec established `modules/bar/BarExpandTransition.qml` as the shared motion contract for bar widgets. This redesign applies that contract to `SuperSystemMonitorWidget.qml` now that the product behavior is explicitly defined as a hover-expanding bar widget.

## Problem

The current `modules/bar/widgets/SuperSystemMonitorWidget.qml` has three product limitations:

1. it is text-first instead of glance-first, which makes the widget visually denser than the rest of the bar
2. optional metrics are controlled as separate text rows instead of a unified expand-on-hover model
3. the data layer only standardizes `cpu`, `memory`, and `temperature`, so adding `battery` or reusable interactive gauges would keep pushing logic into the UI

The product direction is now clearer:

- default state must always show `CPU`, `Memory`, and `CPU Temperature`
- normal state must show icon plus enclosing three-quarter ring only
- hover must expand the same widget instead of swapping widgets or opening a panel
- expanded state must reveal non-persistent metrics on the right side
- `Volume` and `Brightness` must support wheel adjustment while hovered
- `Battery` must be added as a first-class metric source

## Decision

Rebuild the system monitor as one expandable pill with two fixed metric groups:

- persistent group: `cpu`, `memory`, `temperature`
- expanded group: `volume`, `brightness`, `battery`

The widget still respects `systemMonitor.enabled` and `systemMonitor.hoverReveal` from settings:

- `enabled: false` hides the widget completely, matching the current product contract
- `hoverReveal: false` disables hover expansion and keeps the widget permanently collapsed to the persistent trio

Introduce a reusable single-metric gauge component under the bar widget scope and upgrade `SystemMonitorService.qml` into the only view-model layer that emits standardized entries for both groups.

Add a new `BatteryService.qml` so the widget consumes battery state through the same service pattern already used for audio, brightness, and core system metrics.

## Architecture

### 1. Widget shell

`modules/bar/widgets/SuperSystemMonitorWidget.qml` becomes a geometry-owning pill that:

- keeps one horizontal row in all states
- uses `BarExpandTransition.qml` for width expansion and collapse
- treats hover as the only expansion trigger
- keeps the default three gauges mounted at all times
- appends the expanded-only gauges on the right when hovered
- keeps the hover hit area stable across both collapsed and expanded widths

The widget does not fetch raw system values and does not compute metric severity locally. It only renders standardized entries and delegates interaction back to services through `SystemMonitorService.qml`.

### 2. Gauge component

Add a focused child component, suggested path:

- `modules/bar/widgets/systemmonitor/SystemMonitorGauge.qml`

Responsibility:

- render one icon-centered three-quarter ring
- map severity and availability into semantic colors
- optionally expose wheel interaction when `interactive` is true
- optionally expose hover state back to the owner for targeted scroll handling

The gauge is intentionally narrow in scope. It is a metric surface, not a layout coordinator and not a data source.

Suggested required input shape:

```qml
Item {
    required property var metric
    property bool interactive: false
    signal stepRequested(int direction)
}
```

Expected metric fields:

- `key`
- `title`
- `icon`
- `value`
- `normalizedProgress`
- `displayText`
- `severity`
- `available`
- `persistent`
- `interactive`

### 3. Standardized monitor view model

`services/SystemMonitorService.qml` becomes the single adapter from low-level services into widget-facing gauge entries.

It should expose at least:

- `persistentMetrics`
- `expandedMetrics`
- `allMetrics`
- `highestSeverity`
- wheel-adjust helper methods for `volume` and `brightness`

Suggested public shape:

```qml
readonly property var persistentMetrics
readonly property var expandedMetrics
readonly property var allMetrics
readonly property string highestSeverity

function adjustVolumeByStep(direction) {}
function adjustBrightnessByStep(direction) {}
```

Rules:

- `persistentMetrics` always resolves to `cpu`, `memory`, `temperature`
- `expandedMetrics` resolves to `volume`, `brightness`, `battery`
- `persistentMetrics` and `expandedMetrics` both keep that fixed order
- `allMetrics` is the stable concatenation of `persistentMetrics` followed by `expandedMetrics`
- `battery` remains present in the data contract even when unavailable, but the widget suppresses its visual slot so no empty width is reserved
- only `persistentMetrics` participate in widget-level alert severity, and `highestSeverity` must be derived exclusively from that group

That last rule avoids false product signaling such as a low volume level making the entire monitor appear unhealthy.

### 4. Battery service

Add a new singleton:

- `services/BatteryService.qml`

Responsibility:

- detect whether a battery exists on the current machine
- read charge percentage, charging/discharging state, and availability
- normalize output into one stable snapshot shape
- provide a smoke-safe override path similar to the existing device services

Expected snapshot fields:

- `available`
- `level`
- `percentLabel`
- `charging`
- `status`

Expected service affordances:

- `readonly property var batterySnapshot`
- `function refresh()`
- `function _setStateOverride(state)` for smoke-safe and harness-oriented overrides

Override lifecycle rules:

- passing `null` or `undefined` to `_setStateOverride(state)` clears the override and restores live state
- while an override is active, `refresh()` may continue updating internal real-device cache, but it must not replace the exposed override state until the override is cleared
- when `available` is false, `batterySnapshot.level` resolves to `0`

Data-source direction:

- first preference: read from `/sys/class/power_supply/*` battery entries
- if no battery device exists, surface `available: false`
- do not make battery support depend on extra desktop-specific packages if the kernel power-supply interface is enough

This follows the repository's existing service style: keep OS probing inside the service, and keep the widget insulated from command and file-system details.

## Visual Contract

### 1. Gauge shape

Each metric uses the same compact visual language:

- center icon
- one surrounding three-quarter ring
- open gap kept on the lower arc so the gauge reads as a directional instrument instead of a full progress donut
- no text shown in the regular resting state

This is the visual equivalent of a car dashboard cluster: the icon identifies the subsystem and the ring communicates magnitude in peripheral vision.

### 2. Color rules

Color should remain semantic and token-driven:

- `normal` => standard foreground or muted-accent ring
- `warning` => `Colors.highlight`
- `critical` => `Colors.destructive`
- `unavailable` => muted ring and muted icon

Do not introduce metric-specific hardcoded colors. The gauge family should stay visually coherent with the shell theme.

### 3. Text policy

Resting state:

- no inline numbers
- no text tags such as `VOL` or `BRIGHT`

Expanded state:

- still keep the default presentation icon-first and ring-first
- optional tooltip-style or accessibility text may be added later, but it is not part of this redesign

The product requirement here is consistency, not mixed visual modes.

## Interaction Model

### 1. Hover expansion

Hovering anywhere on the widget expands the pill using `BarExpandTransition.qml`.

Behavior rules:

- collapsed width fits exactly the persistent three gauges plus internal spacing
- expanded width fits persistent plus expanded gauges plus one group gap
- leaving hover collapses back to the persistent width
- moving the cursor from the persistent group into the revealed group must not collapse the widget
- when `systemMonitor.hoverReveal` is false, the widget never enters the expanded state from hover

This should feel like one instrument cluster unfolding sideways, not like separate blocks blinking in and out.

### 2. Wheel adjustment

Only `volume` and `brightness` are interactive.

Rules:

- wheel input is accepted only while the cursor is over the corresponding gauge
- up increases, down decreases
- each step is `5%`
- values are clamped to `0..1`
- the service remains the source of truth after each command

Suggested product-level methods:

- `adjustVolumeByStep(direction)` where `direction` is `1` or `-1`
- `adjustBrightnessByStep(direction)` where `direction` is `1` or `-1`

This behaves more like turning a knob than scrolling a list, which matches the bar's compact control surface.

### 3. Battery visibility

Battery is part of the expanded group by default, but it should collapse out cleanly when no battery exists.

Rules:

- if `BatteryService.available` is false, hide the battery gauge in the expanded row
- do not reserve empty width for a nonexistent battery
- keep `battery` in the service contract even when unavailable so the UI logic stays data-driven

## Metric Semantics

### 1. Persistent metrics

Persistent metrics keep their current data sources:

- `cpu` from `SystemMetricsService.cpuUsage`
- `memory` from `SystemMetricsService.memoryUsage`
- `temperature` from `SystemMetricsService.temperatureC`

Severity rules remain mostly unchanged:

- `cpu` compares against `warningCpuPercent`
- `memory` compares against `warningMemoryPercent`
- `temperature` compares against `warningTempC` and `criticalTempC`

### 2. Expanded metrics

Expanded metrics use these sources:

- `volume` from `AudioDeviceService.volumeLevel` and `volumeMuted`
- `brightness` from `BrightnessService.level`
- `battery` from `BatteryService.level`, `charging`, and `available`

Default severity rules:

- `volume` => always `normal`
- `brightness` => always `normal`
- `battery` => `normal` in v1 unless a later product pass adds explicit low-battery signaling

This keeps the first redesign focused on layout and interaction instead of inventing new alert behavior.

### 3. Progress normalization

Every metric must publish a `normalizedProgress` in the `0..1` range.

Mapping rules:

- ratio-based metrics (`cpu`, `memory`, `volume`, `brightness`, `battery`) map directly
- temperature maps through a bounded temperature range suitable for visual progress, independent of severity thresholds
- unavailable metrics publish `0` progress and rely on muted styling instead of fake values

The widget should never need to know how raw values become ring progress.

## Settings Impact

The old `systemMonitor` settings currently expose `pinnedMetrics`, `showVolume`, `showBrightness`, and `showMicrophone`.

This redesign changes the product model:

- `pinnedMetrics` is no longer a user-facing permutation in v1 of this redesign; the persistent trio is fixed by product decision
- `showVolume` and `showBrightness` become obsolete because those metrics always belong to the expanded group
- `showMicrophone` is out of scope for this redesign and does not participate in the new gauge contract or widget UI

Recommended direction:

- keep backward compatibility in settings loading and persistence for one migration wave
- stop using obsolete toggles in the widget implementation immediately
- defer physical removal of obsolete persisted fields to a separate cleanup pass after the redesigned widget ships

Compatibility rule:

- `systemMonitor.enabled` remains authoritative for whether the widget is mounted
- `systemMonitor.hoverReveal` remains authoritative for whether hover may open the expanded group
- `pinnedMetrics`, `showVolume`, `showBrightness`, and `showMicrophone` continue to deserialize and persist for config compatibility during this redesign wave, but they no longer affect rendering in the redesigned widget

This protects hot reload and user config migration while still moving the widget to the new contract.

## File Impact

### New files

- `services/BatteryService.qml`
  - battery availability and charge snapshot service
- `modules/bar/widgets/systemmonitor/SystemMonitorGauge.qml`
  - reusable single-metric ring gauge

### Modified files

- `modules/bar/widgets/SuperSystemMonitorWidget.qml`
  - replace text rows with expandable gauge layout and hover interaction
- `services/SystemMonitorService.qml`
  - standardize all six metrics and expose step-adjust helpers
- `services/SettingsService.qml`
  - keep schema stable while deciding which legacy fields remain persisted
- `config/settings-default.json`
  - align defaults with the fixed persistent/expanded model if obsolete fields are removed
- `modules/bar/BarContent.qml`
  - verify no API changes are needed beyond the existing widget mount

## Risks And Controls

### Risk: the widget becomes visually noisy when all six gauges are shown

Control:

- keep gauge geometry small and consistent
- animate only the container size and content reveal opacity
- do not add numbers or extra labels in v1

### Risk: scroll adjustment causes accidental changes during casual hover

Control:

- accept wheel only on the hovered interactive gauge
- do not accept wheel on the whole widget surface
- clamp all writes and let services refresh the true device state immediately after commands

### Risk: battery detection varies across desktops and hardware

Control:

- prefer kernel power-supply paths instead of desktop-environment-specific tooling
- treat battery presence as optional, not exceptional
- keep `available: false` as the normal no-battery state

### Risk: stale settings fields create confusing product behavior

Control:

- migrate rendering logic fully away from `pinnedMetrics`, `showVolume`, `showBrightness`, and `showMicrophone`
- decide cleanup sequencing explicitly in the implementation plan instead of leaving it implicit

## Testing Strategy

The implementation should emphasize service-level behavior and shell-load safety.

Required verification targets:

- `services/SystemMonitorService.qml`
- `services/BatteryService.qml`
- `modules/bar/widgets/SuperSystemMonitorWidget.qml`
- `modules/bar/widgets/systemmonitor/SystemMonitorGauge.qml`

Required verification directions:

- validate battery-present and battery-absent snapshots
- validate volume and brightness step helpers clamp correctly at `0%` and `100%`
- validate expanded metrics do not affect `highestSeverity`
- validate hover expansion and collapse load cleanly in the shell

Repo-level validation commands:

```bash
timeout 5 qs --path .
timeout 5 qs -p .
```

If a targeted harness is introduced during implementation, keep it under `tests/` and make it prove behavior rather than visual guesswork.

## Recommended Implementation Direction

Implement the redesign as one expandable bar widget backed by one standardized metric service contract and one new battery service.

This keeps the product behavior simple for users, keeps geometry ownership aligned with the existing bar motion system, and gives the codebase a reusable gauge primitive instead of another one-off monitor layout.
