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
        implicitHeight: barContent.implicitHeight
        // Reserve only the body height, excluding bottom ears.
        exclusiveZone: Services.BarLayoutService.barHeight

        anchors {
            top: true
            left: true
            right: true
        }

        BackgroundEffect.blurRegion: Services.SettingsService.appearance.enableBlur ? barBlurRegion : null

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
            anchors.fill: parent
        }

    }

}
