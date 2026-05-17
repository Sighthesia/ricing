# Active Window Transition Visibility Design

## Goal

Make active window title and icon changes visually obvious by avoiding same-frame replacement.

## Scope

- `modules/bar/widgets/ActiveWindow.qml` only.
- Keep the existing `Services.NiriService` data source and bar layout contract unchanged.

## Approach

- Stop reusing the same visible nodes for both old and new content.
- Keep an outgoing content layer visible until its fade-out completes.
- Bring in the incoming content layer separately so opacity changes are observable.
- Preserve the root width animation, but let content opacity transition independently.

## Constraints

- Do not add new shared state or service APIs.
- Do not change how `NiriService` computes focus changes.
- Keep the widget compact enough for the current bar section.

## Risks

- Rapid focus changes can stack animations if the implementation is too eager; the transition logic should stay minimal.
- If the incoming and outgoing layers overlap badly, the widget may look blurry, so timing must be short and restrained.
