---
name: pinned-head-trail-motion
description: Use when a mark (indicator bar, focus frame, selection highlight) must carry a trailing wake, or when a wake is cut, reset, frozen, or jumps during a transition — especially where a head is pinned to a travelling element rather than animated toward it.
---

# A wake behind a pinned head

A "wake" is the gap between a fast **head** and a slow **tail** of the same mark,
drawn as a stretched bar or a trailing shadow. The reference implementation is
`modules/bar/widgets/Workspaces.qml` (`_edgeX` / `_edgeShadowX` / `_edgeSpan`),
and the place this has been built and debugged repeatedly is
`modules/bar/BarWindowHintContent.qml`.

Most of what follows is not theory. Each item is a defect that shipped, survived
several verified-looking rounds, and was found only by instrumenting the running
shell.

## Where the recipe lives

`modules/lazerbar/TrailIndicator.qml` is the shared mark. Its tracker came out of
`modules/bar/widgets/Workspaces.qml` (which still carries the widget's own
geometry and colours) and is now the single implementation behind three hosts:

| host | axis | `targetCenter` |
| --- | --- | --- |
| `modules/bar/widgets/Workspaces.qml` | x | the focus frame's centre |
| `modules/lazerbar/LazerSettingsSidebar.qml` | y | `indicatorY`, the row centre |
| `modules/lazerbar/FullscreenSidebar.qml` | y | the row centre of whichever band owns the selection |

Do not re-implement it per rail, and do not hand the mark a leading edge: it owns
its own length **and its own position along that axis**, because both are half the
mark's geometry — a host that placed the mark itself would have to know the wake to
get the position right, and the wake is the one thing it must not know. **Pass a
CENTRE and a `crossAxis`; set neither `x` nor `y`.**

`modules/bar/BarWindowHintContent.qml` is deliberately NOT on it — see the two
laws below.

Two host-side traps were removed when it was lifted out, and neither is obvious
enough to rediscover:

- **Commits coalesce to one per event-loop turn** (`Qt.callLater`). A publish that
  writes the identity and the position in one block used to have to write them in
  that order, or the mark flew to a stale centre and then snapped — the wake dying
  for no visible reason. Coalescing makes the order irrelevant.
- **Placement versus switch is derived, not declared.** `targetValid` is how a host
  says "not yet": the first valid target lands outright (`_committed`), so nothing
  slides in from zero or blinks on boot. The widget carried `_indicatorPlaced`
  because only the host could tell a first computation from a selection change —
  a gap the widget could not fill from its own numbers.

## The mechanism, and the one thing that replaces it

The widget's recipe: two ends, each a plain `Behavior` — head
`MotionTokens.medium` (160ms, `OutQuad`), tail `MotionTokens.slow * 2` (480ms,
`OutSine`); anchored at `min(head, tail)`; span is the **raw** separation; **no
cap, no clamp**. Both ends fly toward **one fixed target**, so the stretch opens
as they separate and closes as the shadow lands. Its peak is analytically
**55.5% of the travel at 121ms**, closing exactly at 480ms — check any new
implementation against that number rather than against a screenshot.

Measured on the shared component driving a 100px two-row switch, sampled in wall
clock at 16ms: peak **55.33px at 128ms**, closed exactly at **480ms**. When you
re-measure, divide by the **whole** travel — a probe that divides a two-row jump
by one row's pitch reports 110% and looks like a broken cap.

That recipe assumes the target is **fixed**. When the head must instead follow a
**travelling** element, a `Behavior` cannot be re-targeted every frame and a
follower replaces it:

```qml
// A Timer at 16ms, closing a fixed fraction of the gap per tick.
_tailY += (_headY - _tailY) * trailCatchUp
```

## Ten ways this goes wrong, each measured

1. **A `Behavior` re-targeted per frame is a latch, not a follower.** Restarting
   an easing every frame means it never gets past the start of its curve:
   `OutSine` covers `sin(0.033 * PI/2)`, about 5% of the gap, on the first tick of
   a 480ms flight. With the target moving ~5px a frame the tail advanced
   **0.0085px per frame** — measured as the tail sitting at exactly 60.0 for
   nineteen consecutive frames while the head ran 137 → 196. The wake was the
   head's motion alone.

2. **A follower gated on the gap can never start.** `running:
   Math.abs(head - tail) > 0.5` looks obviously right. But a **pinned** head is
   written directly rather than animated, so both ends are set equal every frame,
   the gap is always zero, and the Timer never starts. No gap → no follower → no
   gap. The wake is then identically zero for the whole transition. **Gate on the
   head moving, or on the pin being in charge — never on the effect you are
   trying to produce.**

3. **"Is it moving?" fails at a leg's start.** `InOutQuad` has no derivative at
   t=0, so a leg's first ticks move the frame by **less than half a pixel** while
   it is very much travelling. A `|Δframe| > 0.5` gate cuts the trail at the
   instant it is widest. Gate on the journey, not on its derivative.

4. **Stepping an animation clock is not wall clock, and every per-tick number
   derived that way is wrong.** `driveMarkerTo` teleports the clock N steps with
   no wall time between samples, so a 480ms tail cannot advance at all, and the
   real shell draws a different number of frames per step. This produced a
   `trailCatchUp` of 0.7 that was **~6× too large**: measured live, the trail was
   1.6px over the calmer half of a crossing on a 26px bar — indistinguishable from
   none. **Sample in wall clock (`wait(16)` in a loop) for anything about the
   mark's own motion.** Stepping the clock is only valid for where the *frame* is.

5. **A slow-motion multiplier divides every per-tick travel.** With an
   observation multiplier of 6, the crossing is stretched over six times as many
   frames and each is one sixth as large. Anything derived per frame in that
   state describes a frame the live shell does not draw. And if a rate couples to
   the multiplier, say so on the property: `k = 0.7 / debugTimeScale` gives a wake
   of `1.262·v` at 6x against `0.429·v` at 1x — **not** thickness-invariant.

6. **Cancelling a transient state destroys the wake.** A branch that parks the
   mark when there is nothing to mark ("it is hidden, so it must not be left
   mid-trail") will wipe a live wake whenever the content is momentarily without
   a target — which is the normal state *during* a transition. Distinguish
   "nothing travelling and nothing to mark" (park it) from "travelling, content
   mid-replacement" (hand it back), and do it from the state rather than from a
   flag that means one thing at rest and another mid-journey.

7. **A publish can replace the target several times in one synchronous block**,
   so no tick exists in which a per-frame follower can see the jump. Carry both
   ends by the same amount and re-base; otherwise the wake grows to 157%/279%/
   619% of itself for a frame.

8. **A bound can contradict its own documented rule, and then red is not a
   mechanism fault.** A bound stated as *"an end travels at most the distance it
   had LEFT, plus however far the target itself moved"* was implemented as only
   the second clause. The tail's resting rate is 3.6px per 16ms against a 1.0px
   allowance, so the bound was unsatisfiable — and it stayed red with the
   mechanism removed entirely, which is the control that proves it. **Before
   treating red as a defect, check the bound is satisfiable by the mechanism's own
   resting rate, and check whether it still fails with the mechanism gone.**

9. **A one-frame sample that straddles a designed teleport is not a defect
   reading.** A corner that jumps across the panel in zero time will show a huge
   step to any 16ms sampler — while a clock-stepping driver, which walks the
   clock in steps with no time between them, cannot see it at all. Both
   instruments are wrong about it; say which.

## How to verify, in order

- **Measure the target's path, and the mark's own motion, separately.** They have
  different clocks and the difference is where every defect above lives.
- **Assert the drawn box, not the ends.** Position AND extent, against the row the
  mark claims, in wall clock — driven through the real host component rather than a
  bare `TrailIndicator`, because a host binding that silently stopped re-evaluating
  looks exactly like a mechanism fault from the mark's side. The ends reading
  correctly is not the mark being correct; it is one property of it.
- **Prove a test bites** by reverting the fix. If reverting leaves it green, the
  test is decorative. QtTest returns from a test function on its *first* failed
  assertion, so to observe several clauses, neutralise their predecessors one at
  a time — and confirm which clause actually catches the defect, because the one
  you assumed may not.
- **Test the path the product takes.** Every failed round here tested the
  *focus-glide* path (the head arrives by `Behavior`, so a gap opens and the
  follower works) while the product used the *pinned* path, which had no coverage
  at all. When two paths exist, find which one the user's gesture takes and test
  that one first.
- **A bound derived from an animation's rates should be expressed against the
  remaining travel, not a peak rate** — peak-over-mean is a function of the
  flight's *total* travel, which is not readable mid-flight, and the two disagree
  most in the middle of a flight.
- **When the user reports a fault that verified work did not reproduce, stop
  reading code and instrument the live shell.** Offscreen simulation reported
  green through five rounds of a fault the user could see every time. A temporary
  per-frame log — one prefixed line, read from `scripts/check-shell.sh`, removed
  before committing — found the latch in one capture. See the project's
  `regression-proof` skill, rule 4.

## Judgement calls to argue rather than assume

- **"Consistent with the reference widget" means the recipe, not the
  conclusion.** The widget *blinks* on an identity change and stretches on a
  positional move; taking its recipe while rejecting its conclusion is legitimate,
  but it must be said out loud, because it is exactly where a user who has asked
  for a trail twice will disagree.
- **An unbounded wake can exceed the panel.** It is 55% of travel by the recipe's
  own nature, so a long list draws a bar longer than the surface and clips it.
  A cap is the tempting fix and it is worse: clamping the stored tail looks
  equivalent and is not, because the head's teleport then forces the tail across
  the panel — trading a 42px step for a 219px one. If a bound is wanted, it has to
  bound the *drawn* wake while the mark stays anchored to the head. Put the
  numbers in front of the user; that trade is theirs.