---

## Fix round (final review: C1, I1, plus one non-blocking concern)

Commit: see the task-7 fix commit — `fix(startup): latch the auxiliary chrome
mount and open the self-test queue gate` (4 files: `shell.qml`,
`modules/lazerbar/WallpaperBackground.qml`, `tst_lock_startup_order.qml`,
`tests/qml/tst_wallpaper_slot_wiring.qml`, plus this report)

### C1 — the auxiliary Loaders were bound to live TopBar readiness

The review was right, and the mechanism is exactly as described. `barStaged` is
`topBar.startupReady === true` (`shell.qml`), and `TopBar.startupReady` is a
*live* readiness binding over the current screen list
(`TopBar.qml:23`, `BootLogic.isReady(finishedStartupScreens, currentStartupKeys())`).
A re-key or a hotplug prunes the recorded key for the changed geometry
(`TopBar.qml` `refreshStartupReady`), so readiness goes **false** again while the
newly arrived screen batches its widgets. All three auxiliary Loaders were
`active: chromeRoot.barStaged`, so that transition

- destroyed `NotificationHost`, `ScreenRoundedCorners` and
  `OverviewBackgroundWindow` mid-session and rebuilt them a few frames later, and
- left them gone for good if the re-batch never reported, because
  `active` would never come back.

**Fix: a one-way auxiliary-mount latch on `chromeRoot`.**

```qml
property bool auxiliariesMounted: false
…
onBarStagedChanged: {
    if (barStaged)
        chromeRoot.markAuxiliariesMounted()
}
…
function markAuxiliariesMounted() {
    if (chromeRoot.auxiliariesMounted)
        return
    chromeRoot.auxiliariesMounted = true
}
```

with all three Loaders now on `active: chromeRoot.auxiliariesMounted`. The first
staging mounts them; nothing afterwards can unmount them except the root's chrome
loader, which is never deactivated. The `if (barStaged)` guard means a later
`barStaged === false` does not even reach the latch, and the latch's own guard
means a duplicate report is a no-op — one-way twice over.

The change handler cannot miss that first transition: `TopBar`'s own staging is
batched over timer ticks *after* construction (`startupStaging: true` →
`BarContent` batches), so `startupReady` is still false when `chromeRoot` is
created and the first true always arrives as a change.

Preserved on purpose:

- **Terminal Ready/Error handling.** `reportAuxiliaryTerminal` is untouched, so a
  failed auxiliary surface still warns and releases its gate instead of parking
  the startup lock on its floor.
- **Auxiliary watchdog semantics.** `auxiliaryFallbackTimer` still keys off
  `chromeRoot.barStaged && !chromeRoot.auxiliariesReady` at `slow * 2`. A re-key
  during staging stops it exactly as it did before (with the old binding the
  Loaders would have been destroyed and restarted, re-firing `onStatusChanged` and
  re-marking the same latched flags — the same end state, without the teardown).
- **`startupReady` composition** (`barStaged && auxiliariesReady`), so the root's
  chrome-readiness report still sees a re-key, harmlessly, because every report is
  latched.
- **No new layer-shell surface.** A `Loader` still only decides when an existing
  component is created.

`active: chromeRoot.barStaged` no longer appears anywhere in the file.

### I1 — self-test mode could never open the work/palette/pulse gates

Also real, and the two halves interlock:

| Fact | Consequence in self-test mode |
| --- | --- |
| the root skips `startupLock()` when `lockModule.selfTestEnabled` | `_startupGateResolved` is never set, and `_startupLockArmed` stays true → `startupLockExpected` stays **true** forever |
| `startupSelfTestTimer` arms `root.lock()` with **no argument** | `startupRequest = false` |
| `startupWaveStarted` is emitted only under `if (root.startupRequest …)` | no wave, ever |

So `startupWorkDue` (chrome-ready **and** quiet-ready **or** no-lock-expected)
could never become true: `finishStartupWork()` never ran, the shared screen pulse
stayed muted (`RipplePulseService.startupMuted = true` from the root completion)
and `ColorService`'s startup gate stayed closed for the whole run — plus no
launcher prime, no clipboard index, no window-hint read.

**Fix: the self-test flag as a third way into the queue, behind the same guard.**

```qml
readonly property bool startupWorkDue: root.startupChromeReady
        && (root.startupQuietReady || !lockModule.startupLockExpected
            || lockModule.selfTestEnabled)
```

A shell in self-test mode therefore runs the deferred queue as soon as the chrome
has staged, which unmutes the pulse and opens the palette gate one 16 ms tick
later. Unchanged: normal startup and the marker-spent reload (the flag is false
outside self-test mode), the manual lock path, the stage ladder and quiet-ready
(wave is still the only normal writer), the bounded watchdog, and the root's own
`if (!lockModule.selfTestEnabled)` guard on `startupLock()` — self-test still never
requests the real startup auto-lock, and the root never sets `startupRequest`
(it does not appear in the file at all).

One consequence is left standing deliberately: in self-test mode nothing reports a
wave, so the degraded watchdog still fires after its 2.4 s budget and logs
`[startup] startup gates released by the startup-watchdog fallback …`. That is
true of the watchdog's own contract ("no wave was reported") and predates this
change; silencing it would need a lock-side decision about what a self-test run
should report, which is outside this dispatch.

### Non-blocking — `WallpaperSlotLogic.promote()` equal-role pair

Confirmed, and it was dangerous for exactly the stated reason.
`WallpaperSlotLogic.promote` deliberately returns a readable equal pair unchanged
(pinned by `test_promotionDoesNotSwapAnEqualPair`), so with
`settledSlot === incomingSlot` the role-derived `settledImage` **is**
`incomingImage`, and `released.source = ""` clears the very image that was just
promoted — the wallpaper on screen, wiped.

Fixed in production `promoteIncoming()`, not in the pure helper: the equal-pair
contract is intentional and already pinned, and the damage happens at the release.

```qml
if (roles.settledSlot === roles.incomingSlot) {
    console.warn("WallpaperBackground: refusing to promote a collapsed slot pair",
                 wallpaperWindow.settledSlot, wallpaperWindow.incomingSlot)
    wallpaperWindow.incomingSlot = SlotLogic.otherSlot(roles.settledSlot)
    return
}
released.source = ""
```

Fail closed: keep the pixels, say so in the log, and hand the pair back distinct so
the next switch still has a spare slot. Everything above it (`pendingWallpaper`,
`bootRevealWaitingForImage`, `settledOpacity`, both roles, `revealRadius`) has
already settled, so the transition completes either way; the non-settled slot is
invisible — both slots' `visible`/`opacity` follow the settled role — so the
repair has no visual effect. `WallpaperSlotLogic` and its 18 checks are unchanged.

### Tests

`tst_lock_startup_order.qml`: 72 → **80 checks**.

- New `checkAuxiliaryLatch()` (4): the latch is declared inside the chrome and
  closed, and written by one guarded function (guard before write); exactly one
  writer and **no** clearing write anywhere in the file; the arming handler is
  pinned whole as `onBarStagedChanged: { if (barStaged)
  chromeRoot.markAuxiliariesMounted() }`; and no `active:` anywhere reads
  `barStaged` while exactly three read the latch. The handler and latch bodies are
  read as bounded statements, so a function or a comment elsewhere in the file
  cannot vouch for them.
- New `checkSelfTestQueue()` (4): the whole `startupWorkDue` condition asserted
  whitespace-collapsed (a dropped disjunct or a reordered term fails, not just a
  missing substring); the self-test term sits behind the chrome guard and after the
  `&&`; `if (!lockModule.selfTestEnabled)` still guards `lockModule.startupLock()`
  and `startupRequest` appears nowhere in the root; the flag is read in exactly two
  places.
- Updated: the per-loader gate now asserts `active: chromeRoot.auxiliariesMounted`;
  the "still reaches the queue" check covers all three disjuncts and its failure
  detail now prints the bounded declaration. The old detail was a fixed-offset
  slice that drifted ~200 chars past the declaration into the queue body — during
  the negative controls it named neither the missing term nor the mutation, so it
  was replaced with the `statementEnd`-bounded text.
- `checkChromeStaging` is unchanged and still pins `startupReady` and the bounded
  auxiliary watchdog to `barStaged`, so a rewire of either turns red.

`tst_wallpaper_slot_wiring.qml`: 12 → **13**, new
`test_promotionRefusesToReleaseThePromotedSlot()` (the guard exists, comes before
the release, re-separates the pair, and warns).

#### Negative controls (14 production mutations, all reverted from a backup)

Production files only, tests untouched; the tree was restored from a copy after
each run (the fix is uncommitted, so `git checkout` would have thrown it away).

| Mutation | Caught by |
| --- | --- |
| `notificationLoader.active` back on `chromeRoot.barStaged` | 2 checks (per-loader gate + no live `active:`) |
| `markAuxiliariesMounted()` loses its guard | the auxiliary mount has its own one-way latch |
| latch write moved inline into `onBarStagedChanged` | 2 checks (one-way latch + never released: 2 writers) |
| `releaseAuxiliaries()` clears the latch | the auxiliary mount latch is never released |
| `onBarStagedChanged` drops its `if (barStaged)` guard | the first bar staging mounts the auxiliary surfaces |
| `auxiliariesMounted` becomes a static readonly `true` | the auxiliary mount has its own one-way latch |
| `|| lockModule.selfTestEnabled` dropped | 4 checks |
| self-test term hoisted out of the chrome guard | 3 checks |
| self-test now calls `lockModule.startupLock()` | still skips the real startup auto-lock + read-count |
| third `lockModule.selfTestEnabled` read in the pulse mute | read-in-two-places + the pre-existing pulse-mute check |
| root sets `startupRequest: lockModule.selfTestEnabled` on the lock | still skips the real startup auto-lock + read-count |
| collapsed-pair guard deleted | promotion must refuse a collapsed slot pair |
| guard moved after `released.source = ""` | the guard must come before the release |
| refused promotion no longer re-separates the pair | must hand the pair back distinct |

#### Runs

- Focused (`--no-python`): `tst_lock_startup_order tst_wallpaper_slot
  tst_wallpaper_boot tst_glow_pulse tst_color_service_reveal tst_startup
  tst_bar_content_startup` → **9 passed, 0 failed**
  (80 / 13 / 18 / 19 / 21 / 8 / 24 / 25 / 18).
- Full headless suite: **81 passed, 0 failed** (run 1, and run 3 on the final
  content), and one run between them at 80/1 — `tst_smoke_settings`, which is a
  pre-existing runner classification flake, not a regression: it fails to compile
  under `qmltestrunner` with `module "Quickshell" plugin
  "quickshell-coreplugin" not found` (the documented module ceiling), and the
  runner only classifies it as `n/a` when that warning happens to reach its report
  file. It is `n/a` in the other runs and is untouched by this diff. Between run 1
  and run 3, two redundant assertions were dropped from the new test code (a
  re-derived `releasedAt >= 0` and a redundant `indexOf(...) >= 0`); the focused
  set was re-run green after that, and the mutation that each one backed was
  re-checked against the trimmed check.
- `qmllint` on all four files → 0 diagnostics, same as the pre-change baseline
  (weak signal on this machine; recorded as unchanged, not as proof).
- `qmlformat` parses `shell.qml`, `tst_lock_startup_order.qml` and
  `tst_wallpaper_slot_wiring.qml` (rc 0). It returns rc 1 with empty output for
  `modules/lazerbar/WallpaperBackground.qml` — **identically before and after**
  this change, and identically for untouched `modules/lazerbar/WallpaperReveal.qml`,
  so it is a pre-existing property of those files rather than a parse error here.
  The parse gate used instead for that file: `qmldom` builds the full DOM (rc 0),
  plus `tst_wallpaper_slot_wiring` and `tst_wallpaper_slot_logic`.
- `git diff --check` clean. All four files end with a newline.

### Boundaries

- Only `shell.qml`, `modules/lazerbar/WallpaperBackground.qml`,
  `tst_lock_startup_order.qml`, `tests/qml/tst_wallpaper_slot_wiring.qml` and this
  report changed. `modules/lock/` and `modules/lazerbar/WallpaperSlotLogic.js` were
  not touched; `docs/superpowers/{plans,specs}/2026-10-01-startup-reveal-scheduling*`
  and `progress.md` were not modified.
- No `-g`, no `lock-test.qml`, no `qs -p shell.qml`, no real shell.
- Nothing about the manual lock or PAM changed: the self-test release path,
  `startupRequest`, the wave emission rule and the marker file are as they were.

### Manual verification still wanted (human)

- **C1:** with the shell running, change a display's resolution (or unplug and
  re-plug an output) and confirm the notification host, the corner bezel and the
  overview backdrop neither blink nor disappear, and that no surface is recreated.
  Then repeat mid-wallpaper-reveal.
- **I1:** run the shell once with `AFLOAT_LOCK_SELFTEST=1` and confirm the deferred
  queue runs shortly after chrome staging — the pulse unmutes, the palette gate
  opens — and that the lock still releases itself after `selfTestDelayMs` without
  touching PAM.
- The collapsed slot pair is unreachable from the production paths (nothing writes
  the roles except a promotion that preserves them), so the wallpaper guard has no
  manual check; it is a fail-closed net.
- Carried forward from Task 6: palette extraction can still overlap the 800 ms
  lock animation by design — confirm the visible result if approval is available.
