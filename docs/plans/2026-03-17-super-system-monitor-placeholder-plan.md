# Super System Monitor Placeholder Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make `Super System Monitor` available in the widget library and insertable into the bar as a minimal placeholder widget.



---


**Files:**


Create a harness that:

- instantiates `BarContent`
- instantiates `WidgetPickerWindow`
- asserts `barContent.widgetRegistry.superSystemMonitor` exists
- asserts `widgetPickerWindow.widgetRegistry.superSystemMonitor` exists
- asserts `widgetPickerWindow.widgetNames.superSystemMonitor` exists
- calls `BarLayoutService.resetLayout()`
- calls `BarLayoutService.addWidget("superSystemMonitor", "right")`
- asserts the layout model now contains one item with `id === "superSystemMonitor"`

**Step 2: Run the harness to verify it fails**

Run:

```bash
```

Expected: FAIL because the registry entries and widget file do not exist yet.

---

### Task 2: Add the placeholder widget component

**Files:**
- Create: `modules/bar/widgets/SuperSystemMonitorWidget.qml`

**Step 1: Implement the minimal widget shell**

Build a compact pill that follows the existing widget conventions:

- `color: Colors.background`
- `radius: Theme.cornerRadius`
- `implicitHeight: Theme.barHeight`
- `implicitWidth` derived from content + `Theme.widgetPadding`

Use simple content only, for example:

```qml
Row {
    Text { text: "SYS" }
    Text { text: "CPU 42%" }
    Text { text: "MEM 68%" }
}
```

Adapt the exact styling to match current widget language and token usage.

**Step 2: Keep it dependency-free**

Do not add a new service, settings section, or external process in this task.

---

### Task 3: Register the widget in runtime and picker registries

**Files:**
- Modify: `modules/bar/BarContent.qml`
- Modify: `modules/bar/WidgetPickerWindow.qml`

**Step 1: Add the runtime registry entry**

In `BarContent.qml`, add:

```qml
"superSystemMonitor": "widgets/SuperSystemMonitorWidget.qml"
```

and add a human-readable label such as:

```qml
"superSystemMonitor": "系统监控"
```

**Step 2: Add the mirrored picker registry entry**

In `WidgetPickerWindow.qml`, add the same key to `widgetRegistry` using
`Qt.resolvedUrl(...)`, and add the same display name to `widgetNames`.

**Step 3: Re-run the availability harness**

Run:

```bash
```

Expected: PASS.

---


**Files:**
- Verify: all touched files


Run:

```bash
```

Expected: PASS.

**Step 2: Run the full shell load check**

Run:

```bash
timeout 10 qs --path .
```

Expected: PASS aside from known environment warnings.

---

### Task 5: Perform the post-availability implementation check

**Files:**
- Verify: `modules/bar/widgets/SuperSystemMonitorWidget.qml`
- Verify: `modules/bar/BarContent.qml`
- Verify: `modules/bar/WidgetPickerWindow.qml`

**Step 1: Inspect for structural mismatches**

Confirm:

- the registry key is exactly `superSystemMonitor` in both files
- the runtime path and picker path point to the same widget
- the placeholder widget uses theme/color tokens instead of hardcoded feature colors
- the widget keeps stable implicit sizing suitable for bar layout

**Step 2: Record any follow-up work separately**

If real monitoring data is needed next, treat that as a new iteration rather than
expanding this placeholder task.
