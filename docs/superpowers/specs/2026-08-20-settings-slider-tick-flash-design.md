# Settings Slider Tick Flash Design

## Goal

Add a short visual flash to `LazerSettingsSlider` whenever a user-driven value change lands on a new discrete step. The feedback should make tick crossings perceptible without changing slider geometry, layout, or input behavior.

## Authority

The animation follows `osu.Game/Graphics/UserInterface/OsuAnimatedButton.cs`:

- A separate additive overlay receives the click flash.
- The flash colour is white at `0.3` opacity.
- The flash lasts `800ms`.
- The fade uses `Easing.OutQuint`.

The hover animation and press-scale animation from `OsuAnimatedButton` are unrelated and are not copied into the slider.

## Interaction

- A flash starts only when the normalized value changes to a different step because of user interaction.
- Pointer taps, pointer dragging, keyboard left/right movement, and reset-to-default all use the same trigger path.
- Repeating the current value does not retrigger the flash.
- A fast drag may retrigger the same overlay for each crossed step; each new step restarts the `800ms` decay from full flash strength.
- External value changes and initial construction do not flash unless they pass through the user interaction path.
- Disabled sliders do not flash.
- With `MotionTokens.reducedMotion`, no time-based flash animation runs and the overlay remains invisible.

## Visual Structure

Add one non-interactive overlay above the filled progress portion and below the thumb/default marker. It must:

- Match the existing filled-progress geometry and preserve the current input boundary.
- Use the slider's existing radius and dimensions.
- Use `LazerTheme.textPrimary` as the local equivalent of osu's white flash colour.
- Render as an additive-style highlight where supported by the existing QML stack.
- Animate only opacity; no layout, width, height, or position changes are allowed.

The overlay is not a new hit target and must not intercept hover, tap, or drag events.

When the flash starts, the complete slider visual receives a center-anchored scale bump to `1.015`, then returns to `1.0` over `220ms` with `Easing.OutQuint`. This uses a `Scale` transform only, so the slider's layout size and input boundary remain unchanged. Reduced motion keeps the scale at `1.0`.

## State And Triggering

`LazerSettingsSlider` owns a private flash state. `setValue()` remains the single normalized mutation entry point. After confirming that the next value differs from the current value, it emits `valueModified(next)` and starts the flash. Existing callers continue to receive the same signal and value semantics.

The flash restart must work while a previous fade is running. A restart sets the overlay to full strength before beginning a fresh `800ms` `OutQuint` fade to zero.

## Testing

Expose read-only test aliases for the overlay and its animation state, following the existing slider test seam. Add focused QML tests that verify:

- The overlay is present, non-interactive, and does not change the slider's geometry.
- A changed step starts the flash.
- Setting the current step again leaves the flash untouched.
- Reset-to-default uses the same flash path.
- Reduced motion keeps the overlay invisible and does not run its animation.

The existing QML test environment may fail before test execution if `qrc:/qs-blackhole` is unavailable. In that case, record the environment blocker separately from code or lint results.

## Non-Goals

- No new tick-mark visuals.
- No changes to slider step rounding or value persistence.
- No changes to hover focus glow, thumb motion, default marker, or row layout.
- No changes to osu itself.
