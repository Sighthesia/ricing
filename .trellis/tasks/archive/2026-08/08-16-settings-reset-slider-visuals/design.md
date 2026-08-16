# Design: Settings Reset And Slider Default Visuals

## Architecture

`LazerSettingsRow` owns the shared card, label, content budget, and restore-default affordance. Injected controls retain their existing presentation contracts. `LazerSettingsSlider` owns the trough, fill, active thumb, and default marker. Page components remain responsible for supplying the existing default/current/reset values.

## Ownership And Layering

- Keep the card as the lowest visual sibling.
- Keep the injected content below the reset affordance and reserve the right-side reset slot from its width budget.
- Give the reset affordance an explicit layer above content and ensure the row does not clip it unintentionally.
- In Slider, order the trough first, fill second, default marker third, and active thumb last; use explicit `z` values where necessary so the marker and colored thumb cannot disappear behind earlier layers.

## Reset Contract

The existing state contract remains authoritative:

```qml
defaultValue: root.defaultOf("key")
currentValue: root.settingsObject ? root.settingsObject.key : null
resetCallback: function() { root.resetKey("key") }
```

`revertVisible` is true only when a default exists and `currentValue` is not equal to it. The reset item calls `activateReset()` and does not mutate settings directly.

## Slider Contract

- `defaultFraction` is calculated through `Logic.sliderFraction(from, to, defaultValue)`.
- `defaultMarkerVisible` compares normalized current and default values.
- The marker is non-interactive and anchored to the track's coordinate space.
- `nubItem` continues to reference the active thumb for tooltip ownership and follow behavior.
- The outer thumb uses the settings accent color; the inner light bar remains the high-contrast visual core.

## Compatibility And Rollback

No model or persistence migration is required. If runtime verification shows the reset item collides with a narrow row, reduce only the content budget through the existing reserved slot; do not remove the affordance or change settings persistence. If marker overlap at an endpoint is visually ambiguous, preserve both layers and adjust only explicit z-order or marker position clamping.

## Verification Design

- Component tests assert visibility, bounds, z-order, colors, dimensions, and reset behavior.
- Page-level fixture coverage confirms real settings pages pass all three reset properties.
- Slider tests cover modified/default transitions, normal/reversed ranges, marker fraction, and active thumb layering.
- Run the repository's QML/Python/lint/smoke checks after implementation.
