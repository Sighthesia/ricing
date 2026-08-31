# Task 3 Report: Interruptible Content Crossfade

## Status

Implemented Task 3 in `BarPopupHost`.

- Added host-owned `contentOpacity` and `contentInteractive` state.
- Bound the existing `popupContentSlot` opacity and enabled state to the host state without adding a measurement wrapper.
- Added one `NumberAnimation` using `MotionTokens.fast` for serialized fade-out and fade-in.
- Added serial-guarded `beginIntentReplacement(intentObj)` and `applyPendingIntent(serial)` paths.
- Added a host-owned replacement serial so a delayed completion cannot apply a stale intent.
- Routed hover and context replacements through the same state machine.
- Preserved the single mounted `BarPopupActions` and `BarContextPopupActions` instances.
- Added `TwoLayerPopup.interactable`, which reports a fully revealed popup for input gating.
- Preserved geometry retargeting and fixed outer host sizing.
- Reduced motion applies the pending intent immediately and restores opacity to `1`.

## Tests

Command:

```bash
timeout 25 qs -p tst_bar_popup_host.qml
```

Result: `73 passed, 0 failed`.

Coverage added or exercised:

- Hover-to-context replacement keeps the host open and retains the current content until replacement.
- Rapid replacement keeps only the latest pending target.
- Reduced motion applies the replacement immediately, clears pending state, and leaves `contentOpacity === 1`.
- Existing geometry, direction, fixed-surface, close/reopen, and hover-bridge checks remain passing.

Command:

```bash
qmllint modules/bar/BarPopupHost.qml modules/lazerbar/TwoLayerPopup.qml tst_bar_popup_host.qml
```

Result: no output and exit success.

Command:

```bash
```

Result: no output and exit success.

## Fixes During Verification

The first verification run exposed that a custom property cannot be assigned directly on the built-in `Timer` object in this QML environment. The serial was moved to a host property and the timer now passes that host-owned serial to `applyPendingIntent()`.

## Concerns

- The `qs` harness still emits the pre-existing `ProxyFloatingWindow` deprecation warnings for `width` and `height`; no new warning or error was introduced by this task.
- `TwoLayerPopup.qml` was changed by one line to provide the required `interactable` contract; this is a supporting interface change for the host binding.
- Existing unrelated worktree changes were left untouched and were not staged.

## Review Follow-up

- Removed the replacement timer; `contentFade.onFinished` is now the sole
  fade-out completion path and applies a pending intent only after opacity
  reaches zero.
- Added unified transition invalidation for normal close, reopen, and
  `dismissImmediately`, including serial invalidation, animation cancellation,
  pending cleanup, and opacity restoration.
- Added asynchronous host checks for fade ordering, interaction gating,
  latest-wins replacement, fade-in completion, close/reopen opacity, and
  reduced-motion replacement.
- Kept the two content components mounted once and left geometry animation and
  unrelated workspace files unchanged.

## Review Verification

The focused host harness reports `83 passed, 0 failed`. The two-layer binding
and geometry harness reports `111 passed, 0 failed` with reduced motion enabled
for deterministic non-crossfade assertions. `qmllint` reports no diagnostics
for the modified host, popup, and focused harnesses.

The only remaining warnings are the pre-existing `ProxyFloatingWindow` width
and height deprecations, plus environment-level service/thread warnings from
the integration harness.
