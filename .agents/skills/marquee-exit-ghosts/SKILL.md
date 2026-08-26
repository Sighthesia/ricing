---
name: marquee-exit-ghosts
description: Use when modifying Afloat MarqueeLabel title scrolling, switch transitions, falling ghosts, or diagnosing long titles that disappear instead of falling during a window/media change.
---

# Marquee Exit Ghosts

Preserve the visible outgoing characters when a marquee title changes after deep scrolling.

## Verified Trap

`MarqueeLabel.spawnGhosts()` used to inspect only the first `transitionMaxChars` characters. After the marquee had moved farther right into a long title, the characters visible in the clipped viewport were beyond that prefix, so no outgoing ghosts were created. The new title faded in while the old title appeared to vanish past the left edge.

Rapid title changes add a second trap: an interrupted sweep can already have
standing ghosts while `_collapseRevealedChars()` creates another falling set.
Those generations can occupy the same horizontal positions and render as
doubled glyphs with simultaneous fall effects.

## Correct Pattern

- Measure each old character's prefix position plus the current `scrollX`.
- Skip characters wholly outside the outgoing viewport.
- Continue scanning the entire old title until the visible ghost cap is reached.
- Keep the cap to bound object creation; the cap is a creation limit, not a prefix slice.
- On a new interrupt, retire the previous standing ghost generation before
  creating ghosts for the current sweep. Never let two transition generations
  own the same outgoing layer.

## Verification

- Run `qs -p tst_marquee_drift.qml`.
- Require the `deep-exit-ghost` check to pass after the old title has scrolled deeply.
- Require the pacing check to pass for a very long title.
- Temporarily restore the prefix-limited loop; `deep-exit-ghost` must fail.
- Run the rapid-interrupt scenario and require only one active ghost generation.
