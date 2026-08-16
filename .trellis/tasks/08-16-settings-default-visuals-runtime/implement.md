# Implementation Plan

1. Add canonical category defaults and a validated category/key reset API to `services/SettingsService.qml`, matching current JsonAdapter initial values.
2. Bind the service maps and reset API through `modules/lazerbar/TopBar.qml` into the existing `LazerSettingsOverlay.panel` inputs.
3. Forward `defaultOf(key)` into every numeric `LazerSettingsSlider` in Appearance and Bar pages.
4. Add focused tests for the service/host contract, representative row reset visibility, and Slider default marker propagation without changing interaction tests.
5. Run QML lint and all relevant test/smoke checks; fix any warnings or failures.
6. Capture the runtime-wiring contract in the frontend quality guideline, commit with a conventional message, then archive the task.

## Risk Checks

- Compare service default maps field-for-field with the JsonAdapter declarations to avoid silently changing persisted defaults.
- Preserve reversed-range behavior by testing marker position through `Logic.sliderFraction()` rather than raw arithmetic.
- Ensure the reset API triggers the existing debounced save exactly through `SettingsService.save()`.
- Keep the host bindings per `TopBar` screen instance; do not move panel ownership or overlay lifecycle.

## Verification

- `python3 -m pytest -q`
- `qmllint` for modified QML and affected tests
- Relevant `qmltestrunner` settings suites (record the known silent runner limitation if it recurs)
- `git diff --check`
- `timeout 15s qs -p .`
