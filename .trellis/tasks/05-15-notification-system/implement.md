# Implementation Plan

## Phase 1: Notification Service
1.1 Create services/NotificationService.qml
  - [ ] pragma Singleton + Singleton root
  - [ ] import Quickshell.Services.Notifications
  - [ ] NotificationServer listener
  - [ ] popupList: ListModel (max 3)
  - [ ] Per-notification Timer (5s) for auto-removal
  - [ ] removeNotification(notifId) function
  - [ ] dndEnabled property
  - [ ] Map incoming notification to { notifId, appName, summary, body, icon, timestamp }
1.2 Update services/qmldir — register NotificationService

## Phase 2: Notification Popup Window
2.1 Create modules/notification/NotificationWindow.qml
  - [ ] Variants { model: Quickshell.screens } for multi-screen
  - [ ] PanelWindow with WlrLayershell.layer: WlrLayer.Overlay
  - [ ] Anchors: top + right
  - [ ] Column of notification cards from NotificationService.popupList
  - [ ] Each card: Row { Image + Column { summary, body } }
  - [ ] MouseArea click → dismiss
  - [ ] Progress bar (Rectangle width animation 5s)
  - [ ] Enter transition: slide from right (NumberAnimation on x)
  - [ ] Exit transition: opacity fade out

## Phase 3: Integration
3.1 Update shell.qml — import and instantiate NotificationWindow
3.2 End-to-end test: `notify-send "Test" "Hello world"`

## Validation
- notify-send triggers popup appearance
- Popup auto-dismisses after 5s
- Click dismisses immediately
- Multiple notifications stack vertically
- Shell restart: no crash, no leftover state
