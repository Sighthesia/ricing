# Task 1 Report: Pure Clipboard Metadata Parsing

## Files Changed

- `services/launcher/LauncherAdapters.js`
  - Added `parseClipboardImageMeta(preview)`, which parses the cliphist binary
    preview shape and returns `{ size, format, width, height }`, or `null`.
  - Added short-text character counts to clipboard descriptions.
  - Treats previews with length >= 100 as `Long text`.
  - Adds parsed image format, byte size, and resolution to clipboard results.
  - Keeps MIME fallback and the existing copied timestamp suffix.
- `tests/qml/tst_launcher_adapters.qml`
  - Added focused tests for short and long text descriptions.
  - Added valid image metadata parsing/display coverage and invalid-image MIME
    fallback coverage.

## Tests Run

### Before implementation

Command:

```bash
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_launcher_adapters.qml -o -,txt
```

Relevant exact output:

```text
FAIL!  : qmltestrunner::LauncherAdapters::test_clipboardAdapterFormatsImageMetadataAndFallsBackToMime() Uncaught exception: Property 'parseClipboardImageMeta' of object [object Object] is not a function
FAIL!  : qmltestrunner::LauncherAdapters::test_clipboardAdapterFormatsTextMetadata() 'verify()' returned FALSE. ()
Totals: 28 passed, 6 failed, 1 skipped, 0 blacklisted, 20ms
```

The other four failures were pre-existing launcher-session failures in the
same suite. The existing production-service test also emitted its known local
XHR warning and was skipped because `QML_XHR_ALLOW_FILE_READ` was not enabled.

### After implementation

Command:

```bash
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_launcher_adapters.qml -o -,txt
```

Relevant exact output:

```text
PASS   : qmltestrunner::LauncherAdapters::test_clipboardAdapterFormatsImageMetadataAndFallsBackToMime()
PASS   : qmltestrunner::LauncherAdapters::test_clipboardAdapterFormatsTextMetadata()
Totals: 30 passed, 4 failed, 1 skipped, 0 blacklisted, 27ms
```

The four remaining failures are unchanged existing launcher-session tests:

```text
FAIL!  : qmltestrunner::LauncherAdapters::test_sessionExecuteIsGatedWhileErrorShown() Uncaught exception: undefined is not a function
FAIL!  : qmltestrunner::LauncherAdapters::test_sessionExecuteIsGatedWhileLoading() Compared values are not the same
FAIL!  : qmltestrunner::LauncherAdapters::test_sessionWithProductionFactoryListsAndExecutesApplications() Compared values are not the same
FAIL!  : qmltestrunner::LauncherAdapters::test_sessionWithProductionFactorySurfacesUnavailableSources() 'verify()' returned FALSE. ()
```

The suite also retained the existing local-XHR warning and skip:

```text
QWARN  : qmltestrunner::LauncherAdapters::test_productionServiceInstallsFactoryAdapters() XMLHttpRequest: Using GET on a local file is disabled by default.
SKIP   : qmltestrunner::LauncherAdapters::test_productionServiceInstallsFactoryAdapters() local XHR file reads disabled; set QML_XHR_ALLOW_FILE_READ=1 to enable
```

Additional check:

```bash
git diff --check
```

Output: no output; the check passed.

## Concerns

- The focused suite is not fully green because of four unrelated existing
  launcher-session failures and one known environment-dependent skipped test.
- The truncation threshold is set to 100 characters as required by the new
  test fixture and long-preview behavior; no cliphist decode, image probing,
  process, or additional list-rendering work was added.
- The report file itself is intentionally outside the two-file implementation
  commit requested by the Task 1 brief.

## Reviewer Fix Report

### Changes

- Replaced the newly added Unicode middle-dot separators in clipboard metadata
  descriptions with the ASCII separator ` | `.
- Preserved the existing copied timestamp suffix and its ` · copied MM-dd
  HH:mm:ss` formatting semantics.
- Removed the unused `shortText` initialization and callback from the text
  metadata test.

### Focused Test

Command:

```bash
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_launcher_adapters.qml -o -,txt
```

Exact output:

```text
********* Start testing of qmltestrunner *********
Config: Using QtTest library 6.11.2, Qt 6.11.2 (x86_64-little_endian-lp64 shared (dynamic) release build; by GCC 16.2.1 20260810), arch unknown
PASS   : qmltestrunner::LauncherAdapters::initTestCase()
PASS   : qmltestrunner::LauncherAdapters::test_actionArgvBuildsNiriCommandsFromActionBodies()
PASS   : qmltestrunner::LauncherAdapters::test_appsAdapterCommandWithoutRunnerErrors()
PASS   : qmltestrunner::LauncherAdapters::test_appsAdapterExecuteLaunchesEntryAndRecordsUse()
PASS   : qmltestrunner::LauncherAdapters::test_appsAdapterExecuteReportsFailedLaunch()
PASS   : qmltestrunner::LauncherAdapters::test_appsAdapterExecuteSurvivesThrowingEntry()
PASS   : qmltestrunner::LauncherAdapters::test_appsAdapterExecutesCommandsThroughIpcHelper()
PASS   : qmltestrunner::LauncherAdapters::test_appsAdapterFiltersCommandsByQuery()
PASS   : qmltestrunner::LauncherAdapters::test_appsAdapterFiltersQueriesAcrossNameCommentAndId()
PASS   : qmltestrunner::LauncherAdapters::test_appsAdapterListsApplicationsForEmptyQuery()
PASS   : qmltestrunner::LauncherAdapters::test_appsAdapterNamelessEntriesFallBackToId()
PASS   : qmltestrunner::LauncherAdapters::test_appsAdapterSurfacesBuiltinCommands()
PASS   : qmltestrunner::LauncherAdapters::test_appsAdapterSurfacesUnavailableSource()
PASS   : qmltestrunner::LauncherAdapters::test_clipboardAdapterErrorsOnceProbeFinishedUnavailable()
PASS   : qmltestrunner::LauncherAdapters::test_clipboardAdapterFormatsImageMetadataAndFallsBackToMime()
PASS   : qmltestrunner::LauncherAdapters::test_clipboardAdapterFormatsTextMetadata()
PASS   : qmltestrunner::LauncherAdapters::test_clipboardAdapterMapsEntriesWithWriteBackExecution()
PASS   : qmltestrunner::LauncherAdapters::test_clipboardAdapterSurfacesUnavailableSource()
PASS   : qmltestrunner::LauncherAdapters::test_clipboardAdapterWaitsForFirstHistoryFetch()
PASS   : qmltestrunner::LauncherAdapters::test_clipboardAdapterWaitsForProbeBeforeErroring()
PASS   : qmltestrunner::LauncherAdapters::test_clipboardTimeLabelShowsMonthDayAndSeconds()
PASS   : qmltestrunner::LauncherAdapters::test_factoryInstallsAllThreeModes()
QWARN  : qmltestrunner::LauncherAdapters::test_productionServiceInstallsFactoryAdapters() XMLHttpRequest: Using GET on a local file is disabled by default.
Set QML_XHR_ALLOW_FILE_READ to 1 to enable this feature.
SKIP   : qmltestrunner::LauncherAdapters::test_productionServiceInstallsFactoryAdapters() local XHR file reads disabled; set QML_XHR_ALLOW_FILE_READ=1 to enable
   Loc: [/home/Sighthesia/0_Files/Producing/Software/Quickshell/afloat/tests/qml/tst_launcher_adapters.qml(809)]
FAIL!  : qmltestrunner::LauncherAdapters::test_sessionExecuteIsGatedWhileErrorShown() Uncaught exception: undefined is not a function
   Loc: [/home/Sighthesia/0_Files/Producing/Software/Quickshell/afloat/tests/qml/tst_launcher_adapters.qml(793)]
FAIL!  : qmltestrunner::LauncherAdapters::test_sessionExecuteIsGatedWhileLoading() Compared values are not the same
   Actual   (): false
   Expected (): true
   Loc: [/home/Sighthesia/0_Files/Producing/Software/Quickshell/afloat/tests/qml/tst_launcher_adapters.qml(770)]
FAIL!  : qmltestrunner::LauncherAdapters::test_sessionWithProductionFactoryListsAndExecutesApplications() Compared values are not the same
   Actual   (): 0
   Expected (): 2
   Loc: [/home/Sighthesia/0_Files/Producing/Software/Quickshell/afloat/tests/qml/tst_launcher_adapters.qml(753)]
FAIL!  : qmltestrunner::LauncherAdapters::test_sessionWithProductionFactorySurfacesUnavailableSources() 'verify()' returned FALSE. ()
   Loc: [/home/Sighthesia/0_Files/Producing/Software/Quickshell/afloat/tests/qml/tst_launcher_adapters.qml(734)]
PASS   : qmltestrunner::LauncherAdapters::test_shortcutsAdapterExecutesNiriActionsThroughRunner()
PASS   : qmltestrunner::LauncherAdapters::test_shortcutsAdapterFiltersByLabelSequenceAndDetail()
PASS   : qmltestrunner::LauncherAdapters::test_shortcutsAdapterPropagatesActionFailures()
PASS   : qmltestrunner::LauncherAdapters::test_shortcutsAdapterRoutesManagedShellBindsThroughIpcHelper()
PASS   : qmltestrunner::LauncherAdapters::test_shortcutsAdapterSurfacesBindFileErrors()
PASS   : qmltestrunner::LauncherAdapters::test_shortcutsAdapterSurfacesUnavailableSource()
PASS   : qmltestrunner::LauncherAdapters::test_shortcutsAdapterWaitsForLoadThenListsBinds()
PASS   : qmltestrunner::LauncherAdapters::cleanupTestCase()
Totals: 30 passed, 4 failed, 1 skipped, 0 blacklisted, 27ms
********* Finished testing of qmltestrunner *********
```

### Concerns

- The two new metadata tests pass.
- The four existing launcher-session failures and the local-XHR skip remain
  unchanged and are unrelated to this reviewer fix.

### Final Output Correction

The focused command was run after this fix report section was drafted. The
actual final output was:

```text
********* Start testing of qmltestrunner *********
Config: Using QtTest library 6.11.2, Qt 6.11.2 (x86_64-little_endian-lp64 shared (dynamic) release build; by GCC 16.2.1 20260810), arch unknown
PASS   : qmltestrunner::LauncherAdapters::initTestCase()
PASS   : qmltestrunner::LauncherAdapters::test_actionArgvBuildsNiriCommandsFromActionBodies()
PASS   : qmltestrunner::LauncherAdapters::test_appsAdapterCommandWithoutRunnerErrors()
PASS   : qmltestrunner::LauncherAdapters::test_appsAdapterExecuteLaunchesEntryAndRecordsUse()
PASS   : qmltestrunner::LauncherAdapters::test_appsAdapterExecuteReportsFailedLaunch()
PASS   : qmltestrunner::LauncherAdapters::test_appsAdapterExecuteSurvivesThrowingEntry()
PASS   : qmltestrunner::LauncherAdapters::test_appsAdapterExecutesCommandsThroughIpcHelper()
PASS   : qmltestrunner::LauncherAdapters::test_appsAdapterFiltersCommandsByQuery()
PASS   : qmltestrunner::LauncherAdapters::test_appsAdapterFiltersQueriesAcrossNameCommentAndId()
PASS   : qmltestrunner::LauncherAdapters::test_appsAdapterListsApplicationsForEmptyQuery()
PASS   : qmltestrunner::LauncherAdapters::test_appsAdapterNamelessEntriesFallBackToId()
PASS   : qmltestrunner::LauncherAdapters::test_appsAdapterSurfacesBuiltinCommands()
PASS   : qmltestrunner::LauncherAdapters::test_appsAdapterSurfacesUnavailableSource()
PASS   : qmltestrunner::LauncherAdapters::test_clipboardAdapterErrorsOnceProbeFinishedUnavailable()
PASS   : qmltestrunner::LauncherAdapters::test_clipboardAdapterFormatsImageMetadataAndFallsBackToMime()
PASS   : qmltestrunner::LauncherAdapters::test_clipboardAdapterFormatsTextMetadata()
PASS   : qmltestrunner::LauncherAdapters::test_clipboardAdapterMapsEntriesWithWriteBackExecution()
PASS   : qmltestrunner::LauncherAdapters::test_clipboardAdapterSurfacesUnavailableSource()
PASS   : qmltestrunner::LauncherAdapters::test_clipboardAdapterWaitsForFirstHistoryFetch()
PASS   : qmltestrunner::LauncherAdapters::test_clipboardAdapterWaitsForProbeBeforeErroring()
PASS   : qmltestrunner::LauncherAdapters::test_clipboardTimeLabelShowsMonthDayAndSeconds()
PASS   : qmltestrunner::LauncherAdapters::test_factoryInstallsAllThreeModes()
QWARN  : qmltestrunner::LauncherAdapters::test_productionServiceInstallsFactoryAdapters() XMLHttpRequest: Using GET on a local file is disabled by default.
Set QML_XHR_ALLOW_FILE_READ to 1 to enable this feature.
SKIP   : qmltestrunner::LauncherAdapters::test_productionServiceInstallsFactoryAdapters() local XHR file reads disabled; set QML_XHR_ALLOW_FILE_READ=1 to enable
   Loc: [/home/Sighthesia/0_Files/Producing/Software/Quickshell/afloat/tests/qml/tst_launcher_adapters.qml(813)]
FAIL!  : qmltestrunner::LauncherAdapters::test_sessionExecuteIsGatedWhileErrorShown() Uncaught exception: undefined is not a function
   Loc: [/home/Sighthesia/0_Files/Producing/Software/Quickshell/afloat/tests/qml/tst_launcher_adapters.qml(797)]
FAIL!  : qmltestrunner::LauncherAdapters::test_sessionExecuteIsGatedWhileLoading() Compared values are not the same
   Actual   (): false
   Expected (): true
   Loc: [/home/Sighthesia/0_Files/Producing/Software/Quickshell/afloat/tests/qml/tst_launcher_adapters.qml(774)]
FAIL!  : qmltestrunner::LauncherAdapters::test_sessionWithProductionFactoryListsAndExecutesApplications() Compared values are not the same
   Actual   (): 0
   Expected (): 2
   Loc: [/home/Sighthesia/0_Files/Producing/Software/Quickshell/afloat/tests/qml/tst_launcher_adapters.qml(757)]
FAIL!  : qmltestrunner::LauncherAdapters::test_sessionWithProductionFactorySurfacesUnavailableSources() 'verify()' returned FALSE. ()
   Loc: [/home/Sighthesia/0_Files/Producing/Software/Quickshell/afloat/tests/qml/tst_launcher_adapters.qml(734)]
PASS   : qmltestrunner::LauncherAdapters::test_shortcutsAdapterExecutesNiriActionsThroughRunner()
PASS   : qmltestrunner::LauncherAdapters::test_shortcutsAdapterFiltersByLabelSequenceAndDetail()
PASS   : qmltestrunner::LauncherAdapters::test_shortcutsAdapterPropagatesActionFailures()
PASS   : qmltestrunner::LauncherAdapters::test_shortcutsAdapterRoutesManagedShellBindsThroughIpcHelper()
PASS   : qmltestrunner::LauncherAdapters::test_shortcutsAdapterSurfacesBindFileErrors()
PASS   : qmltestrunner::LauncherAdapters::test_shortcutsAdapterSurfacesUnavailableSource()
PASS   : qmltestrunner::LauncherAdapters::test_shortcutsAdapterWaitsForLoadThenListsBinds()
PASS   : qmltestrunner::LauncherAdapters::cleanupTestCase()
Totals: 30 passed, 4 failed, 1 skipped, 0 blacklisted, 22ms
********* Finished testing of qmltestrunner *********
```
