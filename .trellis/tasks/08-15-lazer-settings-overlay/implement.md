# Implementation Plan: Lazer Settings Overlay

## Ordered Checklist

1. Inspect current `TopBar`, zone, service, `qmldir`, and test contracts before each integration change.
2. Complete settings/music button integration and add `OsuTopBarButton`/music overlay contracts.
3. Connect live Bar settings to top-bar geometry and validate clamping/exclusive-zone behavior.
4. Connect notification timeout and position to `NotificationService` and per-screen notification hosts.
5. Connect Appearance settings to `ColorService`, theme tokens, background, and panel consumers.
6. Run the focused QML test for each completed task in a separate process; repeat lifecycle tests to catch timing flakiness.
7. Run the full relevant QML suite, `python -m unittest discover -s scripts/tests -v`, `qs -p .`, and `git diff --check`.
8. Review the diff for binding loops, deprecated `PanelWindow` sizing, missing QML declaration comments, and unrelated changes.
9. Update project specs if a reusable QML/testing convention was discovered.
10. Commit completed changes with a conventional commit message.

## Validation Commands

```sh
/usr/lib/qt6/bin/qmltestrunner -input tests/qml/<focused-test>.qml -o -,txt -v1
/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_lazer_settings_overlay.qml -o -,txt -v1
python -m unittest discover -s scripts/tests -v
timeout 10s qs -p .
git diff --check
```

## Review Gates

- Do not start `task.py start` until this plan and the PRD have been approved.
- After each QML edit, focused tests must pass without WARN/ERROR lines.
- Full regression must run sequentially because parallel Qt processes can compete for global focus/event state.
- Only intended source, test, and task-artifact files may be included in the final commit.
