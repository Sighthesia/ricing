# Implement

## Scope

Implement only the bar dockzone blur geometry refactor for task `2026-05-24-dockzone-blur-geometry-refactor-task`.

## Plan

1. Inspect `modules/bar/DockzoneSurfaceRoot.qml`, `BarSection.qml`, `BarContent.qml`, and `BarWindow.qml` before editing.
2. Replace the single body-only blur export with a small, explicit list/model of blur parts for the section. Each part should correspond to an existing visible body/ear geometry source and include radius/per-corner radius data as needed.
3. Update `BarSection.qml` and `BarContent.qml` to pass those per-section blur parts upward.
4. Update `BarWindow.qml` to build `BackgroundEffect.blurRegion` from all exposed section parts.
5. Preserve existing Canvas painting unless a smaller, safer geometry-owner change is available. The core requirement is that blur source geometry is aligned with visible body/ear geometry; do not attempt unsupported subtract-region composition.
6. Keep all changes under `modules/bar` unless task context files need notes.

## Engineering Guidance

- Use the smallest correct change.
- Prefer explicit properties over broad new abstractions.
- If QML cannot express exact concave ear blur through `wl_region`, expose and document the best region-compatible geometry alignment rather than reintroducing `Intersection.Subtract`.
- Do not add dependencies.
- Do not commit.

## Expected Files

- Likely: `modules/bar/DockzoneSurfaceRoot.qml`
- Likely: `modules/bar/BarSection.qml`
- Likely: `modules/bar/BarContent.qml`
- Likely: `modules/bar/BarWindow.qml`
- Must not change: `modules/island/*`

## Verification To Run If Feasible

- `git diff --check`
- QML lint/syntax check if an established command exists or `qmllint` is available.
- Inspect `git status --short` and ensure no `modules/island` file is modified by this task.
