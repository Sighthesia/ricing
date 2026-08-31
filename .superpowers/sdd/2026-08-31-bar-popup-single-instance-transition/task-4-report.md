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
  - Covers the `closeTimer`-fired intermediate state: `open` is false while intent, current intent, popup owner, and active surface remain available until exit cleanup.
  - Covers explicit hover-to-context reopen callback data and context-to-context callback data: latest `instanceKey`, widget ID, and section.
  - Covers complete immediate-dismiss state clearing, timer cancellation, and final delayed cleanup after a natural close.
  - Covers context `close` invoking immediate dismissal and clearing intent.

## Verification

- `timeout 25 qs -p tst_bar_popup_host.qml`
  - `143 passed, 0 failed`
- `timeout 25 qs -p tst_bar_two_layer_popup.qml`
  - `110 passed, 0 failed`
- `QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_bar_context_popup_actions.qml -o -,txt`
  - `4 passed, 0 failed, 0 skipped, 0 blacklisted`
- `qmllint modules/bar/BarPopupHost.qml modules/bar/BarContextPopupActions.qml modules/bar/BarContent.qml`
  - Passed with no output.

## Follow-up Verification

- Added explicit assertions for the Task 4 test-review gaps above; focused popup tests and `qmllint` were rerun after the additions.
- Final rerun: host `143 passed, 0 failed`; two-layer `110 passed, 0 failed`; context actions `4 passed, 0 failed, 0 skipped, 0 blacklisted`; `qmllint` passed with no output.
- Added the remaining live-open hover-to-context replacement regression: while a hover intent is open and no close was requested, `updateIntent()` now verifies that `open` and the popup owner remain stable, `currentIntent` stays on the displayed hover intent while the context intent is pending, and the completed replacement exposes the latest context callback payload.
- Final rerun after the additional scenario: host `154 passed, 0 failed`; two-layer `110 passed, 0 failed`; context actions `4 passed, 0 failed, 0 skipped, 0 blacklisted`; `qmllint` passed with no output.

## Concerns

- The Quickshell behavior harness still emits pre-existing environment/runtime warnings: deprecated proxy floating-window width/height messages, an already-registered notification service, and a cross-thread image reader warning. None are from the changed code, and `qmllint` is clean.
- The worktree contains unrelated pre-existing modifications and untracked debug/media files. They were intentionally excluded from this task commit.
