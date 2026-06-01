---
name: overlay-pointer-event-starvation
description: Use when an inner or lower element stops receiving hover/pointer events (no hover highlight, hover-driven popup never opens, or a popup flickers open/closed) because an overlapping element above it silently consumes those events. Applies to QML, web (CSS/DOM), and native UI. Trigger signs include a full-area transparent catcher, a hoverEnabled/pointer-capturing layer drawn on top, or a fullscreen overlay window that covers the very element that triggered it.
---

# Overlay Pointer-Event Starvation

Diagnose and fix bugs where one element is *starved* of pointer/hover events because another element stacked above it consumes them. The starved element looks correct in isolation, so the bug hides in the **stacking + input-routing** relationship, not in the element itself.

## The Generic Pattern / Methodology

**Core Concept**

- Pointer/hover events are routed to the **topmost element that accepts them at that coordinate**. An element that visually sits "behind" or "inside" another may never see the event even though it has a correct handler.
- Two distinct sub-cases keep recurring:
  1. **Static starvation** — a sibling/ancestor drawn on top (a full-area `hoverEnabled` catcher, a transparent click-shield, a higher `z` layer) eats hover/move events the inner element needed. Symptom: inner hover *never* fires.
  2. **Self-inflicted starvation (flicker loop)** — the element that triggers an overlay is then *covered* by that overlay, which steals its pointer events, which dismisses the overlay, which uncovers the element, which re-triggers it. Symptom: rapid open/close **flicker** while the pointer holds still.
- The fix is always the same shape: **stop the upper layer from monopolizing input it does not need**, so events reach the layer that should handle them.

**Universal Checklist** (before touching handler logic)

| Question | Why it matters |
|---|---|
| At the failing coordinate, what is the **topmost** input-accepting element? | That element, not your handler, owns the event. |
| Does an upper element capture hover/move just to detect presence or catch a click? | Presence/click detection rarely needs to *consume* hover; that is the usual culprit. |
| When the popup is open, does it **geometrically cover** the element that opened it? | Covering the trigger creates the flicker loop. |
| Is dismissal driven by the *trigger* losing hover while the overlay sits on top of it? | That is the self-inflicted loop; dismissal must key off the overlay/content, not the now-covered trigger. |
| Does the upper layer span the **whole window/screen** when it only needs its own card? | Fullscreen catchers starve everything beneath them. |

## The Specific Trap / Symptom (Case Study)

A Quickshell top-bar system-tray menu (hover a tray icon -> glass menu slides down) failed twice for the same underlying reason:

1. **Static starvation**: each bar widget was wrapped by a `BarWidgetWrapper` whose `MouseArea { anchors.fill: parent; hoverEnabled: true; acceptedButtons: RightButton }` (for a right-click context menu) sat above the tray icons. `hoverEnabled` made it consume hover-move, so the inner tray `HoverHandler` (and earlier a `MouseArea.containsMouse`) **never fired** -> "hovering does nothing". Swapping MouseArea->HoverHandler inside the icon did not help, because the event never reached that layer.
2. **Self-inflicted flicker**: once opened, the menu lived in a **fullscreen overlay `PanelWindow`** (`anchors { top; left; right; bottom }`) layered above the bar. It covered the tray icon, so the icon lost hover -> close timer fired -> overlay vanished -> icon regained hover -> reopened -> **flicker**. Moving onto the menu card was stable only because that area set `pointerInMenu = true`.

## The Anti-Pattern vs. Best Practice

- ❌ **Anti-Pattern (static)**: using a full-area, hover/pointer-*consuming* element (e.g. `MouseArea { hoverEnabled: true }`, a DOM node with `pointer-events: auto` over its children, a transparent overlay `View`) merely to detect presence or catch one button. It silently eats every event for everything beneath it.
- ✅ **Best Practice (static)**: use **passive** detection that does not monopolize input — QML `HoverHandler` + `TapHandler` (multiple handlers can observe the same event), CSS `pointer-events: none` on decorative overlays, hit-testing that explicitly forwards/propagates. Reserve full-area event-consuming catchers for when consumption is the actual intent (modal blocker).
- ❌ **Anti-Pattern (flicker)**: a hover-triggered popup rendered in a layer that **covers its own trigger**, with dismissal keyed to the trigger losing hover.
- ✅ **Best Practice (flicker)**: constrain the overlay's **input region** to the popup content only (QML `PanelWindow.mask: Region { item: card }`, equivalent compositor input-region, or a non-fullscreen popup) so the area over the trigger **passes through**; the trigger keeps its hover and the loop cannot form. Drive dismissal off the *content* hover / hover-out, not the covered trigger.

## Generalizable Rules (Highly Portable)

- **Detect without consuming.** Presence detection (hover) and single-gesture capture (one click/tap) should use passive, observe-only handlers. Only use input-consuming full-area elements when blocking is the explicit goal.
- **Never let a popup steal its own trigger's input.** If an overlay can geometrically cover the element that opened it, restrict the overlay's input/hit region to its content, or position it so it never overlaps the trigger.
- **Dismissal must key off a stable owner.** Tie hover-out dismissal to the element the pointer is actually over (the popup content), never to a trigger that the popup now covers.
- **Match input region to visual need.** A fullscreen overlay should claim fullscreen *input* only when it truly needs click-away everywhere; otherwise mask input to the visible card and let the rest pass through.
- **Warning signs in other code**: a `hoverEnabled`/`pointer-events` element with `anchors.fill`/`absolute inset:0` whose siblings or children also need hover; any fullscreen popup window layered over the bar/toolbar that spawned it; "hover does nothing" or "popup flickers while the mouse is still" reports.

## Universal Verification Strategy

- **Locate the real event owner first.** Add a presence probe (log on hover-change) at *each* stacked layer from outermost to innermost; the first layer that stops firing is where the event is consumed. Do not guess from the handler code.
- **Confirm with a controlled deactivation.** Temporarily disable the suspected upper layer's input consumption (e.g. `hoverEnabled: false`, `pointer-events: none`). If the inner layer's hover suddenly fires, the upper layer was the thief. Revert after confirming.
- **Reproduce the flicker deterministically.** Hold the pointer still on the trigger; a correct fix shows the popup opening **once** and staying. Repeated open/close logs with a stationary pointer means the overlay is still covering the trigger.
- **Verify pass-through.** After masking input to the popup content, confirm the area over the trigger still receives events (trigger hover stays true) and regions outside the card pass through to whatever is below.
