# Implementation Plan

1. Re-read current Row, Slider, Choice, theme, and existing control/page tests; preserve the runtime-default fix from the archived task.
2. Update Slider marker layering and state-dependent height so the default marker remains visible above the thumb and becomes slightly shorter than the thumb at equality.
3. Give the Row restore slot a visible rounded button surface and explicit spacing while preserving its z-order, callback, keyboard, and input isolation.
4. Normalize Choice and standard full-width control geometry to the same Row content edge.
5. Adjust split Slider control height and bottom-align its label/value block without changing slider input math or fixed panel geometry.
6. Add focused control/page regression assertions for marker state/layer, button surface/spacing, Choice alignment, Slider/card height, and value baseline.
7. Run validation and resolve all QML warnings or test failures.
8. Update `.trellis/spec/frontend/quality-guidelines.md`, commit with a conventional message, and archive the task.

## Risk Checks

- Ensure marker z-order does not steal pointer input from the Slider; keep interaction handlers on the Slider/thumb, not the marker.
- Ensure default-state marker visibility does not regress the modified-state marker or reduced-motion behavior.
- Ensure restore-button spacing is included in Slider width calculations, especially at the right edge.
- Verify Choice alignment with a Row-level coordinate assertion, not only matching widths.
- Verify notification timeout remains milliseconds in persistence and seconds in the display control.

## Verification Commands

- `python3 -m pytest -q`
- `qmllint` on modified QML and affected tests
- Relevant `qmltestrunner` settings suites; record the known silent runner limitation if it recurs
- `git diff --check`
- `timeout 15s qs -p .`
