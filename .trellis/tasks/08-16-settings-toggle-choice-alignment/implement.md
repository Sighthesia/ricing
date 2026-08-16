# Implementation Plan

1. Inspect the current Row inline/choice geometry and Content `showDropdownFor()` path; identify the smallest owner boundary that explains each mismatch.
2. Correct inline Toggle host sizing/vertical centering at the Row boundary while preserving `44x20`, right reset reservation, transitions, and input ownership.
3. Normalize Choice root/header surface bounds so the visible surface starts at the same content edge as other controls and does not introduce a second offset layer.
4. Keep Content popup placement sourced from the authoritative Choice `headerItem`; adjust only mapping/geometry if tests demonstrate a mismatch.
5. Add coordinate-level regression assertions for Toggle center, Choice/header alignment, popup origin/width, and existing interaction contracts.
6. Run `qmllint`, relevant QML suites, `python3 -m pytest -q`, `git diff --check`, and `timeout 15s qs -p .`; investigate all new warnings.
7. Update `.trellis/spec/frontend/quality-guidelines.md` with the geometry ownership and mapped-coordinate contracts, then commit and archive the task.

## Risk Checks

- Do not “fix” the symptom by changing the Toggle's own size or adding a second card/background.
- Do not position the popup from the Choice root if `headerItem` is the painted surface; both must remain the same geometry source.
- Verify reset-slot reservation after any width change so Choice and Toggle cannot consume the reset button area.
- Compare mapped coordinates in one coordinate space; local `x/y` values from different parents are not valid evidence.
- Preserve per-screen popup ownership and the existing keyboard/focus lifecycle.

## Verification Commands

- `python3 .trellis/scripts/task.py validate 08-16-settings-toggle-choice-alignment`
- `qmllint` for modified QML and affected tests
- `qmltestrunner` for controls/pages/panel suites; record the known silent-runner limitation if reproduced
- `python3 -m pytest -q`
- `git diff --check`
- `timeout 15s qs -p .`
