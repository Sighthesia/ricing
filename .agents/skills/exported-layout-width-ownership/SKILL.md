---
name: exported-layout-width-ownership
description: Use when a component's visible width animates correctly but the parent layout, wrapper, or reserved space still measures a different width.
---

# Exported Layout Width Ownership

The width users see and the width the layout system reserves are not automatically the same; trace the exported width contract before changing global layout code.

## A. The Generic Pattern / Methodology

| Item | Guidance |
| --- | --- |
| Core Concept | Wrapper-based layouts measure one exported width contract, not whichever child looks visually correct. |
| Universal Checklist | 1. Identify the actual animated width owner. 2. Identify which root property the wrapper reads first. 3. Export the intended width through that boundary consistently. 4. Only define a separate measurement property when layout must intentionally differ from visuals. 5. Treat shared layout files as suspect only after root export is proven correct. |

## B. The Specific Trap / Symptom (The Trigger)

| Context | Summary |
| --- | --- |
| DymicShell bar widgets | Internal pill animation looked correct, but the bar still reserved the wrong width because `BarWidgetWrapper` was measuring the root export, not the animated child that developers were staring at. |

## C. The Anti-Pattern vs. Best Practice

| Pattern | Explanation |
| --- | --- |
| ❌ The Anti-Pattern (Why it failed) | Patch section-level or whole-layout geometry because one widget's internals animate correctly but the wrapper still measures stale root data. |
| ✅ The Best Practice (The Fix) | Decide which root property is the authoritative exported width and make the wrapper consume that one value consistently. |

## D. Generalizable Rules (Highly Portable)

### Agnostic Rules

- Fix width ownership at the component boundary first.
- Do not patch global layout until the exported root width is proven wrong or insufficient.
- The key question is not which child animates, but which root property the wrapper measures.

### Warning Signs

- Visible width springs smoothly but reserved width snaps.
- Internal states look correct while neighboring layout still behaves as if width never changed.
- Repeated fixes in shared layout files create collateral regressions.

## E. Universal Verification Strategy

### Agnostic Testing Logic

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
