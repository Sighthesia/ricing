# Super Island Implementation Plan

**Goal:** Keep Super Island focused on center-worthy information by separating primary transients from weak navigation hints.

**Architecture:** Use one durable baseline surface, one round-trip transient flow for important content, and one flash-only weak-hint path for window switching.

**Tech Stack:** Quickshell QML, singleton services, `Theme.anim.*`, `NotificationService`, `MediaService`, `NiriService`, smoke-harness validation.

---

## Status Snapshot — 2026-03-10

Current implementation in `.worktrees/super-island/` has already completed the core behavior change.

Implemented:

- Super Island registered as the center widget
- media and notification integration
- round-trip transient flow with baseline return
- single active plus single pending scheduling for primary transients
- window switching demoted to flash-only weak hint
- workspace number folded into the window hint
- no standalone workspace content when no focused window exists
- hot-update behavior for consecutive window changes
- smoke regression coverage for round-trip behavior and latest-pending retention

Still open:

- documentation sync in the main workspace if needed outside this worktree
- final UX tuning after real-world usage feedback

## Final Behavior Contract

### Primary transient contract

Applies to:

- notifications
- media changes

Rules:

1. old baseline content moves to flash
2. new content enters the Pill
3. the event holds for 1.5 seconds
4. the event exits
5. baseline content returns from flash to Pill
6. only the latest pending primary transient is retained during overlap

### Window hint contract

Applies to:

- focused window changes
- workspace changes that resolve to a focused window

Rules:

1. the hint does not take over the Pill
2. the hint renders only in flash
3. repeated window changes hot-update the same hint slot
4. stronger primary transients may replace the hint immediately
5. if no focused window exists, no hint is shown

## File Responsibilities

### `services/SuperIslandService.qml`

Responsible for:

- baseline state selection
- active primary transient slot
- latest-pending retention
- weak-hint scheduling rules for window switching
- source adaptation from media, notifications, and Niri events

### `modules/bar/widgets/SuperIslandWidget.qml`

Responsible for:

- rendering the baseline Pill
- rendering the round-trip transition for primary transients
- rendering the flash-only weak hint path for window switching
- protecting against race conditions when a pending transient starts near the end of a return animation

### `tests/qml/SuperIslandServiceSmoke.qml`

Responsible for asserting:

- baseline remains stable during primary transient playback
- primary transient returns baseline content after exit
- only the latest pending transient is retained
- flash extension settles back to zero

## Remaining Tasks

### Task 1 — Refine widget-level controls

**Files:**

- `modules/bar/WidgetSettingsPanel.qml`
- `modules/bar/widgetsettings/SuperIslandSection.qml` (new)
- `services/SettingsService.qml`
- `config/settings-default.json`

**Outcome:**

Expose widget-level toggles for media, notifications, and window-switch weak hints.

### Task 2 — Refine weak-hint visual weight

**Files:**

- `modules/bar/widgets/SuperIslandWidget.qml`
- `modules/bar/superisland/IslandWorkspaceCard.qml`

**Outcome:**

Further compress the visual footprint of window hints if real-world testing still feels too noisy.

### Task 3 — Validate interaction priority in real usage

**Files:**

- runtime only

**Outcome:**

Confirm that rapid window browsing no longer blocks media and notifications from surfacing on time.

### Task 4 — Keep docs aligned with implementation

**Files:**

- `docs/plans/2026-03-09-super-island-design.md`
- `docs/plans/2026-03-09-super-island-plan.md`

**Outcome:**

Update these files whenever the priority model or scheduling model changes again, because the design drift around Super Island has already caused repeated confusion.
