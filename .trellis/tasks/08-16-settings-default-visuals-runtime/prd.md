# Diagnose runtime settings default visuals

## Goal

Make restore-default controls and Slider default markers work in the live shell, while keeping the Slider thumb full-height, visibly brighter than the fill, and isolated from the reset hit area.

## Background

- `LazerSettingsRow.qml` and `LazerSettingsSlider.qml` already implement the requested visual layers and their local state contracts.
- `LazerSettingsPanel.qml` accepts `appearanceDefaults`, `barDefaults`, `notificationDefaults`, and `settingsReset`, but `TopBar.qml` currently injects only settings objects and `saveCallback`.
- The live panel therefore receives empty default maps and no reset callback. Rows never satisfy `hasDefault`, and Sliders cannot receive a default value for their marker.
- Category pages forward defaults to Rows but omit `defaultValue` on numeric `LazerSettingsSlider` controls.

## Requirements

- R1: `SettingsService` owns immutable default maps for the appearance, bar, and notification categories, matching the persisted `JsonAdapter` initial values.
- R2: `SettingsService` exposes one category/key reset operation that writes the requested default into the correct persisted settings object and schedules the existing save path.
- R3: The live `TopBar.qml` settings overlay injects all three default maps and the reset operation into `LazerSettingsPanel`.
- R4: Every numeric Slider receives its default in the Slider's display unit. Persisted values remain canonical; notably, notification timeout stays in milliseconds while its Slider default is expressed in seconds.
- R5: A modified live setting shows its existing right-side reset control; activating it restores the service default, saves, and hides both reset control and Slider default marker when equality returns.
- R6: Split controls are right-aligned inside the Row content budget so the Slider neither paints over nor receives pointer input from the reset slot.
- R7: The Slider thumb is the same height as its 26px trough and uses the brighter `#9A86FF` shade of the `#765BFF` fill, without a separate inner light bar.
- R8: Existing input, focus, accessibility, tooltip `nubItem`, persistence, and fixed-panel contracts remain unchanged.

## Out Of Scope

- Redesigning Toggle, tooltip ownership, or fixed settings geometry beyond the targeted Slider thumb and Row reset-slot corrections.
- Changing persisted setting defaults, migration behavior, or the global `osuPink` token.
- Adding standalone `OsuSlider.qml` or `OsuToggle.qml` components.

## Acceptance Criteria

- [ ] Live overlay injection gives `LazerSettingsPanel` non-empty defaults and a callable reset function for all three categories.
- [ ] Resetting a modified Appearance, Bar, or Notification setting updates the correct `SettingsService` object and invokes the existing save debounce.
- [ ] Representative modified Toggle/Choice/Slider rows report `revertVisible: true`; equality with the default hides it again.
- [ ] Every numeric Appearance, Bar, and Notification Slider receives a defined display-unit `defaultValue`; a non-default Slider reports `defaultMarkerVisible: true` at `Logic.sliderFraction(from, to, defaultValue)`.
- [ ] Notification timeout resets to canonical `5000`ms while the Slider displays and compares the default as `5`s, never clamping the reset to its maximum.
- [ ] The Slider thumb is 26px high, uses `#9A86FF`, has no inner light bar, and remains the tooltip `nubItem`.
- [ ] The Slider's right edge does not cross the reset button's left edge; clicking reset emits no Slider `valueModified` event.
- [ ] Regression tests cover service/host injection, page Slider forwarding, and restore/marker state transitions.
- [ ] Relevant QML tests, `python3 -m pytest -q`, `qmllint`, `git diff --check`, and `timeout 15s qs -p .` pass, with only the known D-Bus notification ownership warning allowed.

## Technical Notes

- Runtime host evidence: `modules/lazerbar/TopBar.qml:106-113` injects settings objects/save only; `modules/lazerbar/LazerSettingsPanel.qml:14-17` declares but never receives default/reset inputs.
- Page evidence: numeric Sliders originally omitted `defaultValue`; notification timeout additionally crosses a persisted-ms/display-seconds unit boundary.
- No blocking open questions remain.
