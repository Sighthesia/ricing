# Minimal QuickShell shell.qml

## Goal

Create a minimal runnable `shell.qml` for Quickshell that shows a top status bar and can serve as the smallest usable starting point for later shell work.

## Requirements

* Add a root `shell.qml` entry file.
* Use Quickshell's panel-oriented window type for a top bar.
* Render the bar on each available screen.
* Keep the UI intentionally minimal: a visible top bar with simple text content only.
* Do not integrate clocks, system tray, audio, workspace state, or compositor-specific services in this task.

## Acceptance Criteria

* [ ] The repository contains a `shell.qml` entry file.
* [ ] `shell.qml` uses Quickshell APIs appropriate for a top-anchored bar.
* [ ] The bar is anchored to the top, left, and right edges of each screen.
* [ ] The file stays minimal and readable, suitable as a starter shell.

## Definition of Done

* Minimal implementation is present.
* Basic validation for QML syntax or project checks is run if available.
* No unnecessary abstractions or placeholder integrations are added.

## Technical Approach

Use `Variants` over `Quickshell.screens` and create one `PanelWindow` per screen. Keep the window height fixed and render centered text so the file remains the smallest runnable top-bar example.

## Decision (ADR-lite)

**Context**: The user asked for the smallest `shell.qml`, but clarified the desired shape is a top status bar.

**Decision**: Implement a minimal per-screen `PanelWindow` top bar instead of a generic floating window.

**Consequences**: This matches shell expectations better and stays close to Quickshell's documented patterns, at the cost of introducing a little more structure than a single plain window.

## Out of Scope

* Styling system or theme architecture
* Dynamic time/date updates
* System integrations or desktop services
* Modular component extraction

## Technical Notes

* Quickshell docs show `PanelWindow` as the standard primitive for bars.
* Quickshell docs also show `Variants { model: Quickshell.screens }` for per-screen windows.
* Relevant research is stored in `research/quickshell-minimal-top-bar.md`.
