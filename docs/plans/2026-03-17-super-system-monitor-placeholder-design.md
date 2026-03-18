# Super System Monitor Placeholder Design

## Overview

This design makes `Super System Monitor` appear in the widget library and become
insertable into the bar as a minimal placeholder widget.

The goal of this iteration is not to build a full monitoring subsystem. The goal
is to eliminate the current product gap where the widget does not exist in the
library at all, so nobody can validate its shell integration.

## Problem

The current widget library is driven by two hardcoded registries:

- `modules/bar/BarContent.qml`
- `modules/bar/WidgetPickerWindow.qml`

Those registries currently expose only:

- `superIsland`
- `mediaControl`
- `clock`
- `workspaceWidget`
- `notificationBell`

There is no `superSystemMonitor` entry, and there is no corresponding widget
component file under `modules/bar/widgets/`.

That means the current failure is not a rendering regression. It is a missing
product artifact: the widget cannot appear in the library because the shell has
nothing to load.

## Chosen Approach

Add a minimal placeholder widget and wire it into the existing registry pattern.

### Placeholder Widget

Create `modules/bar/widgets/SuperSystemMonitorWidget.qml` as a compact bar pill
that follows the same structural contract as the existing widgets:

- stable `implicitHeight`
- content-driven `implicitWidth`
- token-backed colors and spacing
- no service dependencies yet

The visual content should be intentionally simple:

- small monitor/metrics glyph
- `CPU` label with placeholder percentage
- `MEM` label with placeholder percentage

This is enough to prove the widget can render inside the bar and in the picker
preview.

### Registry Wiring

Add the same `superSystemMonitor` entry to both registry maps:

- `BarContent.qml` for runtime widget resolution
- `WidgetPickerWindow.qml` for library listing and preview loading

This keeps the current architecture intact instead of introducing a new registry
abstraction during a debug-driven stopgap iteration.

### Validation Strategy

Add a narrow smoke harness that proves three things:

1. `BarContent.qml` exposes the runtime registry entry
2. `WidgetPickerWindow.qml` exposes the mirrored picker entry
3. `BarLayoutService.addWidget("superSystemMonitor", section)` successfully adds
   the widget type to the live layout model

This is the smallest automated proof that turns “not in the library” into
“available and insertable”.

## Why This Approach

- solves the immediate usability gap with the smallest surface area
- avoids inventing a monitoring service before the widget contract is proven
- preserves the existing duplicated-registry architecture used by current widgets
- creates a stable checkpoint before a later real-data implementation

## Scope

### In Scope

- create `modules/bar/widgets/SuperSystemMonitorWidget.qml`
- register `superSystemMonitor` in `BarContent.qml`
- register `superSystemMonitor` in `WidgetPickerWindow.qml`
- add a smoke harness for placeholder availability and insertion
- run the nearest widget/picker/settings smoke coverage needed to verify the change

### Out of Scope

- CPU, memory, disk, network, or sensor data collection
- new `SystemMonitorService.qml`
- widget settings UI for this widget
- redesigning the widget registry architecture

## Error Handling

Because the placeholder widget has no external process or service dependency,
the main failure modes are structural:

- mismatched registry keys between runtime and picker
- bad QML source path
- widget loads in one place but not the other

The smoke test should catch these by asserting both registries and the runtime
layout insertion path.

## Verification Strategy

The narrow proof should include:

```bash
bash tests/run-qml-harness.sh SuperSystemMonitorAvailabilitySmoke
bash tests/run-settings-smoke.sh
timeout 10 qs --path .
```

If the new harness is folded into an existing grouped suite instead, the suite
must still directly prove picker/runtime registration for `superSystemMonitor`.

## Expected Outcome

After this change:

- `Super System Monitor` appears in the widget library
- the widget can be inserted into the layout model
- the placeholder renders without introducing service dependencies
- the repository has a safe base for a later real monitoring implementation
