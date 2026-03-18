# Super System Monitor Widget Integration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Merge the `feature/super-system-monitor` service layer into the current workspace and upgrade `SuperSystemMonitorWidget.qml` to render real data from `SystemMonitorService`.

**Architecture:** Preserve the repo's service-to-module separation. Import the system monitor services and schema from the dedicated branch, then keep `SuperSystemMonitorWidget.qml` as a thin presenter that reads only from `SystemMonitorService` instead of assembling raw metrics itself.

**Tech Stack:** QML, Quickshell, `Process`, `FileView`, `SettingsService`, bar widget registry maps, smoke harness runner.

---

### Task 1: Import the system monitor settings and service layer

**Files:**
- Modify: `config/settings-default.json`
- Modify: `null/dymicshell/settings.json`
- Modify: `services/SettingsService.qml`
- Create: `services/SystemMetricsService.qml`
- Create: `services/AudioDeviceService.qml`
- Create: `services/BrightnessService.qml`
- Create: `services/SystemMonitorService.qml`

**Step 1: Copy the settings schema additions**

Bring over the `systemMonitor` defaults and schema exactly, keeping runtime and
defaults aligned.

**Step 2: Copy the four services into `services/`**

Keep service responsibilities unchanged:

- `SystemMetricsService.qml` samples metrics
- `AudioDeviceService.qml` handles audio state
- `BrightnessService.qml` handles brightness state
- `SystemMonitorService.qml` aggregates widget-facing monitor state

**Step 3: Do not connect UI yet**

This task only brings in the backend contract.

---

### Task 2: Add failing service-level smoke coverage in the current workspace if needed

**Files:**
- Create: `tests/qml/SystemMetricsServiceSmoke.qml`
- Create: `tests/qml/AudioDeviceServiceSmoke.qml`
- Create: `tests/qml/BrightnessServiceSmoke.qml`
- Create: `tests/qml/SystemMonitorServiceSmoke.qml`
- Create: `tests/qml/SystemMonitorSettingsSmoke.qml`
- Modify: `tests/run-settings-smoke.sh`

**Step 1: Bring over the service/settings smoke harnesses**

Copy the branch harnesses into the current workspace.

**Step 2: Wire the settings smoke script**

Ensure `tests/run-settings-smoke.sh` includes `SystemMonitorSettingsSmoke`.

**Step 3: Run one harness first to confirm the RED/GREEN status matches import state**

Run the nearest service smoke that proves the imported file exists, for example:

```bash
timeout 12 qs -p tests/qml/SystemMonitorSettingsSmoke.qml
```

Expected: PASS if Task 1 is already in place.

---

### Task 3: Write the failing widget integration smoke

**Files:**
- Create: `tests/qml/SuperSystemMonitorWidgetSmoke.qml`

**Step 1: Write a harness that proves real service consumption**

The harness should:

- instantiate `SuperSystemMonitorWidget`
- set deterministic overrides through imported services
- assert the widget reflects real system monitor values rather than placeholder
  literals

Examples of acceptable assertions:

- rendered metric text includes a service-provided CPU label
- rendered metric text includes a service-provided memory or temperature label
- a severity-driven visual state changes when `highestSeverity` changes

**Step 2: Run the harness before widget refactor**

Run:

```bash
bash tests/run-qml-harness.sh SuperSystemMonitorWidgetSmoke
```

Expected: FAIL because the current widget still renders placeholder content.

---

### Task 4: Upgrade `SuperSystemMonitorWidget.qml` to consume `SystemMonitorService`

**Files:**
- Modify: `modules/bar/widgets/SuperSystemMonitorWidget.qml`

**Step 1: Replace placeholder literals with service-backed rendering**

Read only from `SystemMonitorService`, such as:

- `metrics`
- `highestSeverity`
- `volumeLevel`
- `volumeMuted`
- `brightnessLevel`

**Step 2: Keep the widget presentation-only**

Do not move threshold logic, ordering, or metric fallback rules into the widget.

**Step 3: Keep bar layout stable**

Maintain a compact pill with stable `implicitHeight` and predictable content
width so the widget behaves well in both the bar and picker preview.

**Step 4: Re-run the widget smoke**

Run:

```bash
bash tests/run-qml-harness.sh SuperSystemMonitorWidgetSmoke
```

Expected: PASS.

---

### Task 5: Re-verify widget availability wiring

**Files:**
- Verify: `modules/bar/BarContent.qml`
- Verify: `modules/bar/WidgetPickerWindow.qml`
- Verify: `tests/qml/SuperSystemMonitorAvailabilitySmoke.qml`

**Step 1: Run the existing availability smoke**

Run:

```bash
bash tests/run-qml-harness.sh SuperSystemMonitorAvailabilitySmoke
```

Expected: PASS.

**Step 2: Confirm the widget still uses the same registry key**

Keep `superSystemMonitor` unchanged in both registries.

---

### Task 6: Run the broader verification set

**Files:**
- Verify: all touched files

**Step 1: Run the imported service/settings proof**

Run the smallest useful set, including at minimum:

```bash
bash tests/run-settings-smoke.sh
```

If the imported service smokes are not all covered by grouped scripts yet, run
them individually as well.

**Step 2: Run the widget integration smoke**

Run:

```bash
bash tests/run-qml-harness.sh SuperSystemMonitorWidgetSmoke
```

Expected: PASS.

**Step 3: Run the full shell load check**

Run:

```bash
timeout 10 qs --path .
```

Expected: PASS aside from known environment warnings.

---

### Task 7: Review the integration boundary

**Files:**
- Verify: `services/SystemMonitorService.qml`
- Verify: `modules/bar/widgets/SuperSystemMonitorWidget.qml`

**Step 1: Confirm service/UI responsibilities remain clean**

Verify:

- services own sampling and aggregation
- widget owns only rendering and light interaction
- no duplicated threshold logic appears in UI code

**Step 2: Record follow-up work separately**

Future panel work, richer interaction, and visual polish should be tracked as
new iterations instead of expanding this integration milestone.
