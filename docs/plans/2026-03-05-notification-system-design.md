# Notification System Design

**Date:** 2026-03-05  
**Status:** Approved  
**Reference:** noctalia-shell `Modules/Notification/` + `Services/System/NotificationService.qml`

---

## Goals

Implement a complete, standards-compliant desktop notification system for DymicShell that:

1. Receives DBus notifications via Quickshell's `NotificationServer`
2. Displays ephemeral popup cards on-screen at a user-configurable edge position
3. Persists a scrollable history panel accessible from a Bar bell widget
4. Supports Do-Not-Disturb mode and per-urgency auto-dismiss timeouts
5. Adheres to the DymicShell three-layer architecture and all token conventions

---

## Architecture Overview

```
services/
  NotificationService.qml       # Singleton — data, state, lifecycle

modules/
  notifications/
    NotificationPopupWindow.qml # PanelWindow overlay — ephemeral cards
    NotificationCard.qml        # Single card with swipe/dismiss/actions
  bar/
    NotificationHistoryPanel.qml  # AnimatedPanelBase drop-down — history
    widgets/
      NotificationBell.qml        # Bar widget — bell icon + unread badge

config/
  settings-default.json         # New "notifications" section
```

---

## Layer 1 — Service: `services/NotificationService.qml`

### Responsibility
Single source of truth for all notification state. Never touched by UI code directly — UI only reads from models and calls public API methods.

### State

| Property | Type | Description |
|---|---|---|
| `activeList` | `ListModel` | Currently visible popup notifications (max `maxVisible`) |
| `historyList` | `ListModel` | Persisted history, newest first (max `maxHistory`) |
| `doNotDisturb` | `bool` | When `true`, suppress new popups (history still appended) |
| `unreadCount` | `int` (readonly) | Items added since `_lastSeenTimestamp` |

### Notification Data Object
Each entry in `activeList` and `historyList`:

```js
{
  id:        string,    // Quickshell notification id (numeric → string)
  appName:   string,    // Human-readable app name
  summary:   string,
  body:      string,
  appIcon:   string,    // Icon name or file URI; empty string if none
  urgency:   int,       // 0=low, 1=normal, 2=critical
  timestamp: int,       // Unix ms — for sorting and unread computation
  actions:   [{identifier: string, text: string}]
}
```

### Timeout Logic
Each entry in `activeList` has an associated `Timer` child created via a `Component`. Duration is selected at insertion time:

```
urgency 0 → SettingsService.data.notifications.lowDuration     (default 3000ms)
urgency 1 → SettingsService.data.notifications.normalDuration  (default 5000ms)
urgency 2 → SettingsService.data.notifications.criticalDuration (default 0 = never)
```

A timer is paused when the cursor hovers the card (card emits `hoveredChanged` signal, service responds via `Connections`).

### History Persistence
`FileView` reads/writes `~/.cache/dymicshell/notifications.json`. JSON schema:

```json
{ "lastSeenTimestamp": 0, "items": [ ...NotificationData ] }
```

`historyList` is populated on `onLoaded`. New notifications are appended to `historyList` and written via a 300ms-debounced `Timer` (same pattern as `SettingsService`).

### Public API

```qml
// Dismiss a popup without removing from history
function dismissActive(id: string): void

// Invoke a notification action then dismiss
function invokeAction(id: string, identifier: string): void

// Remove a single entry from history
function removeFromHistory(id: string): void

// Clear entire history
function clearHistory(): void

// Mark all current items as "seen" (resets unreadCount to 0)
function markAllSeen(): void
```

---

## Layer 2 — Popup Window: `modules/notifications/NotificationPopupWindow.qml`

### Window Properties
- `PanelWindow`, layer `Overlay`, `ExclusionMode.Ignore` (never pushes other windows)
- Positioned by `SettingsService.data.notifications.position` (`"top_right"` | `"top_left"` | `"bottom_right"` | `"bottom_left"`)
- Bar offset computed from `Theme.barHeight` to avoid overlapping the bar
- `mask: Region` with `Xor` to make shadow area click-through

### Layout
```
Column (spacing: 8)
  └─ Repeater on NotificationService.activeList
       └─ NotificationCard (max maxVisible entries shown)
```

Cards are inserted at the top of the column; older cards push downward.

### `NotificationCard.qml` Behavior

**Entry animation (per card):**
- `opacity`: 0 → 1, `Theme.anim.enterDuration`, `Easing.OutQuad`
- `y` offset: `-20px` → `0`, same duration, `Easing.OutBack`

**Exit animation (dismiss/timeout):**
- `opacity`: 1 → 0, `Theme.anim.exitDuration`, `Easing.InExpo`
- `y` offset: `0` → `-10px`, same duration

**Swipe-to-dismiss:**
- `DragHandler` on horizontal axis
- Threshold: card width × 0.35 triggers `dismissActive(id)`
- Below threshold: spring-return to 0

**Card layout:**
```
Row
  ├─ AppIcon (32×32, resolved from appIcon field)
  └─ Column
       ├─ Row [ appName (muted) — timestamp (muted) ]
       ├─ summary (bold)
       ├─ body (muted, max 3 lines elide)
       └─ Row [ ActionButton... ] (shown only if actions.length > 0)
```

Colors: `Colors.surface` background, `Colors.border` border, `Colors.text` / `Colors.textMuted` for typography — all via token.

---

## Layer 3 — Bar Components

### `modules/bar/widgets/NotificationBell.qml`
- Wrapped in `BarWidgetWrapper` for drag-reorder + enter animation support
- Icon: `"bell"` (Material Symbols / Nerd Font glyph from existing icon set)
- Unread badge: small `Rectangle` at top-right of icon area, `visible: NotificationService.unreadCount > 0`
- `onClicked`: toggles `BarLayoutService.notificationHistoryOpen`
- Right-click: `BarContextMenu`-style popup with "Toggle DND" + "Clear History"

### `modules/bar/NotificationHistoryPanel.qml`
- Extends `AnimatedPanelBase`
- `active: BarLayoutService.notificationHistoryOpen`
- `anchors { top: true; right: true }`, `margins.top: Theme.barHeight`
- On `panelOpening`: calls `NotificationService.markAllSeen()`

**Content:**
```
Column
  ├─ Header Row [ "Notifications" label | "Clear all" button ]
  └─ ListView on NotificationService.historyList
       └─ HistoryItem: compact card (no actions, swipe-to-delete)
```

Empty state: centered placeholder text when `historyList.count === 0`.

---

## Settings Extension

New key group in `config/settings-default.json`:

```json
"notifications": {
    "position":         "top_right",
    "maxVisible":       5,
    "lowDuration":      3000,
    "normalDuration":   5000,
    "criticalDuration": 0,
    "persistHistory":   true,
    "maxHistory":       100
}
```

Exposed in the `AppearancePage` / a dedicated settings section later.

---

## Token Usage

| Element | Token |
|---|---|
| Card enter animation duration | `Theme.anim.enterDuration` |
| Card exit animation duration | `Theme.anim.exitDuration` |
| Card background | `Colors.surface` |
| Card border | `Colors.border` |
| Summary text | `Colors.text` |
| Body / app name text | `Colors.textMuted` |
| Badge color | `Colors.highlight` |
| Panel open/close | `AnimatedPanelBase` (reuse) |

---

## File Creation Checklist

- [ ] `services/NotificationService.qml`
- [ ] `modules/notifications/NotificationPopupWindow.qml`
- [ ] `modules/notifications/NotificationCard.qml`
- [ ] `modules/bar/NotificationHistoryPanel.qml`
- [ ] `modules/bar/widgets/NotificationBell.qml`
- [ ] `config/settings-default.json` — add `notifications` section
- [ ] `services/BarLayoutService.qml` — add `notificationHistoryOpen: bool`
- [ ] `shell.qml` — instantiate `NotificationPopupWindow`
