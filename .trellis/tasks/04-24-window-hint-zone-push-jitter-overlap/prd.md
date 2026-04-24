# PRD

## Problem
The current window hint expanded layout has two visible layout defects:
1. After the window hint expands, the title area can push the right zone in the opposite direction even when the title width has not actually reached the right-side zone component.
2. Push/reflow changes are delayed by transition timing, so neighboring components visually overlap for a short time before their positions catch up.

## Goal
Fix the bar layout behavior so expanded window hint content only pushes neighboring zones when geometric collision actually happens, and ensure zone repositioning stays visually synchronized with the expansion so temporary overlap does not occur.

## Requirements
- The right zone must remain stable while the expanded title width still fits within the available non-overlapping space.
- The right zone must only be pushed when the expanded window hint truly intrudes into its reserved area.
- During expand/collapse and width transitions, neighboring components must not visibly overlap due to delayed push updates.
- The fix should preserve existing smooth motion as much as possible, but correctness and visual stability are higher priority than decorative lag.

## Non-Goals
- Redesigning the overall bar layout system.
- Reworking unrelated widget animations.

## Acceptance Criteria
- Expanding the window hint no longer causes premature reverse push of the right zone.
- No transient overlap is visible between the expanded title region and adjacent zone components during the problematic transition.
- Collapse behavior remains stable and does not introduce new drift or snap artifacts.
