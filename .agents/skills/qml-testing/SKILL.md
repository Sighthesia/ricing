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

**Always go through `scripts/run-tests.sh`.** It runs both tiers on the
offscreen platform, so a test run never maps a window over the user's live
desktop.

```sh
scripts/run-tests.sh                  # whole suite, zero windows
scripts/run-tests.sh tst_bar tst_osu  # only files matching a name
scripts/run-tests.sh --no-python      # skip the Python bridge tests
scripts/run-tests.sh -g               # ALSO run the window-based harnesses
```

- `/usr/bin/qmltestrunner` is **Qt 5** and fails silently (exit 1, zero
  output). Always use `/usr/lib/qt6/bin/qmltestrunner`.
- Real failures print `FAIL!` / non-zero `Totals`; verify output, not exit codes.
- Python helper tests: `python3 -m pytest scripts/tests/`.

| Test kind | Command |
| --- | --- |
| Pure JS/QML logic (`tests/qml/tst_*.qml`, no Quickshell imports) | `QML_IMPORT_PATH=/usr/lib/qt6/qml QT_QPA_PLATFORM=offscreen QT_QPA_FONTDIR=/usr/share/fonts /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_bar_layout.qml -o -,txt` |
| Service behavior needing Quickshell singletons (Mpris, Process, ...) | Root-level behavioral harness: `QT_QPA_PLATFORM=offscreen qs -p tst_media_binding.qml` (run from repo root) |

## The Quickshell module ceiling (why some tests "never ran")

`qmltestrunner` is plain Qt: the Quickshell plugin is **linked into the `qs`
binary**, and `/usr/lib/qt6/qml/Quickshell/qmldir` only declares
`linktarget quickshell-coreplugin`. So any QML file that transitively touches a
`Quickshell.*` core type or a `Quickshell.Services.*` module cannot load:

```
ThemeSchemePicker.qml:2,1: module "Quickshell" plugin "quickshell-coreplugin" not found
tst_media_service.qml:3,1: module "Quickshell.Services.Mpris" plugin "quickshell-service-mprisplugin" not found
```

Adding a path to `QML_IMPORT_PATH` does **not** help — the `.qmltypes` are
there, the plugin is not. `scripts/run-tests.sh` reports these as `n/a` rather
than red, because they are a coverage gap, not a regression.

The fix for an individual file is to convert it from a `tests/qml/` QtTest file
into a **root-level `qs -p` harness** (the pattern in "Behavioral harness
pattern" below), because `qs` *does* provide the module. Do not invent a stub
`Quickshell` module for tests: faking `MprisPlaybackState` or `Quickshell.env`
produces false greens.

Also: a QtTest file's **root object must be an `Item`** (qmltestrunner hosts it
in a `QQuickView` and rejects anything else with `invalid root object`). A
`Window` root does not merely fail — to make `when: windowShown` fire it needs
`visible: true`, which maps a window on the user's live desktop.

## Never run a window-based harness unprompted

Offscreen is the isolation mechanism, not a workaround: the offscreen platform
has no layer-shell backend, so a harness that instantiates a `PanelWindow`
**cannot** map a surface. It fails to load with `No PanelWindow backend loaded`,
and `scripts/run-tests.sh` reports it under "window-only (skipped, desktop
untouched)".

The eight such harnesses are the ones that flash windows over the running
desktop: `tst_bar_popup_host`, `tst_bar_two_layer_popup`, `tst_real_volume`,
`tst_top_volume_half` (all drive `BarPopupHost`'s `surfaceActive`), plus the
`PanelWindow`-declaring visual probes `tst_network_visual`,
`tst_loading_ring_visual`, `tst_loading_ring_wiring`, `tst_network_popup`.
Run them only via `scripts/run-tests.sh -g`, and only when the user asked for
visual verification. **Do not** invoke `qs -p <window harness>` directly.

Worse than a popup: `lock-test.qml` (root level, and deliberately not named
`tst_*` so the runner never touches it). With `AFLOAT_LOCK_SELFTEST=1` it mounts
`Lock` for real, grabs the session lock and blacks out the screen for 5s.
Manual-only, ask first. The ad-hoc probes `ghost_race_harness.qml`,
`harness_media_char.qml`, `clock_scene_probe.qml` and the `launcher_*_stress` /
`launcher_launch_e2e` harnesses are headless-safe — the launcher ones only write
inside `/tmp/opencode/xdg-data/`.

## Writing a test that does not lie

- A test must be **green the first time it runs**. Red-on-arrival means it never
  executed (the suite could not load — see the module ceiling above) or it was
  written against behaviour that had already changed. Both happened repeatedly in
  `tst_lazer_settings_controls`, which accumulated 15 failures that way.
- A QML `TestCase` function does **not** run the event loop, so a property that a
  `Behavior` animation drives still reads its pre-change value. Assert with
  `tryCompare` / `tryVerify` / an explicit `wait(MotionTokens.<duration>)`.
- `init()` resets only what you put in it. A test function that mutates
  `row.enabled`, `slider.defaultValue` or a `Qt.binding` permanently poisons
  every test that runs after it.
- Read the animation's *contract* (a token or a formula) rather than a copied
  constant, so a deliberate retune does not silently desync the test.

## Do not let tests touch the real environment

`AppThemeService` is a test seam: with `AFLOAT_APP_THEME_PREFIX` unset it runs
`apply_app_themes.py` against the user's real `~/.config/kitty` and
`gtk-3.0`. `scripts/run-tests.sh` exports a throwaway prefix for every run; keep
that when invoking a harness by hand.

## QtTest / Quickshell exit differences

- `Qt.quit()` in Quickshell takes **no arguments**. `Qt.quit(failures === 0 ? 0 : 1)`
  throws `Too many arguments` and the harness hangs instead of exiting.
- A `Qt.quit()` emitted before the shell finishes loading is dropped
  (`Signal QQmlEngine::quit() emitted, but no receivers connected`) and also
  hangs. Defer it: `Qt.callLater(function() { Qt.quit() })`.
- QtTest harnesses report failure through `FAIL!` lines and a non-zero
  `Totals:`; `qs` harnesses return 0 regardless, so scan for `FAIL:` /
  `Totals: … N failed` in the output.

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
3. Print `PASS:`/`FAIL:` lines plus a final `Totals:` line; end with a bare
   `Qt.quit()`, deferred one event-loop turn if the run finished inside
   `Component.onCompleted` (see the exit-differences section above).

## Cross-service signal timing

A signal emitted inside a property cascade (e.g. `MediaService.mediaChanged`
from `onActivePlayerChanged`) reaches handlers while other derived bindings
(`hasPlayer`, `title`) still return pre-change values. Defer consumer refreshes
to the next event-loop turn (0-interval `Timer` or `Qt.callLater`) — see
`MediaControlService._scheduleLyricsRefresh` and
`NeteaseWebLyricsService._scheduleLyricWindowSync`.
