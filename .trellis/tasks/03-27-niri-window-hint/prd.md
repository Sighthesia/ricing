# Niri Window Hint Design

## Goal

Design a centered floating window hint for `niri` that appears while the user holds the `Mod` key.
The hint should help users understand horizontal tiling order and nearby workspace context without turning the bar into a dense always-on navigator.

## Confirmed Requirements

- Create this as a new independent task.
- The hint is primarily a preview aid, not a direct switcher.
- The visual density should stay compact and focus on the current context.
- The hint should appear below the bar center area.
- The first row shows all windows in the current workspace in horizontal order.
- The second row highlights the current window and its previous/next window titles.
- Upper/lower translucent icon strips should hint at windows from adjacent workspaces.

## Product Intent

- Improve spatial memory for `niri` horizontal tiling.
- Reduce the need to mentally reconstruct left/right window order.
- Reuse the existing bar center affordance instead of adding a separate global overlay style.

## Design Question

The remaining architecture choice is how responsibility is split between `WorkspaceWidget` and `SuperIsland` when `Mod` is held.

## Options Under Evaluation

### Option A: WorkspaceWidget Owns Hint

- `WorkspaceWidget` expands into a two-row preview when `Mod` is held.
- Pros: direct reuse of workspace-focused data and existing focus/overview logic.
- Cons: high duplication risk with `SuperIsland` motion shell and transient presentation.

### Option B: SuperIsland Owns Hint

- `SuperIsland` temporarily takes over the center lane and renders the hint as a new event type.
- Pros: aligns with existing transient presentation architecture.
- Cons: may blur the responsibility boundary if workspace semantics stay embedded in two widgets.

### Option C: Hybrid Ownership

- Shared service/model prepares workspace hint data.
- `WorkspaceWidget` keeps always-on summary behavior.
- `SuperIsland` renders the `Mod`-hold transient preview layer.
- Pros: lowest duplication at the data layer while preserving clean UI responsibilities.
- Cons: requires a small new shared state contract.

## Working Recommendation

Prefer Option C.

- Put compositor-derived ordering and adjacent-window context in a shared service/helper layer.
- Keep `WorkspaceWidget` responsible for steady-state bar presence.
- Let `SuperIsland` own the temporary expanded visualization because it already handles transient, center-aligned, time-bounded UI.

## Acceptance Criteria

- [ ] A final ownership choice is confirmed.
- [ ] The hint layout is specified for current, previous, and next windows.
- [ ] Adjacent workspace icon treatment is specified.
- [ ] State flow for `Mod` press/release is defined.
- [ ] Reuse boundaries between workspace UI and SuperIsland are explicit.
