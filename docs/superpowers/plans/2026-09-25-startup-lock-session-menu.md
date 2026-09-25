# Startup Lock And Wave Session Menu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` (recommended) or execute this plan task-by-task with checkpoints. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Afloat acquire the Niri session lock once during shell startup and add a Wave-style Lock / Logout / Suspend / Reboot / Shutdown menu inside each lock surface without weakening PAM ownership of unlock.

**Architecture:** Keep `Lock.qml` as the only owner of `WlSessionLock` and add a startup-only request gate around its existing `lock()` state machine. Add a singleton `SessionService` for system actions; it emits `lockRequested()` for the lock action and runs `loginctl`/`systemctl` commands for the other actions through one in-flight process. Add a static lock-surface menu composed of a pure JS state seam, one menu host, and five statically declared rows. The menu reports actions to `SessionService` and never changes `LockContext` or releases the session lock.

**Tech Stack:** Qt 6 QML, Quickshell `Scope`/`Process`/`IpcHandler`, `WlSessionLock`/`WlSessionLockSurface`, QML Test/QtTest, pure `.js` decision seams, existing `LazerTheme` and `MotionTokens`.

## Global Constraints

- Preserve PAM as the only normal unlock path; menu actions must not release `WlSessionLock` directly.
- Preserve the existing one-lock/per-screen lifecycle, opaque first-frame floor, delayed reveal, exit animation, and failsafes.
- Do not use `Repeater` for visual children inside `WlSessionLockSurface`; declare the five menu rows statically.
- Startup locking must be idempotent and wait for screens without repeatedly creating lock requests.
- Use the existing Lazer/Wave visual language and `MotionTokens`; large surfaces remain sharp rectangular geometry.
- Work with existing user changes in lock-related files; do not reset or overwrite unrelated dirty-worktree edits.
- After every QML change, run the relevant Qt6 `qmltestrunner` test file and fix warnings/errors before moving on.
- Lock changes require a full `qs` restart for host checks; do not rely on Quickshell hot reload.

---

### Task 1: Add pure startup-lock and session-menu decision seams

**Files:**
- Create: `modules/lock/StartupLockLogic.js`
- Create: `modules/lock/LockSessionMenuLogic.js`
- Test: `tests/qml/tst_startup_lock_logic.qml`
- Test: `tests/qml/tst_lock_session_menu_logic.qml`

**Interfaces:**
- `StartupLockLogic.canAttempt(state, armed, screensReady)` returns a boolean. It is true only when `armed === true`, `screensReady === true`, and `state === "idle"`.
- `StartupLockLogic.nextAttempt(armed, screensReady, state, lockResult)` returns `{ armed: bool, retry: bool }`; a successful request clears `armed`, an unavailable screen set keeps `armed` and requests retry, and a rejected state clears `armed` without retrying.
- `LockSessionMenuLogic.actions()` returns a new array of five records in this exact order: `lock`, `logout`, `suspend`, `reboot`, `shutdown`. Each record contains `id`, `label`, `requiresConfirmation`, and `icon`.
- `LockSessionMenuLogic.toggle(open)` returns `!open`.
- `LockSessionMenuLogic.confirmationAction(menuOpen, pendingAction, actionId)` returns `"confirm"` for the same confirmable action, `"pending"` for a different action while one is pending, `"pending"` for an already pending action, and `"select"` for the first selection.
- `LockSessionMenuLogic.escapeAction(menuOpen, pendingAction)` returns `"cancel-confirmation"`, then `"close"`, then `"none"` in that precedence order.
- `LockSessionMenuLogic.canTrigger(actionId, available, running)` returns false for unknown/unavailable/running actions and true otherwise.

- [ ] **Step 1: Write failing startup and menu logic tests**

  Add `TestCase` files using only relative JS imports. Cover these concrete cases:

  ```qml
  function test_startupAttemptRequiresReadyIdleAndArmed() {
      verify(Logic.canAttempt("idle", true, true))
      verify(!Logic.canAttempt("idle", false, true))
      verify(!Logic.canAttempt("preparing", true, true))
      verify(!Logic.canAttempt("idle", true, false))
  }

  function test_startupResultClearsOnlyAfterAcceptedLock() {
      compare(Logic.nextAttempt(true, true, "idle", true), { armed: false, retry: false })
      compare(Logic.nextAttempt(true, false, "idle", false), { armed: true, retry: true })
      compare(Logic.nextAttempt(true, true, "locked", false), { armed: false, retry: false })
  }

  function test_menuHasFiveStableActions() {
      var ids = Logic.actions().map(function(action) { return action.id })
      compare(ids, ["lock", "logout", "suspend", "reboot", "shutdown"])
  }

  function test_confirmationAndEscapePrecedence() {
      compare(Logic.confirmationAction(true, "", "shutdown"), "select")
      compare(Logic.confirmationAction(true, "shutdown", "shutdown"), "confirm")
      compare(Logic.confirmationAction(true, "shutdown", "reboot"), "pending")
      compare(Logic.escapeAction(true, "shutdown"), "cancel-confirmation")
      compare(Logic.escapeAction(true, ""), "close")
      compare(Logic.escapeAction(false, ""), "none")
  }
  ```

- [ ] **Step 2: Run the new tests and verify they fail**

  Run:

  ```bash
  QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner \
    -input tests/qml/tst_startup_lock_logic.qml -o -,txt
  QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner \
    -input tests/qml/tst_lock_session_menu_logic.qml -o -,txt
  ```

  Expected: FAIL because the two new JS modules do not yet expose the tested functions.

- [ ] **Step 3: Implement the minimal pure functions**

  Keep both files `.pragma library`, avoid QML imports, and return fresh objects/arrays so test mutation cannot leak between cases. Use the existing lock state strings rather than importing QML. Mark the five menu records with `requiresConfirmation: false` only for `lock` and `true` for the other four actions.

- [ ] **Step 4: Run the logic tests and verify they pass**

  Re-run both exact commands from Step 2. Expected: PASS with no WARN/ERROR output.

- [ ] **Step 5: Commit the pure seams**

  ```bash
  git add modules/lock/StartupLockLogic.js modules/lock/LockSessionMenuLogic.js \
    tests/qml/tst_startup_lock_logic.qml tests/qml/tst_lock_session_menu_logic.qml
  git commit -m "feat(lock): add startup and session menu decision seams"
  ```

### Task 2: Add the SessionService command seam

**Files:**
- Create: `services/SessionService.qml`
- Modify: `services/qmldir`
- Create: `tests/qml/tst_session_service_logic.qml`

**Interfaces:**
- Singleton properties:
  - `readonly property bool running`
  - `readonly property string runningAction`
  - `readonly property string errorText`
  - `readonly property string resultText`
  - `readonly property string sessionId`
- Signals:
  - `signal lockRequested()`
  - `signal actionStarted(string actionId)`
  - `signal actionFinished(string actionId, bool success, string message)`
- Functions:
  - `function isKnownAction(actionId): bool`
  - `function isAvailable(actionId): bool`
  - `function execute(actionId): bool`
  - `function clearMessage(): void`
- `execute("lock")` emits `lockRequested()` and returns true without starting a process.
- `execute("logout")` runs `loginctl terminate-session <XDG_SESSION_ID>` only when `XDG_SESSION_ID` is non-empty.
- `execute("suspend")`, `execute("reboot")`, and `execute("shutdown")` run `systemctl suspend`, `systemctl reboot`, and `systemctl poweroff` respectively.
- A second `execute()` while `running` returns false and leaves the current process untouched.

- [ ] **Step 1: Add a failing service behavior harness**

  Create a root-level QML harness only if direct singleton instantiation is needed by Quickshell imports; pure availability and command mapping assertions belong in `tst_session_service_logic.qml` through a small exported JS seam inside the service folder, `services/SessionServiceLogic.js`. The test must cover known/unknown actions, empty session id disabling logout, all three `systemctl` argv mappings, lock emitting instead of spawning, and in-flight rejection. Use a fake runner callback so tests never invoke the host's real power commands.

- [ ] **Step 2: Run the service test and verify it fails**

  ```bash
  QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner \
    -input tests/qml/tst_session_service_logic.qml -o -,txt
  ```

  Expected: FAIL because `services/SessionServiceLogic.js` is absent.

- [ ] **Step 3: Implement `SessionServiceLogic.js` and `SessionService.qml`**

  Put pure data and argv mapping in `services/SessionServiceLogic.js`:

  ```javascript
  var actionIds = ["lock", "logout", "suspend", "reboot", "shutdown"]

  function commandFor(actionId, sessionId) {
      if (actionId === "logout")
          return sessionId ? ["loginctl", "terminate-session", sessionId] : []
      if (actionId === "suspend") return ["systemctl", "suspend"]
      if (actionId === "reboot") return ["systemctl", "reboot"]
      if (actionId === "shutdown") return ["systemctl", "poweroff"]
      return []
  }
  ```

  In the singleton, use one `Process` with `running: false`. Set its `command` before starting it, clear previous messages, set `runningAction`, then set `running = true`. Handle `onExited(exitCode)` by clearing `running`, setting a success message for zero and a stable failure message for non-zero, and emitting `actionFinished`. Do not use `execDetached`, because the service needs an exit result and in-flight gate. Keep the lock action as a signal-only path.

- [ ] **Step 4: Run the service tests and verify they pass**

  Re-run the exact Qt6 command from Step 2. Expected: PASS with no warnings. If a QML singleton cannot be loaded by the pure runner, keep the command mapping in the JS seam and add the small root-level qs harness specified above for only the process lifecycle.

- [ ] **Step 5: Commit the service**

  ```bash
  git add services/SessionService.qml services/SessionServiceLogic.js services/qmldir \
    tests/qml/tst_session_service_logic.qml
  git commit -m "feat(session): add system action service"
  ```

### Task 3: Make shell startup acquire the lock once

**Files:**
- Modify: `shell.qml`
- Modify: `modules/lock/Lock.qml`
- Modify: `modules/lock/LockController.js`
- Test: `tests/qml/tst_lock_controller_logic.qml`
- Test: `tests/qml/tst_startup_lock_logic.qml`

**Interfaces:**
- Add `Lock.startupLock(): bool` as the startup-only entry point. It returns false once the startup request has been accepted or when the normal controller rejects the current state.
- Add `Lock.startupLockRequested` as an internal boolean guard; it is not an IPC API.
- `SessionService.lockRequested` is connected to `root.lock()` so menu Lock reuses the existing manual lock path.

- [ ] **Step 1: Extend the controller test with startup duplicate cases**

  Add assertions that an idle state accepts one startup attempt, a preparing/locked/exiting state does not accept another, and an already-armed startup request is not accepted twice. Keep the existing tests for manual `lock()` and PAM-only release unchanged.

- [ ] **Step 2: Run the focused controller tests before implementation**

  ```bash
  QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner \
    -input tests/qml/tst_lock_controller_logic.qml -o -,txt
  ```

  Expected: existing tests PASS; the new startup assertions FAIL until the seam is added.

- [ ] **Step 3: Implement the startup gate in `Lock.qml`**

  Import `StartupLockLogic.js` and add `property bool _startupLockArmed: true`. Add `startupLock()` that checks `Quickshell.screens.length`, passes the current `_state` and guard to `StartupLockLogic.canAttempt()`, calls the existing `lock()`, then clears the guard only when `lock()` returns true. Add a single `startupLockTimer` with a `100` millisecond interval that restarts while screens are empty or the startup request remains armed. Start it from `Component.onCompleted` after the existing self-test setup without changing the self-test branch. Do not call startup lock from an `onScreensChanged` loop.

  Connect `SessionService.lockRequested` to `root.lock()` in a `Connections` block. The service signal must not call `startupLock()` and must not alter `_startupLockArmed`.

- [ ] **Step 4: Implement the shell startup trigger**

  In `shell.qml`, retain the existing theme and service warmup statements, then call `LockModule.Lock` through an `id` and invoke `startupLock()` after the root completes. Prefer exposing a public `startupLock()` on the existing `Lock` object and call it from `Component.onCompleted` through a queued `Qt.callLater` so screen discovery can settle. The timer inside `Lock.qml` remains the final guard for an empty screen list.

- [ ] **Step 5: Run all focused lock logic tests**

  ```bash
  for test in \
    tests/qml/tst_startup_lock_logic.qml \
    tests/qml/tst_lock_controller_logic.qml \
    tests/qml/tst_lock_logic.qml
  do
    QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner \
      -input "$test" -o -,txt || exit 1
  done
  ```

  Expected: PASS with no WARN/ERROR output. If `Qt.callLater` is unavailable in the installed Quickshell Qt build, use the existing `Timer` path and document the exact queued trigger in the code rather than introducing a second retry loop.

- [ ] **Step 6: Commit startup integration**

  ```bash
  git add shell.qml modules/lock/Lock.qml modules/lock/LockController.js \
    tests/qml/tst_lock_controller_logic.qml tests/qml/tst_startup_lock_logic.qml
  git commit -m "feat(lock): acquire session lock on shell startup"
  ```

### Task 4: Build the static Wave session menu

**Files:**
- Create: `modules/lock/LockSessionMenu.qml`
- Create: `modules/lock/LockSessionMenuItem.qml`
- Modify: `modules/lock/qmldir`
- Modify: `modules/lock/LockSurface.qml`
- Test: `tests/qml/tst_lock_session_menu.qml`

**Interfaces:**
- `LockSessionMenu` properties:
  - `property bool open`
  - `property bool reducedMotion`
  - `property var sessionService`
  - `property string errorText`
  - `property string statusText`
- `LockSessionMenu` signal: `signal escapeHandled(bool handled)`.
- `LockSessionMenu` function: `function handleEscape(): bool`.
- `LockSessionMenuItem` properties: `actionId`, `label`, `iconSource`, `available`, `confirmationPending`, `running`, `enabled`.
- `LockSessionMenuItem` signal: `signal activated(string actionId)`.

- [ ] **Step 1: Add a failing menu component test**

  Create a pure-QML test component with a fake service object exposing `execute(actionId)`, `isAvailable(actionId)`, `running`, and `actionFinished`. Assert that the menu starts closed, opens on its affordance, has five statically declared children, sends `lock` immediately, requires a second activation for destructive actions, closes on Escape, and does not call the service when an action is unavailable.

- [ ] **Step 2: Run the component test and verify it fails**

  ```bash
  QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner \
    -input tests/qml/tst_lock_session_menu.qml -o -,txt
  ```

  Expected: FAIL because the menu components are absent.

- [ ] **Step 3: Implement the static menu item**

  Use a sharp rectangular row with a narrow accent indicator for focus/selection. Reuse the existing `MenuItem` interaction contract where useful, but keep the lock menu row independent so its menu action state is explicit. Add `TapHandler`, `HoverHandler`, Return/Enter/Space activation, `MotionTokens.clickFlash*`, `MotionTokens.disabledOpacity`, and `ColorAnimation { duration: MotionTokens.fast }`. Add a brief comment before the major `Rectangle` and `Item` declarations as required by the QML style rules.

- [ ] **Step 4: Implement the static menu host**

  Declare exactly five `LockSessionMenuItem` objects in a `Column` rather than a `Repeater`. Put the visual menu body in a fixed rectangular `Item`/`Rectangle` anchored to the lower-right lock surface, with a separate trigger affordance. Animate a `revealProgress` from `0` to `1` using `MotionTokens.medium` or `MotionTokens.slow`, gate all animations on `reducedMotion`, and keep the outer geometry stable while content slides/reveals inside. The menu host should only capture pointer input inside its own bounds; do not add a full-screen transparent catcher.

  Route item clicks through `LockSessionMenuLogic.confirmationAction()`. For `lock`, call `sessionService.execute("lock")` immediately. For the other actions, first set `pendingAction`; the second click calls `execute()`. On `actionFinished`, clear the pending action and show the service message. While `sessionService.running` is true, disable all rows. `handleEscape()` must cancel confirmation before closing the menu.

- [ ] **Step 5: Mount the menu into `LockSurface.qml`**

  Add `Services.SessionService` as the menu service and place `LockSessionMenu` above the auth content but below the keyboard owner where possible. Give it a stable z-order that cannot cover the whole keyboard owner. Connect its Escape handling from the existing inner keyboard focus item so menu Escape is consumed first while open. Do not change `LockContext`, `startExit()`, `requestRelease()`, `releaseSent`, or the existing backdrop animation ownership.

- [ ] **Step 6: Register and run the menu tests**

  Add `LockSessionMenu` and `LockSessionMenuItem` to `modules/lock/qmldir`, then run the exact command from Step 2. Expected: PASS with no WARN/ERROR output. Also run `tests/qml/tst_lock_surface_logic.qml` because `LockSurface.qml` changed.

- [ ] **Step 7: Commit the menu surface**

  ```bash
  git add modules/lock/LockSessionMenu.qml modules/lock/LockSessionMenuItem.qml \
    modules/lock/LockSurface.qml modules/lock/qmldir \
    tests/qml/tst_lock_session_menu.qml
  git commit -m "feat(lock): add wave session menu surface"
  ```

### Task 5: Connect action feedback and lock-surface lifecycle safely

**Files:**
- Modify: `modules/lock/Lock.qml`
- Modify: `modules/lock/LockSurface.qml`
- Modify: `modules/lock/LockSessionMenu.qml`
- Modify: `services/SessionService.qml`
- Test: `tests/qml/tst_lock_session_menu.qml`
- Test: `tests/qml/tst_lock_controller_logic.qml`

**Interfaces:**
- `Lock.qml` owns the only connection from `SessionService.lockRequested` to `root.lock()`.
- `LockSessionMenu` observes `SessionService.running`, `errorText`, and `resultText`; it never writes lock state.
- PAM `LockContext.unlocked()` remains the only signal that transitions `Lock.qml` from `locked` to `exiting`.

- [ ] **Step 1: Add regression tests for PAM and menu independence**

  Assert that opening/closing the menu does not call `LockContext.reset()`, a menu action failure leaves `SessionService` available for retry, a successful `SessionService` action does not emit `LockContext.unlocked()`, and only the existing auth success path changes the controller state to `exiting`.

- [ ] **Step 2: Run the regression tests and verify the new assertions fail**

  ```bash
  QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner \
    -input tests/qml/tst_lock_session_menu.qml -o -,txt
  QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner \
    -input tests/qml/tst_lock_controller_logic.qml -o -,txt
  ```

- [ ] **Step 3: Implement error/status synchronization**

  Ensure `SessionService` clears stale errors on every new attempt, emits one `actionFinished` per process, and leaves the menu open after a non-zero exit. Ensure menu animations stop and snap to the correct final state when `MotionTokens.reducedMotion` changes. Do not add a second authentication or release signal.

- [ ] **Step 4: Run the full focused QML lock suite**

  ```bash
  for test in \
    tests/qml/tst_lock_logic.qml \
    tests/qml/tst_lock_controller_logic.qml \
    tests/qml/tst_lock_surface_logic.qml \
    tests/qml/tst_lock_backdrop.qml \
    tests/qml/tst_lock_session_menu_logic.qml \
    tests/qml/tst_lock_session_menu.qml \
    tests/qml/tst_session_service_logic.qml
  do
    QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner \
      -input "$test" -o -,txt || exit 1
  done
  ```

  Expected: PASS with no WARN/ERROR output.

- [ ] **Step 5: Commit lifecycle integration**

  ```bash
  git add modules/lock/Lock.qml modules/lock/LockSurface.qml \
    modules/lock/LockSessionMenu.qml services/SessionService.qml \
    tests/qml/tst_lock_session_menu.qml tests/qml/tst_lock_controller_logic.qml
  git commit -m "fix(lock): keep session actions outside pam release flow"
  ```

### Task 6: Run full verification and isolated qs-host smoke test

**Files:**
- Modify: `.specs/2026-09-25-startup-lock-session-menu.md`
- Modify: `docs/superpowers/plans/2026-09-25-startup-lock-session-menu.md`
- No product-code changes unless verification exposes a concrete defect.

- [ ] **Step 1: Run the complete pure/QML test set touched by the feature**

  ```bash
  for test in \
    tests/qml/tst_startup_lock_logic.qml \
    tests/qml/tst_lock_session_menu_logic.qml \
    tests/qml/tst_session_service_logic.qml \
    tests/qml/tst_lock_logic.qml \
    tests/qml/tst_lock_controller_logic.qml \
    tests/qml/tst_lock_surface_logic.qml \
    tests/qml/tst_lock_backdrop.qml
  do
    QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner \
      -input "$test" -o -,txt || exit 1
  done
  ```

  Record any remaining environment-only limitations; do not call `qs -p tests/qml/tst_*.qml` because it does not drive QtTest.

- [ ] **Step 2: Run the Python regression suite if the changed IPC/service path is imported there**

  ```bash
  python3 -m pytest scripts/tests/
  ```

  Expected: PASS. If no test imports the changed service, still run it because the shell IPC adapter is a neighboring integration boundary.

- [ ] **Step 3: Run an isolated qs-host smoke test**

  Start from the repository root with the existing safe self-test mechanism, after stopping only known Quickshell processes if necessary:

  ```bash
  AFLOAT_LOCK_SELFTEST=1 \
  AFLOAT_LOCK_BACKGROUND=wallpaper \
  QS_DISABLE_FILE_WATCHER=1 \
  qs -n -d -p lock-test.qml
  ```

  Verify from console output and manual display inspection that startup creates one lock surface, the menu opens/closes, the self-test releases the lock, and no `qs` process remains. Do not run real logout/reboot/shutdown actions during this check.

- [ ] **Step 4: Audit the task contract**

  Read `.specs/2026-09-25-startup-lock-session-menu.md`, mark `C-01` through `C-06` and `AC-01` through `AC-11` complete only with corresponding test or smoke evidence, and update the execution log. If a criterion cannot be verified because the compositor is unavailable, mark it blocked and state the exact command/environment limitation instead of claiming completion.

- [ ] **Step 5: Commit the verification record**

  ```bash
  git add .specs/2026-09-25-startup-lock-session-menu.md \
    docs/superpowers/plans/2026-09-25-startup-lock-session-menu.md
  git commit -m "test(lock): verify startup session menu flow"
  ```

## Plan Self-Review

- **Spec coverage:** Startup idempotence is covered by Tasks 1 and 3; PAM-only release and error isolation by Tasks 2 and 5; static Wave UI and focus/Escape behavior by Task 4; reduced motion by Task 4/5; multi-screen preservation by the unchanged `LockSurface` ownership and Task 6 host smoke; automated and host verification by Task 6.
- **Placeholder scan:** No `TBD`, `TODO`, or unspecified implementation step is used. Every task names files, interfaces, commands, and expected outcomes.
- **Type consistency:** `StartupLockLogic.canAttempt/nextAttempt`, `LockSessionMenuLogic.actions/toggle/confirmationAction/escapeAction/canTrigger`, `SessionService.execute/isAvailable`, `Lock.startupLock`, and menu properties/signals are defined before their consumers.
