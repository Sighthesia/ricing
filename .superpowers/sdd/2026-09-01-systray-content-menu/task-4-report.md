# Task 4 Report: Live QsMenuOpener, submenu motion, height hold

## TDD evidence

### Red

Extended `tests/qml/tst_bar_tray_menu_content.qml` with the held-height and
face-occlusion contracts. Before implementation, the content test reported two
failures: `useStubEntries` was missing, and `menuFace`/`noteColumnHeight` were
missing.

### Green

Implemented the live menu path and reran the focused tests:

- `tst_bar_tray_menu_content.qml`: 12 passed, 0 failed
- `tst_bar_popup_content.qml`: 19 passed, 0 failed
- `qs -p tst_bar_popup_host.qml`: 176 passed, 0 failed
- `qs -p tst_bar_two_layer_popup.qml`: 112 passed, 0 failed
- `git diff --check`: passed

## Implementation coverage

- Added lazy `QsMenuOpener` bridge loaders for root and submenu children.
- Preserved explicit `entries` injection and `useStubEntries` for Quickshell-free tests.
- Added medium/outSoft reveal, slow/inOut retract, constant opacity, scale/translate travel, and required z-order aliases.
- Held root column height while asynchronous menu data is empty or transiently tiny.
- Exposed submenu `extraWidth` and included it in popup target geometry.
- Kept dismiss propagation through `BarPopupActions` unchanged and live.

## Concerns

The live opener path requires the production Quickshell runtime; qmltestrunner
cannot instantiate that plugin in this environment, so live DBus menu population
was verified structurally and through the guarded fallback path. Existing host
harnesses emit unrelated deprecated `ProxyFloatingWindow` size warnings.

## Follow-up Evidence

- Fixed the important live-path regression: an omitted `entries` payload now
  leaves `BarTrayMenuContent` on the native `QsMenuOpener` path; only
  `useStubEntries: true` or a non-empty explicit entries list activates stubs.
- Connected `extraWidthChanged` and `submenuProgressChanged` to
  `BarPopupHost.updateTargetGeometry(currentIntent)` so the popup mask and
  target width follow submenu motion.
- Raised the empty-state label above the opaque menu face (`z: 4`).
- Focused verification after the fixes: tray content 12 passed, popup content
  19 passed, popup host 176 passed, two-layer popup 112 passed.
