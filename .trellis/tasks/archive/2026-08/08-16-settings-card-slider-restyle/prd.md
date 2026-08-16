# Rebuild Settings Cards And Slider Controls

## Goal

Restore the visual weight of the osu! settings panel by giving every setting row a
consistent card surface and by making the numeric slider read and feel like the
specified osu! control. The change must preserve the existing settings data flow,
focus behavior, tooltip ownership, and persistence callbacks.

## Background

- `LazerSettingsRow.qml` currently renders a transparent row and owns the label,
  search visibility, revert affordance, and description tooltip.
- `LazerSettingsSlider.qml` already owns normalization, reverse ranges, step
  snapping, pointer taps, horizontal dragging, keyboard changes, value tooltips,
  and default reset. Its visual contract needs to become the requested thick
  track with an embedded light thumb.
- `LazerSettingsToggle.qml` already owns the 44x20 interaction capsule and
  keyboard/accessibility behavior; its surrounding setting row needs the shared
  card surface rather than a second toggle-specific card.
- The current Row presentation contracts are `standard`, `inline`, `split`, and
  `choice`. They must remain compatible with Choice and TextField controls.

## Requirements

### R1. Shared setting card

- Every visible Toggle, Slider, and Dropdown setting is hosted by a consistent
  Row card surface.
- The card uses `#221F2B`, radius `6`, full available width, and 12px visual
  content padding. The existing 20px revert zone remains available inside the
  row when a setting has a non-default value.
- Hovering the row transitions the card to `#2A2636` over approximately 150ms.
- The card is owned by `LazerSettingsRow`; individual controls must not add a
  duplicate outer card.
- Search filtering, disabled opacity, default reset, tooltip source identity,
  and Row presentation contracts continue to work.

### R2. Slider visual and interaction fidelity

- `LazerSettingsSlider` uses a left label/value region and a right track region
  in the existing `split` Row contract.
- The label uses 13px text and the current value uses 14px bold white text.
- The track is approximately 200-240px wide where space permits, 24-26px high,
  radius 4, with base `#2E2A3A` and fill `#765BFF`.
- The thumb is embedded in the track at the fill edge, 6x20px, radius 3,
  color `#EBE5FF`; it must not be a hollow or detached Nub.
- Clicking the track positions the value; horizontal dragging updates the value
  continuously and respects range direction and step size.
- Existing keyboard, focus ring, value tooltip anchored to `nubItem`, reduced
  motion, and double-click default reset behavior remain intact.

### R3. Toggle compatibility

- `LazerSettingsToggle` remains a compact 44x20 control with checked accent and
  visible unchecked state.
- Its existing `checked`, `toggled`, keyboard, focus, disabled, accessibility,
  and row width contracts remain unchanged.

### R4. Regression coverage

- Add assertions for Row card colors/radius/width and hover transition state.
- Add assertions for Slider track, fill, thumb geometry/colors, split layout,
  direct click, drag, and `nubItem` identity.
- Keep Choice, TextField, panel geometry, persistence, dropdown, tooltip,
  Escape, and sidebar behavior covered by the existing suites.

## Out Of Scope

- Settings models, defaults, save timing, persistence schema, or service APIs.
- Global `LazerTheme.osuPink`, fixed 570px panel geometry, sidebar widths, or
  per-screen overlay ownership.
- Tooltip arbitration, measurement, viewport mapping, or lifecycle semantics.
- Replacing the project's `LazerSettings*` component names with standalone
  `OsuSlider.qml` or `OsuToggle.qml` files.
- Unrelated shell controls or page-specific setting values.

## Acceptance Criteria

- [ ] Each visible settings Row has one `#221F2B` radius-6 card with full width
      and 12px content inset; no control has a duplicate card.
- [ ] Row hover visibly transitions the card toward `#2A2636` without changing
      persistence or tooltip ownership.
- [ ] Slider track is a thick rounded bar with `#2E2A3A` base, `#765BFF` fill,
      and an embedded `6x20` `#EBE5FF` thumb at the fill edge.
- [ ] Slider labels and values use the requested 13px/14px hierarchy and the
      split row remains usable at the fixed content width.
- [ ] Track click and horizontal drag update stepped values in real time,
      including reversed ranges; keyboard and default reset still work.
- [ ] Toggle remains visible and interactive at `44x20` with unchanged API and
      accessibility behavior.
- [ ] QML tests, Python tests, `qmllint`, `git diff --check`, and `qs -p .` pass;
      only the known environmental notification ownership warning is allowed.

## Technical Notes

- Use settings-only visual tokens where a value is shared; do not alter global
  shell colors.
- Keep scene graph animation on inner QML items. Do not resize the compositor
  surface per frame.
- Follow the frontend quality contracts for fixed settings geometry, per-screen
  ownership, tooltip `nubItem` identity, and major QML declaration comments.

## Open Questions

- None blocking. The provided pixel values and the existing project contracts
  determine the implementation choices.
