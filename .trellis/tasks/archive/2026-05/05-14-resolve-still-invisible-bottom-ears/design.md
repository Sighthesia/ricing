# Design: Dedicated Bottom Ear Overlay Windows

## Architecture

Keep the existing `modules/bar/BarWindow.qml` as the main per-screen bar surface with height fixed to `Services.BarLayoutService.barHeight`.

Add a separate per-screen overlay module under `modules/bar/` that creates transparent `PanelWindow` instances dedicated to the left and right bottom ears.

Planned structure:

```text
shell.qml
├── Bar.BarWindow                # main bar body, unchanged height
├── Bar.BarBottomEarWindow       # new overlay windows for bottom ears
└── Bar.WidgetPickerWindow
```

## Boundaries

- `BarWindow.qml`
  - Remains the only window that owns the main bar body and section contents.
  - Height stays equal to `Services.BarLayoutService.barHeight`.

- `BarDockZoneBackground.qml`
  - Keeps top-ear and body drawing logic.
  - Stops being responsible for the runtime visibility of the bottom ears.

- `BarBottomEarWindow.qml` (new)
  - Owns one transparent overlay `PanelWindow` per screen for the left bottom ear and one for the right bottom ear.
  - Uses the same fill/border colors and ear radius as the current dock background language.
  - Anchors windows to the top edge with a top margin so the ear sits just below the main bar body.

## Geometry Contracts

- Left overlay ear window:
  - anchored `top + left`
  - width = `earRadius`
  - height = `earRadius`
  - top margin = `Services.BarLayoutService.barHeight - earRadius`

- Right overlay ear window:
  - anchored `top + right`
  - width = `earRadius`
  - height = `earRadius`
  - top margin = `Services.BarLayoutService.barHeight - earRadius`

- Main bar window:
  - remains `implicitHeight: Services.BarLayoutService.barHeight`

This preserves the current body height while letting the overlay ear windows occupy space outside the main bar surface.

## Rendering Strategy

The bottom ears should be drawn natively in their own overlay window canvas, not rotated from the top-ear path at runtime.

- left ear path: bottom-left attached ear with inward top-right cut
- right ear path: bottom-right attached ear with inward top-left cut

This avoids the transform issues already observed in the single-window approach.

## Visibility Rules

Recommended minimal behavior:

- show the left bottom ear only when the left section has content
- show the right bottom ear only when the right section has content

This keeps the overlay windows aligned with actual dockzone presence and avoids floating decorative ears when a side section is empty.

## Compatibility

- No service-layer change is required.
- `WidgetPickerWindow.qml` already proves that separate bar-owned windows per screen are accepted in this repo.
- `shell.qml` already composes top-level reusable surfaces, so adding one more bar-owned overlay module stays aligned with current structure.

## Trade-offs

- Benefit: the ears become independently visible without forcing the main bar window to grow.
- Cost: one additional overlay layer per side per screen increases structural complexity.
- Benefit: the main bar body and content layout remain untouched.
- Cost: duplicated ear drawing logic may exist unless a small reusable ear painter is introduced.

## Rollback Shape

Rollback is simple:

- remove the new bottom-ear overlay module from `shell.qml`
- delete the new overlay file(s)
- restore any bottom-ear visibility conditions in `BarDockZoneBackground.qml` if needed
