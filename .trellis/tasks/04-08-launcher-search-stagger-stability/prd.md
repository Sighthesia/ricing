# Launcher Search Stagger Stability

## Goal

Fix the launcher search filtering transition so result filtering stays visually stable when many items still match.

## Confirmed Requirements

- Non-matching results should retire with the existing staggered exit effect.
- Matching results should keep their identity and move upward to fill vacated slots instead of triggering a whole-list re-entry.
- Large filtered result sets should not degrade into a full staggered fade-in of the entire list.
- Keep the existing launcher visual language and avoid redesigning the panel or delegate structure.

## Product Intent

- Search refinement should feel like narrowing one live list, not replacing the whole result surface.
- Retained rows should preserve spatial continuity so users can track where surviving matches moved.
- Only rows that truly disappear should use the detached staggered exit layer.

## Suspected Problem Areas

- The branch in `modules/launcher/LauncherCore.qml` that decides between shrink-only filtering and full result replacement.
- The delegate-window heuristic used to decide whether retained rows can safely occupy top slots during filtering.
- Reused `ListView` delegate state in `modules/launcher/LauncherResultsList.qml` during filter-driven layout changes.

## Acceptance Criteria

- [ ] Refining launcher search with many remaining matches keeps retained rows moving into vacated slots instead of replaying a whole-list enter animation.
- [ ] Rows removed by filtering still exit with staggered motion.
- [ ] Large matching result sets no longer flash or re-enter as one new batch during filtering.
- [ ] `timeout 5 qs --path .` passes after the fix.
