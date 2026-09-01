# Systray Content Menu Final Fix

Implemented the three merge-blocking review fixes:

- Root submenu anchors now use the root row delegate item.
- Root menu content is bounded to the available screen height and scrolls when needed.
- Exceptions from `triggered()` no longer prevent dismissal evaluation.
- Added regression coverage for all three behaviors and tightened level-two hover retention.

## Verification

`qmltestrunner -input tests/qml/tst_bar_tray_menu_content.qml -o -,txt`

`Totals: 15 passed, 0 failed, 0 skipped, 0 blacklisted`

`qmltestrunner -input tests/qml/tst_bar_popup_content.qml -o -,txt`

`Totals: 19 passed, 0 failed, 0 skipped, 0 blacklisted`
