# Implementation Plan: Settings System and Panel

## Execution Order

### Phase 1: Settings Service (foundation)

- [ ] 1.1 Create `services/SettingsService.qml`
  - Singleton with `FileView` + `JsonAdapter`
  - Define all MVP settings as nested `JsonObject` properties with defaults
  - Debounced save timer (500ms)
  - File watch + reload for external edits
  - Validation: service loads, saves, and reloads correctly

- [ ] 1.2 Register in `services/qmldir`
  - Add `singleton SettingsService 1.0 SettingsService.qml`

- [ ] 1.3 Wire existing services to read from SettingsService
  - `BarLayoutService.barHeight` → `SettingsService.bar.height`
  - `NotificationService` popup cap → `SettingsService.notifications.maxVisible`
  - `NotificationService.dndEnabled` → `SettingsService.notifications.dnd`
  - Validation: shell still works identically with default values

### Phase 2: Settings Panel UI

- [ ] 2.1 Create `modules/settings/` directory structure
  - `SettingsWindow.qml` — PanelWindow on overlay layer
  - `SettingsContent.qml` — search + flat scrollable list

- [ ] 2.2 Implement reusable setting controls
  - `controls/SettingToggle.qml` — label + description + Switch
  - `controls/SettingSlider.qml` — label + description + Slider + value display
  - `controls/SettingDropdown.qml` — label + description + ComboBox
  - `controls/SettingText.qml` — label + description + TextField
  - `controls/SettingFilePicker.qml` — label + description + TextField + browse button

- [ ] 2.3 Implement `SettingsContent.qml`
  - Search TextField at top
  - ScrollView with Column of category headers + setting rows
  - Filter logic: hide rows whose label doesn't match search text
  - All MVP settings wired to SettingsService properties

- [ ] 2.4 Implement `SettingsWindow.qml`
  - PanelWindow anchored below bar, overlay layer
  - Toggle visibility from bar widget
  - Escape to close

### Phase 3: Bar Integration

- [ ] 3.1 Add settings gear widget to bar widget registry
  - Clickable gear icon that toggles SettingsWindow visibility

- [ ] 3.2 Register SettingsWindow in `shell.qml`
  - Add `Settings.SettingsWindow {}` entry

### Phase 4: Validation

- [ ] 4.1 Verify persistence round-trip
  - Change settings → restart shell → settings preserved
- [ ] 4.2 Verify reactive updates
  - Change bar height in panel → bar immediately resizes
- [ ] 4.3 Verify external edit reload
  - Edit settings.json manually → shell picks up changes
- [ ] 4.4 Verify search filtering works

## Rollback Points

- After Phase 1: revert SettingsService + qmldir changes
- After Phase 2: revert modules/settings/ directory
- After Phase 3: revert shell.qml + bar widget changes

## Review Gates

- After Phase 1.3: confirm shell behavior is unchanged with default settings
- After Phase 2.3: confirm all controls render and bind correctly
- After Phase 3.2: full end-to-end test
