# Intake: Dockzone blur geometry refactor

Id: 2026-05-24-dockzone-blur-geometry-refactor-intake
Status: promoted
Created At: 2026-05-24T10:10:49+00:00
Session: opencode-main

## Raw Request
Implement 方案B: refactor bar dockzone background geometry so visible surface and BackgroundEffect blur region share matching geometry; scope limited to modules/bar; avoid island files.

## Current Understanding
The bar dockzone currently paints its attached-island body and ears with Canvas. Background blur is currently reliable only for the body because Quickshell/niri blur regions do not preserve subtract/concave region composition for the ear shapes. The user approved implementing 方案B: restructure dockzone geometry so the visible surface and blur source geometry match, scoped to modules/bar.

## Expected Outcome
The dockzone background blur matches the visible body and ear silhouette closely enough that ears no longer appear unblurred or incorrectly filled by rectangular/elliptical blur artifacts.

## Expected Behavior
Dockzone body and ears remain visually continuous during existing hover, attach, detach, and visibility motion. Blur follows the same geometry sources as the visible dockzone background.

## Actual Behavior
The current implementation can only blur the center body accurately. Ear blur attempts using nested Region subtract or ellipse composition are flattened by BackgroundEffect.blurRegion, producing incorrect rectangular fill or other mismatched shapes.

## Reproduction
Enable BackgroundEffect blur for bar dockzones and attempt to include ear geometry with Region subtract/ellipse composition. The body blur tracks, but ear blur either remains absent or fills the ear bounding rectangle instead of the concave visible silhouette.

## Scope
In scope: modules/bar dockzone surface rendering and blur region plumbing. Out of scope: modules/island files, unrelated bar layout behavior, niri configuration fallback, and broad redesign of widgets.

## Anti-Outcome
Do not change island files or resume the paused island-related task. Do not accept whole-window blur that blurs transparent space around the bar. Do not break existing dockzone hover/motion behavior.

## Final Expected Effect
The bar dockzone body and ears use shared, geometry-aligned QML sources for visible surface and BackgroundEffect blur. Visible background and blur no longer diverge at the dockzone ears.

## Approach Options
方案A: Keep body-only blur. Stable but leaves ears without blur.

方案B: Refactor dockzone background geometry owner. Recommended because it aligns visible geometry and blur source geometry for long-term correctness.

方案C: Add a visual approximation patch. Lower risk but still accepts blur mismatch.

## Chosen Approach
方案B. The user explicitly confirmed this plan. It best matches the requirement that blur regions precisely match visible dockzone shapes and avoids relying on unsupported Region subtract semantics.

## Final Implementation Plan
1. Refactor DockzoneSurfaceRoot.qml so body and ears are exposed as normal geometry-aligned blur source items rather than relying on Canvas paint nodes alone.
2. Update BarSection.qml and BarContent.qml to expose per-section blur region parts instead of a single body-only item.
3. Update BarWindow.qml to build BackgroundEffect.blurRegion from those per-section parts while preserving section motion and existing layout behavior.
4. Keep changes scoped to modules/bar and avoid island files.
5. Verify with syntax/lint checks where available and inspect git diff for scope.

## Validation
Run relevant QML syntax/lint checks if available, run git diff --check, inspect the changed region plumbing, and confirm no modules/island files were modified.

## Approval
User confirmed the final plan with "确认".

## Decisions

## Deferred Options

## Blocking Questions


## Non-Blocking Questions

## Open Questions
