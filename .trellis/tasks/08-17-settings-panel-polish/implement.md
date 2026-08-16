# Implementation Plan

## Ordered Checklist

1. Update `LazerSettingsPanel.qml` so Sidebar and Content use stable visible opacity during panel open/close while their existing translation follows `progress`.
2. Adjust `LazerSettingsOverlay.qml` and `LazerSettingsSidebar.qml` lifecycle handling so closing does not clear navigation item opacity before the exit animation; preserve final cleanup and fresh-open stagger behavior.
3. Update `LazerSettingsSlider.qml` widths for the thumb and default marker, preserving fraction-centered positioning and interaction geometry.
4. Add Choice menu sizing state in `LazerSettingsChoice.qml`, make its TapHandler toggle open/close, and expose the reserved height required by its parent row.
5. Update `LazerSettingsRow.qml` choice geometry to include the active menu reservation without changing standard, split, or inline row contracts.
6. Update `LazerSettingsContent.qml` dropdown placement to anchor below the Choice header, recalculate after layout/scroll changes, and keep existing outside-click, keyboard, ownership, and focus behavior.
7. Extend `tests/qml/tst_lazer_settings_controls.qml` with regression checks for each observable behavior, using cross-parent coordinate mapping where overlay geometry is involved.

## Validation Commands

- `qmllint modules/lazerbar/LazerSettingsPanel.qml modules/lazerbar/LazerSettingsOverlay.qml modules/lazerbar/LazerSettingsSidebar.qml modules/lazerbar/LazerSettingsSlider.qml modules/lazerbar/LazerSettingsChoice.qml modules/lazerbar/LazerSettingsRow.qml modules/lazerbar/LazerSettingsContent.qml tests/qml/tst_lazer_settings_controls.qml`
- `python3 -m pytest -q`
- `git diff --check`
- `timeout 15s qs -p .`
- `qmltestrunner -platform offscreen -input tests/qml/tst_lazer_settings_controls.qml` when the runner produces usable output.

## Risk And Rollback Points

- After panel lifecycle changes, verify close interruption and reopen before touching dropdown layout.
- After Choice row reservation changes, verify all three category Flickables still calculate content height and scroll bounds.
- After overlay placement changes, verify outside click does not starve the Choice header and that Escape is consumed by the menu first.
- Roll back only the affected file-level change if a regression appears; do not revert unrelated worktree changes.

## Review Gate

- Keep the task in planning until the user approves the final summary.
- Only then run `python3 ./.trellis/scripts/task.py start settings-panel-polish` and begin product code edits.
