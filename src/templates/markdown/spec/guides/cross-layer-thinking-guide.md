# Cross-Layer Thinking Guide

> **Purpose**: Think through data flow across layers before implementing.

---

## The Problem

**Most bugs happen at layer boundaries**, not within layers.

Common cross-layer bugs:
- API returns format A, frontend expects format B
- Database stores X, service transforms to Y, but loses data
- Multiple layers implement the same logic differently

---

## Before Implementing Cross-Layer Features

### Step 1: Map the Data Flow

Draw out how data moves:

```
Source → Transform → Store → Retrieve → Transform → Display
```

For each arrow, ask:
- What format is the data in?
- What could go wrong?
- Who is responsible for validation?

### Step 2: Identify Boundaries

| Boundary | Common Issues |
|----------|---------------|
| API ↔ Service | Type mismatches, missing fields |
| Service ↔ Database | Format conversions, null handling |
| Backend ↔ Frontend | Serialization, date formats |
| Component ↔ Component | Props shape changes |

### Step 3: Define Contracts

For each boundary:
- What is the exact input format?
- What is the exact output format?
- What errors can occur?

---

## Common Cross-Layer Mistakes

### Mistake 1: Implicit Format Assumptions

**Bad**: Assuming date format without checking

**Good**: Explicit format conversion at boundaries

### Mistake 2: Scattered Validation

**Bad**: Validating the same thing in multiple layers

**Good**: Validate once at the entry point

### Mistake 3: Leaky Abstractions

**Bad**: Component knows about database schema

**Good**: Each layer only knows its neighbors

### Mistake 4: Split Animation Ownership

**Bad**: A service emits correct state changes, but the component mixes anchor-driven
geometry, manual `x`/`y` offsets, `Behavior`, and imperative animations on the same
visual node.

**Good**: Pick one animation owner per visual property. If a state service drives a
transition, the render layer should expose explicit animation state and one clear
timeline for each animated property.

Animation bugs often hide at a cross-layer boundary:

- the service snapshot changes correctly
- the host widget receives the update correctly
- the leaf component still appears static because geometry ownership is split

When motion looks wrong, trace all three layers before changing easing values.

### Mistake 5: Same-Frame State Reset

**Bad**: Set an animation start value, then reset it with `Qt.callLater()` in the same
update path and expect the user to see motion.

**Good**: Use an explicit `SequentialAnimation` or `ParallelAnimation` when the visual
result depends on intermediate states being observable across frames.

### Mistake 6: Rebuilding Delegates During Motion

**Bad**: A service refresh replaces the rendered array model while a motion effect is in
flight, so repeated delegates are recreated and local animation state is lost.

**Good**: Keep animation-driving state at the root, prefer stable delegate identity for
animated rows, and update slot content separately from slot position.

Typical symptom chain:

- service snapshots are correct
- focus/index values are correct
- a highlight or capsule still appears to jump, restart, or always stretch from one side

In those cases, inspect whether the animated subtree is being rebuilt before tuning
durations.

---

## Checklist for Cross-Layer Features

Before implementation:
- [ ] Mapped the complete data flow
- [ ] Identified all layer boundaries
- [ ] Defined format at each boundary
- [ ] Decided where validation happens

After implementation:
- [ ] Tested with edge cases (null, empty, invalid)
- [ ] Verified error handling at each boundary
- [ ] Checked data survives round-trip
- [ ] Verified which layer owns each animated property (`anchors`, bindings,
  `Behavior`, or imperative animation)
- [ ] Confirmed no animated property is both anchor-controlled and manually offset
- [ ] Confirmed animation start/end states are visible across frames, not reset in the
  same tick

---

## Motion Debugging Ladder

For UI motion bugs, debug in this order:

1. **State layer**: confirm the service emits a new snapshot with the expected IDs,
   indices, and revisions.
2. **Host layer**: confirm the container widget receives the new event and does not
   rebuild or replace the wrong visual subtree.
3. **Leaf layer**: confirm the actual animated item owns the geometry property being
   changed.

4. **Identity layer**: confirm the animated delegate instance survives snapshot updates.
   If the host rebuilds the `Repeater` model from fresh arrays, local animation state may
   reset even when state and geometry are otherwise correct.

Do not tune durations until all three layers are verified. Otherwise you only make a
broken animation slower.

For repeated animated rows, do not tune durations until the fourth identity step is also
verified.

---

## When to Create Flow Documentation

Create detailed flow docs when:
- Feature spans 3+ layers
- Multiple teams are involved
- Data format is complex
- Feature has caused bugs before
