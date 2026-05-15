# Notification System with Popup Window

## Goal

Implement a notification service that receives D-Bus desktop notifications and displays them as transient popup windows. Referencing the quickshell project's `NotificationManager` + `NotificationContent` pattern.

## Requirements

### R1: Notification Service
- Singleton `NotificationService` in `services/`
- Listen to incoming notifications via Quickshell's `NotificationServer`
- Maintain a `popupList: ListModel` (max 3 concurrent popups)
- Each entry: `{ notifId, appName, summary, body, icon, timestamp }`
- Auto-remove entries after timeout (5 seconds)
- `removeNotification(notifId)` function for manual dismiss
- Respect a `dndEnabled` property (skip popupList when true)

### R2: Notification Popup Window
- `modules/notification/NotificationWindow.qml` — a `PanelWindow` per screen
- Positioned top-right corner via WlrLayershell anchors (top + right)
- WlrLayer.Overlay to appear above all other surfaces
- Displays up to 3 notifications stacked vertically
- Each notification card: icon (40x40) + summary (bold) + body (1 line, elided)
- Click to dismiss
- Auto-dismiss after 5s with a visual countdown (shrinking progress bar)
- Slide-in animation on appear, fade-out on dismiss
- Uses Color singleton tokens for theming

### R3: Integration
- Register in shell.qml as a top-level surface
- NotificationService registered in services/qmldir
- Notifications appear without any user action (passive listener)

## Constraints
- Reuse Quickshell's built-in `NotificationServer` type (from `Quickshell.Services.Notifications`)
- No external dependencies
- Keep popup simple — no notification center/history in V1
- Follow existing PanelWindow patterns (see BackgroundWindow, BarWindow)
- Color tokens from Color singleton

## Acceptance Criteria
- [ ] Notifications from `notify-send` appear as popups
- [ ] Popups auto-dismiss after 5 seconds
- [ ] Click dismisses immediately
- [ ] Max 3 popups visible simultaneously
- [ ] Popups appear on correct layer (above bar, above background)
- [ ] Color tokens applied, theme-responsive
- [ ] DND mode suppresses popups
- [ ] Shell loads cleanly with notification module
