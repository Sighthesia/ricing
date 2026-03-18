# Super System Monitor Implementation Status

## Summary

The Super System Monitor feature has been partially integrated into the main workspace. The service layer is complete and committed, but the widget layer remains a placeholder pending completion. A separate teardown crash investigation was conducted in parallel, revealing issues in `AnimatedPanelBase` and `SettingsService` lifecycle management.

## Completed Work

### Service Layer (Committed: af70eed)

Four singleton services provide the monitoring backend:

| Service | Responsibility |
|---------|----------------|
| `SystemMetricsService` | CPU/memory/temperature sampling from `/proc` |
| `AudioDeviceService` | Volume and microphone state/control |
| `BrightnessService` | Display brightness state/control |
| `SystemMonitorService` | Aggregation layer, severity computation, flash state |

Settings schema added:
- `systemMonitor.enabled`
- `systemMonitor.panelEnabled`
- `systemMonitor.pinnedMetrics` (array)
- `systemMonitor.warningCpuPercent`, `warningMemoryPercent`, `warningTempC`
- `systemMonitor.criticalTempC`
- `systemMonitor.superIslandEscalation`

### Test Infrastructure (Committed: 4fd9691, 14ac83e)

- `TestHarnessRunner.qml` - repository-root harness loader
- `TestHarnessRunnerMinimal.qml` - isolated debugging runner
- `tests/run-qml-harness.sh` - wrapper script
- Service smoke tests for all four services
- `SystemMonitorSettingsSmoke.qml` for schema validation
- `SuperSystemMonitorAvailabilitySmoke.qml` for widget registration
- Debug harnesses for teardown crash isolation

### Widget Placeholder (Committed: 3addced)

- `modules/bar/widgets/SuperSystemMonitorWidget.qml` - placeholder with hardcoded values
- Registry wiring in `BarContent.qml` and `WidgetPickerWindow.qml`
- Widget appears in library and is insertable

### Documentation (Committed: 69c77d6)

- `2026-03-17-super-system-monitor-placeholder-design.md`
- `2026-03-17-super-system-monitor-widget-integration-design.md`
- Implementation plans for both phases

## Remaining Work

### Widget Integration (Phase 1)

The placeholder widget needs to be upgraded to consume real `SystemMonitorService` data:

1. Replace hardcoded CPU/MEM labels with bindings to `SystemMonitorService.metrics`
2. Add severity visual indicator based on `SystemMonitorService.highestSeverity`
3. Optionally show volume/brightness when enabled in settings
4. Create/extend `SuperSystemMonitorWidgetSmoke.qml` to verify real data consumption

### Panel Integration (Phase 2 - Future)

A system monitor panel would extend the feature with:
- Detailed metric graphs
- Historical data
- Interactive threshold configuration
- Per-metric enable/disable

This is intentionally deferred to keep Phase 1 focused.

## Teardown Crash Investigation

During smoke test development, teardown segfaults were observed. Root cause analysis:

### Confirmed Issues

1. **SettingsService FileView/watchChanges**
   - Harness mode fix applied: `watchChanges: !root._isHarnessRun`
   - Reduces crash frequency but does not eliminate it
   - Location: `services/SettingsService.qml:33`

2. **AnimatedPanelBase/PanelWindow teardown**
   - `PanelWindow` destruction during close animation can segfault
   - Affects: `SettingsPanelWindow`, `WidgetPickerWindow`, `MediaControlPanel`, `NotificationHistoryPanel`
   - Does NOT affect: `BarContextMenu` (uses `PopupWindow`)
   - Likely a Quickshell/Wayland layer-shell lifecycle issue
   - Location: `modules/bar/AnimatedPanelBase.qml`

### Evidence

- `AnimatedPanelBaseBareSmoke`: crashes on teardown
- `BarContextMenuBareSmoke`: passes (uses `PopupWindow`)
- `SettingsPanelWindowBareSmoke`: crashes even with stubbed content
- `WidgetPickerWindowBareSmoke`: crashes regardless of preview content
- `MediaControlPanelSmoke`: crashes on teardown

### Recommended Fix Direction

The `AnimatedPanelBase` teardown issue likely requires one of:
1. Delaying `PanelWindow` visibility change until after close animations complete
2. Explicitly destroying child items before the Wayland surface is destroyed
3. Reporting upstream to Quickshell if it's a Qt/Wayland regression

### Debug Artifacts Retained

The minimal debug harnesses are kept for future investigation:
- `tests/qml/AnimatedPanelBaseBareSmoke.qml`
- `tests/qml/SettingsPanelWindowBareSmoke.qml`
- `tests/qml/WidgetPickerWindowBareSmoke.qml`
- `tests/qml/BarContextMenuBareSmoke.qml`
- `tests/qml/SettingsServiceBareSmoke.qml`

## Architecture

```
services/
  SystemMetricsService.qml  ─┐
  AudioDeviceService.qml     ├─> SystemMonitorService.qml
  BrightnessService.qml      ┘          │
                                          ▼
modules/bar/widgets/          SuperSystemMonitorWidget.qml
  SuperSystemMonitorWidget.qml     (placeholder → real data)
```

Data flow:
1. `SystemMetricsService` samples system metrics on interval
2. `AudioDeviceService` and `BrightnessService` expose hardware controls
3. `SystemMonitorService` aggregates, orders, and derives severity
4. `SuperSystemMonitorWidget` renders the computed state

## Verification Commands

```bash
# Service layer
bash tests/run-system-monitor-smoke.sh

# Widget availability
bash tests/run-qml-harness.sh SuperSystemMonitorAvailabilitySmoke

# Settings schema
bash tests/run-qml-harness.sh SystemMonitorSettingsSmoke

# Full shell
timeout 10 qs --path .
```

Note: Some harnesses may segfault on teardown due to the issues above. The assertions still pass; the crash occurs during process exit.

## Next Steps

1. Complete widget integration (consume real `SystemMonitorService` data)
2. Investigate `AnimatedPanelBase` teardown with minimal reproduction case
3. Consider upstream report to Quickshell if it's a layer-shell issue
4. Proceed with panel design once widget and teardown issues are resolved
