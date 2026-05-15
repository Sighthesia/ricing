# Implementation Plan

## Phase 1: Services
1.1 Create services/VolumeService.qml — Pipewire sink/source volume singleton
1.2 Create services/BrightnessService.qml — brightnessctl polling singleton
1.3 Update services/qmldir — register new singletons

## Phase 2: Widgets
2.1 Update modules/bar/widgets/Clock.qml — replace hardcoded colors with Color tokens
2.2 Create modules/bar/widgets/Tray.qml — SystemTray icon row + menu
2.3 Create modules/bar/widgets/ActiveWindow.qml — focused window title
2.4 Create modules/bar/widgets/Brightness.qml — brightness indicator + scroll
2.5 Create modules/bar/widgets/Volume.qml — volume indicator + scroll + mute

## Phase 3: Registration
3.1 Update services/barlayout/BarLayoutLayoutModel.js — add all 5 widgets to registry

## Validation
- Shell loads without errors
- Each widget renders in bar
- Scroll/click interactions work
- Color tokens respond to palette changes
