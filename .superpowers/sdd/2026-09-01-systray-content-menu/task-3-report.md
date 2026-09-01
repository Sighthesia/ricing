# Task 3 Report: Wire Payload Handle and Replace Open / Menu

## Scope

- Added `hasMenu` and `menuHandle` to tray hover intent payloads.
- Replaced popup-level `Open` / `Menu` controls with `BarTrayMenuContent`.
- Routed native menu dismiss requests through `BarPopupHost.dismissImmediately()`.
- Preserved left/right click handlers on the tray icon widget delegates.
- Rewrote popup-content and two-layer harness assertions for the native menu contract.

## RED

Command:

```text
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_bar_popup_content.qml -o -,txt
```

Result before production wiring: **17 passed, 2 failed**.

- `test_trayRendersNativeMenuRows`: `trayMenuRoot` was not found.
- `test_trayEmptyStateWithoutHandle`: `trayEmptyState` was not found.

This confirms the rewritten tests failed against the old `Open` / `Menu` implementation.

## GREEN

### QtTest

Command:

```text
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_bar_popup_content.qml -o -,txt
```

Result: **19 passed, 0 failed, 0 skipped, 0 blacklisted**.

### Quickshell harness

Command:

```text
qs -p tst_bar_two_layer_popup.qml
```

Result: **Totals: 112 passed, 0 failed**.

The harness confirmed the native tray menu content exists and the old popup
TapHandlers are absent. Primary widget click and wheel-path checks also passed.

The harness emitted pre-existing environment/runtime warnings for deprecated
`ProxyFloatingWindow` sizing, an already-registered notification service, and
cross-thread pixmap-reader QObject creation. No task-specific QML warning or
error was reported.
