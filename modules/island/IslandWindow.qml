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

        // Track blur to visible island geometry parts instead of the body-only envelope.
        property Variants islandBlurRegions: Variants {
            model: islandBody.blurParts

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
            id: islandBlurRegion

            regions: islandBlurRegions.instances
        }

        // Mask: when collapsed only the island body receives input;
        // when expanded the full window receives input (for click-away dismiss).
        mask: Region {
            item: (Services.IslandService.expanded || Services.BarLayoutService.widgetPickerVisible) ? fullHitRegion : collapsedHitRegion
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

        // Click-away dismiss while the island owns a full-window overlay state.
        MouseArea {
            anchors.fill: parent
            enabled: Services.IslandService.expanded || (Services.BarLayoutService.widgetPickerVisible && Services.BarLayoutService.widgetPickerScreenName === modelData.name)
            z: 0
            onClicked: {
                if (Services.IslandService.expanded)
                    Services.IslandService.close()
                Services.BarLayoutService.closeWidgetPicker()
            }
        }

        // Fullscreen pulse mode paints over the whole screen instead of only shell surfaces.
        Item {
            id: fullscreenRippleLayer

            anchors.fill: parent
            visible: Services.SettingsService.appearance.ripplePulseFullscreen && fullscreenRippleRing.opacity > 0.01
            z: 0.5

            readonly property real maxDiameter: Math.ceil(Math.sqrt(width * width + height * height) * 2)

            function play() {
                fullscreenRippleRing.width = 16
                fullscreenRippleRing.opacity = 0
                fullscreenRippleGlow.opacity = 0
                fullscreenRipplePulse.restart()
            }

            Connections {
                target: Services.IslandService

                function onRipplePulseTokenChanged() {
                    if (Services.IslandService.ripplePulseToken > 0 && Services.SettingsService.appearance.ripplePulseFullscreen)
                        fullscreenRippleLayer.play()
                }
            }

            Rectangle {
                id: fullscreenRippleGlow

                width: fullscreenRippleRing.width
                height: width
                x: parent.width / 2 - width / 2
                y: -height / 2
                radius: width / 2
                color: Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.08)
                opacity: 0
            }

            Rectangle {
                id: fullscreenRippleRing

                width: 16
                height: width
                x: parent.width / 2 - width / 2
                y: -height / 2
                radius: width / 2
                color: "transparent"
                border.width: Math.max(8, Math.min(20, width * 0.018))
                border.color: Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.9)
                opacity: 0
            }

            ParallelAnimation {
                id: fullscreenRipplePulse

                NumberAnimation { target: fullscreenRippleRing; property: "width"; from: 16; to: fullscreenRippleLayer.maxDiameter; duration: 1800; easing.type: Easing.OutCubic }
                NumberAnimation { target: fullscreenRippleRing; property: "opacity"; from: 0.95; to: 0; duration: 1800; easing.type: Easing.OutCubic }
                NumberAnimation { target: fullscreenRippleGlow; property: "opacity"; from: 0.34; to: 0; duration: 1450; easing.type: Easing.OutCubic }
            }
        }

        // The island body itself.
        IslandBody {
            id: islandBody
            z: 1
            screenName: modelData.name
            screenX: modelData.x
            screenY: modelData.y
            screenWidth: modelData.width
            screenHeight: modelData.height
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
