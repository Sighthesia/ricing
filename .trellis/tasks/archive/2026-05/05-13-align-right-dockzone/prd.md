# Align right dockzone with center background and ears

## Goal

Make the right dock zone use the same attached-island background language as the center dock zone, while changing its silhouette so the overall body is a rectangle with only the bottom-left corner rounded and with edge-attached ears positioned to match the requested orientation.

## Confirmed Facts

- `modules/bar/BarSection.qml` renders all three sections through the shared `modules/bar/BarDockZoneBackground.qml`.
- `modules/bar/BarContent.qml` anchors the right section flush to `parent.right`, so edge attachment should be solved inside the shared background geometry rather than by moving the section container.
- `modules/bar/BarDockZoneBackground.qml` currently has three geometry modes: `center` with two top ears, `left` with one side ear, and `right` with one mirrored side ear.
- The current right-side branch does not share the center body's corner treatment: the body still rounds both bottom corners, and the ear sits on the lower-left side rather than behaving like a rotated center-right ear.
- The requested change is localized to the bar QML surface shape and does not require layout-model or service-layer changes.

## Requirements

- Keep using the shared `BarDockZoneBackground.qml` component instead of introducing a duplicate right-side background component.
- Make the right dock zone background fill style match the center dock zone background style.
- Change the right dock zone main body so it reads as a rectangle with only the bottom-left corner rounded.
- Make the right dock zone left ear match the center dock zone left ear implementation style.
- Change the right dock zone right ear so it follows the center-right ear drawing logic rotated clockwise by 90 degrees.
- Position the rotated right ear so its top edge tightly meets the rectangle bottom edge.
- Position the rotated right ear so its right edge tightly meets the screen right edge.
- Preserve current center dock zone behavior.
- Avoid unrelated layout or widget behavior changes.

## Acceptance Criteria

- [ ] Right dock zone uses the same background fill/border treatment as the center dock zone.
- [ ] Right dock zone body has only one rounded corner: bottom-left.
- [ ] Right dock zone left ear visually matches the center-left ear style.
- [ ] Right dock zone right ear visually matches the center-right ear style after a clockwise 90 degree rotation.
- [ ] Rotated right ear attaches with its top flush to the body bottom edge.
- [ ] Rotated right ear attaches with its right edge flush to the screen edge.
- [ ] Left and center dock zones do not regress.
- [ ] Affected QML files pass `qmllint`.

## Out of Scope

- Reworking widget layout, spacing, or section anchoring policy.
- Changing bar services or layout persistence.
- Redesigning the center or left dock zone beyond any minimal shared-logic adjustment required to keep the component coherent.

## Open Questions

- None currently. The user request is specific enough to implement as a lightweight PRD-only task.
