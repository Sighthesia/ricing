# Settings And Common Control Click Flash

 ## Goal

 Extend the verified osu-style click flash from the settings slider to the high-value settings and common button controls without changing their existing geometry, input ownership, or state transitions.

 ## Scope

 Add click flash feedback to:

 - `LazerSettingsToggle`
 - `LazerSettingsChoice` header and selected option
 - `LazerSettingsRow` restore-default button
 - `IconButton`
 - `MusicControlButton`
 - `MenuItem`

 Do not add this feedback to text-field focus, search clearing, settings navigation, fullscreen navigation, or close actions in this change.

 ## Visual Contract

 Each component owns its overlay and trigger because the controls have different surfaces and delegate lifetimes. Do not add a shared QML visual component for this pass.

 Use shared `MotionTokens` values:

 - white overlay equivalent: `0.3` opacity
 - fade duration: `800ms`
 - easing: `Easing.OutQuint`

 The overlay is visual-only. It must not receive pointer events, change layout dimensions, or alter the control's hit target. Existing hover, press-scale, focus, selection, and menu animations remain active.

 ## Trigger Rules

 Trigger only after the user action is accepted by the control:

 - Toggle: after `activate()` accepts the action and emits `toggled`.
 - Choice header: after opening the menu; selecting a changed value flashes the option and header once for the value commit.
 - Restore default: after `activateReset()` invokes `resetCallback`.
 - `IconButton`: after pointer or keyboard activation reaches `clicked`.
 - `MusicControlButton`: after pointer or keyboard activation reaches `clicked`.
 - `MenuItem`: after pointer or keyboard activation reaches `triggered`.

 Rejected, disabled, empty, duplicate, or purely focus-changing actions do not flash. Pointer and keyboard activation must share the same activation path whenever the component already has one.

 ## Reduced Motion

 When `MotionTokens.reducedMotion` is true, keep the flash opacity at `0`, stop the flash animation, and preserve each component's existing reduced-motion behavior. The flash must never remain visible after the mode changes.

 ## Component Details

 - Toggle: overlay the complete capsule, below any required state surface details and above the capsule paint; keep its rounded detail geometry.
 - Choice: overlay the header surface and option delegate independently. Opening the header flashes the header; choosing a different option flashes the chosen delegate and commits the value once. The option overlay must remain inside the delegate and not cover neighboring options.
 - Restore default: overlay the visible reset surface only; retain the existing pseudo-crescent z-order and slide-back animation.
 - `IconButton`: overlay the full icon-button surface, including its circular detail geometry; keep the existing press scale and keyboard activation behavior.
 - `MusicControlButton`: overlay the full transport button; preserve outlined/active variants and existing keyboard callbacks.
 - `MenuItem`: overlay the full menu row; preserve current-state color and hover behavior.

 ## Testing

 Add focused QML assertions for every component:

 - flash starts only for accepted actions
 - disabled or no-op actions do not flash
 - opacity, duration, easing, and overlay geometry are correct
 - overlay does not own input
 - keyboard and pointer paths use the same feedback
 - reduced motion stops and hides the flash

 Continue running `qmllint`, `pytest -q`, and `qs -p .`. The focused QML suite should be attempted; if the environment still lacks `qrc:/qs-blackhole`, record that as an infrastructure blocker rather than changing production behavior.
