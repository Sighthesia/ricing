# Implementation Plan: Settings Reset And Slider Default Visuals

## Ordered Steps

1. Start the Trellis task and re-check the post-archive diff and applicable frontend spec.
2. Inspect all settings page bindings and confirm `defaultValue`, `currentValue`, and `resetCallback` reach each modified row.
3. Fix `LazerSettingsRow` reset-slot ownership, explicit z-order, clipping, and right-side content reservation without changing reset semantics.
4. Fix `LazerSettingsSlider` explicit visual layering and accent-colored outer thumb while preserving the existing marker, inner light bar, `nubItem`, and interaction paths.
5. Add regression assertions for runtime-style row/slider visibility, geometry, z-order, state transitions, and page wiring.
6. Update `.trellis/spec/frontend/quality-guidelines.md` with the verified reset-slot and default-marker contracts.
7. Run all focused and full validation commands; fix warnings or failures.
8. Inspect the final diff, create a conventional commit, archive the task, and verify the worktree.

## Validation Commands

```bash
python3 -m pytest -q
qmllint modules/lazerbar/LazerSettingsRow.qml modules/lazerbar/LazerSettingsSlider.qml modules/lazerbar/LazerSettingsAppearance.qml modules/lazerbar/LazerSettingsBar.qml modules/lazerbar/LazerSettingsNotifications.qml tests/qml/tst_lazer_settings_controls.qml
git diff --check
timeout 15s qs -p .
```

Run the relevant QML test suites using the repository-supported runner. If the local runner exits silently, record that limitation and rely on the available test, lint, and smoke evidence without treating a silent exit as a passing assertion report.

## Risk Points

- QML sibling stacking can hide reset and marker visuals even when their properties are correct.
- A reset slot must not make inline Toggle labels collapse or change fixed surface geometry.
- Reversed Slider ranges must keep marker placement consistent with the active fill and thumb.
- Equality checks must use normalized values so a stepped current value does not leave a stale reset state.

## Rollback Point

The implementation is limited to Row, Slider, settings page wiring/tests, and frontend guidance. If validation fails, revert only the new task commit; do not alter previous archived task commits or user-owned files.
