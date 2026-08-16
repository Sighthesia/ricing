# Settings Indicator And Alignment Design

## Boundaries

- Keep `LazerSettingsRow` as the single owner of the card, reset affordance, content padding, and presentation contract.
- Keep `LazerSettingsSlider` as the single owner of track, fill, default marker, active thumb, and pointer interaction.
- Keep `LazerSettingsChoice` label-owning, but derive its geometry from the same Row content region as full-width controls.

## Default Marker

The marker remains anchored to `defaultFraction` and remains non-interactive. Its layer moves above the active thumb so the default state is readable when the two positions coincide. Marker appearance is stateful:

- Modified value: compact vertical marker at the default position.
- Default value: a taller but still slightly shorter vertical line centered over the active thumb.

Only opacity, height, and layer order change; marker x-position and `nubItem` identity remain unchanged. A coordinated animation prevents a hard visual jump when the value crosses the default.

## Restore Action

The Row keeps a reserved right slot, but the visual button gets explicit horizontal breathing room and a rounded surface token. Its hit area remains above `contentHost` and the Slider. The Slider width is calculated from the content area after the reset slot is reserved, so geometry and input ownership agree.

## Choice And Slider Layout

- Choice width is bound to the Row content width and starts at the same `contentPadding` edge as standard controls.
- Split Slider control height follows the Row's available card height. The text block is positioned from the bottom of the card, with label above value and a small bottom inset.
- The Slider track fills the control region vertically; its existing radius, fill, thumb color, click, drag, and animation contracts remain.

## Compatibility

- Preserve `rowPresentation`, `fieldLabel`, `availableWidth`, `requestedWidth`, `nubItem`, reset callbacks, and all existing service/page bindings.
- Preserve canonical/display unit separation for notification timeout.
- Preserve fixed 570px settings surface and per-screen overlay ownership.

## Verification Strategy

Tests should inspect the exposed `defaultMarkerItem`, `nubItem`, `revertButtonItem`, `contentItem`, `trackItem`, and Choice header surface. Assertions must cover both modified and default states, z-order, geometry boundaries, and input isolation rather than only token values.
