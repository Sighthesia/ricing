# Active Window Icon Implementation

## Steps

1. Update `modules/bar/widgets/ActiveWindow.qml` to render an app icon alongside the title.
2. Add a width transition so title-size changes animate smoothly.
3. Add a brief content fade transition so icon/title updates do not pop.
4. Keep `Desktop` as the fallback title and tolerate empty or missing app ids.

## Validation

- Inspect the updated QML for syntax and binding errors.
- Confirm the widget still fits inside the existing bar section width budget.
- Confirm the widget does not depend on any new service API.

## Rollback point

- If the transition behavior feels unstable or too noisy, revert only the animation block in `ActiveWindow.qml` and keep the icon/title layout.
