# Panel Unification and Notification Diagnostics Design

## Overview

This design addresses a cluster of related shell issues:

- the settings panel should be centered and expose a clear close action
- the widget picker should be centered and expose a clear close action
- opening widget settings from the widget context menu should only auto-enter
  layout mode temporarily
- closing widget settings should exit layout mode only when this session entered
  layout mode automatically
- widget context menus should no longer expose copy/delete actions
- widgets should stop handling normal left-click behavior while layout mode is
  active, but still support dragging and right-click menus
- notification ownership failures should be diagnosed and surfaced clearly when
  another notification daemon already owns `org.freedesktop.Notifications`

This is not treated as a set of isolated patches. These issues are all symptoms
of two broader concerns:

1. panel interaction rules are inconsistent across the shell
2. notification takeover failures are opaque to the user

---

## Goals

- unify panel close behavior for settings, widget picker, and widget settings
- keep layout-mode entry and exit predictable
- make layout mode safe by disabling normal left-click widget actions
- reduce destructive or noisy context menu actions
- replace notification takeover guesswork with explicit diagnostics

## Non-Goals

- no automatic termination of external notification daemons
- no large-scale global UI state machine rewrite
- no redesign of widget settings content
- no environment-dependent end-to-end notification takeover test

---

## Chosen Approach

We use a medium-scope architecture cleanup.

### Panel Interaction Contract

All panel-like surfaces involved in this workflow adopt a shared behavioral
contract:

- centered placement for settings and widget picker panels
- explicit close button in panel chrome
- close actions perform both UI dismissal and the correct shared-state cleanup

`WidgetSettingsPanel.qml` keeps its dedicated close affordance, but its semantic
role changes from a loose “back” action to a clear close action for the current
settings session.

### Temporary Layout Entry

When widget settings are opened from the widget context menu, the shell records
whether layout mode had to be entered automatically for this interaction.

- if layout mode was already active, closing widget settings does not change it
- if widget settings caused a temporary auto-entry into layout mode, closing the
  panel exits layout mode again

This creates a temporary-access model instead of a destructive global toggle.

### Widget Interaction Guard

While layout mode is active, widgets should no longer execute their normal
left-click business behavior.

- dragging remains available
- right-click context menus remain available
- left-click actions are suppressed through the wrapper layer instead of being
  reimplemented separately inside each widget

This keeps editing behavior consistent across all widgets and avoids repeated
per-widget checks.

### Notification Diagnostics

`NotificationService.qml` should distinguish between:

- successful shell notification ownership
- takeover failure because another daemon already owns the bus name

Instead of silently failing, the service should publish a readable diagnostic
state that identifies the current owner when possible and advises the user to
disable the external notification daemon if they want shell-managed notifications.

The current confirmed owner in this environment is `swaync`, discovered from the
user bus owner of `org.freedesktop.Notifications`.

---

## State Placement

The interaction state belongs in `services/BarLayoutService.qml`, which already
coordinates bar-local panel and editing behavior.

### New Shared State

Add a minimal set of layout-session flags, such as:

- whether the current widget settings session auto-entered layout mode
- whether widget business left-clicks should be suppressed

The exact property names can be chosen during implementation, but the principle
is fixed: session rules live in the service, not in scattered panel components.

### Why Here

This service already owns:

- `activePanel`
- `widgetPickerOpen`
- `widgetSettingsPanelOpen`
- drag state
- selected widget instance state

So it is the correct control point for panel lifecycle and editing-mode cleanup.

---

## Component-Level Responsibilities

### `modules/bar/SettingsPanelWindow.qml`

- move from right-edge anchoring to centered placement below the bar
- add a close button in the panel header area
- close action should set the panel state back to closed without affecting
  unrelated layout-mode state

### `modules/bar/WidgetPickerWindow.qml`

- move from section-left anchoring to centered placement below the bar
- add a close button in the panel header area
- keep picker content behavior intact
- close action should only dismiss the picker

### `modules/bar/WidgetSettingsPanel.qml`

- keep a clear top-level close control
- closing should always close the widget settings panel
- closing should only exit layout mode when the session entered it automatically
- destructive widget removal remains in this panel, not in the context menu

### `modules/bar/BarContextMenu.qml`

- keep widget-specific entry for opening widget settings
- remove `复制组件`
- remove `删除组件`
- when opening widget settings, record whether layout mode was auto-entered for
  this session

### `modules/bar/BarWidgetWrapper.qml`

- remain the unified wrapper for drag and right-click behavior
- act as the shared interception point for layout-mode left-click suppression
- avoid pushing edit-mode checks into every widget implementation

### `services/NotificationService.qml`

- preserve notification data handling behavior
- add takeover diagnostics state
- diagnose current notification bus owner when registration fails
- expose a readable message/status for UI and logs

---

## Data Flow

### Widget Settings Entry and Exit

1. user right-clicks widget
2. context menu opens
3. user clicks `组件设置`
4. service records whether layout mode had to be auto-entered
5. widget settings panel opens
6. user closes widget settings panel
7. service clears widget settings state
8. if layout mode was auto-entered for this session, service exits layout mode

### Widget Interaction in Layout Mode

1. layout mode becomes active
2. wrapper-level guard becomes active
3. normal left-click widget actions are blocked
4. drag and right-click remain available

### Notification Diagnostics

1. notification service attempts to register `NotificationServer`
2. if registration succeeds, ownership state becomes healthy
3. if registration fails, service inspects or records the current bus owner
4. diagnostics state is updated
5. settings UI can show the user who currently owns notifications and how to fix it

---

## UX Notes

### Why Center the Settings and Picker Panels

Centering these two broad surfaces makes them feel like shell-wide workspaces
instead of local side drawers. That better matches their purpose:

- settings affect the shell globally
- widget picker is a catalog, not a local per-section menu

This also makes the close affordance easier to find consistently.

### Why Remove Copy/Delete from the Context Menu

The widget context menu should stay lightweight and low-risk. Removing copy and
delete reduces accidental destructive actions and keeps “quick actions” separate
from “editor actions”.

Delete remains available in the dedicated widget settings surface, where users
already understand they are in an editing context.

---

## Verification Strategy

### UI Structure and Behavior

Extend existing smoke coverage rather than creating a new broad integration test.

Likely targets:

- add or extend a settings/panel structure smoke to verify centered panel config
  and close affordances for settings and widget picker
- add widget-settings session assertions to prove auto-entered layout mode is
  cleaned up on panel close
- add wrapper-level assertions or focused smoke coverage to prove left-click
  business behavior is suppressed in layout mode while right-click remains usable

### Notification Diagnostics

Do not attempt to force real DBus ownership changes inside smoke tests.

Instead:

- verify that the diagnostics state exists and is renderable
- verify that registration failure can produce a readable diagnostic message path
- verify full-shell loading still succeeds even when an external daemon owns the
  notification bus name

### Full Verification

After implementation:

- run the relevant smoke suites
- run `timeout 10 qs --path .`
- confirm diagnostics still report the external notification owner rather than
  failing silently

---

## Expected Outcome

After this change:

- major shell panels feel like one coherent system
- users can close settings surfaces consistently
- widget settings no longer strand users inside layout mode unexpectedly
- layout mode becomes a true editing mode instead of a half-edit / half-runtime mode
- notification takeover failures become understandable and actionable

This is a consistency and operability wave, not a visual redesign wave.
