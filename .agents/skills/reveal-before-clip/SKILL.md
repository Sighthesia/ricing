---
name: reveal-before-clip
description: Use when content inside an expanding/contracting surface (dockzone, island, drawer, menu) overflows or reads as harshly cut during the host's grow/shrink. Drive content reveal (opacity, slide, anchor edge) from the host's reveal progress before relying on a clip mask. 
---

# Reveal Before Clip

When a surface is *growing* to host content, prefer to **reveal** the content in sync with the parent's growth rather than **clip** overflowed content after the fact. Clipping is a safety net; reveal is the design.

## A. The Generic Pattern / Methodology

**Core Concept**

- An expanding surface has a **reveal domain** (how much of itself is actually visible right now) and a **content domain** (what wants to be drawn). The two domains must move together.
- Three legitimate ways to keep content inside an expanding surface:
  1. **Reveal in sync** — content opacity / offset / scale tracks the parent's reveal progress, so it appears *as the surface arrives to host it*. No clipping needed.
  2. **Wait for completion** — content stays invisible until the parent's animation settles, then fades in. No clipping needed.
  3. **Hard clip** — content is drawn at full size, and a rectangular `clip: true` mask keeps it inside the current bounds. Feels like cutting.
- (1) and (2) keep the user's mental model intact: content *grows in* with the host. (3) breaks the model: content was already drawn; the host caught up to hide it. Hard clipping is acceptable only as a **safety net** under (1) or (2), not as the primary strategy.

**Universal Checklist**

| Step | Check |
|---|---|
| 1 | Identify the **reveal progress** of the host surface (0 → 1 over the animation). |
| 2 | Drive every per-row or per-page visibility from that progress (e.g. row opacity 0 until fully inside; page slide from anchor edge). |
| 3 | Use the *final* geometry (rounded corners, ears) — not a rectangular approximation — to define the safe area. |
| 4 | Keep a thin rectangular clip as a safety net for off-by-one pixels and anti-aliasing, never as the main visual strategy. |
| 5 | For nested pages, anchor their entry to a visible edge of the host (left/right/top) so the eye reads the motion as "the page arrived", not "the page was cut". |

## B. The Specific Trap / Symptom

**Context** — In a Wayland shell's tray dockzone, hovering a tray icon expands the dockzone body downward and widens it to host a DBus menu. The menu drew at its full natural size (220 px) from the moment the body started expanding. The visible result: rows half-cut during the spring, text bleeding through the transparent rounded corners at the bottom, the rectangular clip producing a "scissors" line where the live body edge met the menu's lower rows.

**The trap** — fighting the cut by stacking `ShaderEffectSource + OpacityMask` to silhouette-clip the menu, by tightening insets, by removing per-page scale animations. Each fix made one symptom smaller and the next one worse: the texture sample introduced blurriness, the bigger inset truncated valid rows, the removed scale made navigation feel static. The root cause was never addressed: **content was being drawn before the host was ready to host it**.

**The fix shape** — switch the menu from "draw full, clip remainder" to "reveal in sync":
- Each row checks `y + height ≤ currentVisibleHeight` and only draws (opacity 1, mouse enabled) when fully inside.
- The page slides in from the **anchor edge** of the host (here, the same edge the menu attaches to), so the eye reads the motion as the page arriving with the body.
- The rectangular clip is kept as a one-pixel safety net; it is no longer doing the visual work.

## C. The Anti-Pattern vs Best Practice

| Anti-Pattern | Why it Fails |
|---|---|
| Drawing content at full size and letting `clip: true` hide the overflow | Reads as "scissors cut" — content is visibly truncated mid-shape. The cut also follows the host's *rectangle*, ignoring rounded corners and ears. |
| Using `ShaderEffectSource + OpacityMask` to silhouette-clip | Adds a texture-sample hop on every frame; introduces visible blurriness; compounds with layer-shell commit paths and slows the animation. |
| Increasing the conservative inset until "it looks mostly fine" | Trades overflow for over-truncation; valid rows disappear; the menu still looks wrong, just differently. |
| Removing page scale/overshoot to "stop text escaping" | Throws out a real motion signal. The escape was caused by the clip lag, not the scale. |

| Best Practice | Effect |
|---|---|
| Bind per-row or per-page visibility to the host's reveal progress | Content and host move as one object; no clip lag to chase. |
| Anchor content's entry to the host's **visible edge** (left/right/top), not the center | The eye reads "the page arrived with the glass", not "the page was exposed". |
| Keep a 1-px safety clip for off-by-one | Eliminates last-row half-pixels and antialias seams without doing visual work. |
| For non-rectangular silhouettes (rounded corners, ears), let the *visibility* domain do the work | Don't try to mask non-rectangular shapes with rectangular clips. |

## D. Generalizable Rules

**Agnostic Rules**

- **Reveal domain before content domain.** When a host is animating, define what part of it is *visible right now* before defining what content it shows. The content's visibility is a function of the host's.
- **Anchor entry to a visible edge.** Content that enters from where the host is currently visible reads as motion. Content that is *exposed by* the host reads as cutting.
- **Use integer-safe thresholds.** `y + height <= availableHeight - 1` (or similar) avoids sub-pixel flicker and antialias seams.
- **Disable interaction alongside visibility.** A row that is opacity 0 must also be `enabled: false`, so hover-driven popups do not open on the unseen row.
- **The rectangular clip is a safety net, not a strategy.** It is for off-by-one pixels; the visual work is done by the reveal.
- **Do not draw rounded background corners inside the clipped content viewport.** If the actual visible panel background lives inside a `clip: true` viewport, the viewport rectangle can square off the far corners. Keep the visible rounded background as a sibling or outer layer, and let the inner clipped viewport handle only payload overflow.

**Warning Signs**

- An item is drawn at full size while its host is animating from 0 to full.
- A new fix keeps introducing new visual artifacts (blur from sampling, over-truncation from insets, jitter from removing motion).
- A "fix" is making one symptom smaller and another bigger; the root cause is upstream.
- The user's first complaint was a hard cut, the second was blurriness, the third was over-truncation. The trap is the strategy, not any one of its symptoms.
- The clip shape is rectangular but the host shape is not (rounded corners, ears, blobs).

## E. Universal Verification Strategy

**Agnostic Testing Logic**

| Verification | What it Proves |
|---|---|
| Run the expand animation at 0.25x speed and inspect the content | If you see "content arriving" with the host, reveal is working. If you see "content being exposed" by the host, clip is still doing the work. |
| Inspect with a non-rectangular host (rounded corners, ears) | Reveal should hide the non-rectangular part; a rectangular clip cannot. |
| Set `availableHeight = 0` mid-animation | Reveal-based content should be invisible and non-interactive. Clip-only content still draws at full size and may still interact through padding. |
| Set the host's reveal progress to a non-rectangular path (e.g. an L-shape) | Reveal-based content should follow the path; clip-based content cannot. |
| Check `enabled` state on rows/buttons during the animation | A row with opacity 0 must also be `enabled: false`; reveal must be coordinated with interaction. |

**Cleanup Rule** — If reveal alone is correct, the rectangular clip can become a single-pixel safety net (or removed where measurement is exact). Never delete the test for the trap (non-rectangular host with mid-animation reveal) — it is the regression that catches the next time someone reaches for `clip: true` as the first tool.
