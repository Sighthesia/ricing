# Diagnose runtime settings default visuals

## Goal

Make the settings panel's existing restore-default affordance, Slider default marker, and accent Slider thumb appear in the live shell by completing the missing runtime defaults/reset contract.

## Background

- `LazerSettingsRow.qml` and `LazerSettingsSlider.qml` already implement the requested visual layers and their local state contracts.
- `LazerSettingsPanel.qml` accepts `appearanceDefaults`, `barDefaults`, `notificationDefaults`, and `settingsReset`, but `TopBar.qml` currently injects only settings objects and `saveCallback`.
- The live panel therefore receives empty default maps and no reset callback. Rows never satisfy `hasDefault`, and Sliders cannot receive a default value for their marker.
- Category pages forward defaults to Rows but omit `defaultValue` on numeric `LazerSettingsSlider` controls.

## Requirements

- R1: `SettingsService` owns immutable default maps for the appearance, bar, and notification categories, matching the persisted `JsonAdapter` initial values.
- R2: `SettingsService` exposes one category/key reset operation that writes the requested default into the correct persisted settings object and schedules the existing save path.
- R3: The live `TopBar.qml` settings overlay injects all three default maps and the reset operation into `LazerSettingsPanel`.
- R4: Every numeric Slider in Appearance and Bar receives the same `defaultOf(key)` value that its enclosing Row uses.
- R5: A modified live setting shows its existing right-side reset control; activating it restores the service default, saves, and hides both reset control and Slider default marker when equality returns.
- R6: Existing Slider thumb, marker, reset-slot geometry, input, focus, tooltip, persistence, and fixed-panel contracts remain unchanged except where needed to wire runtime data.

## Out Of Scope

- Redesigning Slider, Toggle, Row, theme tokens, tooltip ownership, or fixed settings geometry.
- Changing persisted setting defaults, migration behavior, or the global `osuPink` token.
- Adding standalone `OsuSlider.qml` or `OsuToggle.qml` components.

## Acceptance Criteria

- [ ] Live overlay injection gives `LazerSettingsPanel` non-empty defaults and a callable reset function for all three categories.
- [ ] Resetting a modified Appearance, Bar, or Notification setting updates the correct `SettingsService` object and invokes the existing save debounce.
- [ ] Representative modified Toggle/Choice/Slider rows report `revertVisible: true`; equality with the default hides it again.
- [ ] Every numeric Appearance and Bar Slider receives a defined `defaultValue`; a non-default Slider reports `defaultMarkerVisible: true` at `Logic.sliderFraction(from, to, defaultValue)`.
- [ ] Existing component visual contracts remain: accent outer thumb, light inner bar, marker above fill, and reset control above row content.
- [ ] Regression tests cover service/host injection, page Slider forwarding, and restore/marker state transitions.
- [ ] Relevant QML tests, `python3 -m pytest -q`, `qmllint`, `git diff --check`, and `timeout 15s qs -p .` pass, with only the known D-Bus notification ownership warning allowed.

## Technical Notes

- Runtime host evidence: `modules/lazerbar/TopBar.qml:106-113` injects settings objects/save only; `modules/lazerbar/LazerSettingsPanel.qml:14-17` declares but never receives default/reset inputs.
- Page evidence: `LazerSettingsAppearance.qml` and `LazerSettingsBar.qml` pass defaults to Rows but their `LazerSettingsSlider` instances omit `defaultValue`.
- No blocking open questions remain.
