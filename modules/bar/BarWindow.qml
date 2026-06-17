import "."
import "../../services" as Services
import QtQuick
import Quickshell
import Quickshell.Wayland

// Own one transparent bar window per screen.
Variants {
    id: root

    model: Quickshell.screens

    // Host the reusable bar content on the current screen.
    PanelWindow {
        required property var modelData

        screen: modelData
        color: "transparent"
        // Fixed tall height (like IslandWindow) so the window never resizes per
        // frame while the tray dockzone expands its menu downward — resizing a
        // layer-shell surface every animation frame forces a compositor
        // reconfigure roundtrip and stutters the expand. The dockzone grows
        // inside this constant-size transparent window; the mask keeps input
        // restricted to the visible shapes.
        implicitHeight: modelData.height
        // Reserve only the bar body height, excluding the expanded menu area.
        exclusiveZone: Services.BarLayoutService.barHeight

        anchors {
            top: true
            left: true
            right: true
        }

        BackgroundEffect.blurRegion: Services.SettingsService.appearance.enableBlur ? barBlurRegion : null

        // The window is a fixed tall transparent surface. Restrict input to the
        // bar-height band at the top while idle (so the empty area below never
        // blocks other windows); when a dockzone-hosted menu is open take the
        // whole window so a click anywhere outside the menu dismisses it
        // (island-style). exclusiveZone stays pinned to the bar height regardless.
        mask: Region {
            item: (Services.TrayMenuService.visible || Services.BarLayoutService.contextMenuVisible || Services.BarLayoutService.widgetPickerVisible || Services.BarLayoutService.widgetSettingsVisible) ? fullHit : barBandHit
        }

        Item {
            id: fullHit
            anchors.fill: parent
        }

        // Top bar-height band: the resting interactive bar area. Tall enough to
        // include the bottom-ear envelope so edge dockzone ears stay clickable.
        Item {
            id: barBandHit
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: barContent.implicitHeight
        }

        // Click-away dismiss: active only while a dockzone-hosted menu is open,
        // so a click anywhere outside the menu closes it (island-style).
        MouseArea {
            anchors.fill: parent
            z: -1
            enabled: Services.TrayMenuService.visible || Services.BarLayoutService.contextMenuVisible || Services.BarLayoutService.widgetPickerVisible || Services.BarLayoutService.widgetSettingsVisible
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: {
                Services.TrayMenuService.close()
                Services.BarLayoutService.closeContextMenu()
                Services.BarLayoutService.closeWidgetPicker()
                Services.BarLayoutService.closeWidgetSettings()
            }
        }

        // Track blur to visible dockzone geometry parts instead of the full transparent bar window.
        property Variants barBlurRegions: Variants {
            model: barContent.leftSectionBlurParts.concat(barContent.rightSectionBlurParts)

            Region {
                required property var modelData

                item: modelData.item && modelData.item.visible ? modelData.item : null
                radius: modelData.radius
                topLeftRadius: modelData.topLeftRadius ?? modelData.radius
                topRightRadius: modelData.topRightRadius ?? modelData.radius
                bottomLeftRadius: modelData.bottomLeftRadius ?? modelData.radius
                bottomRightRadius: modelData.bottomRightRadius ?? modelData.radius
            }
        }

        Region {
            id: barBlurRegion

            regions: barBlurRegions.instances
        }

        BarContent {
            id: barContent

            screenName: modelData.name
            screenX: modelData.x
            screenY: modelData.y
            screenWidth: modelData.width
            screenHeight: modelData.height
            anchors.fill: parent
        }

    }

}
