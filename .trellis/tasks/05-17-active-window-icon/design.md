# Active Window Icon Design

## Goal

Show the focused window's app icon in the bar's active window widget and animate content changes smoothly.

## Scope

- `modules/bar/widgets/ActiveWindow.qml` only.
- Use existing `Services.NiriService.activeTitle` and `Services.NiriService.activeAppId` data.
- Keep the current bar layout and widget ownership unchanged.

## Approach

- Render the active window as a compact inline row.
- Derive the icon source from `image://icon/` and the focused app id.
- Keep the title text as the primary label and preserve the `Desktop` fallback.
- Use a width `Behavior` on the root widget so the bar reflows smoothly as the title changes.
- Use a short fade-out / swap / fade-in sequence when the focused window data changes.

## Constraints

- Do not introduce new shared service state.
- Do not change how `NiriService` computes focus or app id.
- Keep the widget compact enough for the existing section layout.

## Risks

- If the focused app id changes rapidly, animations may queue; the implementation should stay simple and not retain intermediate states.
- Some app ids may not resolve to an icon; the UI must degrade gracefully without visual noise.
