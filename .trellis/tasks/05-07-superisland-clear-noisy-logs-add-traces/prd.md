# debug superisland clear noisy logs and add targeted traces

## Goal

Reduce noisy existing SuperIsland debug output and add a small set of targeted logs that make the remaining `window-hint` exit width/timing bug easier to observe.

## What I already know

* `modules/bar/widgets/SuperIslandWidget.qml` already contains multiple debug channels:
  * `_debugLogging` via `DYMICSHELL_SUPERISLAND_DEBUG`
  * `_debugWidthLogging` via `DYMICSHELL_SUPERISLAND_WIDTH_DEBUG`
  * width-chain logs
  * return-chain logs
  * reservation logs
* Additional debug output also exists in:
  * `modules/bar/superisland/SuperIslandStateMachine.qml`
  * `modules/bar/superisland/SuperIslandStateMachineTimelineCallbacks.js`
  * `modules/bar/superisland/SuperIslandTimelineAttached.qml`
  * `modules/bar/superisland/SuperIslandTimelineTransient.qml`
  * `modules/bar/BarWindow.qml`
* The current problem is not lack of logs, but too much mixed logging without one clean observation path for the remaining `window-hint` exit bug.

## Assumptions (temporary)

* The preferred change is not to remove all debugging infrastructure, but to clear noisy or duplicative lines that obscure the specific investigation.
* The added traces should focus on one precise question at a time.
* This task can change logging only; it should not alter runtime behavior.
* The preferred first question is the final width target/landing width, not the start timing.
* Do not add realtime position/frame-by-frame logs; they create too much noise during transitions.
* The preferred trace form is a tiny set of phase-boundary snapshots, not a single final snapshot and not continuous logging.

## Open Questions

* None currently.

## Requirements (evolving)

* Identify and remove or silence the noisy existing SuperIsland debug logs that are not needed for the current investigation.
* Add one focused trace path for the remaining bug.
* Keep the logging easy to grep and correlate frame-to-frame.
* Focus the new trace on the final width landing target/reference.
* Do not emit realtime position or per-frame logs.
* Prefer a tiny set of phase-boundary snapshots, such as `hint-exit` start, `completeWindowHintExit()`, and steady `idle`.
* Do not change non-debug behavior.

## Acceptance Criteria (evolving)

* [ ] Existing noisy debug output is reduced.
* [ ] New targeted trace clearly answers one specific runtime question.
* [ ] Shell still validates with `timeout 5 qs --path .`.

## Definition of Done (team quality bar)

* Debug output is easier to read for the current investigation.
* The new trace is narrow and actionable.

## Out of Scope (explicit)

* Fixing the visual bug itself in this task.
* General logging refactors across unrelated modules.

## Technical Notes

* Existing SuperIsland log tags already in use:
  * `[DymicShell:SuperIslandWidth]`
  * `[DymicShell:SuperIslandReturn]`
  * `[DymicShell:SuperIslandReservation]`
  * state-machine pulse/return logs
* Likely main file to adjust:
  * `modules/bar/widgets/SuperIslandWidget.qml`
