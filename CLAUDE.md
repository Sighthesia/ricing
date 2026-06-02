Read [AGENTS.md](AGENTS.md) before starting any task.

## Skills

Load these for detailed context on specific topics:

| Skill | When to use |
|---|---|
| [async-layer-sync-lag-debugging](.agents/skills/async-layer-sync-lag-debugging/SKILL.md) | When a secondary layer on an async/coalesced commit path (compositor blur/mask region, cached/mirror copy) lags, stutters, overflows, or pops behind a per-frame main layer during fast animations. |
| [comment-before-declarations](.agents/skills/comment-before-declarations/SKILL.md) | When editing QML modules that should stay self-documenting and easy to scan. |
| [glass-liquid-design](.agents/skills/glass-liquid-design/SKILL.md) | When designing or modifying visible QML/Quickshell surfaces, motion, states, or interaction feedback. |
| [overlay-pointer-event-starvation](.agents/skills/overlay-pointer-event-starvation/SKILL.md) | When an inner/lower element stops getting hover/pointer events (no hover, hover popup never opens, or popup flickers open/closed) because an overlapping upper element or fullscreen overlay consumes them. |
| [per-frame-surface-resize-jank](.agents/skills/per-frame-surface-resize-jank/SKILL.md) | When an expand/collapse animation stutters because a per-frame size drives an expensive commit boundary (top-level/layer-shell window resize, compositor region, or per-frame model rebuild). Fix: fixed outer surface, animate clipped inner content. |
| [reveal-before-clip](.agents/skills/reveal-before-clip/SKILL.md) | When content inside an expanding/contracting surface (dockzone, island, drawer, menu) overflows or reads as harshly cut during the host's grow/shrink. Drive content reveal (opacity, slide, anchor edge) from the host's reveal progress before relying on a clip mask. |
| [reactive-measurement-layout-debugging](.agents/skills/reactive-measurement-layout-debugging/SKILL.md) | When diagnosing UI layout bugs where measured, preferred, target, actual, animated, or clipped sizes diverge. |
| [surface-owner-split-debugging](.agents/skills/surface-owner-split-debugging/SKILL.md) | When a visible UI surface has been moved or split from its prior owners and regressions appear in hover, editing, real content rendering, or content-driven sizing. |
| [visual-transition-rules](.agents/skills/visual-transition-rules/SKILL.md) | When adjusting QML visual styles, colors, radii, opacity, blur, shadows, spacing, scale, or related presentation variables. |
