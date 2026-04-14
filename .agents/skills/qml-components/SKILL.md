---
name: qml-components
description: Use when building UI elements with DymicShell tokens, semantic colors, theme values, base components, or interactive surface patterns.
---

# UI Components & Tokens

## Token System
### Colors: `Colors.*`
- Never hardcode feature-level hex colors.
- Prefer `Colors.background`, `Colors.surface`, `Colors.text`, `Colors.textMuted`, `Colors.border`, `Colors.highlight`, and `Colors.destructive`.
- If a semantic color is missing, extend `config/Colors.qml` instead of adding a local literal.

### Animation: `Theme.anim.*`
- All duration and easing choices should derive from `Theme.anim.*`.
- Prefer `Theme.anim.move*` for layout motion, `Theme.anim.highlight*` for emphasis, and `Theme.anim.spring*` / `Theme.anim.pulseSpring*` for expressive size changes.
- Any unavoidable new timing literal must be marked with `// FIXME: use Theme.anim.*`.

### Sizes and Typography: `Theme.*`
- Use `Theme.barHeight`, `Theme.cornerRadius`, `Theme.fontFamily`, `Theme.fontSizeBody`, etc.
- For bar-internal micro-layout, prefer `Theme.barWidget.*`.

## Preferred Base Components
- `modules/bar/AnimatedPanelBase.qml` - dropdown/panel base with safe surface lifecycle.
- `modules/bar/FloatingShellSurface.qml` - shared shell surface for SuperIsland-family popups, cards, menus, and inner panels.
- `modules/bar/StaggerItem.qml` - enter/exit stagger wrapper.
- `modules/bar/HoverRevealHighlight.qml` - standard hover affordance.
- `modules/bar/ClickRipple.qml` - standard click feedback.
- `modules/bar/BarWidgetWrapper.qml` - bar widget container, drag support, shared animation contract.

## Shared Shell Surface Pattern

- When a panel, popup, inner card, badge, or action row should read like the
  SuperIsland family, prefer `FloatingShellSurface.qml` over a local shell
  `Rectangle`.
- Put shared shell sizes, insets, radii, and alpha values in
  `config/ThemeCards.qml`.
- Typical token families to reuse first:
- `ThemeCards.shell*` for outer shells
- `ThemeCards.panel*` for general panel spacing
- `ThemeCards.compact*` for inner control-center cards and action rows
- `ThemeCards.notification*` for notification card geometry
- `ThemeCards.overlayNav*` for expanded-page segmented controls
- Preserve content layout when swapping shell bases: move padding to
  `contentMargin` and avoid reworking business layout unless needed.

## Delegate Animation Ownership

- If a repeated delegate already owns its enter/exit animation, do not move that
  animation into a shared shell wrapper during a visual refactor.
- For list-wide stagger, let the parent assign timing slots from visual order and
  let the delegate continue to execute its own motion.
- A safe pattern for popup card stacks is: parent computes `enterDelay` /
  `exitDelay`, delegate applies those delays before restarting its existing
  `ParallelAnimation`.

## Attached Panel Geometry
- When a floating panel must look attached to a pill or bar affordance, keep the main affordance, bridge, and panel body as separate geometric responsibilities even if one `ShapePath` renders the final shell.
- Do not create the inner corner by cutting directly into the bridge or the panel top edge. That reads like a notch carved out of the main body.
- Prefer this shape model for Noctalia-style attached corners:
- bridge body stays rectilinear
- add a dedicated right-triangle shoulder between bridge and panel
- apply a single quarter-circle `PathArc.Counterclockwise` cut only inside that triangle shoulder
- Clamp the cut radius to both available height and horizontal shoulder span so the arc removes the whole triangle tip instead of leaving a sharp remnant.
- If a seam can appear under fractional scaling, use a small overlap like `1px`, but keep that overlap separate from the shoulder width or cut radius.
- In `modules/bar/widgets/SuperIslandWidget.qml`, the stable pattern is: compute available corner height first, derive `cutRadius`, then set `cornerStartY = panelTop - cutRadius` so the cut fully covers the shoulder tip.

### Attached Panel Collapse Tail
- When an attached panel collapses back into the pill, do not keep drawing bridge shoulders once the panel body is too small to visually support them.
- If the remaining attached height approaches the seam overlap or a tiny visual sliver, hide or geometrically retire the bridge instead of letting it shrink into floating side needles.
- Prefer a tail rule based on reveal progress or visible panel height, not on opacity alone.
- The final collapse read should be: visible panel shrinks toward the pill, then only the pill remains. It should never read as two suspended arc fragments hanging under the bar.
- In `modules/bar/widgets/SuperIslandWidget.qml`, a practical pattern is a host-owned flag such as `_attachedCollapseTailHidden` that disables both `_overlayShellHost` and `_overlayPanelHost` for the last small slice of collapse.

### Interactive Surface Pattern
```qml
HoverRevealHighlight { anchors.fill: parent; hovered: area.containsMouse }
ClickRipple { id: ripple; anchors.fill: parent }
MouseArea {
    id: area
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: (mouse) => { ripple.triggerRipple(mouse.x, mouse.y); /* action */ }
}
```
If the surface uses custom fills or highlights, enable adaptive contrast so hover feedback stays visible.
