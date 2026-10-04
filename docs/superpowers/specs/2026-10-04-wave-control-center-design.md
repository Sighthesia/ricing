# Wave Control Center Design

## Status

Approved product and interaction design. This document is the implementation
contract for the first control-center slice; it does not authorize unrelated
launcher, settings, or service refactors.

## Goal

Add a control-center page to the existing Wave launcher surface so the shell
can provide a high-frequency desktop snapshot and a small set of immediate
actions without turning the launcher into a settings center.

The control center is optimized for opening often, scanning quickly, and
performing one short action. Long-lived configuration remains in the settings
center. Application and command discovery remains in the launcher search page.

## Product Decisions

- `launcher` remains the default Wave route.
- `control-center` is a sibling Wave route, not a settings-center category.
- The first layout is B1: a balanced two-column surface.
- The left column contains core controls.
- The right column contains a calendar and a short notification summary.
- Network and Bluetooth details open as Wave sub-pages on the same surface.
- Volume and media remain directly actionable from the overview.
- Battery is a read-only status in the top overview, not a control card.
- Weather is an optional, non-blocking cached summary.
- The first version contains four core controls: network, Bluetooth, volume,
  and media.

## Out Of Scope

The first version must not add the following to the default control grid:

- Brightness control
- Do-not-disturb control
- Night-mode control
- Power, logout, suspend, or shutdown actions
- A full weather configuration flow
- A second settings navigation system
- A new notification history implementation

These may be added later behind an explicit expansion point after their service
and error contracts are stable.

## Surface And Navigation

### Routes

The Wave route registry must recognize at least:

```text
launcher
control-center
```

The route state remains owned by the existing Wave session/coordinator. The
control-center component must not create a second top-level popup or a second
surface instance.

### Entry Points

The first implementation may expose the route through the existing launcher
page-switch affordance and a bar/status entry. The exact visual trigger is an
implementation detail as long as it requests the shared Wave session and does
not bypass its coordinator.

Opening the launcher from its normal shortcut continues to select `launcher`.
Opening the control-center entry selects `control-center`.

### Back And Escape

Back behavior is ordered from most local to most global:

1. An active input or slider interaction consumes the event.
2. A network or Bluetooth detail page returns to the control-center overview.
3. The control-center overview returns to the launcher when it was entered
   from the launcher.
4. Otherwise the Wave surface closes.

This must use the existing Wave escape/action seam rather than adding an
independent key handler to the page component.

### Focus

The control-center overview must not automatically focus the launcher search
field. Network and Bluetooth detail pages may establish their own focus only
when an operation requires text input, such as a Wi-Fi credential prompt.

## Layout

### Wide Layout

The control-center surface uses a stable two-column grid:

```text
+----------------------+----------------------+
| time/date/weather    | battery/status       |
+----------------------+----------------------+
| core controls        | calendar             |
|                      | notifications        |
+----------------------+----------------------+
```

The columns should remain visually balanced. The left side is the action area;
the right side is the information area. Notification content must not push the
control grid out of its stable position.

### Narrow Layout

When the available width cannot support two usable columns, the surface stacks
the sections in this order:

1. Overview status
2. Core controls
3. Notifications
4. Calendar

The narrow layout must not rely on horizontal scrolling. Calendar and
notification rows must remain reachable without reducing interactive targets to
an unusable size.

### Overview Header

The header may show:

- Current time
- Current date
- Weather summary, when available
- Battery percentage/state, when available

The header must still render when weather, battery, or another optional service
is unavailable.

## Core Controls

The overview contains exactly four first-version control cards.

### Network

The card shows the current connection summary, such as the active Wi-Fi SSID,
wired connection, or disconnected state. Selecting it navigates to the Wave
network detail page. The detail page owns scanning, profile selection,
password entry, connection, disconnection, and network error presentation.

The control-center card must not duplicate `nmcli` invocation or connection
planning logic.

### Bluetooth

The card shows the adapter/device summary and the currently connected device
when one exists. Selecting it navigates to the Wave Bluetooth detail page. The
detail page owns discovery, pairing, connection, disconnection, and related
errors.

If the adapter is unavailable, the card remains paintable and explains the
unavailable state rather than presenting a dead toggle.

### Volume

The card exposes the default output level and mute state. The level is directly
adjustable from the overview, and the card provides a direct mute action.

UI behavior:

- Update the visual value optimistically while dragging.
- Commit through the existing volume service boundary.
- Reconcile with the service-confirmed value after the operation completes.
- On failure, restore the confirmed value and show an in-card error state.

The card must not create its own audio model or duplicate volume parsing.

### Media

The card shows the current media session when one exists and provides direct
play/pause plus previous/next actions when supported.

When no media session is available, the card remains visible with a neutral
empty state and disables unsupported actions. Media commands must be sent
through the existing media service boundary.

## Information Column

### Calendar

The calendar reuses the pure month-grid logic already represented by
`modules/bar/widgets/ClockCalendar.js`. It shows the current month, highlights
today, and supports previous/next month navigation.

Calendar navigation is local UI state. It must not require a calendar network
service for the first version.

### Notifications

The overview shows:

- Current unread count
- The two most recent relevant notifications
- A route/action to the existing full notification view

Opening the control center must not mark every notification as read. Dismissal
and clearing use the existing notification ownership and confirmation rules.

The notification summary must reserve a bounded area so a burst of incoming
notifications cannot resize or reposition the control column.

## Data Boundaries

The control-center page is an orchestration layer. It combines service state
but does not become the owner of system side effects.

Each card should consume a normalized view model with the following conceptual
fields:

```text
title
summary
status
icon
available
action
detailRoute
error
```

The exact QML/JS shape may follow local project conventions, but the adapter
must make unavailable and loading states explicit. A service that is still
starting must not block the Wave surface from opening.

Existing service responsibilities remain unchanged:

- Network service owns NetworkManager parsing, profile selection, activation,
  disconnection, and connection errors.
- Bluetooth service owns device discovery and connection operations.
- Volume service owns PipeWire/PulseAudio state and writes.
- Media service owns media-session metadata and transport commands.
- Notification service owns notification lifecycle and unread state.
- Calendar math remains pure local logic.

## Weather Contract

Weather is a first-version optional header summary, not a prerequisite for
opening the surface.

The future weather adapter should expose at least:

```text
temperature
condition
location
updatedAt
isStale
available
```

Required UI states:

- Cached value: show value and update age.
- Loading without cache: show a compact loading state.
- Missing location or network: show an unavailable state.
- Failed refresh with cache: keep the cached value and mark it stale.
- Failed refresh without cache: keep the header usable and omit weather detail.

The first surface open must never wait for an HTTP request or weather process.

## Lifecycle And Refresh

- Closing the Wave surface must not tear down the long-lived services.
- Entering a network or Bluetooth detail page retains the overview snapshot for
  immediate back navigation.
- Returning from a detail page schedules a fresh state read so the overview does
  not show the pre-operation connection state.
- Incoming notification, media, volume, and network changes update the cards
  without reopening the route.
- Cross-service cascades that can expose stale sibling values should defer the
  combined view refresh by one event-loop turn, following the existing service
  synchronization convention.

## Loading And Error States

Every card has a paintable state for:

- Loading
- Unavailable
- Empty
- Failed
- Ready

Errors remain local to the affected card or detail page. The control center
must not use modal system-level error dialogs for routine service failures.

An error message should be short and actionable where possible, for example:

- `Wi-Fi adapter unavailable`
- `No Bluetooth adapter`
- `Volume service unavailable`
- `No media session`

The detail pages may expose the richer existing error classifications, such as
incorrect Wi-Fi credentials or an unavailable adapter.

## Motion And Visual Language

The control center reuses the Wave surface transition and the settings-panel
style authority. It must follow the project's sharp osu!lazer language:

- Right-angled major surfaces and geometric joins
- Rounded treatment only for detail-level controls where the existing system
  already uses it
- Existing `MotionTokens` values for route changes and reveal/exit behavior
- No independent transition vocabulary for control cards

Overview-to-detail navigation should read as a page transition within the same
surface, not as a second popup appearing above the first one. Content should be
kept alive for the duration of the outgoing transition when required by the
existing Wave surface motion contract.

## Testing Requirements

### Pure Logic

Add headless tests for any new pure logic, including:

- Control-card normalization for ready, loading, unavailable, and failed
  service snapshots
- Route registration and route/back/escape precedence
- Narrow-layout section ordering and width clamping
- Weather cache/freshness state mapping
- Notification summary capping

Pure logic tests belong under `tests/qml/` and must run through
`scripts/qmltest.sh`.

### QML Behavior

Add a root-level harness only when the test needs Quickshell singletons or
window-backed components. Verify at minimum:

- Default Wave entry still selects `launcher`.
- Control-center entry selects `control-center` on the shared session.
- `Esc` returns from network/Bluetooth detail to the overview before closing.
- Volume and media actions are disabled or show a stable empty state when their
  services are unavailable.
- A failed optional weather load does not prevent the surface from rendering.
- Returning from a detail page refreshes the overview snapshot.

All QML tests must follow the repository's offscreen runner rules. No test may
map an unapproved live surface during normal verification.

### Acceptance Checks

The feature is complete when:

1. The normal launcher path is unchanged.
2. The control-center page opens on the existing Wave surface.
3. The B1 wide layout presents core controls on the left and calendar plus
   notifications on the right.
4. The narrow layout remains usable without horizontal scrolling.
5. Network and Bluetooth detail actions use their existing service logic.
6. Volume and media remain directly actionable from the overview.
7. Optional service failures leave the rest of the surface usable.
8. The settings center remains the destination for long-lived configuration.

## Implementation Boundary

The implementation should be organized around a small route/page component, a
pure control-center logic module, and thin card components or delegates. It
should extend existing service interfaces only where a missing read/action
boundary is proven by the implementation plan. Do not begin by refactoring all
status services into a new global abstraction.

The next artifact is an implementation plan that maps these contracts to the
current Wave, launcher, service, and test files.
