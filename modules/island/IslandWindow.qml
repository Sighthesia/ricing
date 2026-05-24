import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../services" as Services

// One island panel per screen — owns center content in both collapsed and expanded states.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: islandWindow
        required property var modelData
        screen: modelData

        anchors {
            top: true
            left: true
            right: true
        }

        implicitHeight: Screen.height
        color: "transparent"
        exclusiveZone: -1
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "afloat-island"

        WlrLayershell.keyboardFocus: Services.IslandService.expanded
            ? WlrKeyboardFocus.Exclusive
            : WlrKeyboardFocus.None

        BackgroundEffect.blurRegion: Services.SettingsService.appearance.enableBlur ? islandBlurRegion : null

        // Keep the blur envelope attached to the animated island surface.
        Region {
            id: islandBlurRegion

            item: islandBody.blurRegionSource
            radius: Math.max(0, islandBody.bodyRadius - Services.SettingsService.blurRegionInset)
        }

        // Mask: when collapsed only the island body receives input;
        // when expanded the full window receives input (for click-away dismiss).
        mask: Region {
            item: Services.IslandService.expanded ? fullHitRegion : collapsedHitRegion
        }

        // Full-window hit region for expanded state.
        Item {
            id: fullHitRegion
            anchors.fill: parent
        }

        // Collapsed hit region tracks the island body bounds.
        Item {
            id: collapsedHitRegion
            x: islandBody.x
            y: islandBody.y
            width: islandBody.width
            height: islandBody.height
        }

        // Click-away dismiss (only active when expanded).
        MouseArea {
            anchors.fill: parent
            enabled: Services.IslandService.expanded
            z: 0
            onClicked: Services.IslandService.close()
        }

        // The island body itself.
        IslandBody {
            id: islandBody
            z: 1
            screenName: modelData.name
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
