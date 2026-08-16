# Fix settings toggle alignment and slider defaults

## Goal

Restore clear state feedback in the osu! settings panel: center Toggle capsules
inside their row backgrounds, make the Slider handle and default marker read as
one coherent control, and place reset actions where users expect them.

## Background

- `LazerSettingsRow` owns the shared setting card, row label, default comparison,
  and reset action.
- `LazerSettingsToggle` already exposes a `44x20` capsule and preserves its
  keyboard, focus, disabled, and accessibility contracts.
- `LazerSettingsSlider` already supports track taps, continuous drag updates,
  stepped values, keyboard input, default reset, and tooltip anchoring through
  `nubItem`.
- Current Row reset affordance is mounted in a fixed `20px` area at the left;
  the requested behavior is a right-side restore action for changed settings.

## Requirements

### R1. Toggle alignment

- Keep the Toggle capsule at `44x20`, with its background and state colors
  unchanged.
- Vertically center the capsule inside the setting card/inline row regardless of
  row height or neighboring label metrics.
- Preserve `checked`, `toggled`, keyboard activation, focus, disabled state,
  and accessibility behavior.

### R2. Slider handle and default marker

- Keep the Slider track height and width contract from the preceding restyle.
- Make the active handle a bright vertical capsule whose height equals the
  track height, with a radius that remains capsule-shaped.
- Add a distinct white vertical capsule marker at the Slider's default-value
  fraction. The marker is slightly shorter than the track and remains centered
  in the track.
- The active handle and default marker must coexist without changing value
  mapping, drag behavior, tap behavior, keyboard behavior, or tooltip source
  identity.

### R3. Right-side restore affordance

- For any Row with a provided `defaultValue` whose current value differs, show
  the restore-default button on the right side of the card.
- The restore button must be hidden when the value equals the default or no
  default is provided.
- Activating the button must use the existing `resetCallback` contract and
  update visibility after the value returns to its default.
- The affordance must remain keyboard accessible and not overlap Toggle labels,
  Choice controls, or Slider tracks.

### R4. Regression coverage

- Add QML assertions for Toggle vertical centering, Slider handle/default marker
  geometry and colors, and right-side restore placement.
- Preserve existing tests for settings persistence, value normalization,
  default/reset flow, tooltip `nubItem` identity, and fixed panel geometry.

## Out Of Scope

- Settings model shape, persistence format, save timing, or default-value source
  data.
- Tooltip arbitration, viewport tracking, or multi-screen ownership.
- Changes to the fixed `570px` surface, sidebar/content widths, or unrelated
  shell controls.
- Changing global `osuPink` or the established settings palette except for new
  Slider marker/handle tokens required by this task.

## Acceptance Criteria

- [ ] Toggle capsule is visibly and geometrically centered within its Row card.
- [ ] Slider active handle is a bright vertical capsule with track-height
      height and no hollow/legacy Nub appearance.
- [ ] Slider default marker is a centered white capsule line, slightly shorter
      than the track, at the exact default-value fraction.
- [ ] Modified Toggle, Slider, Choice, and other default-backed Rows show a
      non-overlapping restore button on the right; default-valued Rows hide it.
- [ ] Restore action continues to invoke `resetCallback` and clears itself once
      the current value matches the default.
- [ ] Existing control interaction, focus, accessibility, persistence, tooltip,
      and panel geometry contracts remain intact.
- [ ] Relevant QML tests, `qmllint`, Python tests, `git diff --check`, and the
      `qs -p .` smoke test pass, allowing only the known notification ownership
      warning from the environment.

## Technical Notes

- The Row should remain the single owner of the restore affordance; controls
  should not grow their own reset buttons.
- The Slider default marker should be derived from the same normalized fraction
  used by the active handle so reversed ranges and non-divisible step sizes stay
  visually consistent.
- Use settings-only theme tokens for any new marker/handle colors and retain
  transitions for visible color, position, opacity, and geometry changes.

## Open Questions

- None blocking planning; the user-provided visual requirements define the
  required geometry and ownership.
