---
name: qml-components
description: Token system, Semantic Colors, Theme values, Base components, and Interactive Surface Patterns for DymicShell. Use when building UI elements.
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
- `modules/bar/StaggerItem.qml` - enter/exit stagger wrapper.
- `modules/bar/HoverRevealHighlight.qml` - standard hover affordance.
- `modules/bar/ClickRipple.qml` - standard click feedback.
- `modules/bar/BarWidgetWrapper.qml` - bar widget container, drag support, shared animation contract.

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