---
name: regression-proof
description: Use when about to claim a bug is fixed, when a fix was verified by a test that passed, or when a bug survived several wrong guesses. Covers the three ways a "green" verification lies — a test that duplicates the logic under test, a flaky suite read as evidence, and repeated reading of code instead of capturing a real frame — plus the red/green proof that actually establishes a fix.
---

# Regression Proof

What it takes to honestly say a bug is fixed. Every item here was learned by
getting it wrong on a real task: a fix committed on a single green run, a
regression test that passed while the production code was reverted, and six
rounds of wrong root causes that all *looked* verified.

## 1. A test that copies the logic under test proves nothing

The most expensive false signal. A regression test written as a replica of the
production expression goes green on **any** change to the real code, because it
never reads it.

Measured: a clip gate was fixed in `BarPopupHost.qml`, and its regression test
carried its own copy of the same boolean. Reverting only the host left the test
at `5 passed`. Reverting both made it fail — which is the only reason it was
caught.

**Put the rule under test in a shared `.js` module** that both the component and
the test import. If the test cannot import it (the logic lives on a `PanelWindow`
that QtTest cannot instantiate), that is a reason to extract the rule, not to copy
it.

```qml
// component
readonly property bool clipPinned: Shared.clipPinned(a, b, c)

// test
import "../../modules/bar/Shared.js" as Shared
```

A test may legitimately replicate *state machine scaffolding* it needs to drive
the sequence. What it may not replicate is the decision being asserted.

## 2. Prove the test bites, by reverting the production code

Every regression test gets one check: revert the fix, confirm red, restore,
confirm green. If reverting the production code leaves the suite green, the test
is decorative — delete it or fix it before trusting anything it says.

Do this **in the same session as the fix**. A test that has never been seen red
is a test that has never been tested.

## 3. "Passed once" is not evidence when the suite is flaky

Measure the baseline before trusting a green run. On this project two main
harnesses turned out to be flaky on **unmodified HEAD**:

| harness | run 1 | run 2 | run 3 |
| --- | --- | --- | --- |
| `tst_bar_popup_host.qml` | 349/0 | 344/5 | 344/5 |
| `tst_bar_tray_menu_content.qml` | 40/3 | 39/4 | 40/3 |

Three "all green" claims in a row were, in truth, one lucky run each. Once this
is known, any single green reading is noise.

Rules that follow:

- Run the relevant file **three times consecutively** before reporting.
- Establish the pre-existing failure set on unmodified code and compare against
  it, rather than expecting zero. "1054 passed / 8 failed, and HEAD gives 1053 /
  8" is a real result; "8 failed" alone reads as breakage.
- Report the instability instead of hiding it. It is a finding about the
  harness, and it changes how much every other result is worth.

**Never** resolve flakiness with a repeat-and-check loop over a bare
`qmltestrunner`. See the platform rules in `AGENTS.md` — each bare invocation maps
a real focused window and breaks the input method.

## 4. After two wrong guesses, stop reading code and capture a frame

Reading the source answers "what does this code do", never "what happened".
Six rounds were spent fixing the wrong layer — clip, then position, then height,
then a submenu, then a stale flag — each verified, each wrong, because the
symptom was always downstream of a state the steady-state reading looked fine.

What ended it: the project's own diagnostics channel (`hoverDebugEnabled` →
`recordHoverSnapshot` → `Quickshell.cacheDir + "/hover-debug.json"`), enabled
against the live session, while the user reproduced it once. One frame showed
`rawColumnHeight=0` against a `421px` panel and named the culprit immediately.

The tell that reading has stopped paying: every trace of the behaviour is healthy
in every phase taken alone. That is a race or a latch, and races are found in
timestamps, not in source.

So: after the second wrong root cause, ask for **one instrumented
reproduction** before writing more code. Add temporary labelled logging, capture,
read the numbers, then remove it.

## 5. Distrust your own earlier green claims

When a fix "did not work", the first thing to re-examine is the verification
that justified the previous commit, not the new hypothesis. Re-derive the
baseline on unmodified code before continuing — otherwise round seven is built on
round one's unverified premise.

## Checklist before saying "fixed"

- [ ] Root cause quoted from a measurement, not from reading the source.
- [ ] Regression test observed **red** with the fix reverted.
- [ ] Rule under test shared with production, not duplicated.
- [ ] Relevant suite run 3× consecutively.
- [ ] Failures compared against the unmodified-HEAD baseline.
- [ ] Temporary instrumentation removed; no unrelated work swept into the commit.
- [ ] Anything unverified stated as unverified.