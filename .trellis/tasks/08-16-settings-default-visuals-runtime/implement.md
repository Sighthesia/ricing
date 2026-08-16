# Implementation Plan

1. Add canonical category defaults and a validated category/key reset API to `services/SettingsService.qml`, matching current JsonAdapter initial values.
2. Bind the service maps and reset API through `modules/lazerbar/TopBar.qml` into the existing `LazerSettingsOverlay.panel` inputs.
3. Forward defaults into every numeric Slider, converting canonical persisted units to display units where required.
4. Right-align split controls inside the Row content budget so the reserved reset slot never overlaps the Slider.
5. Make the Slider thumb full-height and brighter than the fill while preserving marker order, interaction, and `nubItem` identity.
6. Add focused tests for runtime injection, category-aware canonical reset, display-unit defaults, reset/Slider non-overlap, and full-height thumb visuals.
7. Run QML lint and all relevant test/smoke checks; fix any warnings or failures.
8. Capture the runtime, unit-boundary, and reset-slot contracts in the frontend quality guideline, commit with a conventional message, then archive the task.

## Risk Checks

- Compare service default maps field-for-field with the JsonAdapter declarations to avoid silently changing persisted defaults.
- Preserve reversed-range behavior by testing marker position through `Logic.sliderFraction()` rather than raw arithmetic.
- Ensure the reset API triggers the existing debounced save exactly through `SettingsService.save()`.
- Keep the host bindings per `TopBar` screen instance; do not move panel ownership or overlay lifecycle.
- Assert a reset-button click cannot emit Slider `valueModified`, especially at the Slider's maximum/right edge.
- Keep canonical timeout defaults in milliseconds while its Slider consumes seconds.

## Verification

- `python3 -m pytest -q`
- `qmllint` for modified QML and affected tests
- Relevant `qmltestrunner` settings suites (record the known silent runner limitation if it recurs)
- `git diff --check`
- `timeout 15s qs -p .`
