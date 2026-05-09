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

---

## Testing Requirements

<!-- What level of testing is expected -->

(To be filled by the team)

---

## Code Review Checklist

<!-- What reviewers should check -->

(To be filled by the team)
