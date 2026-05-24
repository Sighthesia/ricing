# Implement

1. Start with the repeated simple-panel pattern and make the smallest reusable fix.
2. Preferred direction: separate the blur-bearing fill layer from the visible border/outline layer so blur can cover the full surface geometry while border remains a transparent overlay.
3. Update the blur region source/radius so blur coverage reaches the intended visible edge instead of stopping at the old inset ring.
4. Apply the same structural fix consistently to the simple-panel files listed in `context.md`.
5. Inspect `DockzoneSurfaceRoot.qml` and `IslandBody.qml` only after the simple-panel path is understood. If the same edge-coverage issue exists there, adapt carefully without discarding the already-dirty local changes.
6. Keep edits minimal. Prefer small local changes over introducing a new shared component unless duplication becomes clearly worse than the local patches.
7. Do not commit.
