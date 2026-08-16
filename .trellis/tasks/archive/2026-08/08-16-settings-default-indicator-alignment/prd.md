# Tune settings default indicators and control alignment

## Goal

Correct the remaining settings-panel visual mismatches without changing settings behavior: make the default marker readable at the active thumb, give the restore action a clear button surface and spacing, align Choice controls with the shared card content edge, and make Slider geometry fill its Row card while keeping its value low in the card.

## Confirmed Current Behavior

- `LazerSettingsSlider.qml` renders `defaultMarker` at `z: 2` and the active `thumb` at `z: 3`; the marker is therefore hidden when both occupy the same position.
- The marker is hidden whenever the current value equals the default, so returning to the default does not leave a visible shorter default line.
- `LazerSettingsRow.qml` places the restore action in a 20px slot with a mostly transparent 20px item; its visible background is only a hover state and it sits close to the control/card content.
- `LazerSettingsChoice.qml` is label-owning and is injected through the Row, but its effective left edge must be locked to the same content baseline as the other controls.
- Split Row layout currently gives the Slider a 26px control height inside a taller card while the value text is part of the upper label flow; the value is not explicitly bottom-aligned.

## Requirements

### R1: Default marker layering and state

- Keep the marker at the default fraction using `Logic.sliderFraction()` and preserve reversed-range behavior.
- Render the marker above the active thumb (`defaultMarkerItem.z > nubItem.z`) so it remains visible when the Slider is exactly at its default.
- When the current value equals the default, keep the marker visible as a vertical line slightly shorter than the full-height thumb. When the value differs, retain the compact default-position marker used to show where reset will land.
- Preserve the marker's non-interactive behavior, color transition, position transition, and thumb tooltip identity.

### R2: Restore button affordance

- Keep the existing right-side reset slot and callback semantics.
- Give the restore action a visibly bounded rounded-rectangle surface, with stable padding from the Slider/card content and a hover/focus transition.
- Preserve z-order and pointer isolation: the button must remain above the Slider and clicking it must not emit Slider `valueModified` or move the Slider.

### R3: Choice alignment

- Make the Choice surface's left edge and usable width align with the shared Row content region used by text fields and other full-width controls.
- Preserve its embedded label/value layout, 52px height, menu bridge, keyboard handling, focus, and default/reset behavior.

### R4: Slider card geometry and value baseline

- Make the Slider control region occupy the Row's available card height rather than remain a visually short strip inside the card.
- Keep the track's rounded visual geometry and interaction surface coherent with the Row card; do not change the fixed settings panel dimensions.
- Place the split Slider label and current value as a deliberate lower-aligned text block, with the value closer to the card bottom than the vertical center.
- Preserve track click, continuous drag, stepped updates, reversed ranges, keyboard input, reset, tooltip, and accessibility.

### R5: Regression coverage

- Add QML assertions for marker layer/state transitions, restore button surface/spacing/input ownership, Choice left alignment, Slider/card height, and bottom-biased value placement.
- Preserve existing runtime default injection and notification timeout display-unit behavior.

## Out Of Scope

- Changing settings models, canonical defaults, persistence, save timing, or notification timeout units.
- Changing tooltip arbitration, source ownership, fixed panel/sidebar/content geometry, or unrelated shell controls.
- Replacing the existing `LazerSettingsRow`, `LazerSettingsSlider`, or `LazerSettingsChoice` APIs with standalone `Osu*` components.

## Acceptance Criteria

- [ ] A Slider with a defined default has a marker above its active thumb; the marker remains visible at the default and is visibly shorter than the thumb in that state.
- [ ] A modified Slider still shows its default-position marker and the marker animates without taking pointer input.
- [ ] The restore action has a visible rounded-rectangle background, stable gap from the control, and remains the top input owner; reset does not trigger Slider movement.
- [ ] Choice and standard full-width controls share the same left content edge within their Rows.
- [ ] Slider control height matches its Row card's control region, while the current value block is positioned near the card bottom rather than centered.
- [ ] Existing slider interactions, default reset, tooltip `nubItem`, keyboard/focus/accessibility, persistence, and fixed panel geometry remain intact.
- [ ] Relevant QML tests, `python3 -m pytest -q`, `qmllint`, `git diff --check`, and `timeout 15s qs -p .` pass; only the known environment D-Bus notification ownership warning is allowed.

## Technical Notes

- Relevant owners: `LazerSettingsSlider.qml` owns track/fill/marker/thumb layers; `LazerSettingsRow.qml` owns card, label, reset slot, and split geometry; `LazerSettingsChoice.qml` owns its embedded field surface.
- The existing `settingsSliderThumb` is the brighter accent token `#9A86FF`; global `osuPink` must remain unchanged.
- QML major declarations require concise English intent comments, and perceptible geometry/color/opacity changes require Behaviors or an explicit technical reason.
- No blocking open questions remain.
