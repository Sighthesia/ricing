# Intake: 修复 blur 背景边缘与描边可见性

Id: 2026-05-24-blur-intake
Status: promoted
Created At: 2026-05-24T12:40:44+00:00
Session: main

## Raw Request
background 边框/描边看不见，blur 覆盖不完全；每个应用了 blur 的背景都出现了该问题

## Current Understanding
Fix the shared blur-background rendering so every surface with blur fully covers its background content area while the visible border or outline remains crisp and visible above the blur.

## Expected Outcome
All blur-enabled background surfaces render with blur reaching the visible edge of the filled background area, while border and outline strokes remain clearly visible instead of being visually swallowed by the blur.

## Expected Behavior
Blur should fully cover the background fill area up to the intended edge or rounded edge of the surface. Border or outline strokes should remain a separate visible top layer and stay readable on every blur-enabled background.

## Actual Behavior
Across every background that enables blur, the blur region does not fully cover the visible background edge, and the background border or outline becomes hard to see or disappears visually.

## Reproduction
1. Open any UI surface that uses a blur-enabled background.
2. Observe the outer edge of the background fill and its border or outline stroke.
3. Notice that the blur coverage stops short or does not align cleanly with the visible background edge.
4. Notice that the border or outline is visually swallowed and no longer reads as a crisp top-layer stroke.

## Scope
Adjust the shared implementation patterns for blur-enabled backgrounds so blur coverage and border visibility are correct across all affected surfaces. Keep the existing blur strength, corner radii, colors, and overall visual language unless a minimal structural change is required for the fix.

## Anti-Outcome
Do not redesign the UI style, change blur intensity globally, or introduce a different visual hierarchy where borders disappear into the blur again.

## Final Expected Effect
Every blur-enabled background shows blur fully covering the intended background fill area while the border or outline remains clearly visible and visually separate on top.

## Approach Options
方案1: Split blur fill and border into separate layers. Recommended because it solves both incomplete edge coverage and hidden border visibility in a stable, reusable way across surfaces.

方案2: Keep the current single-layer structure and only tune clip, mask, or inset values. Smaller change in some files, but more fragile across different radii, sizes, and states.

方案3: Expand blur outward and reserve border space manually. Can patch coverage gaps, but adds maintenance complexity and risks new edge artifacts.

## Chosen Approach
方案1。The user explicitly approved separating the blur-bearing fill layer from the visible border or outline layer.

## Final Implementation Plan
1. Identify the shared blur-enabled background patterns and the main owner components that currently combine blur fill and visible border responsibilities.
2. Refactor the affected surfaces so the blur source covers the fill geometry completely while the border or outline is rendered as a separate visible top layer.
3. Preserve current blur intensity, corner radius, and styling tokens unless a minimal geometry adjustment is required for correct coverage.
4. Verify representative blur-enabled surfaces for full edge coverage, crisp visible borders, and absence of new edge artifacts.

## Validation
Inspect several representative blur-enabled surfaces and confirm that blur reaches the visible background edge, the border or outline remains clearly visible, and rounded corners do not show clipping, hard seams, or black-edge artifacts.

## Approval
User approved the recommended direction with "确认".

## Decisions

## Deferred Options

## Blocking Questions

## Non-Blocking Questions

## Open Questions
