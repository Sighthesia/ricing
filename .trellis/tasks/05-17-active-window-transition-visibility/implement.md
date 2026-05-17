# Active Window Transition Visibility Implementation

## Steps

1. Refactor `ActiveWindow.qml` so it can keep old and new content layers separate during transitions.
2. Trigger a fade-out / swap / fade-in sequence that does not reuse the same visible content item.
3. Keep width animation on the widget root so layout changes still reflow smoothly.
4. Verify the widget still reports the correct focused title and icon after the transition finishes.

## Validation

- Inspect the QML for transition flow and binding correctness.
- Confirm the widget still fits in the bar layout budget.
- Confirm rapid focus changes do not leave the widget blank or stuck.

## Rollback point

- If the transition layering introduces flicker, revert the layered content change first and keep the width animation.
