---
name: multi-instance-focus-ownership
description: Use when a text field, search box, or editable control works the first time but stops accepting input on reopen, page switch, or second mount because multiple live instances, wrappers, or lifecycle hooks compete for focus. Applies when hover and pointer are fine but keyboard input goes to the wrong instance or nowhere. Not for pointer starvation from overlapping layers; use `overlay-pointer-event-starvation`. Not for visible-owner migrations that break rendering/editing/geometry together; use `surface-owner-split-debugging`.
---

# Multi-Instance Focus Ownership

Debug and prevent keyboard-focus bugs caused by more than one live instance believing it owns the same editing session.

## The Generic Pattern / Methodology

**Core Concept**

- Keyboard focus must have one active owner per interaction state.
- Bugs appear when multiple mounted instances of the same editable control, or both a wrapper and its child, can request focus during the same reopen or page transition.
- The reliable pattern is: one focus policy, one current owner, one reopen entry point, and explicit focus release when that owner stops being current.

**Universal Checklist**

| Check | Question |
|---|---|
| Live instances | How many mounted copies of the editable control exist across compact/detail/page variants? |
| Ownership rule | Which exact state makes one instance the only allowed focus owner? |
| Entry point | Is there one outer lifecycle path that reassigns focus on reopen/page switch? |
| Release path | Does the old owner explicitly drop focus when hidden, deactivated, or replaced? |
| Wrapper conflict | Can a parent container and child input both call focus APIs during the same transition? |

- Gate focus with a single derived boolean that answers "may this instance own focus right now?".
- Route reopen and page-switch focus through one outer function instead of scattering focus calls across loaders, children, and completion hooks.
- Clear focus when an instance stops being current; do not leave dormant inputs with `focus: true`.

## The Specific Trap / Symptom

**Context**

- In an island-style launcher, the first open focused the search box correctly.
- The second open showed the same UI but typing no longer went into the visible input.
- The root cause was not pointer delivery. Multiple launcher instances existed at once, and both the page wrapper and inner search field requested focus at different lifecycle moments.
- The fix succeeded only after making the visible page the sole focus owner, clearing focus from non-current instances, and resetting page state on close so reopen started from one predictable route.

## The Anti-Pattern vs. Best Practice

❌ **The Anti-Pattern**

- Keep multiple live instances of the same inputable surface and let each decide for itself when to call focus.
- Leave `focus: true` on dormant inputs.
- Trigger focus from several places such as component completion, loader completion, page-change hooks, and child-local callbacks without a single winner.
- Close the surface visually but keep the old page or old focus owner logically active for the next reopen.

✅ **The Best Practice**

- Derive a single ownership predicate for each instance from visibility plus current mode/page.
- Reassign focus from one outer reopen/page-switch function that first chooses the intended owner, then asks only that owner to focus itself.
- Explicitly clear focus when an instance loses ownership.
- Reset close-time state that would otherwise resurrect the wrong page or stale owner on the next open.

## Generalizable Rules

**Agnostic Rules**

- A control that can appear in more than one mounted variant must not self-elect as focus owner without checking a shared ownership rule.
- If a wrapper may focus itself for keyboard handling, it must defer to an inner editable control when text entry is the current task.
- Reopen behavior should be deterministic: the same visible state must map to the same focus owner every time.
- Hidden or inactive editable controls must release focus instead of relying on visibility alone.
- If a bug reproduces only on second open or after navigation, inspect stale owners before changing timing constants.

**Warning Signs**

- First open accepts typing, second open does not.
- Cursor visibility and actual keyboard input disagree.
- Two variants of the same search box exist in different pages or compact/detail shells.
- Focus calls are spread across loaders, page-change handlers, and child components.
- Closing and reopening preserves an old detail page when the user expects a fresh overview state.

## Universal Verification Strategy

**Agnostic Testing Logic**

- Reproduce the full lifecycle, not just initial mount: first open, close, second open, page switch, close, reopen.
- Verify both assignment and release: the intended owner gains focus, and every non-current peer drops it.
- Test transitions where the same logical feature exists in multiple mounted variants.
- Prefer controlled state transitions over manual clicking only, so reopen order is repeatable.

**Minimal Verification Matrix**

| Check | Expected signal |
|---|---|
| First open | Visible editable control accepts typing immediately |
| Second open | Same control still accepts typing without extra click |
| Page switch | Focus follows the newly active editable control only |
| Inactive peer | Hidden or non-current peer no longer owns focus |
| Close and reopen | Reopen starts from the intended default state and owner |

**Good Debug Order**

1. Count all live editable instances.
2. Define the one ownership rule.
3. Centralize focus assignment.
4. Add explicit focus release for non-owners.
5. Reset stale close-time state if reopen still chooses the wrong owner.

If focus still fails after step 4, inspect whether the outer surface must explicitly reacquire keyboard focus before the child can do so.
