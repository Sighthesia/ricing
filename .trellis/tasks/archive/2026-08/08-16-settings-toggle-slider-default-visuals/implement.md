# Implementation Plan: Toggle Alignment And Slider Default Visuals

## Ordered Steps

1. Inspect the current Row, Toggle, Slider, theme tokens, and control/page tests
   after task start; record any concurrent changes before editing.
2. Update Row geometry so the restore affordance is right-owned and its slot is
   reserved from control width; keep `revertVisible`, `canReset`, accessibility,
   and callback behavior unchanged.
3. Correct inline Toggle vertical centering and add a regression assertion for
   the capsule center relative to the Row/card.
4. Add settings-only Slider handle and default-marker tokens and render the
   marker from the normalized default fraction; expose test-only item properties
   if needed without changing interaction ownership.
5. Add/update QML tests for handle height, marker geometry/fraction, reversed and
   out-of-range defaults, right-side restore placement, and visibility after
   reset. Preserve existing interaction and tooltip identity tests.
6. Update `.trellis/spec/frontend/quality-guidelines.md` with the reusable
   right-side reset and Slider default-marker contracts.
7. Run validation and fix all genuine warnings/errors:
   - `python3 -m pytest -q`
   - relevant `qmltestrunner`/project QML test commands
   - `qmllint` for modified QML and tests
   - `git diff --check`
   - `timeout 15s qs -p .`
8. Review the final diff, commit with a conventional message, and archive the
   task using `python3 .trellis/scripts/task.py archive 08-16-settings-toggle-slider-default-visuals`.

## Risk Points

- Moving the reset button can reduce available Slider/Choice width; clamp the
  right control region after reserving the button slot.
- A marker based on raw `defaultValue` can drift for reversed or stepped ranges;
  always normalize through the Slider's established value logic.
- Changing the active handle's height can alter pointer/tooltip geometry; keep
  `nubItem` identity and source-follow behavior intact.
- Existing user changes in the worktree must not be reverted.

## Completion Checks

- Worktree contains only intended implementation, test, spec, and task archive
  changes.
- All acceptance criteria are covered by executable tests or direct smoke
  verification.
- Known environment-only notification ownership warning is documented if it
  remains; unrelated warnings are blockers.
