# brainstorm: refactor superisland architecture

## Goal

Refactor the SuperIsland architecture so its module boundaries reflect product subdomains instead of only animation/mechanism splits. The first iteration should improve structure and readability without changing runtime behavior.

## What I already know

* `modules/bar/widgets/SuperIslandWidget.qml` is the main composition root and currently has grown to 1485 lines.
* `modules/bar/superisland/` already contains many split files, but they are still mostly flat and grouped by mechanics (`StateMachine`, `Timeline`, `WindowHint`, `Expanded*`) rather than by stable subdomain ownership.
* `services/SuperIslandService.qml` is large and mixes queueing, transient timing, preview suppression, and overlay coordination.
* `services/IslandOverlayService.qml` already owns the logical overlay contract and should remain a clean boundary.
* `ExpandedPanelDeck.qml` is a second local hotspot and currently mixes page switching, header chrome, lifecycle, and measurement.
* The user specifically wants the refactor to better express how different SuperIsland parts relate to each other.

## Assumptions (temporary)

* Iteration 1 should prioritize safe structural improvement over behavior changes.
* Directory regrouping, host slimming, and extracting clearer feature hosts are in scope if done incrementally.
* Existing visual behavior and motion should be preserved unless a small correctness fix is required to keep the refactor compiling.

## Open Questions

* None blocking for iteration 1. Proceed with a conservative, behavior-preserving refactor slice.

## Requirements (evolving)

* Reorganize SuperIsland structure so related parts are easier to locate and understand.
* Preserve the current three-layer repo architecture: `services/` -> `config/` -> `modules/`.
* Keep `SuperIslandWidget.qml` as the high-level host/composition root instead of a growing all-in-one implementation file.
* Avoid behavior changes in the first refactor slice.
* Make the relationship between host, attached content, window hint flow, expanded pages, and state-machine pieces more explicit in file structure and ownership.

## Acceptance Criteria (evolving)

* [ ] SuperIsland files are regrouped or extracted in a way that makes subdomain ownership clearer.
* [ ] `SuperIslandWidget.qml` is smaller or delegates more of its responsibilities to clearly named subcomponents.
* [ ] Runtime behavior remains unchanged for existing SuperIsland interactions.
* [ ] `timeout 5 qs --path .` passes after the first refactor slice.

## Definition of Done (team quality bar)

* First refactor slice is merged as a coherent architectural step, not a partial abandoned move.
* Validation relevant to the shell passes.
* Notes in this task are sufficient for follow-up slices.

## Technical Approach

Start with a safe structural slice:

1. Identify one or two high-value extraction points from `SuperIslandWidget.qml` that preserve behavior.
2. Prefer regrouping around subdomains such as `core`, `hint`, `expanded`, `attached`, or `cards` rather than creating more flat files.
3. Keep service boundaries stable in this iteration; avoid deep `SuperIslandService.qml` logic surgery unless required.
4. Use minimal import/wiring changes and validate immediately after the slice.

## Decision (ADR-lite)

**Context**: SuperIsland is already split into many files, but the current layout still reads like a dispersed monolith because file organization follows mechanism names more than user-facing domains.

**Decision**: Perform an incremental, behavior-preserving architectural refactor that starts from structure and host responsibility reduction rather than a broad behavior rewrite.

**Consequences**: This keeps risk low and makes later service/page refactors easier, but it may take multiple slices before the full architecture becomes clean.

## Out of Scope

* Rewriting SuperIsland event semantics.
* Retuning motion curves or redesigning visuals.
* Deep service decomposition across all SuperIsland-related services in the first slice.
* Large cross-feature cleanups outside the SuperIsland area.

## Technical Notes

* Key files inspected:
  * `modules/bar/widgets/SuperIslandWidget.qml`
  * `modules/bar/superisland/ExpandedPanelDeck.qml`
  * `modules/bar/superisland/SuperIslandStateMachine.qml`
  * `modules/bar/superisland/SuperIslandStateMachineBridge.qml`
  * `services/SuperIslandService.qml`
  * `services/IslandOverlayService.qml`
* Relevant constraints:
  * QML element declarations in this repo require short English comments immediately before declarations.
  * Preserve current service/config/module ownership rules from `AGENTS.md` and `qml-architecture`.
* Validation command:
  * `timeout 5 qs --path .`
