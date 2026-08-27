---
name: marquee-exit-ghosts
description: Use when modifying Afloat MarqueeLabel title scrolling, switch transitions, falling ghosts, or diagnosing long titles that disappear instead of falling during a window/media change.
---

# Marquee Exit Ghosts

Preserve the visible outgoing characters when a marquee title changes after deep scrolling.

## Verified Trap

1. **Prefix slice:** `spawnGhosts()` inspected only the first `transitionMaxChars` characters. After deep marquee scroll the visible window was beyond that prefix, so no ghosts were created and the long title vanished past the left edge.
2. **Half-entered flash:** interrupting a sweep and spawning the full `oldText` makes a half-revealed incoming title flash complete before falling. Only already-revealed chars should fall; unrevealed ones must vanish.
3. **Standing-ghost double:** an interrupted sweep can carry standing ghosts while the next transition creates another set at the same x; without overlap checks they render as doubled glyphs.
4. **Desktop flick:** `ActiveWindow.displayTitle` briefly becomes `desktopLabel` during workspace switches (`window → desktop → next window`). Animating `window → desktop` clears the outgoing window's falling ghosts and the desktop itself flashes before the next window arrives.
5. **Acceleration cap:** capping `marqueeLegDuration()` at 8000 ms accelerated long titles (1289 px overflow: 8 s vs 23 s at constant 18 ms/px), reading as a speed change per title length.
6. **Kerning handoff twitch:** `Text` with `kerning:true` vs per-char `Text` with `kerning:false` produces ~1 px prefix drift at handback.

## Correct Pattern

- **Constant speed:** `marqueeLegDuration() = Math.max(2000, overflow * 18)` — no `maxScrollLegMs` cap. `tst_marquee_drift.qml` asserts `overflow 6400 → 115200 ms` linear.
- **Non-interrupted exit (`!wasActive`):** capture `scrollX` (`label.x` or `_preservedScrollX`, clamped to `[-maxScrollX,0]`), `_clearGhosts()`, then `spawnGhosts(oldText, fallSpan, scrollX, viewRight)` scanning the whole `oldText` and counting only visible ghosts toward `transitionMaxChars`.
- **Interrupted exit (`wasActive`):** do **not** spawn full `oldText`. Compute `elapsed = Date.now() - _sweepStart`, then `_collapseStandingGhosts()` (re-stagger ghosts with `y==0 && opacity>=0.99`, overlap-checked) and `_collapseRevealedChars(elapsed, fallSpan)` (only chars with `delays[i]+scanGapMs <= elapsed` fall at `i*8`). `_stopSweepRow()` after collapse. Standing ghosts keep falling; unrevealed chars vanish without flashing.
- **Desktop coalesce (`ActiveWindow.qml`):** `displayTitle === desktopLabel` starts `desktopHold:120ms` storing `_pendingDesktopPrev`; a new window within 120 ms cancels the hold and animates `pendingPrev → newWindow` directly, skipping desktop. Hold expiry animates `pendingPrev → desktop` only if still on desktop.
- **Kerning:** `label` and scan-row `Text` both use `font.kerning: false`; offsets are measured via `TextMetrics` prefix advances (`_charOffsets`) so handback lands pixel-for-pixel.

## Verification

- Run `qs -p tst_marquee_drift.qml` — expect `10 passed, 0 failed`.
- `deep-exit-ghost`: old title scrolled ~1289 px, still leaves visible falling ghosts; immediate ghost at switch boundary.
- `pacing-constant-speed`: `marqueeLegDuration()` linear `overflow*18` (e.g. 6400 px → 115200 ms), `pacing-bounded` never exits viewport.
- `rapid-interrupt` / `title-churn`: only revealed chars fall, standing ghosts re-staggered, `maxGhosts <= 48` (overlap-checked).
- Restore prefix-limited loop or full-spawn on interrupt → `deep-exit-ghost` or flash-full regresses and test fails.
- Desktop hold: `window → desktop (120 ms hold) → next window` coalesces to `window → next window`; direct `window → desktop` hold expiry still animates correctly.
- Kerning: handback does not change prefix offsets (`_charOffsets` vs label metrics).
