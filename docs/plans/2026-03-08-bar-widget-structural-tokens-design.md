# Bar Widget Structural Tokens — Design Document

**Date:** 2026-03-08  
**Status:** Approved

## Overview

Unify WorkspaceWidget internal layout magic numbers into a reusable Theme token namespace so bar widgets can share the same structural rhythm.

This change targets visual structure tokens only. It does not expand user-facing settings and does not alter runtime behavior defaults.

## Problem

WorkspaceWidget still carries a private cluster of internal dimensions inside the component:

- horizontal content padding
- focus icon size
- compact icon size
- icon spacing
- pill spacing
- pill inner horizontal padding
- focus icon/title gap
- focus pulse padding

These values currently live only in the widget, which creates three problems:

1. other bar widgets cannot reuse them directly
2. uiScale does not automatically govern this layer of internal spacing
3. future components are encouraged to add new magic numbers instead of extending Theme

## Decision

Introduce a new global namespace in Theme:

```qml
Theme.barWidget.*
```

This namespace is reserved for reusable bar-internal structural tokens, similar in spirit to how Theme.anim.* centralizes animation behavior.

## Token Map

| New token                           | Replaces         | Purpose                                   |
| ----------------------------------- | ---------------- | ----------------------------------------- |
| `Theme.barWidget.contentPaddingH`   | `_padH`          | Main pill horizontal content padding      |
| `Theme.barWidget.primaryIconSize`   | `_iconSize`      | Focus-mode icon size                      |
| `Theme.barWidget.compactIconSize`   | `_smallIcon`     | Workspace-pill icon size                  |
| `Theme.barWidget.iconSpacing`       | `_iconSpacing`   | Gap between icons in a compact row        |
| `Theme.barWidget.pillSpacing`       | `_pillGap`       | Gap between workspace pills               |
| `Theme.barWidget.pillPaddingH`      | `_pillPadH`      | Horizontal padding inside workspace pills |
| `Theme.barWidget.iconLabelSpacing`  | `_iconTitleGap`  | Gap between focus icon and title          |
| `Theme.barWidget.focusPulsePadding` | `_focusPulsePad` | Outward bleed for focus pulse             |

All values are derived with `Math.round(base * uiScale)` to preserve proportionality under global UI scaling.

## Boundaries

The following values remain outside `Theme.barWidget.*`:

| Value                                       | Reason                                                      |
| ------------------------------------------- | ----------------------------------------------------------- |
| `revertDelay`                               | behavior timing, already a setting                          |
| `revertCooldown`                            | internal event timing, not a structural token               |
| `titleMaxWidth`                             | functional content constraint, already a setting            |
| `Theme.widgetPadding` / `Theme.iconPadding` | broader bar-shell spacing, not widget-internal micro layout |

## Implementation Scope

### Code

| File                                      | Change                                                                            |
| ----------------------------------------- | --------------------------------------------------------------------------------- |
| `config/Theme.qml`                        | Add `Theme.barWidget.*` structural tokens                                         |
| `modules/bar/widgets/WorkspaceWidget.qml` | Replace 8 widget-local hardcoded dimensions with `Theme.barWidget.*`              |
| `AGENTS.md`                               | Require bar-internal sizing to use `Theme.barWidget.*` before adding new literals |

### Non-goals

- no bulk refactor of unrelated widgets in this pass
- no new user-facing settings
- no visual redesign of WorkspaceWidget

## Expected Outcome

The default appearance stays unchanged, but the sizing model becomes globally reusable and governed by the existing theme scale.