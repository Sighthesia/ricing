---
name: qml-performance-debug
description: Use when debugging DymicShell or Quickshell jank, frame drops, layout thrash, layer-shell resize churn, or workspace/widget transitions that feel unexpectedly slow.
---

# QML Performance Debug

Debug QML and Quickshell performance issues by separating local animation cost from global layout and layer-shell churn.

## Use For

- Workspace or widget transitions that stutter even though the animation itself is simple.
- Cases where `implicitWidth`, `implicitHeight`, `childrenRect`, or `Repeater` changes may be retriggering expensive global work.
- Suspected `BarWindow` / `BarLayoutService` / `BarTransientRevealHost` resize churn.
- Suspected service-driven model rebuilds such as `ListModel.clear()` plus `append()` or repeated external IPC refreshes.

## First Pass

1. Identify the visible symptom.
2. Trace the smallest widget that visibly changes.
3. Trace its measurement contract into wrapper and layout services.
4. Check whether the top-level layer-shell window also changes size.
5. Check whether services rebuild models or refetch external state multiple times.

## DymicShell Hotspots

| Area | What to inspect | Why it hurts |
| --- | --- | --- |
| `modules/bar/widgets/*` | `implicitWidth`, `implicitHeight`, `width`, `height`, `Repeater`, `Loader`, `Behavior` | Internal animation can leak into external layout measurement |
| `modules/bar/BarWidgetWrapper.qml` | `childrenRect`, `_naturalWidth`, runtime width reporting | Measures real geometry, not just declared `implicitWidth` |
| `services/BarLayoutService.qml` | `setWidgetMeasuredWidth()`, `_recomputeGeometryContracts()`, `setTransientExtension()` | Width or extension churn can relayout the whole bar |
| `modules/bar/BarWindow.qml` | `implicitHeight`, `barTransientExtension` | Layer-shell surface resize is far more expensive than local QML animation |
| `modules/bar/BarTransientRevealHost.qml` | `expandedHeight`, reservation updates | Per-frame extension updates can resize the whole bar window |
| `services/*Service.qml` | `ListModel.clear()`, bulk append, repeated `Process` reloads | Model teardown and IPC refetches can multiply the visible lag |

## Root-Cause Checklist

### 1. Local Animation vs Global Layout

Ask:

- Does a widget animate only inside its own clip, or does its reported width/height change?
- Does a wrapper read `childrenRect` or live geometry instead of a stable exported measurement?
- Does a width update call into `BarLayoutService.setWidgetMeasuredWidth()`?

Typical fix:

- Keep a stable exported measurement such as `layoutMeasurementWidth`.
- Let internal visuals animate inside that contract.
- Prefer stable `width`/`height` on the root item when wrappers measure live geometry.

### 2. Delegate Rebuilds

Ask:

- Does `ListModel.clear()` rebuild every delegate for a small logical change?
- Does each delegate recompute expensive derived data independently?
- Are icons, sorting, or filtering repeated per delegate?

Typical fix:

- Replace `clear() + append()` with incremental sync.
- Compute derived arrays once at the root or service layer.
- Reuse unchanged array references when possible.

### 3. Layer-Shell Height Churn

Ask:

- Does `BarWindow.implicitHeight` change during the jank window?
- Does `barTransientExtension` change once, or every frame?
- Does a reveal host reserve height from animated content size?

Typical fix:

- Reserve a stable maximum extension for the whole transition.
- Keep internal card or capsule animation inside that reserved surface.
- Avoid deriving extension height from animated child `implicitHeight`.

### 4. External IPC Churn

Ask:

- Does one user action cause multiple `Process` refreshes?
- Are event stream updates and full-state reloads overlapping?
- Is a reload requested while an existing fetch is still running?

Typical fix:

- Queue one follow-up reload instead of running N concurrent reloads.
- Coalesce event bursts.
- Prefer incremental local updates when the event already contains enough data.

## Temporary PERF Logging

When the hot path is unclear, add temporary logs in three layers at once:

1. Service layer: event handling, IPC fetch start/end, model rebuild duration.
2. Widget layer: expensive derived-data functions, mode switches, exported width/height changes.
3. Window/layout layer: `barTransientExtension`, `BarWindow.implicitHeight`, geometry recompute entry points.

Good temporary log targets in this repo:

- `services/NiriService.qml`
- `modules/bar/widgets/WorkspaceWidget.qml`
- `services/BarLayoutService.qml`
- `modules/bar/BarWindow.qml`

Rules:

- Log durations with `Date.now()`.
- Log only state edges and aggregated durations, not every binding reevaluation.
- Remove all temporary PERF logs before finishing.

## Interpretation Guide

| Symptom in logs | Likely cause | Preferred fix |
| --- | --- | --- |
| Widget recompute is `0-3ms`, but `BarWindow.implicitHeight` changes many times | Layer-shell resize churn | Stabilize transient extension height |
| One interaction causes many `setWidgetMeasuredWidth()` calls | Animated local width leaked into global layout | Export stable measurement width |
| `updateWorkspaces()` or `updateWindows()` is cheap, but fetch time is high | External IPC dominates | Coalesce reloads or avoid full refresh |
| `WorkspacesChanged` causes all delegates to rebuild | `ListModel.clear()` churn | Diff and update incrementally |
| Every delegate scans the same model | N x M derived-data work | Precompute once and fan out |

## DymicShell-Specific Lessons

- `childrenRect` in `BarWidgetWrapper` can reintroduce churn even after stabilizing `implicitWidth`.
- `BarTransientRevealHost` should reserve height once per transition, not from animated child size.
- `WorkspaceWidget`-style overview rows should not let visible-item count changes thrash outer width contracts.
- `SuperIsland` full hint surfaces should reserve a stable maximum height and animate internally.

## Validation

- Run `timeout 5 qs --path .`
- Reproduce the original interaction after removing temporary PERF logs.
- Verify both visual smoothness and that no runtime artifact file was accidentally changed for the commit.
