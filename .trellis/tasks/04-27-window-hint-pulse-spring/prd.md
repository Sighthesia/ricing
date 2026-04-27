# fix window hint pulse and spring

## Goal

Make bar-expanded `window hint` match the interaction feel of `WorkspaceWidget`: opening should pulse, switching window/workspace while held should also pulse, and the visible title/workspace background surfaces should show a real spring response instead of only the inner content animating.

## What I already know

* `WindowHintService` publishes live held snapshots with `presentation: "bar-expanded"`.
* Live bar-expanded hint rendering is split into `bar-expanded-main` and `bar-expanded-detached`, not the combined presentation path.
* `WorkspaceWidget` gets its feel from a shared geometry owner: `_pillTransition.animatedWidth`, `pulseOpacity`, and `pulseScale`.
* `SuperIslandWidget` currently animates the top host width through `_pillTransitionControl`, while the detached lower surface reveal width/height is owned separately by `_attachedPanelRevealWidth` and `_attachedPanelRevealHeight`.
* Current user-visible bug: open pulse exists, but switch pulse is missing or incomplete, and background spring still reads as static.

## Assumptions (temporary)

* The missing switch pulse is a live update routing/owner problem, not a service data problem.
* The missing spring is caused by split geometry ownership between top host width and detached lower panel reveal width.

## Open Questions

* None currently blocking; validate against live rendering after the next fix.

## Requirements (evolving)

* Bar-expanded `window hint` must pulse on initial open.
* Bar-expanded `window hint` must pulse again when held hint content changes because window or workspace changed.
* Title background, workspace background, and seam arcs must visually participate in spring motion.
* The fix should preserve existing attached reveal/collapse timing.

## Acceptance Criteria (evolving)

* [ ] Opening bar-expanded `window hint` shows a visible pulse on the whole surface.
* [ ] Switching window while holding hint shows a visible pulse on the whole surface.
* [ ] Switching workspace while holding hint shows a visible pulse on the whole surface.
* [ ] Title and detached workspace backgrounds show spring motion comparable to `WorkspaceWidget` rather than static resizing.
* [ ] `timeout 5 qs --path .` passes.

## Definition of Done (team quality bar)

* Tests added/updated where appropriate
* Lint / typecheck / CI green where applicable
* Docs/notes updated if behavior changes materially
* Rollout/rollback considered if risky

## Out of Scope (explicit)

* Reworking the whole SuperIsland event architecture
* Non-window-hint transient motion redesign

## Technical Notes

* Investigating `services/WindowHintService.qml`, `modules/bar/superisland/SuperIslandEventRouter.qml`, `modules/bar/superisland/SuperIslandStateMachineTransientPolicy.qml`, `modules/bar/widgets/SuperIslandWidget.qml`, and attached panel/shell ownership.
