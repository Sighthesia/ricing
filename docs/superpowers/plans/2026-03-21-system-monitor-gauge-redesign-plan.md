# System Monitor Gauge Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the bar system monitor as a hover-expanding gauge widget that always shows `CPU`, `Memory`, and `CPU Temperature`, reveals `Volume`, `Brightness`, and `Battery` on hover, and supports wheel-based `5%` adjustments for `Volume` and `Brightness`.

**Architecture:** Keep raw system probing inside singleton services, move all widget-facing metric normalization into `SystemMonitorService.qml`, add one focused `BatteryService.qml`, and render everything through one reusable `SystemMonitorGauge.qml` plus one `SuperSystemMonitorWidget.qml` shell that hands width animation to `BarExpandTransition.qml`.

**Tech Stack:** Quickshell, QML, singleton services, `BarExpandTransition.qml`, `Theme.qml` / `Colors.qml`, QML harness verification, `timeout 5 qs --path .`, `timeout 5 qs -p .`

---

## File Structure

### New files

- `services/BatteryService.qml`
  - Reads battery availability and charge state from `/sys/class/power_supply`, exposes a normalized snapshot, and supports override-driven harness verification.
- `modules/bar/widgets/systemmonitor/SystemMonitorGauge.qml`
  - Renders one icon-centered three-quarter ring and emits wheel step requests when interactive.
- `tests/qml/systemmonitor/SystemMonitorHarness.qml`
  - Single QML harness entry that switches assertion modes via `Quickshell.args`.
- `tests/run-system-monitor-harness.sh`
  - Thin wrapper for running the system monitor harness from repo root.

### Modified files

- `services/SystemMonitorService.qml`
  - Standardizes six metric entries, exposes grouped arrays, keeps `highestSeverity` scoped to the persistent trio, and adds step-adjust helpers.
- `modules/bar/widgets/SuperSystemMonitorWidget.qml`
  - Replaces the old text layout with an expandable gauge row using `BarExpandTransition.qml`.
- `modules/bar/BarContent.qml`
  - Verify that the widget can continue mounting without call-site changes.
- `services/AudioDeviceService.qml`
  - Verify existing volume APIs are sufficient; do not expand scope unless the harness proves a missing hook.
- `services/BrightnessService.qml`
  - Verify existing brightness APIs are sufficient; do not expand scope unless the harness proves a missing hook.
- `services/SettingsService.qml`
  - Verify `systemMonitor.enabled` and `systemMonitor.hoverReveal` remain authoritative while legacy fields keep deserializing and persisting.
- `config/settings-default.json`
  - Verify legacy `systemMonitor` defaults stay compatible for this wave.

### Verification targets

- `tests/qml/systemmonitor/SystemMonitorHarness.qml`
- `tests/run-system-monitor-harness.sh`
- `services/BatteryService.qml`
- `services/SystemMonitorService.qml`
- `modules/bar/widgets/systemmonitor/SystemMonitorGauge.qml`
- `modules/bar/widgets/SuperSystemMonitorWidget.qml`
- `services/SettingsService.qml`
- `config/settings-default.json`

---

### Task 1: Establish the harness and battery contract

**Files:**
- Create: `tests/qml/systemmonitor/SystemMonitorHarness.qml`
- Create: `tests/run-system-monitor-harness.sh`
- Create: `services/BatteryService.qml`

- [ ] **Step 1: Write the failing harness entry and runner**

Create `tests/run-system-monitor-harness.sh`:

```bash
#!/usr/bin/env sh
set -eu
timeout 5 qs -p tests/qml/systemmonitor/SystemMonitorHarness.qml -- "$@"
```

Create `tests/qml/systemmonitor/SystemMonitorHarness.qml` with explicit imports, `Quickshell.args` mode switching, and an initial `battery-contract` mode that expects a missing battery service to fail:

```qml
import QtQuick
import Quickshell
import qs.services

Item {
    readonly property string mode: Quickshell.args.length > 0 ? Quickshell.args[0] : "all"

    function expect(condition, message) {
        if (!condition)
            throw new Error(message)
    }

    Component.onCompleted: {
        if (mode === "battery-contract" || mode === "all") {
            expect(BatteryService !== undefined, "missing BatteryService")
            Qt.quit()
        }
    }
}
```

- [ ] **Step 2: Run the harness to verify the missing battery contract fails**

Run:

```bash
sh tests/run-system-monitor-harness.sh battery-contract
```

Expected: FAIL because `services/BatteryService.qml` does not exist yet.

- [ ] **Step 3: Implement `services/BatteryService.qml` with the documented snapshot contract**

Create a singleton that follows the existing service pattern used by `AudioDeviceService.qml` and `BrightnessService.qml`:

```qml
pragma Singleton

import Quickshell
import QtQuick

Singleton {
    readonly property var batterySnapshot: ({
        available: root.available,
        level: root.level,
        percentLabel: root.percentLabel,
        charging: root.charging,
        status: root.status
    })

    readonly property bool available: !!root._effectiveState.available
    readonly property real level: root._effectiveState.level
    readonly property bool charging: !!root._effectiveState.charging
    readonly property string status: root._effectiveState.status
    readonly property string percentLabel: root.available ? Math.round(root.level * 100) + "%" : "--"

    function refresh() {}
    function _setStateOverride(state) {}
}
```

Implementation requirements:

- detect battery directories under `/sys/class/power_supply`
- only treat entries as batteries when their `type` file resolves exactly to `Battery`
- if multiple battery entries exist, pick the first lexicographically sorted `Battery` entry for v1
- treat no battery as `available: false`, `level: 0`, `status: "missing"`
- support `_setStateOverride(null)` and `_setStateOverride(undefined)` as clear operations
- keep override state exposed until it is explicitly cleared

- [ ] **Step 4: Extend the harness to verify battery-present and battery-absent snapshots**

Add harness assertions that prove:

- `_setStateOverride({ available: true, level: 0.64, charging: true, status: "charging" })` yields `64%`
- `_setStateOverride({ available: false, level: 0.93, charging: false, status: "missing" })` still exposes `level === 0`
- `_setStateOverride(null)` returns control to live state

- [ ] **Step 5: Re-run the battery harness**

Run:

```bash
sh tests/run-system-monitor-harness.sh battery-contract
```

Expected: PASS.

- [ ] **Step 6: Run the repo load check**

Run:

```bash
timeout 5 qs --path .
```

Expected: PASS aside from known environment warnings.

- [ ] **Step 7: Commit the battery contract**

```bash
git add services/BatteryService.qml tests/qml/systemmonitor/SystemMonitorHarness.qml tests/run-system-monitor-harness.sh
git commit -m "feat: add battery service contract for system monitor"
```

---

### Task 2: Standardize the monitor metric model before touching the widget

**Files:**
- Modify: `services/SystemMonitorService.qml`
- Verify: `services/SystemMetricsService.qml`
- Verify: `services/AudioDeviceService.qml`
- Verify: `services/BrightnessService.qml`
- Verify: `services/BatteryService.qml`
- Verify: `services/SettingsService.qml`
- Verify: `config/settings-default.json`
- Modify: `tests/qml/systemmonitor/SystemMonitorHarness.qml`

- [ ] **Step 1: Add a failing `service-contract` harness mode**

Extend `tests/qml/systemmonitor/SystemMonitorHarness.qml` so `service-contract` asserts the new grouped API:

```qml
SystemMetricsService._setSnapshotOverride({
    cpuAvailable: true,
    cpuUsage: 0.92,
    memoryAvailable: true,
    memoryUsage: 0.47,
    temperatureAvailable: true,
    temperatureC: 88
})
AudioDeviceService._setStateOverride({
    volumeLevel: 0.35,
    volumeMuted: false,
    microphoneMuted: false,
    sinkAvailable: true,
    sourceAvailable: true
})
BrightnessService._setStateOverride({ available: true, level: 0.61 })
BatteryService._setStateOverride({ available: true, level: 0.22, charging: false, status: "discharging" })

expect(SystemMonitorService.persistentMetrics.length === 3, "persistentMetrics length mismatch")
expect(SystemMonitorService.expandedMetrics.length === 3, "expandedMetrics length mismatch")
expect(SystemMonitorService.persistentMetrics[0].key === "cpu", "persistent order mismatch")
expect(SystemMonitorService.expandedMetrics[2].key === "battery", "expanded order mismatch")
expect(SystemMonitorService.highestSeverity === "critical", "persistent severity must drive highestSeverity")
```

Also add clamp checks for `adjustVolumeByStep()` and `adjustBrightnessByStep()` at `0` and `1`.

Also add one compatibility assertion block that proves the legacy fields still exist after settings load:

```qml
expect(SettingsService.data.systemMonitor.pinnedMetrics !== undefined, "missing pinnedMetrics compatibility field")
expect(SettingsService.data.systemMonitor.showVolume !== undefined, "missing showVolume compatibility field")
expect(SettingsService.data.systemMonitor.showBrightness !== undefined, "missing showBrightness compatibility field")
expect(SettingsService.data.systemMonitor.showMicrophone !== undefined, "missing showMicrophone compatibility field")
```

- [ ] **Step 2: Run the service harness to verify the current API fails**

Run:

```bash
sh tests/run-system-monitor-harness.sh service-contract
```

Expected: FAIL because `SystemMonitorService.qml` does not yet expose `persistentMetrics`, `expandedMetrics`, or step-adjust helpers.

- [ ] **Step 3: Refactor `services/SystemMonitorService.qml` to emit the six standardized metric entries**

Do this in a strict order:

1. define one internal metric-entry builder that always emits the full standardized field set
2. map the persistent trio into that shape first
3. map `volume`, `brightness`, and `battery` into that same shape second
4. derive `persistentMetrics`, `expandedMetrics`, and `allMetrics` from those ordered builders
5. add the wheel-step helpers only after the grouped arrays and `highestSeverity` assertions pass

Keep the service as the only adapter layer and introduce helpers similar to:

```qml
readonly property var persistentMetrics: root._buildPersistentMetrics()
readonly property var expandedMetrics: root._buildExpandedMetrics()
readonly property var allMetrics: persistentMetrics.concat(expandedMetrics)
readonly property string highestSeverity: root._deriveHighestSeverity(persistentMetrics)

function adjustVolumeByStep(direction) {
    root.setVolumeLevel(root._clampRatio(AudioDeviceService.volumeLevel + (0.05 * direction)))
}

function adjustBrightnessByStep(direction) {
    root.setBrightnessLevel(root._clampRatio(BrightnessService.level + (0.05 * direction)))
}
```

Implementation rules:

- `persistentMetrics` order is always `cpu`, `memory`, `temperature`
- `expandedMetrics` order is always `volume`, `brightness`, `battery`
- `battery` stays in data even when unavailable
- temperature ring progress must normalize from a fixed `30C..100C` visual range and clamp outside that interval
- only the persistent trio contributes to `highestSeverity`
- `volume`, `brightness`, and `battery` default to `normal` severity in this wave

Harness rule:

- import singletons through `import qs.services`
- drive service state only through the existing override functions such as `_setSnapshotOverride()` and `_setStateOverride()`
- clear every override before `Qt.quit()` so one mode cannot leak into another

- [ ] **Step 4: Re-run the service harness**

Run:

```bash
sh tests/run-system-monitor-harness.sh service-contract
```

Expected: PASS.

- [ ] **Step 5: Run the repo load checks**

Run:

```bash
timeout 5 qs --path .
timeout 5 qs -p .
```

Expected: PASS aside from known environment warnings.

- [ ] **Step 6: Commit the standardized service layer**

```bash
git add services/SystemMonitorService.qml services/BatteryService.qml tests/qml/systemmonitor/SystemMonitorHarness.qml tests/run-system-monitor-harness.sh
git commit -m "feat: standardize system monitor metric groups"
```

---

### Task 3: Build the reusable gauge component before integrating the widget shell

**Files:**
- Create: `modules/bar/widgets/systemmonitor/SystemMonitorGauge.qml`
- Modify: `tests/qml/systemmonitor/SystemMonitorHarness.qml`

- [ ] **Step 1: Add a failing `gauge-contract` harness mode**

Extend the harness so `gauge-contract` instantiates `SystemMonitorGauge.qml` with representative metric objects and verifies the component can load cleanly for three core states:

- warning metric
- critical metric
- unavailable metric

Use a minimal metric payload like:

```qml
metric: {
    key: "cpu",
    title: "CPU",
    icon: "cpu",
    value: 0.75,
    normalizedProgress: 0.75,
    displayText: "75%",
    severity: "warning",
    available: true,
    persistent: true,
    interactive: false
}
```

Expected initial failure: missing `SystemMonitorGauge.qml`.

- [ ] **Step 2: Run the gauge harness to verify the missing component fails**

Run:

```bash
sh tests/run-system-monitor-harness.sh gauge-contract
```

Expected: FAIL because the gauge component does not exist yet.

- [ ] **Step 3: Implement `modules/bar/widgets/systemmonitor/SystemMonitorGauge.qml` with one clear responsibility**

Create a compact component that:

- reads `metric.normalizedProgress` and clamps it to `0..1`
- maps `metric.severity` and `metric.available` into semantic colors
- renders one icon-centered three-quarter ring
- emits `stepRequested(1)` or `stepRequested(-1)` on wheel only when `interactive` is true
- remains display-only and emits nothing when `interactive` is false

Event boundary rules:

- wheel input is accepted only while the pointer is inside that gauge's own bounds
- use the dominant wheel axis to determine direction; positive delta emits `stepRequested(1)`, negative delta emits `stepRequested(-1)`
- ignore zero-delta wheel events
- the gauge must not mutate services directly; it only emits `stepRequested(...)`

Preferred structure:

```qml
import QtQuick
import qs.config

Item {
    required property var metric
    property bool interactive: false
    signal stepRequested(int direction)
}
```

Implementation notes:

- keep all colors derived from `Colors.*`
- keep geometry derived from `Theme.barWidget.*` or `Theme.*`
- if a temporary drawing literal is unavoidable, mark it with `// FIXME:` per repo rules
- do not add inline numeric labels in the resting surface

- [ ] **Step 4: Re-run the gauge harness**

Run:

```bash
sh tests/run-system-monitor-harness.sh gauge-contract
```

Expected: PASS.

- [ ] **Step 5: Run the repo load check**

Run:

```bash
timeout 5 qs --path .
```

Expected: PASS aside from known environment warnings.

- [ ] **Step 6: Commit the gauge primitive**

```bash
git add modules/bar/widgets/systemmonitor/SystemMonitorGauge.qml tests/qml/systemmonitor/SystemMonitorHarness.qml tests/run-system-monitor-harness.sh
git commit -m "feat: add reusable system monitor gauge"
```

---

### Task 4: Rebuild `SuperSystemMonitorWidget.qml` around grouped gauges and hover expansion

**Files:**
- Modify: `modules/bar/widgets/SuperSystemMonitorWidget.qml`
- Verify: `modules/bar/BarExpandTransition.qml`
- Verify: `services/SystemMonitorService.qml`
- Verify: `services/SettingsService.qml`
- Verify: `config/settings-default.json`
- Modify: `tests/qml/systemmonitor/SystemMonitorHarness.qml`

- [ ] **Step 1: Add failing widget harness modes for collapse, expand, and no-battery cases**

Extend the harness with these modes:

- `widget-collapsed`
- `widget-expanded`
- `widget-no-battery`
- `widget-hover-disabled`
- `widget-disabled`

Assertions should prove:

- collapsed state mounts exactly the three persistent gauges
- expanded state mounts the persistent trio plus the expanded gauges on the right
- no-battery state removes the battery visual slot without removing the battery data contract
- `systemMonitor.hoverReveal = false` prevents expansion even if the widget's hover state is forced true, while still rendering the persistent trio
- `systemMonitor.enabled = false` prevents the widget from mounting any visible gauge surface at all

Use service overrides to control the underlying data and set the widget's internal hover state directly from the harness after construction.

- [ ] **Step 2: Run the widget harness to verify the current text widget fails the new contract**

Run:

```bash
sh tests/run-system-monitor-harness.sh widget-collapsed
sh tests/run-system-monitor-harness.sh widget-expanded
```

Expected: FAIL because the current widget still renders text rows and has no expand-on-hover gauge layout.

- [ ] **Step 3: Replace the widget body with one expandable gauge pill**

Refactor `modules/bar/widgets/SuperSystemMonitorWidget.qml` so it:

- respects `SettingsService.data.systemMonitor.enabled`
- respects `SettingsService.data.systemMonitor.hoverReveal`
- owns one stable hover hit area across collapsed and expanded widths
- binds collapsed and expanded widths through `BarExpandTransition.qml`
- always renders `SystemMonitorService.persistentMetrics`
- renders `SystemMonitorService.expandedMetrics` only in the expanded visual group
- routes wheel requests from `volume` and `brightness` gauges back to `SystemMonitorService.adjust*ByStep()`

Suggested structural sketch:

```qml
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import ".." as BarComponents
import "systemmonitor" as MonitorParts

Item {
    id: root
    property bool _hovered: false
    readonly property bool _expanded: SettingsService.data.systemMonitor.hoverReveal && _hovered
}
```

Width ownership rules:

- `collapsedWidth` must equal the persistent gauge row implicit width plus the widget's horizontal padding
- `expandedWidth` must equal the persistent row width plus one inter-group gap plus the visible expanded-row width plus the widget's horizontal padding
- when battery is unavailable, compute `expandedWidth` from only the visible expanded gauges
- bind `BarExpandTransition.expanded` directly to the widget's resolved expanded state
- set `animateWidth: true` and `animateHeight: false` for this widget
- derive the widget's final `implicitWidth` from `BarExpandTransition.animatedWidth`, not from a competing `Behavior on implicitWidth`

Implementation rules:

- keep one horizontal row only
- no inline `VOL`, `BRIGHT`, or percentage text in the resting widget
- no microphone rendering in the redesigned widget
- expanded group is appended on the right, not swapped in place
- battery hides visually when unavailable, is skipped from the expanded rendered row, and does not reserve width

- [ ] **Step 4: Re-run the widget harness modes**

Run:

```bash
sh tests/run-system-monitor-harness.sh widget-collapsed
sh tests/run-system-monitor-harness.sh widget-expanded
sh tests/run-system-monitor-harness.sh widget-no-battery
sh tests/run-system-monitor-harness.sh widget-hover-disabled
sh tests/run-system-monitor-harness.sh widget-disabled
```

Expected: PASS.

- [ ] **Step 5: Run the full shell load checks**

Run:

```bash
timeout 5 qs --path .
timeout 5 qs -p .
```

Expected: PASS aside from known environment warnings.

- [ ] **Step 6: Commit the widget migration**

```bash
git add modules/bar/widgets/SuperSystemMonitorWidget.qml modules/bar/widgets/systemmonitor/SystemMonitorGauge.qml services/SystemMonitorService.qml services/BatteryService.qml tests/qml/systemmonitor/SystemMonitorHarness.qml tests/run-system-monitor-harness.sh
git commit -m "feat: redesign system monitor as expandable gauges"
```

---

### Task 5: Final verification and compatibility sweep

**Files:**
- Verify: `services/BatteryService.qml`
- Verify: `services/SystemMonitorService.qml`
- Verify: `modules/bar/widgets/systemmonitor/SystemMonitorGauge.qml`
- Verify: `modules/bar/widgets/SuperSystemMonitorWidget.qml`
- Verify: `services/SettingsService.qml`
- Verify: `config/settings-default.json`
- Verify: `modules/bar/BarContent.qml`
- Verify: `tests/qml/systemmonitor/SystemMonitorHarness.qml`
- Verify: `tests/run-system-monitor-harness.sh`

- [ ] **Step 1: Run the complete harness suite**

Run:

```bash
sh tests/run-system-monitor-harness.sh battery-contract
sh tests/run-system-monitor-harness.sh service-contract
sh tests/run-system-monitor-harness.sh gauge-contract
sh tests/run-system-monitor-harness.sh widget-collapsed
sh tests/run-system-monitor-harness.sh widget-expanded
sh tests/run-system-monitor-harness.sh widget-no-battery
sh tests/run-system-monitor-harness.sh widget-hover-disabled
sh tests/run-system-monitor-harness.sh widget-disabled
```

Expected: PASS.

- [ ] **Step 2: Run the shell-level validation commands**

Run:

```bash
timeout 5 qs --path .
timeout 5 qs -p .
```

Expected: PASS aside from known environment warnings.

- [ ] **Step 3: Manually inspect the product rules**

Confirm:

- resting state shows exactly three icon-plus-ring gauges
- hover expands to the right using `BarExpandTransition.qml`
- volume and brightness wheel adjustments apply in `5%` increments only while hovering those gauges
- battery hides cleanly on hardware without batteries
- widget-level alert styling still reflects only `cpu`, `memory`, and `temperature`

- [ ] **Step 4: Verify compatibility fields stayed compatibility-only**

Confirm that `pinnedMetrics`, `showVolume`, `showBrightness`, and `showMicrophone` still deserialize and persist through `SettingsService.qml` and `config/settings-default.json`, but no longer drive the redesigned widget rendering.

- [ ] **Step 5: Commit the final verification pass**

```bash
git add services/BatteryService.qml services/SystemMonitorService.qml modules/bar/widgets/systemmonitor/SystemMonitorGauge.qml modules/bar/widgets/SuperSystemMonitorWidget.qml tests/qml/systemmonitor/SystemMonitorHarness.qml tests/run-system-monitor-harness.sh services/SettingsService.qml config/settings-default.json
git commit -m "test: verify expandable system monitor gauge redesign"
```
