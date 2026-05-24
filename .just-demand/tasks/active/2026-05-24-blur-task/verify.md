# Verify

- Confirm representative blur-enabled surfaces still use the same visual tokens but now have blur coverage flush to the visible edge.
- Confirm border/outline remains clearly visible on top for at least:
  - settings panel
  - launcher panel
  - context menu or widget picker
  - notification card or workspace hint capsule
- Check rounded corners for new seams, clipping, or dark/black edge artifacts.
- Run `git diff --check`.
- If a practical QML test/lint command exists for the touched area, run it; otherwise document why not.
