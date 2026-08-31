# Task 4 Report: Preserve Close, Reopen, And Context Action Behavior

## Status

Completed. The popup host preserves the existing fixed host, replacement, and geometry ownership model. No new popup owner was added, and `BarContent.qml` was left unchanged.

## Changes

- `modules/bar/BarPopupHost.qml`
  - Cancels `closeTimer` before evaluating replacement or reopening an intent.
  - Keeps `intent` and `currentIntent` intact while the close timer and exit reveal are active.
  - Defers transition invalidation and intent clearing until `clearIntentTimer` completes while closed.
  - Keeps same-instance updates live, including refreshed content and callback payloads.
  - Exposes the existing context action object for host-level regression coverage without adding an owner.
- `tst_bar_popup_host.qml`
  - Covers close request content retention and reopen during pending close/exit cleanup.
  - Covers hover-to-context and context-to-context callback data: latest `instanceKey`, widget ID, and section.
  - Covers context `close` invoking immediate dismissal and clearing intent.

## Verification

- `timeout 25 qs -p tst_bar_popup_host.qml`
  - `110 passed, 0 failed`
- `timeout 25 qs -p tst_bar_two_layer_popup.qml`
  - `110 passed, 0 failed`
- `QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_bar_context_popup_actions.qml -o -,txt`
  - `4 passed, 0 failed, 0 skipped, 0 blacklisted`
- `qmllint modules/bar/BarPopupHost.qml modules/bar/BarContextPopupActions.qml modules/bar/BarContent.qml`
  - Passed with no output.

## Concerns

- The Quickshell behavior harness still emits pre-existing environment/runtime warnings: deprecated proxy floating-window width/height messages, an already-registered notification service, and a cross-thread image reader warning. None are from the changed code, and `qmllint` is clean.
- The worktree contains unrelated pre-existing modifications and untracked debug/media files. They were intentionally excluded from this task commit.
