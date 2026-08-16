# Design: Settings Cards And Slider Controls

## Architecture

- `LazerSettingsRow.qml` owns one full-width card surface behind the existing
  revert zone, label, tooltip source, and injected control.
- The card is an inner scene-graph item. The fixed Settings surface and its
  sidebar/content geometry remain unchanged.
- `LazerSettingsSlider.qml` remains the owner of value normalization and input
  handling. Its `split` presentation exposes a left label/value region and a
  right track region.
- `LazerSettingsToggle.qml` remains a direct compact control. It is not wrapped
  in a second card and keeps its current signal, focus, accessibility, and
  width contracts.

## Visual Tokens

Add settings-only tokens in `LazerTheme.qml` where values are shared:

- Card surface: `#221F2B`
- Card hover surface: `#2A2636`
- Slider track: `#2E2A3A`
- Slider fill: existing settings accent `#765BFF`
- Slider thumb: `#EBE5FF`

Do not change `osuPink` or unrelated shell tokens.

## Row Card Contract

- The card fills the Row's available width and uses 12px visual inset and 6px
  radius.
- Card hover is derived from the Row hover state and transitions color over the
  existing fast motion duration, approximately 150ms.
- The current 20px revert zone remains inside the Row. The card must not cover
  or steal its interaction ownership.
- `standard`, `choice`, `inline`, and `split` control layout contracts remain
  intact. Only the shared visual background and padding ownership change.

## Slider Contract

- Keep `rowPresentation: "split"`, `nubItem`, tooltip requests, tap handling,
  drag handling, keyboard methods, reduced-motion behavior, and default reset.
- Use a 200-240px target track width where the fixed content column allows it,
  clamped to the available right region.
- Use a 24-26px track height with radius 4, a 6x20 radius-3 thumb, and a fill
  that ends at the thumb's center/edge according to the existing normalized
  fraction.
- Keep live stepped updates through the existing `setValue` path rather than
  introducing a second value model.
- The Row's split label/value presentation remains the source of the 13px label
  and 14px bold current-value hierarchy.

## Compatibility And Rollback

- No settings model, persistence, save callback, tooltip ownership, or panel
  geometry changes are required.
- If the card causes clipping or control overlap, first adjust the inner Row
  content bounds; do not resize the layer-shell surface.
- Rollback is limited to the Row card/token changes and Slider visual geometry;
  existing interaction functions can remain unchanged.

## Verification

- Add focused control assertions for card geometry/colors, hover state, Slider
  geometry/colors, split layout, tap/drag updates, and `nubItem` identity.
- Run existing Choice, TextField, panel, dropdown, tooltip, and persistence
  suites to catch presentation-contract regressions.
