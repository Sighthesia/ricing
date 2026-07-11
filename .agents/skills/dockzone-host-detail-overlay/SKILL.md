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

## Verification

- With a hover detail open, assert the host body width, pushed-body width, and ear position remain at resting values.
- Hover across several widgets and assert that exactly one detail is visible and interactive on every frame.
- Inspect slow motion: detail should slide and fade with host growth, not be exposed by a clip.
- Verify badge-to-detail pointer travel, tray/menu paths, and `timeout 5 qs -p .`.
