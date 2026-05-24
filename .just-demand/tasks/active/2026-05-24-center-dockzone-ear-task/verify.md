# Verify

- Static verification:
  - `qmllint modules/island/IslandBody.qml` -> passed with no output.
  - `git diff -- modules/island/IslandBody.qml` -> confirmed the fix only removes the double-fill body path and replaces it with a single-pass canvas fill.
- Remaining manual verification:
  - visually confirm the center dockzone no longer shows the darkened inverted-trapezoid overlap;
  - confirm left/right dockzones are unchanged in the running shell.
- Follow-up static verification:
  - `qmllint modules/island/IslandBody.qml modules/island/IslandWindow.qml`
  - `git diff --check`
  - inspect diff to confirm center blur is no longer body-only and left/right bar dockzone code remains unchanged.
