# Task 3 Report: Wave Session-Lock Surface

## Status

Implemented the Task 3 snapshot preparation contract, compositor-owned lock
surface, and focused surface contract tests.

Changed files:

- `modules/lock/LockSnapshot.qml`
- `modules/lock/LockSurface.qml`
- `tests/qml/tst_lock_surface_logic.qml`

No controller or shell files were changed. Existing unrelated untracked files
were preserved.

## Implementation

### LockSnapshot

- Exposes `request(screenCount)`, `ready`, `generation`, and
  `prepared(generation)`.
- Tracks monotonically increasing request generations.
- Accepts an optional synchronous URL/result or provider callback.
- Accepts asynchronous per-screen provider callbacks, deduplicates screen
  indexes, and completes only after all requested screens report ready.
- Ignores stale callbacks from older generations.
- Uses a short `MotionTokens.medium` timeout fallback.
- The fallback deliberately supplies no desktop image; `LockSurface` remains
  protected by its opaque `LazerTheme.bgDark` rectangle.
- Does not create a normal interactive window during preparation.

### LockSurface

- Uses the installed `Quickshell.Wayland/WlSessionLockSurface` type.
- Keeps the Wayland surface transparent while painting an opaque fallback
  rectangle at the bottom of the stack.
- Shows an optional ready image above the fallback, then shared
  `WaveRevealLayers`, then a rectangular authentication surface.
- Keeps keyboard handling inside a focused inner `Item`; no `Keys` handler is
  attached to the lock surface itself.
- Consumes `lockContext.unlocked` and exposes `startReveal()`, `startExit()`,
  and `releaseRequested()`.
- Uses `MotionTokens.waveBackdropEnter`, `MotionTokens.waveExit`, and
  `MotionTokens.reducedMotion`.
- Uses separate enter and exit animations so a stale enter completion cannot
  release the session lock during exit.
- Emits `releaseRequested` only from the completed exit path. Reduced motion
  reaches final values immediately and emits the release signal immediately.

## Installed API Verification

The installed Quickshell 0.3.1 package exposes:

- `WlSessionLock`
- `WlSessionLockSurface`
- `Quickshell.Wayland._Screencopy/ScreencopyView`

The installed screencopy API is a live `ScreencopyView` item with
`captureSource`, `live`, `hasContent`, and `captureFrame()`. It does not expose
a stable snapshot URL or a direct bitmap snapshot provider suitable for this
preparation contract. The ledger ruling was therefore applied: keep the
provider/URL hook, but fall back to the opaque solid background when no usable
image is supplied. Session-lock integration remains independent of snapshot
availability.

The distro package includes the Wayland QML type information but not the
`quickshell-waylandplugin` binary in the Qt6 runner's import path. Therefore
the focused Qt6 test uses a pure QtQuick contract harness for the public
surface animation and release behavior, while the production QML is checked
with `qmllint` and a root-level `qs` load smoke test.

## Test Commands and Results

### Required focused test

Command:

```bash
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner \
  -input tests/qml/tst_lock_surface_logic.qml -o -,txt
```

Result: PASS, 5 passed, 0 failed, 0 skipped, 0 blacklisted, no WARN/ERROR.

### Related lock logic test

Command:

```bash
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner \
  -input tests/qml/tst_lock_logic.qml -o -,txt
```

Result: PASS, 7 passed, 0 failed, 0 skipped, 0 blacklisted, no WARN/ERROR.

### Related wave renderer test

Command:

```bash
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner \
  -input tests/qml/tst_wave_reveal_layers.qml -o -,txt
```

Result: PASS, 4 passed, 0 failed, 0 skipped, 0 blacklisted, no WARN/ERROR.

### Static QML check

Command:

```bash
qmllint -I /usr/lib/qt6/qml \
  modules/lock/LockSnapshot.qml modules/lock/LockSurface.qml
```

Result: PASS, no output.

### Production QML load smoke check

A temporary root-level `qs` harness loaded `LockSurface.qml` from the
repository root and exited after the bounded smoke-test window.

Result: configuration loaded successfully. Quickshell emitted two existing
proxy-window deprecation warnings for `width` and `height`; these originate
from the installed Quickshell proxy surface and are not emitted by either new
QML file. The temporary harness was removed after the check.

### Expected environment limitation

Running the focused test with a direct `import Quickshell.Wayland` fails in
this environment before test execution because
`quickshell-waylandplugin` is absent from `/usr/lib/qt6/qml`. This is why the
focused test intentionally avoids loading that optional plugin. The actual
production surface was still parsed and loaded through `qs`.

## Concerns

- Task 4 must provide the optional snapshot provider/URL and call
  `LockSnapshot.request(screenCount)` before creating or revealing the lock
  surface. If no provider is available, the opaque fallback is the expected
  behavior.
- Task 4 must keep `releaseRequested` as the sole handoff for releasing the
  session lock and must not call `WlSessionLock.unlock()` before that signal.
- The optional snapshot provider should report stable screen indexes and pass
  the request generation through its callback.
- A real compositor-backed session-lock integration test remains unavailable
  in this environment because the distro package lacks the Wayland plugin
  binary and a running compositor lock protocol is not part of qmltestrunner.

## Review Fix Report

### Findings addressed

- Captured `requestGeneration` in every function/object provider callback, so an
  older callback cannot read the current generation and mutate a newer request.
- Built the exact expected screen index set for each request and reject
  non-integer, out-of-range, and duplicate indexes before updating readiness.
- Added a shared `LockSurfaceLogic.js` seam used by production `LockSurface`
  and the Qt6 harness. Reduced-motion reveal and exit paths stop both
  animations before applying final values; exit then emits release once.
- Reworked the focused test to instantiate production `LockSnapshot.qml` and
  cover generation capture, invalid/duplicate indexes, stale callbacks, and
  timeout fallback. Animation tests reuse the production immediate-path seam.

### Verification

Focused lock test:

```bash
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner \
  -input tests/qml/tst_lock_surface_logic.qml -o -,txt
```

Result: PASS, 12 passed, 0 failed, 0 skipped, 0 blacklisted, no WARN/ERROR.

Related lock logic test:

```bash
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner \
  -input tests/qml/tst_lock_logic.qml -o -,txt
```

Result: PASS, 7 passed, 0 failed, 0 skipped, 0 blacklisted, no WARN/ERROR.

Related wave renderer test:

```bash
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner \
  -input tests/qml/tst_wave_reveal_layers.qml -o -,txt
```

Result: PASS, 4 passed, 0 failed, 0 skipped, 0 blacklisted, no WARN/ERROR.

Static check:

```bash
qmllint -I /usr/lib/qt6/qml \
  modules/lock/LockSnapshot.qml modules/lock/LockSurface.qml \
  modules/lock/LockSurfaceLogic.js tests/qml/tst_lock_surface_logic.qml
```

Result: PASS, no output.

Production load smoke check:

```bash
qs -p tst_lock_surface_smoke.qml
```

Result: configuration loaded successfully and the temporary harness created
and destroyed `LockSurface.qml`. Quickshell emitted the same two existing
`QML ProxyFloatingWindow` deprecation warnings for `width` and `height`; they
come from the installed Quickshell proxy surface, not the changed lock files.
The temporary harness was removed afterward.
