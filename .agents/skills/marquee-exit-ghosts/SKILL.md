---
name: marquee-exit-ghosts
description: Use when modifying Afloat MarqueeLabel title scrolling, switch transitions, falling ghosts, or diagnosing long titles that disappear instead of falling during a window/media change.
---

# Marquee Exit Ghosts

Preserve the visible outgoing characters when a marquee title changes after deep scrolling.

## Verified Trap

`MarqueeLabel.spawnGhosts()` used to inspect only the first `transitionMaxChars` characters. After the marquee had moved farther right into a long title, the characters visible in the clipped viewport were beyond that prefix, so no outgoing ghosts were created. The new title faded in while the old title appeared to vanish past the left edge.

Rapid title changes add a second trap: an interrupted sweep can already have
standing ghosts while the next transition creates another falling set. Those
generations can occupy the same horizontal positions and render as doubled
glyphs with simultaneous fall effects. Clearing the old generation must not
also suppress creation of the new transition's ghosts.

## Correct Pattern

- Measure each old character's prefix position plus the current `scrollX`.
- Skip characters wholly outside the outgoing viewport.
- Continue scanning the entire old title until the visible ghost cap is reached.
- Keep the cap to bound object creation; the cap is a creation limit, not a prefix slice.
- On a new interrupt, retire the previous standing ghost generation before
  creating ghosts for the current `oldText`. Capture `scrollX` first, then
  clear and create exactly one outgoing generation.
- Do not omit the fresh `spawnGhosts(oldText, ...)` call after clearing an
  interrupted sweep: early interrupts may have no revealed scan characters,
  but the outgoing title still needs a falling effect.
- Keep the real label and scan-row glyph layout on the same kerning setting;
  otherwise handback from per-character `Text` items to the single `Text`
  produces a small but visible spacing jump.

## Verification

- Run `qs -p tst_marquee_drift.qml`.
- Require the `deep-exit-ghost` check to pass after the old title has scrolled deeply.
- Require the pacing check to pass for a very long title.
- Temporarily restore the prefix-limited loop; `deep-exit-ghost` must fail.
- Run the rapid-interrupt scenario and require only one active ghost generation.
- Verify that an interrupt before the incoming scan reveals a character still
  produces falling ghosts for the outgoing title.
- Verify that a long-title exit creates a visible ghost immediately at the
  switch boundary and that the handback does not change prefix offsets.
