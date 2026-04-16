# SuperIsland Visual Language Unification

## Goal

Refactor the standalone `media control` panel so it follows the unified SuperIsland panel language instead of reading like a traditional dropdown media popup.

## Confirmed Scope

- Only refactor the standalone panel opened from the bar media widget.
- Do not redesign the compact bar widget interaction model in this iteration.
- Keep existing media data, playback actions, and panel open/close behavior intact.

## Visual Intent

- Make the panel feel like it expands from the SuperIsland family rather than appearing as a generic floating card.
- Prefer one continuous shell with inner capsule/group structure over stacked ad-hoc rectangles.
- Reuse shared shell surfaces, shared tokens, and existing interaction affordances.

## Product Intent

- The media panel should feel visually consistent with SuperIsland expanded surfaces.
- The panel should preserve readability for artwork, track metadata, progress, and transport actions.
- The redesign should stay safe under hot reload and avoid creating a second divergent media visual language.

## Requirements

- Keep `AnimatedPanelBase` lifecycle and positioning behavior unless a minimal structural adjustment is required.
- Refactor `MediaPanelContent.qml` toward a SuperIsland-style hierarchy using shared shell components and shared tokens.
- Reduce local feature-specific surface styling when a shared shell treatment can be reused.
- Keep hover, ripple, and click affordances pointer-friendly.
- Avoid adding unrelated settings or persistence changes.

## Acceptance Criteria

- [ ] The standalone media control panel visually reads as part of the SuperIsland family.
- [ ] The panel uses shared shell surfaces/tokens instead of recreating local floating-panel chrome.
- [ ] Track info, artwork, progress, and transport controls remain functional after the refactor.
- [ ] The change stays scoped to the standalone panel path and any directly shared media presentation pieces it depends on.
- [ ] `timeout 5 qs --path .` passes after the change.
