# Quickshell Minimal Top Bar Research

## Sources

* Context7 `/websites/quickshell_master`
* Quickshell guide introduction
* Quickshell `PanelWindow` type docs

## Findings

* `PanelWindow` is the documented primitive for bars/panels.
* A minimal top bar can be built by anchoring `top`, `left`, and `right`.
* For multi-monitor behavior, Quickshell recommends `Variants` with `model: Quickshell.screens`.
* A minimal example can stay entirely in one `shell.qml` file with `Text` centered in the panel.

## Implication For This Task

Use a single-file `shell.qml` with `Variants` and `PanelWindow`, avoiding extra services or components.
