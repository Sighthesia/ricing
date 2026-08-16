# Implementation Plan: Refine osu settings panel details

## Ordered Checklist

1. Add settings-only theme tokens for search background, toggle off-state, and
   choice height/radius without changing global `osuPink`.
2. Reorder `LazerSettingsContent` chrome so search is first and the single
   Content-owned category title follows it. Apply exact search styling and
   preserve query/clear/focus behavior.
3. Remove duplicate title delegates from Appearance, Notifications, and Bar
   pages without changing their rows, scroll model, or settings persistence.
4. Add the additive Choice label/presentation contract and Row bindings; hide
   only the external label for the embedded Choice layout.
5. Restyle Choice to the 52px labeled surface and preserve dropdown bridge,
   keyboard, accessibility, focus, and disabled behavior.
6. Change Toggle unchecked color to the settings off token while retaining its
   checked, interaction, and accessibility contracts.
7. Remove selected nav background and update indicator dimensions and selected
   or inactive colors, retaining hover/focus/collapse/stagger transitions.
8. Update focused QML tests for exact dimensions, colors, title ownership,
   label injection, navigation, and preserved close behavior.
9. Run all required checks and fix every introduced WARN/ERROR before commit.

## Risky Files

- `modules/lazerbar/LazerSettingsContent.qml`: layout order and search focus.
- `modules/lazerbar/LazerSettingsRow.qml`: injected child bindings and height.
- `modules/lazerbar/LazerSettingsChoice.qml`: menu source identity and focus.
- `modules/lazerbar/LazerSettingsAppearance.qml`:
  `LazerSettingsNotifications.qml`, `LazerSettingsBar.qml`: title removal.
- `modules/lazerbar/LazerSettingsNavItem.qml`: selection indicator hit geometry.
- `modules/lazerbar/LazerTheme.qml`: settings-only token compatibility.

## Validation Commands

```bash
python3 -m pytest -q
qmltestrunner -input tests/qml/tst_lazer_settings_logic.qml
qmltestrunner -input tests/qml/tst_lazer_settings_controls.qml
qmltestrunner -input tests/qml/tst_lazer_settings_pages.qml
qmltestrunner -input tests/qml/tst_lazer_settings_panel.qml
qmltestrunner -input tests/qml/tst_lazer_settings_overlay.qml
qmltestrunner -input tests/qml/tst_smoke_settings.qml
qmllint modules/lazerbar/LazerSettings*.qml modules/lazerbar/SettingsOverlayBridge.qml modules/lazerbar/LazerTheme.qml
git diff --check
timeout 15s qs -p .
```

The shell smoke test is expected to end with timeout code `124` because the
Quickshell process is resident; it must first print `Configuration Loaded`.
The known D-Bus notification ownership warning is acceptable only when caused
by another existing service and no QML WARN/ERROR is introduced.

## Pre-Commit Review

- Read the final diff for accidental changes to persistence, focus, or global
  theme values.
- Confirm task manifests contain real entries and no `_example` rows.
- Commit with a conventional message, then archive with
  `python3 .trellis/scripts/task.py archive 08-16-osu-settings-panel-detail-tuning`.
