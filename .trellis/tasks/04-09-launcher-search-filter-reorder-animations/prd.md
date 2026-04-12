# Launcher Search Filter Reorder Animations

## Goal

Match the launcher filtering feel to the referenced WinBoat list behavior.

## Confirmed Requirements

- Narrowing launcher search should keep surviving rows in one live list.
- Surviving application and clipboard rows should move upward into their new slots.
- Visible rows removed by filtering should animate out before disappearing.
- Provider switches can still use the existing full-swap choreography.
- `timeout 5 qs --path .` must pass after the change.

## Product Intent

- Filtering should read as refining one ordered surface, not rebuilding it.
- Users should be able to visually track matching rows as non-matches fall away.

## Acceptance Criteria

- [ ] App results reorder in place during search refinement.
- [ ] Clipboard results reorder in place during search refinement.
- [ ] Removed visible rows retire with exit motion instead of vanishing abruptly.
- [ ] Full-shell validation passes.
