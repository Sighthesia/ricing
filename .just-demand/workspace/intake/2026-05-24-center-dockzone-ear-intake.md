# Intake: 修复 center dockzone ear 内部重叠

Id: 2026-05-24-center-dockzone-ear-intake
Status: promoted
Created At: 2026-05-24T01:15:22+00:00
Session: main

## Raw Request
目前发现center dockzone的ear实现和left或right不同：center的左右ear区域会在主体内部连起来形成一个倒梯形，导致主体内部ear在高度内有额外的叠加部分，在半透明下可见其颜色变深，修复

## Current Understanding
Fix the center dockzone ear geometry so the left and right top ears no longer extend inward and connect through the body area. The center surface should keep the intended outer silhouette without semi-transparent self-overlap inside the visible body.

## Expected Outcome
The center dockzone renders without any inward ear overlap or darkened semi-transparent region inside the body, while left and right dockzones keep their current appearance and behavior.

## Expected Behavior
The center dockzone should render like a single continuous surface whose top ears only contribute to the outer contour. Inside the body area there should be no extra ear fill layered on top of the body fill.

## Actual Behavior
The center dockzone currently renders its left and right ear regions differently from left and right dockzones: both ears extend inward inside the body height and visually connect into an inverted trapezoid. Because the surface is semi-transparent, the overlapped region appears darker than the surrounding body.

## Reproduction
1. Show a center dockzone surface with visible content.
2. Observe the top-left and top-right ear regions where they meet the center body.
3. Notice that both ears extend inward inside the body area and connect visually.
4. With the current semi-transparent surface fill, the overlapped region appears darker than the surrounding body.

## Scope
Adjust the center dockzone ear/body rendering so the internal overlap is removed. Keep the existing left and right dockzone rendering behavior unchanged unless a minimal shared rendering change is required to preserve the same outer result.

## Anti-Outcome
Do not redesign the dockzone shape language, change unrelated hover or detach behavior, or regress the current left and right dockzone silhouettes.

## Decisions

## Deferred Options

## Blocking Questions

## Non-Blocking Questions

## Open Questions
