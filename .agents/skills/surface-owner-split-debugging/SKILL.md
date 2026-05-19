---
name: surface-owner-split-debugging
description: Use when a UI surface's visible owner has been moved or split away from its prior state, layout, or editing owner, and behavior regresses in ways such as hover animations disappearing, real content not rendering, right-click or drag editing breaking, or container width/height no longer tracking content.
---

# Surface Owner Split Debugging

Debug UI regressions caused by moving a surface's visible owner without fully migrating its input, content, and geometry responsibilities.

## The Generic Pattern / Methodology

**Core Concept**

- A shell surface usually has 5 linked responsibilities:
- visible rendering owner
- input owner
- real content owner
- editing owner
- geometry owner
- Bugs appear when one responsibility moves to a new component or window, but the others still live in the old path.

**Universal Checklist**

| Responsibility | Questions to answer |
|---|---|
| Visible owner | Which item/window now paints the surface the user sees? |
| Input owner | Which item now receives hover, left click, right click, drag, and focus? |
| Real content owner | Which path renders the actual managed widgets, not a placeholder? |
| Editing owner | Which path now owns context menus, remove buttons, drag handles, and picker entry points? |
| Geometry owner | Which item computes width, height, radius, and hover expansion from content? |

- If the visible owner moved, re-walk all 5 responsibilities before changing code.
- Compare normal mode, editing mode, and expanded mode separately.
- Verify whether the new owner still uses placeholder content where the old owner used real widgets.
- Verify whether the new owner still uses a stale width constant that should now be content-driven.

## The Specific Trap / Symptom

**Context**

- In a top-bar center surface, the visible body moved from a bar dockzone to an island window.
- The old dockzone stayed hidden, but still owned parts of the real widget pipeline.
- Symptoms appeared in stages:
- hover expand/reset motion disappeared
- right-click editing entry disappeared
- layout mode showed a placeholder clock instead of real center widgets
- after reconnecting real content, the surface stayed wider than its contents because an old minimum width remained in the geometry path

## The Anti-Pattern vs. Best Practice

❌ **The Anti-Pattern**

- Move only the visible surface.
- Leave real widgets in the hidden owner.
- Keep fallback content in the new owner even during editing mode.
- Keep old geometry baselines such as `Math.max(minWidth, contentWidth)` after the product expectation becomes true content-fit sizing.
- Leave global or root-level input catchers enabled while real editable widgets are visible.

✅ **The Best Practice**

- Treat owner migration as a full responsibility migration.
- When the visible owner changes, reconnect:
- hover and motion drivers
- context menu and editing entry points
- real widget rendering path
- content-driven width and height logic
- mode-aware input layering
- In editing mode, render the real managed widget chain, not a display-only fallback.
- Make geometry derive from current visible content first, then add hover lift or explicit min-width only if the product requires it.

## Generalizable Rules

**Agnostic Rules**

- If a visible owner changes, inspect content ownership before debugging animation or input symptoms.
- A placeholder view is acceptable only in display mode; editing mode must show the real managed content path.
- Input catchers must shrink as more specific interactive content becomes visible.
- Geometry must follow the content currently rendered in that mode, not the content that used to be rendered before the owner split.
- If a surface should feel adaptive, compute `targetSize` from current content and then add state-specific deltas such as hover lift.

**Warning Signs**

- A region is visible but cannot be edited.
- A region can open an edit menu but still does not show the real managed content.
- A width or height remains suspiciously fixed after switching from placeholder content to dynamic content.
- Right-click works only on background, not on the widgets now visible inside the surface.
- Hover works on one owner path while rendering happens in another.

## Universal Verification Strategy

**Agnostic Testing Logic**

- Reproduce each mode separately:
- normal display mode
- editing/layout mode
- expanded or alternate content mode
- For each mode, verify 4 things in order:
- visible content is the intended content
- width/height fit that content
- hover and motion attach to the same visible object
- right-click/drag/edit interactions reach the intended owner

**Minimal Verification Matrix**

| Check | Expected signal |
|---|---|
| Display mode content | Placeholder or compact content appears only when intended |
| Editing mode content | Real managed widgets appear instead of fallback content |
| Geometry | Width and height track the currently rendered content |
| Input | Root catchers disable themselves when widget-level interaction should take over |
| Motion | Hover expansion and reset occur on the same visible object the user is interacting with |

**Good Debug Order**

1. Find the visible owner.
2. Find the real content owner.
3. Find the geometry owner.
4. Find the editing/input owner.
5. Fix mismatches in that order.

If the bug survives step 2, inspect stale size baselines before touching animation values.
