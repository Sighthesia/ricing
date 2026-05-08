# fix superisland safe idle width latch cache

## Goal

Fix the remaining `bar-expanded window-hint` exit width regression by turning the "safe idle collapsed width" source from a live computed value into a persistent cached value that survives entry into `barExpandedHintActive`.

## What I already know

* The current regression persists because `_latchIdleCollapsedWidthForBarExpandedHint()` runs after `root._barExpandedHintActive` becomes `true`.
* The current `_safeIdleCollapsedWidthLive` implementation is a readonly live computation gated by `root._phase === "idle" && !root._barExpandedHintActive && !root._attachedPanelActive` and an idle display event.
* Once `barExpandedHintActive` becomes `true`, `_safeIdleCollapsedWidthLive` immediately returns `0`.
* The bar-expanded hint activation handler currently calls `_latchIdleCollapsedWidthForBarExpandedHint()` inside `on_BarExpandedHintActiveChanged` after activation, so it reads the already-invalidated live value.
* `SuperIslandTrackGeometry.qml` currently resolves `windowHintCollapseTargetWidth` through `Math.max(root.host._latchedIdleCollapsedWidth, root.host._safeIdleCollapsedWidthLive)`.
* This explains the failing logs where `latchedIdleCollapsedWidth=0`, `transitionCollapsedWidth=20`, and the live path remains polluted by the tiny transient width.
* The user-proposed fix direction is to persist the safe idle width in a cached property updated only during safe idle, then reuse that cache when latching and when resolving the collapse target.

## Assumptions

* The intended collapse target is the normal idle SuperIsland width visible before entering the bar-expanded window hint flow.
* This task should stay focused on width source/latching logic rather than broader visual-domain refactors unless explicitly requested.

## Open Questions

* None currently.

## Requirements

* Replace the current live-only safe idle width source with a persistent cached width that is refreshed only while the host is in a safe idle state.
* Ensure entering `bar-expanded window-hint` can latch a usable idle collapsed width even after `barExpandedHintActive` becomes `true`.
* Make `transitionCollapsedWidth` prefer the stable cached/latched idle width during `bar-expanded + hint-exit + window-hint`.
* Keep the fix scoped to this width-source regression and avoid changing unrelated hint, overlay, or non-window-hint behavior.
* Preserve existing debug logging behavior behind the current debug gating.

## Acceptance Criteria

* [ ] During `bar-expanded window-hint` exit, `transitionCollapsedWidth` no longer collapses to the polluted tiny live width such as `20`.
* [ ] The idle-width latch can be populated from a value that survives `barExpandedHintActive=true`.
* [ ] `SuperIslandTrackGeometry.qml` resolves the window-hint exit width from stable cached/latching state instead of relying only on a live value that can invalidate on mode entry.
* [ ] Non-window-hint and non-bar-expanded width behavior remains unchanged.

## Definition of Done

* Relevant SuperIsland width logic is updated consistently.
* Static shell validation is run.
* Any spec-relevant lesson is reviewed before wrap-up.

## Technical Approach

Introduce a persistent safe-idle cache on `SuperIslandWidget.qml`, refresh it only while the widget is in a safe idle state, and make both `_latchIdleCollapsedWidthForBarExpandedHint()` and the track-geometry collapse target read from that cached state. In the same change, clean up the old `Live`-style naming/plumbing where it now misrepresents persisted state, so future fixes do not accidentally reintroduce the same live-vs-snapshot bug.

## Decision (ADR-lite)

**Context**: The existing implementation derives the fallback width from a readonly live computation that is valid only before `barExpandedHintActive` flips on, but the latch runs after that mode transition.

**Decision**: Store the safe idle collapsed width as persistent cached state, and rename/remove misleading live-only naming in the affected path as part of the same fix.

**Consequences**: This keeps the bug fix small while making the ownership model clearer. The trade-off is one more persistent width property to maintain, but it removes a failure mode where a transition reads an already-invalidated live value.

## Out of Scope

* General SuperIsland visual-domain refactors.
* Reworking unrelated bar-expanded shared clock timing.
* Redesigning debug log structure beyond what is necessary to verify this width fix.

## Technical Notes

* Primary files:
  * `modules/bar/widgets/SuperIslandWidget.qml`
  * `modules/bar/superisland/SuperIslandTrackGeometry.qml`
* Confirmed problematic flow:
  * `on_BarExpandedHintActiveChanged` calls `_latchIdleCollapsedWidthForBarExpandedHint()` after activation.
  * `_resolveSafeIdleCollapsedWidthLive()` returns `0` whenever `root._barExpandedHintActive` is `true`.
* Current consumer path:
  * `windowHintCollapseTargetWidth = Math.max(root.host._latchedIdleCollapsedWidth, root.host._safeIdleCollapsedWidthLive)`
* Expected fix shape:
  * `property real _safeIdleCollapsedWidth: 0`
  * refresh helper updates it only in safe idle
  * latching reads cached value
  * track geometry prefers `Math.max(_latchedIdleCollapsedWidth, _safeIdleCollapsedWidth)`
