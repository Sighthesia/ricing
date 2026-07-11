---
name: dockzone-host-detail-overlay
description: Keep dockzone-hosted hover details from changing host body or ear geometry. Use when a bar widget detail popup shifts a dockzone, pushes an attached ear offscreen, is clipped after decoupling, or needs a non-layout overlay viewport.
---

# Dockzone Host Detail Overlay

Treat the dockzone body and ears as fixed host geometry. Render hover details in an independent overlay viewport so detail width never feeds the body, silhouette, or ear position.

## Geometry Ownership

- Keep menu expansion and hover-detail expansion as separate channels.
- Let tray, context menu, picker, and settings widths drive their existing host expansion path.
- Do not route `CircularHoverWidget` detail width into `bodyWidth`, `pushedBodyWidth`, or ear coordinates.
- Center hover details in the overlay viewport unless a user-visible design explicitly requires another anchor.
- Use an absolute overlay viewport that contributes no `implicitWidth`; do not solve clipping by growing the host.

## Diagnosis

Trace this chain before changing anchors:

```text
detail width -> section aggregation -> host expand width
             -> body/pushed-body width -> ear position
```

If this chain exists for hover detail, cut it at section aggregation and use the overlay width only for the detail viewport.

## Reveal Motion

- Drive detail opacity and vertical offset from the host's animated expand progress, not merely the hover boolean.
- Let content enter from the host's newly visible bottom edge and leave before that edge retracts.
- Keep clipping only as a guardrail; a detail must not appear fully formed before the host reaches it.
- Preserve hover hit coverage while the detail is partially revealed.

## Single Content Owner

- Keep one active detail key per dockzone section, matching the single-content ownership used by tray menus.
- Let only the active wrapper consume the host's actual reveal height; gate every inactive detail to zero height, opacity, and interaction.
- Transfer ownership immediately when the pointer enters another widget, regardless of leave/enter signal order.
- Retain the departing owner during host collapse so its content can follow the actual glass height instead of hard-cutting.
- Do not use the shared host height alone as visibility state: without an owner gate, every detail instance reveals simultaneously.

## Unified Expand Host

- When hover details and menus share a dockzone, use one section-owned latest-wins request owner and one visible payload path.
- A non-null request replacing another non-null request is visually atomic: destroy the old payload before the new owner renders. Do not cross-fade unrelated detail and menu content in the same host.
- Retain an outgoing payload only for a non-null-to-null close. Keep it until the host's actual animated expand height reaches zero, then unload it.
- Keep request state, visual owner state, and host geometry distinct. A request replacement must not accidentally preserve an old visual owner at the new menu's dimensions.
- Drive every payload's opacity, offset, row reveal, and interaction gate from the same actual host reveal height/progress. Per-view clips are safety guards, not independent lifecycle owners.
- Tray menus with asynchronously arriving DBus rows must report their live implicit dimensions to the active request. Do not freeze the host height from the first empty-menu measurement.

## Joint Pointer Domain

- Treat the active badge and its visible detail as one pointer domain; leaving the badge alone must not start collapse while the pointer is inside the detail.
- Track explicit badge intent with a fixed HoverHandler scoped to the unscaled badge hit box, not the animated badge visual or a tall transit MouseArea.
- Own detail hover at a fixed section-level overlay viewport; do not read hover from the animated detail slot's height or position.
- Route overlay pointer presence only to the current active detail owner, and keep the overlay handler passive so detail controls still receive input.
- With stable hit layers, remove contraction-direction and pending-claim workarounds instead of stacking them on top.
- Always allow an explicit badge hover to claim immediately, including while another detail is contracting.
- End visual contraction from the host's actual animated height rather than a timer or stale requested height.

## Active Detail Host

- Prefer one section-owned active detail host over forwarding a full-body overlay hover state into every widget.
- Scope its pointer catcher below the top badge band and size it from the actual visible detail expansion only.
- Disable the host whenever tray, context menu, widget picker, or widget settings content owns the dockzone.
- Route host pointer presence only to the active detail key; never let the host cover the badge row or compete with menu controls.
- Keep the host handler passive so sliders and other detail controls retain pointer grabs.

## Verification

- With a hover detail open, assert the host body width, pushed-body width, and ear position remain at resting values.
- Hover across several widgets and assert that exactly one detail is visible and interactive on every frame.
- Move badge to detail and hold the pointer still during collapse tests; the host must not repeatedly reopen as geometry passes under the pointer.
- Inspect slow motion: detail should slide and fade with host growth, not be exposed by a clip.
- Verify badge-to-detail pointer travel, tray/menu paths, and `timeout 5 qs -p .`.
- Verify `detail -> tray`, `detail -> context menu`, and `tray -> detail`: exactly one payload may paint or receive input at every frame.
- Verify `detail -> closed` separately: the same detail remains visible only while the host contracts, then unloads at zero reveal.
