---
name: effective-visibility-cycle-debugging
description: Use when a QML/Quickshell surface reports healthy state (open=true, opacity=1, non-zero geometry, mapped layer-shell surface) yet paints nothing on screen — especially when an ancestor's `visible` is bound to a descendant's `visible`, or when a child's implicitHeight/implicitWidth is derived from its own `visible`. QML `Item.visible` reads return EFFECTIVE visibility including ancestors, so parent/child visibility bindings deadlock at false and no imperative write can break them out.
---

# Effective-Visibility Cycle Debugging

Debug the class of bug where every state flag, geometry number, and compositor
surface says "rendered", but nothing is painted. The cause is a visibility
dependency cycle: an ancestor's `visible` is driven by a descendant's `visible`,
and the descendant is (transitively) driven by the ancestor. Because QML reports
*effective* visibility, both terms evaluate to `false` forever.

## The Core QML Fact

- `Item.visible` is a *stored* flag, but **every read of `visible` (QML
  expression, JS function, `console.log`, `debugSnapshot`) returns the effective
  value: `localVisible && parentVisible && grandparentVisible && …`**.
- Therefore, once a cycle exists, there is **no value you can write** to break
  out. `child.visible = true` while its parent is effectively invisible reads
  back `false` on the very next statement, and `onVisibleChanged` never fires
  because the effective value never changed.
- A sibling-to-sibling mirror (`MultiEffect { visible: icon.visible }`, icon
  shadow, echo/ghost layers) is **safe**: siblings have no ancestor chain
  between them. Only upward reads from parent→child (or a child whose
  geometry/opacity is derived from its own effective `visible`) form the cycle.

## Symptom Signatures

| Signature | What it rules out |
|---|---|
| Debug snapshot shows `open/visible/opacity` healthy, item rect non-zero | Not a state-machine bug, not a sizing bug |
| Compositor confirms the layer-shell surface is **mapped** at the right layer (`niri msg -j layers`, `wlr-layer-shell` dump) | Not a window/layer/mask problem |
| Nothing paints, or content height collapses to `0` | Classic effective-visibility deadlock |
| Imperative `x.visible = true` followed by an immediate read returns `false`, and no `visibleChanged` fires | Confirms the cycle — this is the decisive test |
| A child's `implicitHeight: visible ? contentHeight : 0` measures `0` while the subtree looks healthy | The cycle has already propagated into geometry |

## The Decisive Test (run before editing anything)

```qml
console.log("before:", target.visible)
target.visible = true
console.log("immediately after write:", target.visible)   // false ⇒ cycle
```

If the write does not stick **synchronously**, stop reasoning about bindings and
find the ancestor chain: for `target`, list every ancestor that has a `visible`
binding, and check whether any of them mentions `target` (directly or via a
helper/alias/snapshot function).

## The Fix Pattern

Break the cycle by giving each level exactly one **upward-only** owner:

1. One state property on the host owns life-cycle truth (`surfaceActive`,
   `open`, `phase !== "closed"`).
2. The reveal/content item binds its `visible` **only** to that host state.
3. Structural wrappers (positioning containers, clip hosts, clamp layers) stay
   **always visible** — they exist to place and size, never to hide.
4. Remove every imperative `child.visible = …` write. Those writes both break
   the intended binding *and* cannot override an effective-visibility cycle, so
   they mask the bug while making the state impossible to reason about.

```qml
// WRONG: parent reads child, child reads host ⇒ deadlock at false
Item { id: box; visible: reveal.visible
    TwoLayerPopup { id: reveal; visible: host.open || reveal.revealProgress > 0 } }

// RIGHT: wrappers always visible; one host flag drives one item
Item { id: box                                  // positioning only
    TwoLayerPopup { id: reveal; visible: host.surfaceActive } }
```

Cover the exit animation with the *same* single flag (keep it true for
`revealDuration` after `open` goes false) instead of adding a second visibility
term back into the child.

## Blast Radius: Geometry And Snapshots

The cycle lies to everything downstream, so audit these too:

- `implicitHeight: visible ? … : 0` → measures `0`; a parent that sizes to the
  child's `childrenRect`/`implicitHeight` collapses, so even after fixing
  visibility the surface may still look wrong until the geometry re-measures.
- Diagnostics/snapshot functions that log `item.visible` report the effective
  value, so they **confirm the wrong story**. Log the stored flag
  (`item.visible && item.enabled` is still effective — instead log the host
  state and each ancestor's own binding input) or rely on the decisive test above.
- Layer-shell input `mask: Region { item: … }` following a stuck-invisible item
  yields an empty region, which reads like "click-through / not mapped".

## Anti-Patterns That Waste Time

| Attempt | Why it fails |
|---|---|
| Re-tune `layer`/`z`/exclusive zone/margins after seeing nothing paint | Compositor already proved the surface is mapped; stacking was never the issue. |
| Add more imperative `visible = true` writes | Cannot override effective visibility; guarantees the binding stays broken. |
| Trust a debug snapshot's `visible: true` field | It is the effective value from a different moment or a different item. |
| Replace the item with a fresh component | The cycle lives in the ancestor chain, so it reproduces. |
| Suspect shader/blur transparency | If `opacity` is 1 and colors resolve, and the sibling mirror of the same content paints, it is visibility, not material. |

## Prevention Checklist

- No ancestor's `visible` may mention any of its own descendants.
- Only the host's life-cycle flag drives content `visible`; wrappers never do.
- Gating a child's `implicitHeight` on its own `visible` is allowed **only** when
  nothing in its ancestor chain reads that child's `visible`.
- Every new hover/popup/overlay host gets a harness assertion that the reveal
  item is visible **while open** (`popupItem.visible === true`), not just that
  the host flag flipped.
- Give each layer-shell window a distinct `WlrLayershell.namespace`
  (e.g. `afloat-bar`, `afloat-popup`) so `niri msg -j layers` can name the
  surface instead of returning anonymous `quickshell` rows.
