# Implementation Plan

1. Inspect the full settings overlay geometry and use the debug snapshot to identify the first layer that owns pointer input in each affected coordinate band.
2. Add focused geometry/hit-test assertions to the settings QML tests for all three categories, including control scene rectangles, viewport bounds, and hidden overlay layers.
3. Apply the smallest shared-layout or overlay ownership fix indicated by the failing assertions.
4. Re-run the focused tests after the QML change and remove every warning/error before proceeding.
5. Run the broader settings panel/control test set and review the diff for unchanged persistence and overlay contracts.
6. Record the reusable prevention rule in the appropriate frontend spec if the fix confirms a new hit-test/overlay convention.
7. Commit with a conventional commit message after verification.

## Validation Commands

- `qs -p tests/qml/tst_lazer_settings_controls.qml`
- `qs -p tests/qml/tst_lazer_settings_panel.qml`
- `git diff --check`
- `git status --short`

## Review Gates

- No implementation before this plan is explicitly approved and the task is started.
- No acceptance of a visual-only fix without a test that checks actual pointer/hover ownership.
- No change to settings persistence or service interfaces.
