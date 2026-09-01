# Task 2 Report: Tray Menu Content Component

## Status

Implemented `BarTrayMenuContent` with fake-entry support and registered it in
the `Afloat.Bar` QML module.

## TDD Evidence

### RED

Command:

```text
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_bar_tray_menu_content.qml -o -,txt
```

Result: expected compile failure. `Bar.BarTrayMenuContent` was unavailable
because `modules/bar/BarTrayMenuContent.qml` did not exist yet.

### GREEN

The same command completed with:

```text
Totals: 8 passed, 0 failed, 0 skipped, 0 blacklisted
```

The final run emitted no QML warnings or errors.

## Implemented Behavior

- Empty-state rendering and stable `rowCount` for assignable fake entries.
- Root rows, separators, enabled/disabled labels, checks, chevrons, tap
  activation, dismissal signaling, and click flash feedback.
- Submenu API and state (`openSubmenu`, `closeSubmenu`, phase, progress,
  entry, anchor level), with reduced-motion support and delayed data release.
- Level-two rows do not close the submenu; the bridge and submenu surface have
  the required object names and z/opacity behavior.
- `openerChildren` remains optional for the live opener integration in Task 4.

## Scope Note

No Quickshell import or live `QsMenuOpener` was added, as required by Task 2.

## Fix Evidence

Open and close now configure the `MotionTokens.slow` duration and
`Easing.OutQuint`, then restart `submenuAnimation`. Closing retains
`submenuEntry` and `submenuAnchorRow` until the animation completion handler
observes progress `0`; reduced-motion closing uses a zero-duration animation
and the same cleanup path. Root and level-two rows use
`LazerTheme.settingsCard` / `settingsCardHover`; tests also assert submenu
opacity, card colors, and post-close data cleanup.

The final run reported `10 passed, 0 failed, 0 skipped, 0 blacklisted` with no
QML warnings or errors.

Command:

```text
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_bar_tray_menu_content.qml -o -,txt
```
