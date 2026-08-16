# Fix Settings Reset And Slider Default Visuals

## Goal

Make the restore-default affordance and Slider default-state visuals reliably visible in the running osu! settings panel. The fix must address actual ownership, stacking, clipping, and page wiring while preserving existing settings behavior.

## Background

- The previous implementation added a right-side reset slot, a Slider default marker, and a colored outer thumb, but the user cannot see these visuals in the running panel.
- Settings pages already pass `defaultValue`, `currentValue`, and `resetCallback` to `LazerSettingsRow`; the investigation must verify the full runtime geometry and visibility chain rather than duplicate those bindings.
- `LazerSettingsSlider` already exposes `nubItem`, supports normalized/reversed ranges, stepping, track clicks, drag scrubbing, keyboard input, and default reset.

## Requirements

### R1. Restore-default affordance

- `LazerSettingsRow` remains the single owner of the right-side reset affordance.
- The affordance must render above the card/content layers, stay inside the row bounds, and not be clipped or covered by the injected control.
- It is visible and interactive only when `defaultValue` exists and differs from `currentValue`.
- Activating it calls the existing `resetCallback`; after the value returns to default it fades out and releases its reserved visual state.
- Existing keyboard, focus, disabled, accessibility, and persistence behavior remain intact.

### R2. Slider default and handle visuals

- The active Slider thumb has a visible outer accent-colored body and retains its inner `4x20`, radius `2`, `#EBE5FF` light bar.
- The default marker is visible only when the current value differs from the default.
- The marker is `3x6`, radius `1.5`, color `#D5CCFF`, and is positioned by the normalized `defaultFraction`.
- Marker and thumb remain visible above the trough and fill, with deterministic overlap behavior at the same position.
- Existing `nubItem` identity and tooltip anchoring are preserved.

### R3. Regression coverage

- Tests cover page-to-row default wiring, reset-button visibility/geometry/layering, reset activation, marker visibility/position/layering, and thumb colors/dimensions.
- Tests cover normal and reversed Slider ranges and default/current equality transitions.

## Out Of Scope

- Settings models, default sources, persistence, save timing, and reset callback semantics.
- Slider or Toggle interaction contracts, including click, drag, keyboard, focus, disabled, and accessibility behavior.
- Tooltip arbitration, geometry, ownership, and multi-screen behavior.
- Fixed settings surface/sidebar/content geometry and global `osuPink`.
- New replacement controls such as `OsuSlider.qml` or `OsuToggle.qml`.

## Acceptance Criteria

- [ ] A modified setting shows a visible, clickable restore-default icon in the row's right-side slot.
- [ ] The restore icon is not hidden by the card, content host, clipping, or control z-order.
- [ ] Resetting restores the existing default and hides the affordance after the state becomes equal.
- [ ] Slider thumb outer body visibly uses `LazerTheme.settingsAccent`; inner light bar remains `4x20`, radius `2`, `#EBE5FF`.
- [ ] Slider default marker matches `3x6`, radius `1.5`, `#D5CCFF` and appears at the normalized default position only while modified.
- [ ] Marker and thumb remain above track/fill and expose stable testable geometry and z-order.
- [ ] Existing settings QML tests, Python tests, `qmllint`, `git diff --check`, and `timeout 15s qs -p .` pass; only the known environment D-Bus notification ownership warning is allowed.

## Technical Notes

- Inspect current declaration order and explicit `z` values before changing visuals; QML sibling order can place the reset item or marker below later content.
- Verify page bindings in `LazerSettingsAppearance.qml`, `LazerSettingsBar.qml`, and `LazerSettingsNotifications.qml` before changing `LazerSettingsRow` state logic.
- Use the existing `LazerSettingsLogic.sliderFraction()` for marker placement so reversed ranges remain correct.
- Add transitions for opacity, color, and position changes where the visual state is perceptible.

## Open Questions

- None blocking implementation.
