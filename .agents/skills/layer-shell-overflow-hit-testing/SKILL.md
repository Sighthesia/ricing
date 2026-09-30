---
name: layer-shell-overflow-hit-testing
description: Use when a Quickshell/layer-shell popup visibly overflows its primary column but the overflow has no hover or click response, especially when the compositor input region is correct yet Qt Quick events stop at a narrow ancestor.
---

# Layer Shell Overflow Hit Testing

Diagnose and fix the split between compositor input coverage, Qt Quick ancestor hit bounds, and visual geometry for overflowing tray submenus.

## Failure Signature

- The popup and submenu are visibly present.
- `PanelWindow.mask` / `Region` covers the submenu screen rectangle.
- The primary catcher receives events until the primary right edge, then the submenu catcher receives zero or only a narrow seam.
- `contentEnabled`, `submenuPhase`, and `submenuInteractable` look healthy.
- A second open may work because the content tree is already warm or has already acquired the wider layout.

Do not classify this as an ordinary `overlay-pointer-event-starvation` problem until the event owner is measured. That skill covers an upper sibling consuming events; this skill covers a child that is outside a narrow ancestor's Qt hit-test geometry.

## Proven Diagnosis

Measure three layers independently:

1. **Compositor region**: log the committed `Region` rect in window/scene coordinates.
2. **QML event counters**: add temporary counters to the primary catcher, overflow catcher, and visible panel probe.
3. **Ancestor chain**: log `objectName`, `width`, `height`, `visible`, `enabled`, and `clip` from the catcher up to the `PanelWindow` content root.

Interpret the result:

- Region too narrow: fix the committed compositor geometry first.
- Region wide, ancestor narrow, overflow catcher silent: fix the Qt Quick ownership tree.
- Region and ancestors wide, catcher receives events but no highlight: inspect row mapping and async delegate readiness.
- Host hover leaves while the remembered pointer is inside the committed region: treat it as compositor/input handoff evidence, not a user departure.

## Prescribed Layout Pattern

Separate the **input canvas** from the **visual columns**:

- Widen the content slot and intermediate action/content parents enough to contain the overflow catcher from the first tray frame.
- Keep the primary visual column at its design width (`primaryMenuWidth`, historically 244px; face including outer pad 260px).
- Keep the submenu surface at its visual width and place it at `primaryMenuWidth + submenuPad` when the design calls for a visible gap.
- Let the overflow catcher begin at `primaryMenuWidth` and include the gap plus the submenu width. It may be wider than the painted surface.
- Keep the layer-shell region at least as wide as the complete input canvas, but do not use region expansion as a substitute for widening QML ancestors.

```qml
readonly property real primaryMenuWidth: implicitWidth

Flickable {
    width: root.primaryMenuWidth
}

Rectangle {
    width: root.primaryMenuWidth
    x: root.primaryMenuWidth + root.submenuPad
}

MouseArea {
    x: root.primaryMenuWidth
    width: submenuSurface.width + root.submenuPad
}
```

The outer content owners must be wide enough for the catcher. Preserve the visual background width separately so widening the input tree does not stretch the first-level menu.

## Common Failed Fixes

- Widening only `PanelWindow.mask` or `popupInputRegion`: the compositor routes the pointer to the surface, but Qt still rejects the overflowing child during ancestor hit testing.
- Widening only the painted background: the menu looks wider while the event owner remains narrow.
- Widening the entire action body without separating visual widths: fixes part of hit testing but visibly expands the primary menu.
- Removing the visual gap to make the old input catcher easier to cross: changes the design and hides the ownership problem; use a catcher that owns the gap instead.
- Treating `contentEnabled=true` and `submenuInteractable=true` as proof of delivery: these only describe state, not whether Qt delivered a pointer event.

## Verification

Use the safe test runner and a real desktop reproduction:

```sh
scripts/run-tests.sh tst_bar_tray_menu_content
qmllint modules/bar/BarPopupHost.qml modules/bar/BarPopupActions.qml modules/bar/BarTrayMenuContent.qml
```

The focused QtTest should assert both geometry contracts:

- primary visual width remains fixed;
- wide input root contains the overflow catcher and can hover/click a submenu row.

For the live shell, enable the existing hover diagnostics, restart the shell so the running process matches the source, reproduce first-open and second-open, and compare:

```text
evPrimary, evBand, evPanel, highlightSub,
region/regionScene, contentEnabled, submenuPhase,
submenuColumn rect, and the ancestor widths/clips
```

Remove temporary tagged diagnostics before committing. Keep any visual spacing restoration separate from hit-area changes and preserve the `submenu-surface-motion` gap/bridge contract.
