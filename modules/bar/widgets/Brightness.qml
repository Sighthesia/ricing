import QtQuick
import ".."
import "../../lazerbar"
import "../../../services" as Services

// Square brightness: wheel steps, level shown as rounded horizontal bar below icon.
Item {
    id: root

    // Widget identity contract filled by the layout loader.
    property string widgetId: ""
    property string instanceKey: ""
    property string section: ""
    property string screenName: ""

    readonly property real level: Math.max(0, Math.min(1, Services.BrightnessService.brightness))

    // Opt-in hover intent publication for BarPopupHost.
    signal popupRequested(var intent)
    signal popupCloseRequested()
    signal popupAnchorUpdate(var intent)

    implicitWidth: LazerTheme.barWidgetHeight
    implicitHeight: LazerTheme.barWidgetHeight

    // Hover observation for brightness pill.
    HoverHandler {
        id: brightnessHover
        onHoveredChanged: {
            if (hovered) root.popupRequested(root.buildHoverIntent())
            else root.popupCloseRequested()
        }
    }

    // Build hover intent payload for the two-layer popup.
    function buildHoverIntent() {
        var centerX = 0
        try { centerX = root.mapToGlobal(root.width / 2, root.height / 2).x } catch (e) {
            try { centerX = root.mapToItem(null, root.width / 2, 0).x } catch (e2) { centerX = 0 }
        }
        if (!isFinite(centerX)) centerX = 0
        var summaryText = Math.round(root.level * 100) + "%"
        return {
            widgetId: root.widgetId,
            instanceKey: root.instanceKey,
            screenName: root.screenName,
            title: "Brightness",
            iconSource: "../icons/brightness.svg",
            summary: summaryText,
            actionKind: "brightness",
            anchorX: centerX,
            payload: {
                brightness: Services.BrightnessService.brightness,
                brightnessService: Services.BrightnessService,
                onBrightnessChanged: function(v) { Services.BrightnessService.setBrightness(v) }
            }
        }
    }

    onXChanged: if (brightnessHover.hovered) popupAnchorUpdate(buildHoverIntent())
    onWidthChanged: if (brightnessHover.hovered) popupAnchorUpdate(buildHoverIntent())

    WheelHandler {
        objectName: "brightnessWheelHandler"
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            var step = Number(Services.SettingsService.controls.brightnessStep) || 0.05
            var delta = event.angleDelta.y > 0 ? step : -step
            Services.BrightnessService.setBrightness(
                Math.max(0, Math.min(1, Services.BrightnessService.brightness + delta)))
            event.accepted = true
        }
    }

    // Icon stays vertically centered; progress sits directly below it.
    Image {
        id: brightnessIcon

        anchors.centerIn: parent
        width: LazerTheme.barGlyphSize - 4
        height: LazerTheme.barGlyphSize - 4
        source: "../icons/brightness.svg"
        opacity: 0.9
    }

    // Rounded horizontal level bar below the icon, replacing the percentage text.
    Rectangle {
        id: brightnessTrack

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: brightnessIcon.bottom
        anchors.topMargin: 4
        width: LazerTheme.barWidgetHeight - 16
        height: 3
        radius: 1.5
        color: Qt.rgba(1, 1, 1, 0.14)
        clip: true

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * root.level
            radius: 1.5
            color: LazerTheme.accentColor

            Behavior on width {
                enabled: !MotionTokens.reducedMotion
                NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuad }
            }
        }
    }

}
