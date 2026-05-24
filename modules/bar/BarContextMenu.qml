import "."
import "../../services" as Services
import QtQuick
import Quickshell
import Quickshell.Wayland

// Right-click context menu rendered in its own PanelWindow so it is never
// clipped by the bar's 42 px height constraint.
Variants {
    id: root

    model: Quickshell.screens

    PanelWindow {
        required property var modelData

        screen: modelData
        visible: Services.BarLayoutService.contextMenuVisible
        color: "transparent"

        // Overlay: no exclusive zone so it floats without pushing other windows.
        exclusiveZone: -1
        WlrLayershell.layer: WlrLayer.Overlay

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        BackgroundEffect.blurRegion: Services.SettingsService.appearance.enableBlur ? contextMenuBlurRegion : null

        // Match blur to the floating menu card, not the full-screen click-away layer.
        Region {
            id: contextMenuBlurRegion

            item: Services.BarLayoutService.contextMenuVisible ? menuSurfaceBlurInset : null
            radius: Math.max(0, menuSurface.radius - Services.SettingsService.blurRegionInset)
        }

        // Menu surface positioned below the bar at the click X.
        Rectangle {
            id: menuSurface

            // Clamp so the menu never overflows the screen edges.
            x: Math.max(4, Math.min(
                Services.BarLayoutService.contextMenuX - width / 2,
                parent.width - width - 4
            ))
            y: Services.BarLayoutService.barHeight + 4
            width: 180
            height: menuColumn.implicitHeight + 16
            radius: 10
            color: Qt.rgba(0.10, 0.10, 0.10, Services.SettingsService.panelSurfaceOpacity)
            border.color: "#3a3a3a"
            border.width: 1
            opacity: Services.BarLayoutService.contextMenuVisible ? 1 : 0
            scale: Services.BarLayoutService.contextMenuVisible ? 1 : 0.92
            transformOrigin: Item.Top

            Item {
                id: menuSurfaceBlurInset

                anchors.fill: parent
                anchors.margins: Services.SettingsService.blurRegionInset
            }

            Behavior on opacity { NumberAnimation { duration: Services.Motion.popup.opacityDuration; easing.type: Services.Motion.popup.opacityEasing } }
            Behavior on scale { NumberAnimation { duration: Services.Motion.popup.scaleDuration; easing.type: Services.Motion.popup.scaleEasing; easing.overshoot: Services.Motion.popup.scaleOvershoot } }

            Column {
                id: menuColumn

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 8
                spacing: 2

                // Layout mode toggle.
                ContextMenuRow {
                    label: Services.BarLayoutService.settingsMode ? "Exit Layout Mode" : "Layout Mode"
                    icon: "\u2630"
                    highlighted: Services.BarLayoutService.settingsMode
                    onClicked: {
                        Services.BarLayoutService.toggleSettingsMode()
                        Services.BarLayoutService.closeContextMenu()
                    }
                }

                // Widget picker entry for the clicked dockzone section.
                ContextMenuRow {
                    label: "Add Widget to " + Services.BarLayoutService.contextMenuSection
                    icon: "+"
                    onClicked: {
                        Services.BarLayoutService.openWidgetPicker(Services.BarLayoutService.contextMenuSection)
                        Services.BarLayoutService.closeContextMenu()
                    }
                }

                // Divider before widget-specific actions.
                Rectangle {
                    width: parent.width - 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 1
                    color: "#333333"
                    visible: Services.BarLayoutService.contextMenuWidgetKey !== ""
                }

                // Remove widget (only when right-clicked on a widget).
                ContextMenuRow {
                    visible: Services.BarLayoutService.contextMenuWidgetKey !== ""
                    label: "Remove Widget"
                    icon: "\u2212"
                    destructive: true
                    onClicked: {
                        Services.BarLayoutService.removeWidget(Services.BarLayoutService.contextMenuWidgetKey)
                        Services.BarLayoutService.closeContextMenu()
                    }
                }

                // Divider before settings.
                Rectangle {
                    width: parent.width - 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 1
                    color: "#333333"
                }

                // Open settings panel.
                ContextMenuRow {
                    label: "Settings"
                    icon: "\u2699"
                    onClicked: {
                        Services.SettingsService.togglePanel()
                        Services.BarLayoutService.closeContextMenu()
                    }
                }

                // Divider before launcher.
                Rectangle {
                    width: parent.width - 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 1
                    color: "#333333"
                }

                // Open launcher overlay.
                ContextMenuRow {
                    label: "Launcher"
                    icon: "\u2315"
                    onClicked: {
                        Services.LauncherService.toggle()
                        Services.BarLayoutService.closeContextMenu()
                    }
                }
            }
        }

        // Click-away area covering the full window to dismiss the menu.
        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: Services.BarLayoutService.closeContextMenu()
        }
    }

}
