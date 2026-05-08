# plan superisland visual-domain refactor

## Goal

Implement the first host-slimming slice of the SuperIsland refactor so `modules/bar/widgets/SuperIslandWidget.qml` becomes a cleaner host/composition root without changing behavior.

## What I already know

* The current `modules/bar/superisland` area already has many visual leaf components such as cards and expanded pages.
* The current structure is only partially split by visual elements; major hotspots are still organized by mechanics, especially `window-hint`, `SuperIslandStateMachine*`, and the large `modules/bar/widgets/SuperIslandWidget.qml` host.
* The desired long-term direction is not a full rewrite, but a clearer refactor that reassigns ownership around visible subdomains.
* The chosen first implementation slice is `Host 瘦身`.
* Frontend spec explicitly recommends helper extraction for host slimming before behavior splitting.
* After the first visual-subtree extraction, the next chosen slice is pure derived geometry/helper extraction inside `SuperIslandWidget.qml`.

## Assumptions (temporary)

* This task is now an implementation task for the first refactor slice.
* Existing services/config/modules layer boundaries should remain intact.
* `modules/bar/widgets/SuperIslandWidget.qml` is inside the restructuring boundary and should be treated as part of the SuperIsland architecture.
* This first slice should prefer extracting pure derived helper clusters or visual host subtrees before moving motion/state-machine behavior.
* Behavior and visual output should remain unchanged.

## Open Questions

* None currently.

## Requirements (evolving)

* Slim `modules/bar/widgets/SuperIslandWidget.qml` into a clearer host/composition root.
* Keep service ownership, state-machine behavior, and runtime behavior stable.
* Prefer low-risk extraction of pure helper ownership and/or visual host subtrees.
* Do not turn this slice into a full `window-hint` or overlay architecture rewrite.
* Preserve exported width/reservation ownership on the host root.
* Keep downstream property names stable through aliases/bindings where practical.
* The current slice should focus on pure derived geometry, shape, and mode-flag helper ownership before touching track/loader orchestration.

## Acceptance Criteria (evolving)

* [ ] `SuperIslandWidget.qml` is meaningfully smaller or simpler in responsibility.
* [ ] Extracted pieces own stable, low-risk responsibility boundaries.
* [ ] Motion/state-machine behavior remains unchanged.
* [ ] Full-shell validation passes with `timeout 5 qs --path .`.

## Definition of Done (team quality bar)

* Code changes for the host-slimming slice are implemented.
* Full-shell validation passes.
* Scope remains limited to the chosen first slice.

## Out of Scope (explicit)

* Full visual-domain reorganization of all `superisland/` files.
* Rewriting animation behavior or service logic.
* Moving `window-hint` into a dedicated subdirectory in this slice.
* Detailed rename cleanup across all component families.

## Technical Approach

Start with the frontend-spec-recommended low-risk host slimming path: extract the most stable pure helper ownership or visual host subtrees out of `SuperIslandWidget.qml`, while preserving host-owned exported measurement contracts and keeping motion orchestration in place.

## Decision (ADR-lite)

**Context**: The long-term refactor target is broad, but the user chose to start implementation with the highest-value first slice.

**Decision**: Begin with `Host 瘦身`, and within that slice prefer helper/subtree extraction over behavior rewrites. After the pill-surface subtree extraction, continue with pure derived helper extraction rather than moving loader/state-machine behavior.

**Consequences**: This should reduce host complexity with lower regression risk, but it intentionally leaves deeper `hint/` and `state/` reorganization for later slices.

## Technical Notes

* Relevant areas already inspected:
  * `modules/bar/widgets/SuperIslandWidget.qml`
  * `modules/bar/superisland/SuperIslandCardComponentRegistry.qml`
  * `modules/bar/superisland/SuperIslandAttachedContentDeck.qml`
  * `modules/bar/superisland/ExpandedPanelDeck.qml`
  * `modules/bar/superisland/SuperIslandStateMachine.qml`
  * `modules/bar/superisland/IslandWindowHintCard.qml`
  * `modules/bar/superisland/IslandWindowHintScene.qml`
* Key diagnosis so far:
  * visual leaf components are mostly reasonable;
  * host/state/hint orchestration remains mechanically organized;
  * the main refactor value lies in making visual-domain ownership explicit.
* Implementation constraints from spec:
  * `directory-structure.md`: group subdomains before mechanics.
  * `component-guidelines.md`: extract helper objects before splitting behavior.
  * `quality-guidelines.md`: use helper extraction for host slimming and keep one owner per animated property.
  * Validation command: `timeout 5 qs --path .`
