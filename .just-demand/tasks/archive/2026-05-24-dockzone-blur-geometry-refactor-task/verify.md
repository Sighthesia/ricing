# Verify

## Acceptance Criteria

- Dockzone body and ears use exposed geometry-aligned blur source parts instead of body-only blur.
- `BarWindow.qml` builds the blur region from all applicable dockzone parts for left/right sections.
- Existing bar layout and dockzone motion semantics are preserved.
- No `modules/island` files are changed.

## Checks

1. Inspect the diff for scope and simplicity.
2. Run `git diff --check`.
3. Run QML lint/syntax checks if available.
4. Confirm `git status --short` does not show `modules/island/*` modifications caused by this task.

## Known Limitation To Watch

`BackgroundEffect.blurRegion` appears not to preserve nested subtract/concave `Region` composition. Verification should reject reintroducing subtract-based ear regions as the main solution.
