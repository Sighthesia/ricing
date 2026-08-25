---
name: qml-testing
description: Running or writing Afloat's QML/JS tests. Load before running tests, adding test files, or trusting a "green" test result. Covers why `qs -p tst_*.qml` does NOT run QtTest, the Qt5/Qt6 qmltestrunner trap, the import-blackholing gotcha, and the qs-host behavioral harness pattern.
---

# QML Testing Infrastructure

## The trap: `qs -p tests/qml/tst_*.qml` runs NO tests

Quickshell only loads the QML file; it does not drive QtTest. Test functions
never execute, the process exits 0 even when assertions would fail, and no
PASS/FAIL output is ever printed. Any "tests passed" claim based on that
command is void.

## How to actually run tests

| Test kind | Command |
| --- | --- |
| Pure JS/QML logic (`tests/qml/tst_*.qml`, no Quickshell imports) | `QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_bar_layout.qml -o -,txt` |
| Service behavior needing Quickshell singletons (Mpris, Process, ...) | Root-level behavioral harness: `qs -p tst_media_binding.qml` (run from repo root) |

- `/usr/bin/qmltestrunner` is **Qt 5** and fails silently (exit 1, zero
  output). Always use `/usr/lib/qt6/bin/qmltestrunner`.
- Real failures print `FAIL!` / non-zero `Totals`; verify output, not exit codes.
- Python helper tests: `python3 -m pytest scripts/tests/`.

## Gotcha: imports outside the config root get blackholed

When `qs -p <file>` runs, any relative QML import resolving outside the
config file's folder (e.g. `../../services` from `tests/qml/`) is
"blackholed": it loads as an empty shell object with no members — no error,
just `undefined` properties/functions at runtime. Consequences:

- Service-behavior harnesses must live in the **repo root** so `./services`
  resolves inside the config folder.
- `tests/qml/*.qml` files must therefore stick to pure-JS logic imports;
  they cannot instantiate singletons.

## Behavioral harness pattern

Root-level `tst_media_binding.qml` is the reference. Structure:

1. Import `"./services" as Services`; run assertions from
   `Component.onCompleted` via `Qt.callLater` steps (not synchronously).
2. Step per event-loop turn with `Qt.callLater(root._steps.shift())`:
   service signals fire mid-cascade while sibling bindings still hold stale
   values; assertions must wait one turn after mutating state.
3. Print `PASS:`/`FAIL:` lines plus a final `Totals:` line; end with
   `Qt.quit(failures === 0 ? 0 : 1)`.

## Cross-service signal timing

A signal emitted inside a property cascade (e.g. `MediaService.mediaChanged`
from `onActivePlayerChanged`) reaches handlers while other derived bindings
(`hasPlayer`, `title`) still return pre-change values. Defer consumer refreshes
to the next event-loop turn (0-interval `Timer` or `Qt.callLater`) — see
`MediaControlService._scheduleLyricsRefresh` and
`NeteaseWebLyricsService._scheduleLyricWindowSync`.
