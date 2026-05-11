# Quality Guidelines

> Code quality standards for frontend development.

---

## Overview

<!--
Document your project's quality standards here.

Questions to answer:
- What patterns are forbidden?
- What linting rules do you enforce?
- What are your testing requirements?
- What code review standards apply?
-->

(To be filled by the team)

---

## Forbidden Patterns

<!-- Patterns that should never be used and why -->

(To be filled by the team)

---

## Required Patterns

<!-- Patterns that must always be used -->

### Convention: Comment Before Major Declarations

**What**: In QML files, place a short descriptive English comment immediately before each major element declaration.

**Why**: This keeps dense QML modules readable at a glance and makes the intent of each declaration obvious during future edits.

**Example**:
```qml
// Keep the mask reusable across all screen corners.
Item {
    // Expose the current corner size to child items.
    readonly property int cornerSize: 24
}
```

**Related**: Use this convention in `modules/background` and any future QML modules that are expected to stay self-documenting.

### Convention: Preserve Canvas Path Semantics When Porting Visual Shapes

**What**: When porting QML `Canvas` shapes from a reference project, preserve the source path semantics: anchor position, path order, arc center, radius, start/end angles, and clockwise/counterclockwise direction.

**Why**: Small arc-direction changes can invert the visual meaning of a shape, such as turning an inner quarter-circle edge decoration into a convex side bulb.

**Example**:
```qml
// Match the source inner corner arc instead of approximating the silhouette.
Canvas {
    onPaint: {
        const ctx = getContext("2d")
        ctx.beginPath()
        ctx.moveTo(0, 0)
        ctx.lineTo(width, 0)
        ctx.lineTo(width, height)
        ctx.arc(0, height, width, 0, -Math.PI / 2, true)
        ctx.fill()
    }
}
```

**Related**: Use this convention when adapting dynamic-island ears, screen-corner masks, or any decorative QML geometry copied from another shell.

### Convention: Normalize Legacy Widget IDs During Renames

**What**: When a registered bar widget is renamed, keep the normalization path aware of the old `id`, `instanceKey`, and fallback `source` so persisted layouts can migrate without surfacing the legacy name at runtime.

**Why**: Layout state may be stored on disk, so a direct rename without normalization can leave stale references in warnings, selectors, or restored widget entries.

**Example**:
```js
// Accept old persisted entries, but emit only the new registry identity.
function normalizeWidgetEntry(widgetEntry) {
    const id = widgetEntry.id === "placeholder" ? "placeholder" : "placeholder"
    return {
        id,
        instanceKey: id + ":0",
        source: "../../modules/bar/widgets/Placeholder.qml",
    }
}
```

**Related**: Use this when bar widget registry entries, source paths, or labels are renamed in `services/barlayout/`.

> **Warning**: Do not leave the legacy widget source string in the default registry after the runtime name changes. The warning output can still expose the old path even when the visible widget is already using the new component.

---

## Testing Requirements

<!-- What level of testing is expected -->

(To be filled by the team)

---

## Code Review Checklist

<!-- What reviewers should check -->

(To be filled by the team)
