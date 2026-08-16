# Design: Toggle Alignment And Slider Default Visuals

## Architecture

`LazerSettingsRow` remains the visual and behavioral owner of the shared card,
label, and restore affordance. The Toggle and Slider remain focused controls:
they expose their existing row contracts and signals, but do not create reset
buttons or alter settings persistence.

## Row Layout

- Keep the existing `standard`, `inline`, `split`, and `choice` presentation
  contracts.
- Make the right-side restore button part of the Row's content coordinate space.
- Reserve a small right-side restore slot before calculating control width, so a
  changed Row cannot place the button over a Slider track or Toggle capsule.
- For inline Toggle rows, center the control host vertically from the Row/card
  bounds rather than relying on label metrics alone.
- Preserve the existing left content padding and card dimensions unless the
  right-side slot requires a bounded subtraction from the available width.
- Keep the existing `revertButtonItem` test/accessibility surface while moving
  its geometry to the right.

## Slider Visuals

- Keep `displayFraction` and `targetFraction` as the single source of truth for
  handle and default marker positioning.
- Render the active handle as a bright vertical capsule centered in the track.
  Its height equals `trackItem.height`, and its width/radius remain small enough
  to read as a vertical pill.
- Render a separate default marker only when `defaultValue` is defined. Derive
  its fraction with `Logic.sliderFraction(from, to, normalized(defaultValue))`.
  The marker is centered vertically, slightly shorter than the track, and drawn
  below the active handle so the active value remains visually dominant.
- Keep the marker non-interactive. The existing track and drag handlers continue
  to own pointer input, and `nubItem` continues to reference the active handle.
- Add settings-only tokens for the brighter handle and white default marker if
  the existing palette cannot distinguish them reliably.

## Toggle Visuals

- Retain the direct `44x20` capsule implementation and existing state/focus
  transitions.
- Correct only the parent Row's vertical placement and width reservation; do
  not introduce a second background or moving thumb.

## Default/Reset Flow

- `revertVisible` remains the derived condition
  `hasDefault && !isDefault`.
- `activateReset()` continues to call the supplied `resetCallback`.
- The Row's right-side button remains enabled only when the Row is enabled and
  the value differs from its default.
- Pages continue to provide their existing defaults/current values and reset
  callback; no model or persistence changes are needed.

## Compatibility And Risks

- Reversed Slider ranges must position the marker using the same fraction helper
  as the handle.
- A default value outside the Slider range must be normalized before deriving
  the marker fraction.
- Narrow Rows must clamp available control width after reserving the restore
  slot rather than allowing negative geometry.
- The restore button remains keyboard accessible and must not steal pointer
  events from the active control outside its own slot.

## Verification Strategy

- Add focused control tests for centering, marker position/geometry/colors,
  right-side restore placement, and reset visibility transitions.
- Keep page-level default/reset tests unchanged and passing.
- Run `qmllint`, all relevant QML tests, Python tests, `git diff --check`, and
  `timeout 15s qs -p .`.
