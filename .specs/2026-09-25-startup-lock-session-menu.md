# Spec Contract: Startup Lock And Wave Session Menu

- **Created**: 2026-09-25
- **Status**: In Progress
- **Target Files/Modules**: `shell.qml`, `modules/lock/Lock.qml`, `modules/lock/LockSurface.qml`, `modules/lock/LockLogic.js`, `modules/lock/LockController.js`, new lock session-menu components/logic, focused QML tests

## 1. Core Objective
Make Afloat's shell invoke its compositor-enforced lock during shell startup so Afloat acts as the system lock screen, and add an osu!lazer/Wave-style session menu to the lock screen for supported session actions.

## 2. Hard Constraints & Negative Rules (Non-negotiables)
- [ ] **C-01**: Preserve PAM as the only normal unlock path; the session menu must not bypass authentication or release `WlSessionLock` directly.
- [ ] **C-02**: Preserve the existing one-lock/per-screen lifecycle, opaque first-frame floor, delayed reveal, exit animation, and failsafes.
- [ ] **C-03**: Do not use `Repeater` for visual children inside `WlSessionLockSurface`; declare lock-screen visual layers statically.
- [ ] **C-04**: Startup locking must be idempotent and must wait for available screens without repeatedly creating lock requests.
- [ ] **C-05**: Use the existing Lazer/Wave visual language and `MotionTokens`; large surfaces remain sharp rectangular geometry.
- [ ] **C-06**: Work with existing user changes in the lock-related files; do not discard unrelated dirty-worktree edits or debug assets.

## 3. Atomized Acceptance Criteria (Checklist)
- [ ] **AC-01**: After the shell root has initialized and screens are available, it requests the lock exactly once for that shell instance.
- [ ] **AC-02**: Startup lock is skipped when an equivalent lock request is already preparing, locked, or exiting, and retries only when screen discovery has not completed.
- [ ] **AC-03**: Existing manual `lock` IPC continues to work and shares the same controller/state machine.
- [ ] **AC-04**: The lock surface presents a Wave-style session affordance while remaining inside the compositor session-lock surface.
- [ ] **AC-05**: The session menu can be opened/closed without changing PAM state and does not steal password input focus while closed.
- [ ] **AC-06**: The menu exposes at least lock, logout, suspend, reboot, and shutdown actions with explicit availability/confirmation behavior.
- [ ] **AC-07**: Session actions execute through a single service/IPC seam, report unavailable or failed commands without destroying the lock surface, and keep the lock held until an explicit unlock succeeds.
- [ ] **AC-08**: Escape/back handling closes the session menu before affecting the password/input flow.
- [ ] **AC-09**: Reduced-motion mode reaches the same menu states without animated intermediate states; normal mode uses shared motion constants and interruptible transitions.
- [ ] **AC-10**: Pure session-menu decisions and startup-lock decisions have automated QML/JS coverage; relevant existing lock tests remain green.
- [ ] **AC-11**: Full qs-host behavior is manually/locally smoke-checked with a bounded startup self-test or equivalent failsafe path, without leaving the real session locked.

## 4. Edge Cases & Boundary Conditions
- The shell starts before `Quickshell.screens` is populated.
- Shell reload or duplicate lifecycle callbacks fire while startup lock is preparing.
- PAM is actively waiting for a password when the user opens or closes the session menu.
- A session command is unavailable, exits non-zero, or returns without a visible desktop transition.
- The user authenticates while the menu is open or during menu close animation.
- Multi-monitor surfaces must expose the same menu behavior without one surface releasing another.
- Reduced-motion preference is enabled.
- Existing `AFLOAT_LOCK_SELFTEST` must continue to avoid trapping unattended test sessions.

## 5. Execution & Verification Log
- [ ] Initial scaffolding
- [ ] Implementation
- [ ] Automated tests / manual verification
