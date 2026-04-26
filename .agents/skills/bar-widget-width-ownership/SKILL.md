---
name: bar-widget-width-ownership
description: Use when a bar widget's visual width, spring width, and exclusive/layout width fall out of sync, especially when internal pill animation seems correct but the bar still reserves the wrong width.
---

# Bar Widget Width Ownership

In DymicShell bar widgets, the width the user sees and the width the bar reserves are not automatically the same; trace width ownership through the widget root, `BarWidgetWrapper`, and `BarLayoutService` before changing global bar layout code.

## When to Use

- A bar widget animates width correctly, but neighboring widgets or reserved space still look wrong.
- A widget has a spring or staged width animation and you need exclusive width to follow it.
- `WorkspaceWidget` or similar pills seem to need `BarSection` or whole-bar changes just to fix one widget's width behavior.

## Symptoms

- The visible pill expands or settles with spring motion, but the reserved width still snaps or uses the wrong target.
- Flash/overview/title states look correct inside the widget, but the bar appears to reserve width from a different value.
- Repeated fixes in `BarSection.qml` or global geometry code create collateral layout regressions.

## Root Cause

- `BarWidgetWrapper` does not measure bar widgets directly from their internal animated child width; it reads one exported width contract from the widget root.
- The wrapper measurement order is: `layoutMeasurementWidth` -> `implicitWidth` -> `width` -> `childrenRect.width`.
- `SuperSystemMonitorWidget` works because it exports its animated width through `implicitWidth` and lets the wrapper reuse that directly.
- `WorkspaceWidget` became hard to debug because separate layout-contract properties were repeatedly mixed with `_pillTransition.animatedWidth`, which encouraged fixes in `BarSection` instead of the widget-local width owner.

## Transferable Lesson

- When one bar widget has width-sync issues, fix width ownership at the widget boundary first.
- Do not patch `BarSection`, section `x`, or whole-bar geometry unless the bug is proven to be cross-widget layout logic rather than a single widget exporting the wrong width.
- In wrapper-based layout systems, the reliable question is not "which child is animating?" but "which root property is the wrapper measuring?"

## Correct Pattern

- First identify the widget's real animated width owner.
- In `WorkspaceWidget`, the spring width lives in `_pillTransition.animatedWidth` from `modules/bar/BarExpandTransition.qml`.
- Prefer the `SuperSystemMonitorWidget` pattern for bar-local width animation: export the animated width via the widget root `implicitWidth`, and let `BarWidgetWrapper` read that fallback path.
- Only define `layoutMeasurementWidth` when the layout contract must intentionally differ from the visible/animated width.
- If `layoutMeasurementWidth` exists, treat it as the single authoritative layout export; do not also expect wrapper fallback to `implicitWidth` to matter.
- When a visual subregion must track the same spring as the title but should never shrink below a detached minimum, clamp the shared animated width at the host boundary instead of binding the subregion directly to the title's instantaneous width.

## Debug Checklist

1. Check the widget root `implicitWidth`, `layoutMeasurementWidth`, and `width` together.
2. Confirm which of those `BarWidgetWrapper._layoutMeasuredWidth` is actually reading.
3. Verify `reportMeasuredWidth()` sends the expected runtime width to `BarLayoutService.setWidgetMeasuredWidth()`.
4. Only after that, inspect `BarLayoutService` geometry recompute behavior.
5. If a proposed fix requires `BarSection.qml`, re-justify it from logs before editing.

## Verification

- Run `timeout 5 qs --path .`
- Reproduce the widget width transition and verify the reserved width follows the intended exported root width.
- For workspace-like pills, compare `implicitWidth`, `layoutMeasurementWidth`, and `_pillTransition.animatedWidth` before changing any bar-global file.

## References

- `modules/bar/widgets/WorkspaceWidget.qml`
- `modules/bar/widgets/SuperSystemMonitorWidget.qml`
- `modules/bar/BarWidgetWrapper.qml`
- `modules/bar/BarExpandTransition.qml`
- `services/BarLayoutService.qml`
