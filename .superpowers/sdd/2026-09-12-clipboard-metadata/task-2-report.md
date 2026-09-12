# Task 2 Report: Launcher Regression Suites

Date: 2026-09-12
Branch: current branch

## Commands and Results

### Launcher adapters

Command:

```bash
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_launcher_adapters.qml -o -,txt
```

Result: failed.

```text
Totals: 30 passed, 4 failed, 1 skipped, 0 blacklisted, 47ms
```

Failures:

```text
test_sessionExecuteIsGatedWhileErrorShown() Uncaught exception: undefined is not a function
  tst_launcher_adapters.qml(797)
test_sessionExecuteIsGatedWhileLoading() Compared values are not the same; Actual false, Expected true
  tst_launcher_adapters.qml(774)
test_sessionWithProductionFactoryListsAndExecutesApplications() Compared values are not the same; Actual 0, Expected 2
  tst_launcher_adapters.qml(757)
test_sessionWithProductionFactorySurfacesUnavailableSources() 'verify()' returned FALSE
  tst_launcher_adapters.qml(734)
```

Skipped test:

```text
test_productionServiceInstallsFactoryAdapters()
  local XHR file reads disabled; set QML_XHR_ALLOW_FILE_READ=1 to enable
```

### Launcher service

Command:

```bash
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_launcher_service.qml -o -,txt
```

Result: passed.

```text
Totals: 31 passed, 0 failed, 0 skipped, 0 blacklisted, 80ms
```

### Launcher page

Command:

```bash
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_launcher_page.qml -o -,txt
```

Result: passed.

```text
Totals: 16 passed, 0 failed, 0 skipped, 0 blacklisted, 372ms
```

### Overlay coordinator logic

Command:

```bash
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_overlay_coordinator_logic.qml -o -,txt
```

Result: passed.

```text
Totals: 16 passed, 0 failed, 0 skipped, 0 blacklisted, 24ms
```

## Final Diff Checks

Command:

```bash
git diff --check
```

Result: no output; no whitespace errors reported.

Command:

```bash
git status --short
```

Result before this report was added:

```text
 M modules/bar/BarTrayMenuContent.qml
 M services/MediaControlService.qml
 M tests/qml/tst_bar_tray_menu_content.qml
 M tests/qml/tst_media_lyrics.qml
?? 142bpm.mp3
?? aubio.err
?? docs/superpowers/plans/2026-09-08-bar-popup-content-geometry-transition.md
?? docs/superpowers/plans/2026-09-12-clipboard-metadata.md
?? live_beats.txt
?? tests/qml/tst_probe_tmp.qml
?? tst_real_volume.qml
?? tst_top_volume_half.qml
```

These pre-existing changes and untracked files were left untouched.

## Concerns

1. The adapter suite is not fully green. The four failures are in production-factory/session behavior and do not assert clipboard metadata descriptions. No source or test assertions were changed for these failures.
2. The production factory adapter test was skipped because Qt local XHR reads are disabled. Re-running with `QML_XHR_ALLOW_FILE_READ=1` may provide additional coverage.
3. The service, page, and overlay coordinator suites passed completely, including the launcher page result-row and description-related coverage present in those suites.

## Commit

The only change made for Task 2 is this report. No source or test files were modified.
