# Adopt Dynamic Island Dock Zone Shape

## Goal

Update the QML/Quickshell Glass Liquid design skill and apply the sibling `quickshell` project's dynamic island outer shape to the current top bar center dock zone that contains the `QuickShell` text.

## What I Already Know

* The target file is `.agents/skills/glass-liquid-design/SKILL.md`.
* The current design language already defines a high-priority motion contract and top status bar composition.
* The current top status bar model uses floating capsule components inside left, center, and right dock zones.
* Dock zones currently use a notch-like glass background attached to the top edge with square top corners and rounded bottom edge.
* The user wants the dock-zone background to mimic `/home/Sighthesia/0_Files/Producing/Software/Quickshell/quickshell` dynamic island shape, especially its edge-attached curved decoration implementation.
* The current runtime UI is a minimal `shell.qml` top `PanelWindow` with centered `Text { text: "QuickShell" }` on an opaque full-width bar.

## Requirements

* Research the sibling `quickshell` project's dynamic island implementation.
* Identify the relevant shape language and edge-attached curved decoration pattern.
* Update the Glass Liquid skill so dock-zone backgrounds adopt the dynamic island's overall outer shape.
* Describe the shape as a center adaptive body with side ear-like curved edge decorations, not as a code port.
* Preserve the existing hierarchy: floating capsule components move inside adaptive left, center, and right dock zones.
* Keep the universal motion contract higher priority than the visual shape rule.
* Apply the dynamic-island-like shape to the current top bar center area containing the `QuickShell` text.
* Replace the full-width opaque bar look with a transparent top `PanelWindow` and a center dock-zone background that carries the text.
* Keep implementation narrow: no service integrations, no full dock-zone system yet, no settings/theme architecture.

## Acceptance Criteria

* [ ] `.agents/skills/glass-liquid-design/SKILL.md` documents that top dock-zone backgrounds should use the sibling dynamic island's edge-attached curved outer shape.
* [ ] The skill keeps individual status bar components as floating capsules.
* [ ] The skill keeps left, center, and right dock zones as adaptive containers.
* [ ] The skill explicitly mentions preserving fluid enter/leave/move behavior for components and adaptive zone background morphing.
* [ ] Research findings are persisted under this task's `research/` directory.
* [ ] The visible `QuickShell` text is contained in a center top dock-zone shape inspired by the source dynamic island.
* [ ] The old full-width opaque top bar is removed or made transparent so the center island shape is the visible status surface.
* [ ] The center dock-zone has visibly rendered left and right ear-like edge curves; the ear curves must read as inner quarter-circle edge decorations and must not be clipped outside the painted area.
* [ ] The center dock-zone body and ear curves are attached to the top screen edge, matching the reference island instead of floating around the widget centerline.
* [ ] The QML follows the project convention for comments before major declarations.

## Definition of Done

* The design skill is updated.
* The current bar implementation is updated.
* Relevant research is recorded.
* The change is reviewed for consistency with existing skill style and QML conventions.

## Out of Scope

* Porting code from the sibling `quickshell` project into this repo.
* Changing runtime shell behavior.
* Implementing left and right dock zones.
* Adding real status modules beyond the static `QuickShell` text.

## Technical Notes

* External reference path: `/home/Sighthesia/0_Files/Producing/Software/Quickshell/quickshell`.
* Target skill path: `.agents/skills/glass-liquid-design/SKILL.md`.
* Research reference: `research/dynamic-island-shape.md`.
* Source dynamic island composes its silhouette from an adaptive rounded body plus left/right Canvas ear curves and matching shadow/mask layers.
* The dock-zone adaptation in this task should mimic the inner quarter-circle edge decoration feel from the reference island, not a convex side bulb.
* Source detached record area shows a related dock-zone idea: a side attachment anchored to the island body, shown/hidden through animated margin rather than hard replacement.
