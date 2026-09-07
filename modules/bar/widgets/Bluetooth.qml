import QtQuick
import ".."
import "../../lazerbar"
import "../../../services" as Services

// Square bluetooth: click toggles adapter power, diamond marks connected devices.
BarPill {
    id: root

    // Widget identity contract filled by the layout loader.
    property string widgetId: ""
    property string instanceKey: ""
    property string section: ""
    property string screenName: ""

    readonly property bool available: Services.BluetoothService.bluetoothAvailable
    readonly property bool adapterEnabled: Services.BluetoothService.enabled
    readonly property var connectedDevices: Services.BluetoothService.connectedDevices
    readonly property int connectedCount: root.connectedDevices ? root.connectedDevices.length : 0
    readonly property string firstDeviceName: {
        if (!root.connectedDevices || root.connectedDevices.length === 0) return ""
        var dev = root.connectedDevices[0]
        if (!dev) return ""
        return dev.name || dev.deviceName || dev.address || ""
    }

    // Opt-in hover intent for BarPopupHost.
    hoverIntentEnabled: true

    onClicked: {
        if (root.available) Services.BluetoothService.setBluetoothEnabled(!root.adapterEnabled)
    }

    implicitWidth: LazerTheme.barWidgetHeight
    implicitHeight: LazerTheme.barWidgetHeight

    // Build hover intent payload for the two-layer popup.
    function buildHoverIntent() {
        var centerX = 0
        try { centerX = root.mapToGlobal(root.width / 2, root.height / 2).x } catch (e) {
            try { centerX = root.mapToItem(null, root.width / 2, 0).x } catch (e2) { centerX = 0 }
        }
        if (!isFinite(centerX)) centerX = 0
        var summaryText = "No adapter"
        if (root.available) {
            if (!root.adapterEnabled) summaryText = "Off"
            else if (root.connectedCount > 0) {
                summaryText = root.firstDeviceName
                if (root.connectedCount > 1) summaryText += " +" + (root.connectedCount - 1)
            } else summaryText = "On · No devices"
        }
        return {
            widgetId: root.widgetId,
            instanceKey: root.instanceKey,
            screenName: root.screenName,
            title: "Bluetooth",
            iconSource: Qt.resolvedUrl("../icons/bluetooth.svg"),
            summary: summaryText,
            actionKind: "bluetooth",
            anchorX: centerX,
            payload: {
                bluetoothService: Services.BluetoothService
            }
        }
    }

    onHoveredChanged: {
        if (hovered) popupRequested(buildHoverIntent())
        else popupCloseRequested()
    }

    // Update anchor while the bar layout moves.
    onXChanged: if (hovered) popupAnchorUpdate(buildHoverIntent())
    onWidthChanged: if (hovered) popupAnchorUpdate(buildHoverIntent())

    // Icon stays vertically centered; status sits directly below it.
    Image {
        id: bluetoothIcon

        anchors.centerIn: parent
        anchors.verticalCenterOffset: -2
        width: LazerTheme.barGlyphSize - 4
        height: LazerTheme.barGlyphSize - 4
        source: Qt.resolvedUrl("../icons/bluetooth.svg")
        opacity: !root.available ? 0.3 : (root.adapterEnabled ? 0.9 : 0.45)

        Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
    }

    // Connected devices read as a sharp accent diamond, never a rounded badge.
    Rectangle {
        anchors.top: parent.top
        anchors.topMargin: 5
        anchors.right: parent.right
        anchors.rightMargin: 5
        width: 7
        height: 7
        radius: 0
        rotation: 45
        color: LazerTheme.osuGreen
        visible: root.adapterEnabled && root.connectedCount > 0
    }

    // Rounded power bar below the icon: full when on, empty when off.
    Rectangle {
        id: bluetoothTrack

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        width: LazerTheme.barWidgetHeight - 16
        height: 3
        radius: 1.5
        color: Qt.rgba(1, 1, 1, 0.14)
        clip: true

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root.adapterEnabled ? parent.width : 0
            radius: 1.5
            color: root.connectedCount > 0 ? LazerTheme.osuGreen : LazerTheme.accentColor

            Behavior on width {
                enabled: !MotionTokens.reducedMotion
                NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuad }
            }
            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        }
    }
}
