# Fix settings toggle visibility

## Goal
Restore visible settings toggle rows after the recent inline-control restyle. A toggle row must show its setting label on the left and the `44x20` toggle capsule on the right without changing settings behavior or persistence.

## Background

- `LazerSettingsToggle.qml` exposes the `inline` row presentation and has a visible `44x20` capsule.
- `LazerSettingsRow.qml` owns the inline layout and currently sizes `controlHost` to the full row width while also sizing the label from the remaining width.
- This can collapse the inline label region and make the toggle row appear to have no usable content, even though the toggle item itself remains mounted.
- Existing Choice (`choice`) and Slider (`split`) presentation contracts must remain unchanged.

## Requirements

- Keep the existing `LazerSettingsToggle` interaction contract: `checked`, `toggled`, keyboard activation, focus, disabled state, accessibility, and persistence callbacks.
- Correct inline row geometry so the label retains usable width and the toggle capsule remains visible at the row's right edge.
- Preserve the fixed settings surface geometry, search filtering, revert affordance, tooltip ownership, and all non-toggle control layouts.
- Add a regression assertion covering inline row label visibility/width, toggle dimensions, and right-edge placement.
- Use the existing QML layout and transition conventions; do not introduce a second toggle implementation or change settings models.

## Out Of Scope

- Changing toggle colors, capsule geometry, or checked/unchecked semantics.
- Changing settings persistence, default values, save timing, or page models.
- Refactoring Choice/Slider layout contracts unless a test demonstrates an unintended regression.

## Acceptance Criteria

- [ ] A settings row containing `LazerSettingsToggle` has a non-zero label width and visible label text.
- [ ] The toggle remains `44px` wide and `20px` high, and its right edge stays inside the row content bounds.
- [ ] Toggle pointer and keyboard activation still emit `toggled` exactly as before.
- [ ] Search visibility and disabled-row behavior remain unchanged.
- [ ] Choice and Slider row geometry tests remain green.
- [ ] `qmllint`, Python tests, QML tests where the local runner is available, `git diff --check`, and `timeout 15s qs -p .` complete with no new QML warnings or errors.

## Technical Notes

- Recommended fix: separate the inline `controlHost`'s layout width from the injected toggle item's requested width. The host should occupy only the control's measured width at the right edge, while the label uses the remaining row width.
- Verify the fix against the existing `test_rowHasMinimumHeightAndDefaultControl`, `test_toggleAndSliderExposeRowPresentationContracts`, and row width-binding tests before adding or changing assertions.
- No blocking product decisions remain; this is a focused regression repair.
