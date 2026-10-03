---
name: startup-reveal-scheduling
description: Use when Afloat's startup visibly stalls in phases — the wallpaper reveal or the bar expand gets interrupted, or several separate hitches land instead of one. Covers measuring first, gating on real completion signals rather than guessed delays, running independent boot work in parallel, deferring cold paths off the first frame, and re-checking every timer budget that was sized against a step you just changed.
---

# Startup / Reveal Scheduling

Afloat's boot is a staged reveal: wallpaper disc opens, chrome mounts behind it,
bar widgets batch in, the lock waves. When that pipeline stalls, the symptom is
"the wallpaper stutters" or "the bar arrives late" — which points at the
animation, while the real cost is almost always initialization work colliding
with the first frames.

## 1. Instrument before changing anything

Two rounds of guessing were spent on this (a suspected second wallpaper decode,
then a parameter retune) and both were wrong. One trace produced both real root
causes.

Add temporary instrumentation, have the user reproduce with a **real reload**,
read it, then delete it. What to record:

- a phase timestamp at each gate (`wallpaper-begin`, `mountChrome:begin`, …)
- **event-loop gaps** — the single most valuable signal. A gap in the hundreds of
  milliseconds is a synchronous CPU job on the GUI thread, named by whatever
  warning appears inside the same window.

A `qml:`-category warning appearing right next to a large gap is the cheapest
possible root cause. In this session the gap and
`LauncherResultRow.qml … Cannot open …` landed in the same window and named the
culprit outright.

## 2. Gate on real completion signals, never on a guessed delay

The classic Afloat bug: a `JsonAdapter` starts with an empty path, the wallpaper
treated "empty" as a terminal boot outcome, boot completed instantly, chrome
mounted, and the real wallpaper arrived ~2s later — so the boot reveal degenerated
into a live switch colliding with bar initialization.

**Rule: an empty/default value is not a terminal state.** Wait for the source that
can supply a real one (persisted settings loaded, image decoded, window measured).

**Rule: never wait a fixed number of frames or milliseconds for something you can
be told about.** DymicShell waits 150ms here on purpose; Afloat deliberately does
not, because it can wait for the wallpaper's own pixels.

## 3. Parallelize independent stages — from a *start* cue, not a completion cue

Serializing chrome behind "wallpaper boot complete" guarantees the bar is always
at least one reveal behind. Move the cue earlier to the wallpaper's **start**:

```qml
// WallpaperBackground: fires when the first request begins, not when it lands.
function reportBootStarted() { … }

// shell.qml: stage chrome alongside the decode.
onBootStartedChanged: if (bootStarted) root.mountChromeForWallpaperBootstrap()
```

The later gate still exists for the startup lock wave — `bootReady` keeps its own
meaning, and only the *cue to mount* moved.

**Gotcha:** this only holds if the parallel work is genuinely independent. Mounting
chrome in the middle of `beginWallpaper()` re-enters the constructor of a large
object graph; keep the cue at a boundary, not inside someone else's setup.

## 4. Keep first-frame-adjacent cold paths off the first frame

Classify each boot task:

| Class | Examples | Rule |
|---|---|---|
| Must block first frame | wallpaper decode, bar shell geometry | do it, gate on its real signal |
| May overlap | bar widget batches, settings-dependent styling | start early, stagger |
| Must not touch frame 1 | launcher page/delegate construction, palette extraction (~1.6s CPU-bound), icon and font first-use init | defer behind an explicit gate |

Concretely: `routeLoader.active: root.phase !== "closed"` stops a closed wave from
constructing `LauncherPage`, and launcher prewarm waits on
`startupPrewarmAllowed` (wired to `shell.qml`'s `startupWorkFinished`).

Palette extraction is the one that hurts most: ~1.6s of synchronous CPU. It must
not start until the circle has finished growing — `ColorService.revealStarted()` /
`revealCompleted()` are that handshake.

## 5. Re-check every budget sized against what you just changed

Lengthening a step silently breaks any timer that was calibrated to the old
length. The startup watchdog was `slow * 10` = 2400ms; raising the boot reveal to
3000ms made **every healthy login** trip it, which both released the gates early
(shell popping in mid-circle — the exact artifact the change was meant to remove)
and logged a misleading degraded-boot warning.

**Rule: after changing any boot duration, grep for every timeout, watchdog and
budget that references it, and make each one cover the new length explicitly.**

## 6. Slow, soft motion is legitimate load shedding

DymicShell's wallpaper reveal is `Math.round(3000 / speedFactor)` with
`Easing.InOutSine` (default speedFactor 1.0) — a three-second soft sweep from the
centre. Afloat originally shipped 480ms `OutCubic`, a hard stop.

A gentle open does not cost frames; it **hides** the initialization happening
underneath it. Treat boot motion as a load-shedding decision, not only a taste
decision. Keep a user-initiated action on a fast contract — a live wallpaper switch
should not crawl open for three seconds, so the two are separate tokens
(`wallpaperBootReveal` vs `wallpaperSwap`) selected by a shared rule.

Reference: `DymicShell/modules/background/BackgroundWindow.qml` (this user's local
checkout at `~/0_Files/Producing/Software/Quickshell/DymicShell`).

## Don't

- Don't tune animation parameters to fix what is really a blocking CPU job.
- Don't treat "the tests pass" as evidence a surface exists — see
  `quickshell-variants-delegate-hijack`, where a static test stayed green through a
  completely dead surface.
- Don't add a `Timer` to paper over a missing readiness signal.

## Verification

- Re-read the trace after the change and confirm the large event-loop gaps are gone,
  not merely shifted.
- `scripts/run-tests.sh` (offscreen by default). Never bare `qmltestrunner` — it maps
  real windows and destroys fcitx5 input on a live session.
- Confirm the startup ladder still has exactly one writer per quiet-ready gate, and
  that the watchdog budget textually covers the longest legitimate step.
- Ask the user for one real reload; startup regressions are invisible to headless
  tests by construction.
