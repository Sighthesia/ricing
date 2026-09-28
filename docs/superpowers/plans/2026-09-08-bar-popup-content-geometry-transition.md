# Bar Popup Content and Geometry Transition Implementation Plan

Date: 2026-09-08
Spec: `docs/superpowers/specs/2026-09-08-bar-popup-content-geometry-transition-design.md`
Scope: plan only. No QML/JS/test implementation in this document step.

## 1. Goal and Non-Goals

Goal: pointer sweeping across bar widgets reuses the single per-screen popup. The popup glides
(`displayX/Y`) and morphs (`displayWidth/Height`) toward the new anchor/size while old content stays
mounted and fully opaque. New content commits at roughly 45% of one shared transition, then width and
height retarget from the current displayed values after the new content measures. One continuous glide,
no blank frame, no opacity dip.

Non-goals:

- No second popup instance, no crossfading content layer, no new window or surface.
- No change to close delay (`closeTimer`, `MotionTokens.fast`), reveal enter/exit (`revealMotion`,
  `revealStartTimer`, `clearIntentTimer`), tray submenu open/close behavior, input mask, or layer-shell
  surface sizing.
- No new motion durations or easings. Position and size use `MotionTokens.medium` + `Easing.OutQuint`.
  Reduced-motion contract unchanged in spirit (immediate commit + direct assign).
- No visual-style change: sharp rectangular surface, existing rail/section colors, existing slide offsets.

## 2. Current Code Facts (verified 2026-09-08)

### 2.1 `modules/bar/BarPopupHost.qml` (850 lines, read in full)

- Intent entry: `updateIntent(intentObj)` (lines 184-231). Calls `cancelClose()`, classifies
  `isOpen = open && currentIntent`, `isReplacement` via `sameIntent()` (lines 266-273, compares
  `widgetId`, `instanceKey`, `kind`, `actionKind`). Fresh open sets `currentIntent` directly; replacement
  calls `beginIntentReplacement(intentObj)`; same-instance refresh overwrites `currentIntent` directly.
  After branching it always writes `root.intent`, `anchorX`, screen/bar/direction fields, then calls
  `updateTargetGeometry(intentObj)` and sets `open = true`, `surfaceActive = true`.
- Replacement today (lines 238-264): `beginIntentReplacement` stores `pendingIntent`, bumps
  `transitionSerial`, and if not reduced-motion does `Qt.callLater(applyPendingIntent(serial))`.
  `applyPendingIntent` guards on `open`, serial match, `pendingIntent`, then sets
  `currentIntent = intent = pendingIntent`, clears `pendingIntent`, calls
  `updateTargetGeometry(nextIntent)`. Exchange happens one event-loop tick after receipt, not at 45%
  of any geometry transition.
- Geometry state (lines 45-64): `displayX/displayY/displayWidth/displayHeight` (rendered) and
  `targetX/targetY/targetWidth/targetHeight` (goal). `revealViewportHeight`, `contentShiftX`,
  `submenuFlipped/flipBaseX` for tray edge flip.
- Geometry computation (lines 307-388): `popupHeightForIntent()` picks `contextPopupActions.implicitHeight`
  for `kind === "context"` else `popupActions.implicitHeight`, with reveal-flight hold via
  `stableContentHeight/stableSidebarHeight`. `targetGeometryFor()` clamps with
  `BarHoverLogic.clampAnchor(anchorX - width/2, ...)` and top/bottom placement. `updateTargetGeometry()`
  measures `baseWidth = max(240, sidebar implicitWidth, content implicitWidth)`, adds
  `trayMenuContent.extraWidth`, computes height from sidebar + slot + 1, handles tray right-expansion /
  left-flip pinning, writes `target*`, calls `commitRevealDistance()` + `retargetGeometry()`.
- Animation today (lines 539-573): four independent `NumberAnimation`s — `xMotion(displayX)`,
  `yMotion(displayY)`, `widthMotion(displayWidth)`, `heightMotion(displayHeight)` — each
  `duration: reducedMotion ? 0 : MotionTokens.medium`, `easing.type: Easing.OutQuint`, restarted together
  in `retargetGeometry()` (lines 398-428). There is no `transitionProgress` property and no shared
  progress clock. Each animation owns its own clock, so a mid-flight `restart()` resets each curve from
  its current value with a fresh full-duration OutQuint; X/Y/W/H ease phases diverge whenever targets
  update at different times.
- `retargetGeometry(intentObj, immediate)` holds display during reveal flight
  (`revealProgress` in 0.01-0.99 returns early unless `immediate`/reduced-motion), direct-assigns
  `display = target` when `immediate || reducedMotion` after stopping all four motions.
- Close paths: `requestClose()` (lines 434-444) invalidates replacement via `invalidateContentTransition()`
  but keeps intents for exit reveal. `closeTimer` (lines 502-523) invalidates replacement, sets
  `open = false`, restarts `clearIntentTimer`. `dismissImmediately()` (lines 461-475) stops timers and
  reveal, invalidates + bumps serial again, zeroes `revealProgress`, clears all intents, sets
  `surfaceActive = false`. `onOpenChanged` (lines 658-689) drives reveal snap/start/exit.
- Content ownership (lines 752-847): one `TwoLayerPopup` with `contentDelay: 0`,
  `animateLayerOpacity: false`, `visible: surfaceActive`. `sidebarData: BarPopupIdentity` bound to
  `currentIntent`; `contentData` slot (`popupContentSlot`) binds `implicitHeight` to
  `popupHeightForIntent(currentIntent)` and calls `updateTargetGeometry(currentIntent)` on
  `onImplicitHeightChanged`. `BarPopupActions` + `BarContextPopupActions` both mounted once, visibility
  switched by `actionKind`/`kind`. `Connections` on `trayMenuContent.extraWidth/submenuProgress` retargets.
- Debug snapshot (lines 129-153) reports `popup.contentLayer.opacity` but host owns no opacity property.
- Gap summary vs spec: (a) no `transitionProgress`; (b) exchange at next tick, not 45%; (c) B's first
  `updateTargetGeometry` measures A's slots because `currentIntent` is still A when `updateIntent`
  computes targets; (d) four clocks can disagree; (e) no start/target capture and no rebase-without-restart
  for the post-exchange size correction.

### 2.2 `modules/lazerbar/MotionTokens.qml` (70 lines)

- `medium: 160`, `fast: 100`, `settingsSidebarFade: 500`, `settingsContentDelay: 200`. Replacement geometry
  must use `medium`; close delay stays `fast`; reveal stays `settingsSidebarFade`/`revealDuration`.
- `reducedMotion` is `reducedMotionOverride` only (line 7). Host already exposes
  `setReducedMotionOverride(v)`. No wall-clock constants may be added for the 45% point; it derives from
  the shared progress (target: exchange when progress crosses 0.45).

### 2.3 `modules/lazerbar/TwoLayerPopup.qml` (135 lines)

- `animateLayerOpacity` exists; host sets it `false`, so sidebar/content opacity stay 1 and reveal is
  geometric (`sidebarOffset/contentOffset` + `revealProgress`). `revealDuration =
  settingsSidebarFade + settingsContentDelay`. `stableSidebarHeight/stableContentHeight` hold heights
  during reveal flight; `popupHeightForIntent` already consults them. No change needed for this plan
  except keeping `animateLayerOpacity: false` and `contentDelay: 0` untouched.

### 2.4 `modules/bar/BarPopupActions.qml` (1202 lines, head read)

- `implicitWidth: 260`; `implicitHeight: actionKind === "context" ? 0 : contentColumn.implicitHeight + 16`;
  `visible: actionKind !== "context"`. Per-kind bodies (volume/brightness/media/notifications/tray/
  battery/bluetooth/network) mount once; only the active kind contributes height. Measurement settles one
  event-loop turn after `currentIntent` changes (binding + childrenRect + async tray DBus batches). Tray
  first-batch cold path needs extra settle ticks (see `revealStartTimer` tray wait, lines 596-654).

### 2.5 Existing tests

- Root harness `tst_bar_popup_host.qml` (635 lines): covers open/replacement/close/reopen/context callbacks/
  geometry separation/reduced-motion/close race. It currently asserts the OLD crossfade contract
  (`host.contentOpacity`, `host.replacingContent`, `contentFade` mid/complete waits, e.g. lines 107, 203-269,
  291-296). The host file in §2.1 defines none of those symbols (grep confirms only hit is the debug
  snapshot's `popup.contentLayer.opacity` read). So the harness as checked out cannot pass against the
  current host; it encodes the superseded 2026-08-31 single-instance crossfade plan. This plan replaces
  those fade assertions with the opaque 45%-exchange contract (see Task 4). Do not treat the stale fade
  checks as regression ground truth.
- Root harness `tst_bar_two_layer_popup.qml` (684 lines, head read): top/bottom direction, edge anchors,
  hover bridge, callbacks. Must stay green; geometry expectations (direction, clamp, owner reuse) are
  unaffected.
- Logic tests `tests/qml/tst_bar_popup_content.qml` (357 lines), `tst_bar_status_popups.qml` (302 lines),
  `tst_two_layer_popup.qml` (168 lines), plus `tst_bar_tray_menu_content.qml`,
  `tst_bar_context_popup_actions.qml`, `tst_bar_hover_logic.qml`: pure QtTest, no Quickshell singletons.
  They cover per-kind content contracts, not host replacement. Must stay warning-free; content-behavior
  changes are out of scope.

## 3. Design Decisions

### 3.1 One shared `transitionProgress` drives all four geometry channels

Add to `BarPopupHost.qml` intent/geometry property block (near lines 22-52):

- `property real transitionProgress: 1` — normalized 0→1 for the current replacement glide. `1` means
  settled. Fresh opens set it `1` (no glide); replacements animate `0 → 1`.
- `property int transitionSerial` already exists; reuse for exchange invalidation. `pendingIntent`,
  `currentIntent`, `display*`, `target*` already exist; reuse.
- Per-channel capture: `property real _startX/_startY/_startW/_startH` plus a target snapshot copy
  (`_targetSnapX/_targetSnapY/_targetSnapW/_targetSnapH`). They snapshot `display*` and `target*`
  whenever a glide starts or rebases.
- One driver: `NumberAnimation { id: transitionMotion; target: root; property: "transitionProgress";
  duration: MotionTokens.reducedMotion ? 0 : MotionTokens.medium; easing.type: Easing.OutQuint }`.
  The easing lives on the progress curve. Displayed geometry is a pure function of progress:
  `displayX = _startX + (_targetX_snapshot - _startX) * transitionProgress` (same for Y/W/H), applied in
  `onTransitionProgressChanged`. Because every channel reads the same eased progress value, X/Y/W/H can
  never disagree about phase, unlike four independent `restart()` clocks.
- Why not keep four animations plus a fifth progress clock: two clocks (geometry vs exchange) reintroduce
  the exact skew the spec forbids ("safe when one property reaches its target before the others" means the
  exchange must not depend on any single channel's `onFinished`). One clock is the exchange source of truth.
- `xMotion/yMotion/widthMotion/heightMotion` are deleted in the same change. `retargetGeometry()` becomes
  "snapshot start + snapshot target + drive progress", never "restart four motions".
- Exchange trigger: in `onTransitionProgressChanged`, when `transitionProgress >= 0.45` and
  `pendingIntent` with matching serial is outstanding, call the exchange once
  (`_exchangeCommitted` flag per serial). "Roughly 45%" = threshold constant `0.45` on the eased progress
  value. It follows `MotionTokens.medium` automatically because progress duration is `medium`. No `Timer`
  with a millisecond delay is used for the exchange.

### 3.2 Exchange-then-rebase without restarting the glide

Sequence for A→B while open (`open && currentIntent && !sameIntent`):

1. `updateIntent(B)`: `cancelClose()`; store `pendingIntent = B`; `transitionSerial += 1`; capture serial.
   Reduced-motion shortcut (see §3.5) bypasses everything below.
2. Immediately retarget POSITION toward B using A's measured size (so motion starts on the same frame):
   compute `targetX/Y` for B's anchor with current width/height via `targetGeometryFor(B, displayWidth,
   displayHeight)`-style call; snapshot `_start* = display*`; snapshot target; set
   `transitionProgress = 0`; `transitionMotion.restart()`. Keep A mounted and opaque. Old `updateIntent`
   also wrote `root.intent = B` immediately for diagnostics; keep writing a separate
   `latestIntent`-style diagnostic or keep `root.intent` as-is? Decision: keep `root.intent = B`
   immediately (existing diagnostics/tests read it), but content bindings stay on `currentIntent = A`
   until exchange. Document that `intent` = newest accepted, `currentIntent` = currently rendered.
3. Progress runs 0→1. At first `transitionProgress >= 0.45` with live serial: commit
   `currentIntent = pendingIntent` (and `intent` already equals it), clear `pendingIntent`, set
   `_exchangeCommitted = true`. Do not touch `display*` or `transitionProgress` here.
4. Measurement turn: `Qt.callLater(remeasureAndRebase, serial)`. In `remeasureAndRebase`, guard serial +
   `open`; read B's settled `implicitHeight`s (`popupActions` / `contextPopupActions` +
   `sidebarLayer.implicitHeight`, `trayMenuContent.extraWidth`); recompute true `targetWidth/Height`
   with existing clamping + tray flip logic; recompute `targetX` with the true width (anchor recenter).
   Then REBASE without resetting progress: `_startX/Y/W/H = displayX/Y/W/H (current)`,
   target snapshot = new targets, keep `transitionProgress` at its current value (≈0.45+ε). The remaining
   0.55 of the same curve now covers the corrected distance. Display never snaps because at the rebase
   instant `display(start, target_new, p) ` is recomputed from the live display value, so continuity holds
   by construction. `commitRevealDistance()` still runs so the viewport covers the new target.
5. Progress continues to 1; `onTransitionProgressChanged` near 1 (or `transitionMotion.onFinished`) marks
  settled. No second animation starts. A late tray DBus batch arriving while progress < 1 rebases at most
  once; a batch arriving after progress hits 1 runs one settled-path micro-glide from current display
  (same driver, fresh 0→1).

Why this satisfies "updating the target must not assign display directly" and "same animations settle
without restarting from zero": the only writes to `display*` are the progress function and the
reduced-motion/immediate direct assign. Rebase changes start/target, never display.

### 3.3 What happens to `updateTargetGeometry` / `retargetGeometry` / reveal guard

- `updateTargetGeometry(intentObj, immediate)` keeps ownership of target computation (width/height/clamp/
  tray flip, lines 333-388). It stops owning animation clocks. Its tail becomes: write `target*`, snapshot
  target copy for the progress driver, `commitRevealDistance()`, then delegate to the progress driver
  (`startOrRebaseGlide(intentObj, immediate)`).
- The reveal-flight hold (`revealProgress` in 0.01-0.99 → return early) stays for FRESH opens only.
  Replacements by definition happen while `open && revealProgress ≈ 1`; if a replacement arrives
  mid-reveal (open just set, reveal still flying), the progress glide still starts (popup is moving anyway)
  but height rebase is deferred until `revealMotion.onFinished` fires, reusing the existing
  "deferred geometry sync" slot (lines 531-536). State this branch explicitly in code comments.
- `commitRevealDistance()` unchanged. `onDisplayXChanged` flip-release (lines 693-701) unchanged; it reads
  `displayX` which the progress driver writes, so it keeps working.

### 3.4 opacity: delete, do not gate

- Spec removes cross-component opacity animation entirely. `TwoLayerPopup.animateLayerOpacity` stays
  `false`; no `contentOpacity`/`replacingContent`/`contentFade` property or animation is introduced.
  Content `enabled`/`contentInteractive` stays derived from `popup.interactable` (reveal-settled) only.
- The stale harness assertions on `contentOpacity`/`replacingContent` are updated to assert
  `sidebarLayer.opacity === 1 && contentLayer.opacity === 1` throughout replacement (see Task 4).

## 4. File Map (exact paths)

Modify:

- `modules/bar/BarPopupHost.qml` — sole implementation file. Regions: intent property block (~lines 22-52),
  `updateIntent` (~184-231), `beginIntentReplacement` + `applyPendingIntent` (~238-264),
  `updateTargetGeometry` + `retargetGeometry` (~333-428), motion block (~526-573), content slot bindings
  (~787-846, read-only except removing any fade hooks if present — none present today).
- Root harness `tst_bar_popup_host.qml` — replace stale fade contract with 45%-exchange contract; add
  A→B→C, close-race, reduced-motion, opacity-pinned checks.
- Root harness `tst_bar_two_layer_popup.qml` — no functional change expected; add one glide smoke check
  only if cheap (owner reuse + clamped target after rapid hover swap). Otherwise verify-only.

Verify-only (no edits):

- `modules/lazerbar/MotionTokens.qml`, `modules/lazerbar/TwoLayerPopup.qml`,
  `modules/bar/BarPopupActions.qml`, `modules/bar/BarContextPopupActions.qml`,
  `modules/bar/BarHoverLogic.js`, `modules/bar/BarContent.qml`.
- Logic tests: `tests/qml/tst_bar_popup_content.qml`, `tests/qml/tst_bar_status_popups.qml`,
  `tests/qml/tst_two_layer_popup.qml`, `tests/qml/tst_bar_tray_menu_content.qml`,
  `tests/qml/tst_bar_context_popup_actions.qml`, `tests/qml/tst_bar_hover_logic.qml`.

## 5. Tasks

### Task 1 — Shared progress driver replaces four clocks

File: `modules/bar/BarPopupHost.qml` (property block + motion block + `retargetGeometry`).

- [ ] Step 1: Add `transitionProgress: 1`, `_startX/_startY/_startW/_startH` plus
  `_targetSnapX/_targetSnapY/_targetSnapW/_targetSnapH`,
  `_exchangeCommitted: false`, `exchangeThreshold: 0.45` (readonly real) next to `display*/target*`.
  Add `transitionMotion` (`NumberAnimation` on `transitionProgress`, `duration: reducedMotion ? 0 :
  medium`, `easing.type: OutQuint`). Add `onTransitionProgressChanged` that (a) writes all four
  `display*` from start/target snapshots, (b) fires the exchange once at `>= 0.45` when a live pending
  serial exists.
- [ ] Step 2: Delete `xMotion/yMotion/widthMotion/heightMotion`. Replace `retargetGeometry(intentObj,
  immediate)` body with snapshot-start + snapshot-target + `transitionProgress = 0; transitionMotion.restart()`
  (or direct assign when `immediate || reducedMotion`, stopping `transitionMotion` first). Keep the
  reveal-flight early return for fresh opens.
- [ ] Step 3: Run `timeout 25 qs -p tst_bar_popup_host.qml` expecting failures on stale fade assertions
  (proves old contract detached); run
  `QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_two_layer_popup.qml -o -,txt`
  expecting pass (no TwoLayer change).
- [ ] Step 4: Manual check: single A→B hover sweep shows one position glide with no snap; `display*` only
  changes via progress handler or reduced-motion assign (grep-verify, no `displayX =` elsewhere).

### Task 2 — 45% exchange + measure + rebase without restart

File: `modules/bar/BarPopupHost.qml` (`updateIntent`, `beginIntentReplacement`, `applyPendingIntent`,
`updateTargetGeometry`).

- [ ] Step 1: Rework `updateIntent` replacement branch: on `isReplacement`, call
  `beginIntentReplacement(B)` which (a) sets `pendingIntent = B`, bumps serial, clears
  `_exchangeCommitted`, (b) computes B-anchor position targets with CURRENT size, snapshots start/target,
  resets `transitionProgress = 0`, restarts `transitionMotion`, (c) keeps `currentIntent = A` mounted.
  Keep `root.intent = B` immediate for diagnostics; content stays bound to `currentIntent`.
- [ ] Step 2: Implement exchange in the progress handler: at first `progress >= 0.45` with
  `serial === transitionSerial && pendingIntent`, set `currentIntent = pendingIntent`,
  `pendingIntent = null`, `_exchangeCommitted = true`, then `Qt.callLater(remeasureAndRebase, serial)`.
  Stale serials do nothing.
- [ ] Step 3: Implement `remeasureAndRebase(serial)`: guard serial + `open`; let B's bindings settle
  (one `Qt.callLater` turn; tray intents additionally wait for `menuLoading === false && liveCount > 0`
  with the existing stability pattern borrowed from `revealStartTimer`, capped, without blocking the glide);
  recompute true width/height/X via the existing `updateTargetGeometry` math (extract pure computation so
  the animation tail is not duplicated); rebase `_start* = display*`, target snapshot = new targets, keep
  `transitionProgress` untouched; call `commitRevealDistance()`. Never assign `display*` here.
- [ ] Step 4: `transitionMotion.onFinished` (or progress reaching 1) marks settled; a deferred tray batch
  arriving after 1 runs one settled-path micro-glide from current display (same driver, fresh 0→1).
- [ ] Step 5: Run `timeout 30 qs -p tst_bar_popup_host.qml` (updated harness from Task 4 may land together;
  at minimum verify no WARN/ERROR, glide completes, content ends on B, `display* === target*` at settle).

### Task 3 — Rapid A→B→C, close race, reduced motion

File: `modules/bar/BarPopupHost.qml` (same regions + close paths).

- [ ] Step 1: Pre-exchange C (progress < 0.45, pending B outstanding): `beginIntentReplacement(C)` overwrites
  `pendingIntent = C`, bumps serial (B's exchange auto-stales), snapshots `_start* = display*` (current
  mid-glide position), recomputes C-anchor targets, resets `transitionProgress = 0`, restarts motion. Display
  does not jump because start equals live display. Only C can commit.
- [ ] Step 2: Post-exchange C (B already committed, progress in 0.45-1): same as a fresh replacement from
  current display: `pendingIntent = C`, new serial, snapshot start, reset progress 0→1. B rendered briefly;
  acceptable per spec (newest intent wins, no stale paint after accept).
- [ ] Step 3: Close invalidates: `requestClose()`, close-timer fire, and `dismissImmediately()` all
  `transitionMotion.stop()` + `invalidateContentTransition()` (bump serial, clear `pendingIntent`, clear
  `_exchangeCommitted`). The progress handler and any deferred `remeasureAndRebase` re-check serial +
  `open` before writing anything, so no content installs after close starts. Exit reveal (`startReveal(0)`)
  is untouched and runs on the old content.
- [ ] Step 4: Reduced motion (`MotionTokens.reducedMotion` true at `beginIntentReplacement` time):
  `transitionMotion.stop()`, commit newest intent immediately (`currentIntent = intent = pendingIntent`,
  clear pending), run target computation, direct-assign `display* = target*`, set
  `transitionProgress = 1`. No exchange threshold, no deferred remeasure (measure synchronously; tray async
  batches still settle via existing reveal-wait path, not via glide).
- [ ] Step 5: Same-instance refresh path (`sameIntent` true) keeps current direct behavior: update fields +
  `updateTargetGeometry` without touching serial/progress/exchange.

### Task 4 — Harness and logic-test updates

Files: `tst_bar_popup_host.qml` (modify), `tst_bar_two_layer_popup.qml` (verify, extend only if cheap),
logic tests (verify-only).

- [ ] Step 1: In `tst_bar_popup_host.qml`, delete/replace every `contentOpacity` / `replacingContent` /
  `contentFade` / `fadeMidWait`-style assertion with the opaque contract:
  (a) different widget identities keep `popup.sidebarLayer.opacity === 1` and
  `popup.contentLayer.opacity === 1` at start, mid-glide, and settle;
  (b) `currentIntent` is still A before progress crosses 0.45 and equals B after (poll or step the progress
  deterministically — prefer driving `transitionProgress` via the real motion with short waits, not by
  poking internals, plus one reduced-motion synchronous case);
  (c) width/height targets update after B measures and `display*` never snaps (assert
  `|display - target|` shrinks monotonically across two samples and `display` at exchange ≠ old A size);
  (d) rapid A→B→C commits only C (`currentIntent.widgetId === C`, never B);
  (e) close during pending glide leaves A rendered through exit and pending cleared;
  (f) reduced-motion commits synchronously with `display* === target*` and `transitionProgress === 1`.
- [ ] Step 2: Keep all still-valid checks: owner reuse (`popupItem` identity), outer surface fixed size,
  clamped targets, top/bottom direction flip, context callback latest-wins, `dismissImmediately` full clear,
  clear-timer race. Update any check that assumed `root.intent` timing if `intent` vs `currentIntent`
  semantics shift (document which one each check reads).
- [ ] Step 3: Run the full focused set and require zero FAIL and zero QML WARN/ERROR (see §6). Logic tests
  must pass unmodified; if any content test needs a timing tweak due to the removed fade, prefer lengthening
  its wait over changing its assertions, and record the reason.

### Task 5 — Final verification and rollout safety

- [ ] Step 1: `qmllint` (if available) on `modules/bar/BarPopupHost.qml`; otherwise `qs -p` startup smoke.
- [ ] Step 2: Full test sweep from §6 in fresh processes.
- [ ] Step 3: Manual sweep: top bar across volume → brightness → media → notifications → tray (one continuous
  glide, size morphs, no blank frame); bottom bar same; right-click context in/out; rapid shake across three
  widgets (ends on newest, never stale); tray submenu open mid-glide; reduced-motion on (instant swap, stable
  final geometry).
- [ ] Step 4: Rollback check: change is confined to `BarPopupHost.qml` + harnesses; revert those files to
  restore the next-tick swap. No service, theme, or content-file dependency.

## 6. Validation Commands

Qs-host behavioral harnesses (run from repo root, one fresh process each):

```bash
timeout 30 qs -p tst_bar_popup_host.qml
timeout 30 qs -p tst_bar_two_layer_popup.qml
```

Pure-logic QtTest (Qt6 runner only; `/usr/bin/qmltestrunner` is Qt5 and invalid):

```bash
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_bar_popup_content.qml -o -,txt
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_bar_status_popups.qml -o -,txt
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_two_layer_popup.qml -o -,txt
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_bar_tray_menu_content.qml -o -,txt
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_bar_context_popup_actions.qml -o -,txt
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_bar_hover_logic.qml -o -,txt
```

Pass criteria: every harness prints `Totals: N passed, 0 failed` (or equivalent zero-FAIL), every
qmltestrunner run prints zero `FAIL!`, and no line matches `WARN`/`ERROR` from the QML engine. Never use
`qs -p tests/qml/tst_*.qml` as a test signal (it loads but does not execute QtTest).

## 7. Risks and Rollback Boundaries

- Progress-function vs OutQuint feel: driving display from eased progress reproduces the current OutQuint
  curve exactly when start/target are fixed; after a mid-glide rebase the remaining curve is a fresh OutQuint
  segment from the rebase point, slightly softer than a restarted full curve. Acceptable; do not add a second
  easing layer. Mitigation: keep `duration: medium`, single easing site.
- Exchange visibility: at eased-progress 0.45 the popup has already covered most travel (OutQuint
  front-loads). Content swaps while moving fast, which is the spec intent, but large height deltas can read
  as a late grow. Mitigation: rebase keeps the remaining 0.55 of travel for the size correction; viewport
  (`revealViewportHeight`) already covers `max(display, target)`.
- Tray async measurement: DBus batches arrive after exchange; each batch must rebase at most once and never
  after settle except via the settled micro-glide path. Mitigation: reuse the `revealStartTimer` stability
  pattern (count + column-height stable ticks, capped attempts), adapted to post-exchange remeasure.
- Reveal interplay: replacement during fresh-open reveal flight must not fight `revealMotion`. Mitigation:
  position glide may run, height rebase defers to `revealMotion.onFinished` (existing deferred-sync slot).
- Stale-harness confusion: `tst_bar_popup_host.qml` currently encodes the removed fade contract and references
  host symbols that do not exist. Mitigation: Task 4 lands with the implementation; never cherry-pick one
  without the other.
- Rollback boundary: `modules/bar/BarPopupHost.qml` + `tst_bar_popup_host.qml`
  (+ `tst_bar_two_layer_popup.qml` if extended). Reverting these restores the current next-tick behavior.
  No other file may carry load-bearing changes for this feature; services, theme tokens, content bodies, and
  `TwoLayerPopup.qml` stay untouched.

## 8. Acceptance Checklist (maps to spec)

- Sweeping widgets produces one continuous glide; position, width, height morph with no blank frame.
- `sidebarLayer.opacity` and `contentLayer.opacity` read 1 at every sample during replacement.
- `currentIntent` renders A before progress 0.45 and B after; `display*` never assigned directly
  mid-glide (only the progress function writes it).
- Rapid A→B→C ends on C; close mid-glide never installs pending content; reduced-motion swaps instantly
  with stable final geometry.
- Close delay, reveal, tray submenu, input mask, outer surface size, and sharp-rectangle language unchanged.
- Full §6 suite green with zero WARN/ERROR.
