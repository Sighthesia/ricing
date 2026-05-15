# Bar Widgets: Clock, Tray, ActiveWindow, Brightness, Volume

## Goal

Add 5 functional bar widgets to afloat, referencing the quickshell project's proven patterns. Each widget integrates with the existing BarLayoutService widget registry and uses Color singleton tokens for theming.

## Requirements

### R1: Clock (enhance existing)
- Upgrade existing Clock.qml to use Color singleton tokens instead of hardcoded colors
- Keep compact date + time format (MMM d | HH:mm)

### R2: System Tray
- Widget displaying SystemTray.items as a row of icons
- Left-click: activate tray item
- Right-click: open tray item menu (PopupWindow with QsMenuOpener)
- Icon size: 18×18, spacing: 4px

### R3: Active Window Title
- Show focused window title (elided, max ~200px)
- Show app icon when available
- Use Hyprland.focusedClient or equivalent IPC

### R4: Brightness Control
- Display current brightness level via brightnessctl
- Scroll wheel to adjust brightness
- Visual indicator (icon or mini bar)
- Poll interval: 5s or on-demand

### R5: Volume Control
- Pipewire integration via Quickshell.Services.Pipewire
- Display sink volume level
- Scroll wheel to adjust volume
- Click to toggle mute
- Visual mute state indicator

## Constraints
- All widgets register in BarLayoutLayoutModel.js (AVAILABLE_WIDGETS + DEFAULT_WIDGET_SOURCE_BY_ID)
- All widgets use Color.mXxx tokens for colors
- Widgets live in modules/bar/widgets/
- Services (Volume, Brightness) live in services/ as singletons
- No new system dependencies beyond brightnessctl (standard on Arch)
- Follow existing widget sizing patterns (implicitWidth/implicitHeight)

## Acceptance Criteria
- [ ] Clock uses Color tokens
- [ ] Tray shows system tray icons, click/right-click work
- [ ] ActiveWindow shows focused window title
- [ ] Brightness responds to scroll wheel
- [ ] Volume responds to scroll wheel and click-to-mute
- [ ] All 5 widgets appear in widget picker
- [ ] All widgets theme correctly when wallpaper changes
