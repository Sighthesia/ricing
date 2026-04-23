# Task: superisland-window-hint-expanded-layout

## Overview

Introduce a new window-hint presentation mode that is independent from the current window-hint and current default SuperIsland behavior. When the new hint expands, a SuperIsland-like body inside the bar must widen to reserve enough bar width for all title capsules, while the existing lower workspace-overview hint lane remains in place.

## Requirements

- Add a new window-hint form that is separate from the current default window-hint presentation path, even if it reuses or parameterizes existing SuperIsland components.
- When the new hint is visible, the SuperIsland-like body rendered in the bar must widen to the full exclusive width required to show all title capsules for the active workspace.
- The widened body must own real bar layout width so neighboring widgets can be displaced, compressed, or pushed off-screen temporarily instead of visually overlapping the expanded hint.
- Move the current window-title capsule row into the widened bar-area SuperIsland body.
- Keep the current lower workspace-overview capsules and the current lower window-hint background body in their existing position and role.
- Relocate the regular SuperIsland body that can show clock and notifications so it sits below the workspace area rather than occupying the same center-bar body used by the new title-row expansion.
- Preserve the existing window-hint data derivation contract from services unless a minimal interface extension is required.
- Reuse existing SuperIsland visual language, attached motion, and width-ownership patterns where possible instead of inventing a separate animation or shell system.

## Acceptance Criteria

- [ ] A distinct new window-hint mode exists without replacing the current default window-hint behavior unintentionally.
- [ ] When the new hint opens, the bar-area SuperIsland body widens enough to contain all title capsules for the active workspace.
- [ ] The widened body exports/reserves real bar width, and nearby bar widgets yield position instead of overlapping the title capsules.
- [ ] The title capsule row is rendered inside the widened bar-area body rather than in the old title-row location.
- [ ] The existing lower workspace-overview hint capsules and their lower background body stay visually anchored where they are today.
- [ ] The regular clock/notification-capable SuperIsland body is moved below the workspace area for this design.
- [ ] Motion and shell styling still read as part of the SuperIsland family.
- [ ] `timeout 5 qs --path .` passes after the implementation.

## Technical Notes

- This is primarily a layout-ownership task, not just an inner-card restyle: the expanded title host must own bar reservation width, not only visual width.
- Keep `WindowHintService.qml` as the normalized data source; prefer introducing a new renderer/state branch around SuperIsland ownership instead of moving rendering logic into the service layer.
- The current `IslandWindowHintCard` two-row structure should be treated as the baseline to preserve the lower overview lane while re-homing only the title row into the widened bar host.
- Follow the widget-local width ownership contract before changing global bar layout behavior: if the widened body looks correct but the bar does not yield, inspect the exported width contract first.
- Reuse attached SuperIsland motion carefully so the widened body and any relocated host do not introduce layout thrash or break shell continuity.

## Out of Scope

- Redesigning unrelated bar widgets beyond the yielding behavior required to make room for the widened hint.
- Reworking the compositor-side window-hint source model beyond minimal data/interface extensions needed for the new presentation.
- Redesigning unrelated SuperIsland expanded pages, control-center pages, or notification content.
