# Task 5 Verification Evidence

## Final-review follow-up

The bar two-layer hover harness now verifies producer icon validity end to end:

- `tst_bar_two_layer_popup.qml` waits for each non-empty identity `Image` to leave `Loading`/`Null` and asserts `Image.Ready`; it no longer treats any non-error state as sufficient.
- Volume, Brightness, Media, Notifications, and Tray producer intents are required to publish non-empty absolute icon URLs. Empty sources are only accepted through an explicit `allowEmptySource` argument, and no current actionable producer uses that exception.
- Tray normalization is exercised without a live system tray: a normal absolute icon remains unchanged, an empty icon returns the documented empty fallback, and an SNI source such as `/usr/share/icons/demo.png?path=/tmp/sni-icons` becomes `file:///tmp/sni-icons/demo.png`.
- The real Tray delegate's normalization path is shared through `normalizeTrayIconSource()`, so the SNI conversion and fallback assertions cover the same function used by the delegate and hover intent producer.

## Verification log

Run after the final test changes on 2026-08-28:

- `QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_bar_hover_logic.qml -o -,txt`: 14 passed, 0 failed.
- `QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_bar_popup_content.qml -o -,txt`: 17 passed, 0 failed.
- `QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_two_layer_popup.qml -o -,txt`: 8 passed, 0 failed.
- `qs -p tst_bar_two_layer_popup.qml`: 109 passed, 0 failed. This includes all five producer identity icons reaching `Image.Ready`, plus Tray SNI normalization and fallback checks.
- `qs -p tst_bar_popup_host.qml`: 23 passed, 0 failed.
- Targeted `qmllint` command from the Task 5 plan: no output.

- Full `qmllint` over all tracked QML files: no output.
- `qs -p shell.qml`: configuration loaded successfully. The shell remains a resident process and was stopped by the command timeout; output contained only pre-existing runtime warnings (notification-server contention, pixmap-reader thread warnings, and service subprocess exit code 15), with no QML load failure.
- `git diff --check`: clean.
