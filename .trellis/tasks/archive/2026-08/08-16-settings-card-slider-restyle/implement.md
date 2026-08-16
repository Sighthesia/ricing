# Implementation Plan: Settings Cards And Slider Controls

## Ordered Steps

1. Add settings-only card, hover, track, and thumb tokens to `LazerTheme.qml`.
2. Update `LazerSettingsRow.qml` to render one full-width 6px-radius card with
   12px inset, hover transition, and preserved revert/tooltip ownership.
3. Update `LazerSettingsSlider.qml` visual geometry and split-region sizing to
   the thick track, purple fill, embedded `6x20` light thumb, and requested
   label/value hierarchy while preserving all existing input methods.
4. Verify `LazerSettingsToggle.qml` remains a direct `44x20` control without a
   duplicate card and preserve its current API.
5. Add or update QML regression assertions for Row cards, Slider visuals and
   interactions, Toggle compatibility, and existing presentation contracts.
6. Run static checks, Python tests, QML suites, and the full shell smoke test.
7. Update frontend quality guidance if the final implementation establishes a
   reusable card/slider contract, then commit and archive the Trellis task.

## Risk Points

- Row inner padding can reduce the split Slider region below the usable width;
  clamp the track without changing the fixed content width.
- A card background must not become an input catcher over the revert zone or
  alter tooltip source identity.
- Track geometry changes must continue using the existing normalized mapping so
  reversed ranges and step snapping stay correct.
- Any QML test runner failure must be distinguished from assertion failures; the
  known environment may exit silently without a report.

## Validation Commands

```text
python3 -m pytest -q
qmllint <modified QML files> <modified QML tests>
qmltestrunner -platform offscreen -input tests/qml/tst_lazer_settings_controls.qml
git diff --check
```

The `qs` smoke test must reach `Configuration Loaded`. Only the known existing
`org.freedesktop.Notifications` ownership warning is allowed.
