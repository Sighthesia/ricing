---
name: comment-before-declarations
description: "Require a brief descriptive comment immediately before major QML element declarations. Use when editing QML modules that should stay self-documenting and easy to scan."
---

# Comment Before Declarations

Follow this rule when editing QML:

- Place a short English comment immediately before each major element declaration.
- Use the rule for `Variants`, `Item`, `PanelWindow`, and reusable visual components such as `ScreenCornerMask`.
- Keep comments brief and descriptive; explain intent, not mechanics.
- Do not add comments that merely restate the line below.

## Example

```qml
// Keep the root item centered in the window.
Item {
    readonly property int radius: 24
}
```

## Goal

The code should remain readable at a glance without needing long inline explanations.
