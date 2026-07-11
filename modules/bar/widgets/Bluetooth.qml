import "." as Widgets
import QtQuick
import "../../../services" as Services

// Bluetooth indicator with click-to-toggle and hover device list.
Item {
    id: root

    property string widgetInstanceKey: ""
    readonly property real dockzoneExpandHeight: btBadge.dockzoneExpandHeight
    readonly property real dockzoneExpandWidth: btBadge.dockzoneExpandWidth
    readonly property bool badgeActive: btBadge.badgeActive
    readonly property Component detailComponent: btBadge.detailComponent

    visible: Services.BluetoothService.bluetoothAvailable
    implicitWidth: visible ? btBadge.implicitWidth : 0
    implicitHeight: 30

    readonly property color stateColor: {
        if (!Services.BluetoothService.enabled)
            return Services.Color.mOnSurfaceVariant
        if (Services.BluetoothService.connectedDevices.length > 0)
            return Services.Color.mPrimary
        return Services.Color.mOnSurface
    }

    readonly property string collapsedIcon: {
        if (!Services.BluetoothService.enabled) return "\uf070" // bluetooth-off
        if (Services.BluetoothService.scanningActive) return "\uf294" // scanning-ish
        return "\uf293" // bluetooth
    }

    // Render the circular bluetooth badge and reveal the device list below the dockzone.
    Widgets.CircularHoverWidget {
        id: btBadge

        anchors.centerIn: parent
        clickable: true
        centerText: root.collapsedIcon
        centerTextFontFamily: "Symbols Nerd Font"
        centerTextPixelSize: 10
        centerTextColor: root.stateColor
        progressValue: -1
        progressColor: root.stateColor
        onActivated: Services.BluetoothService.setBluetoothEnabled(!Services.BluetoothService.enabled)
        detailComponent: Component {
            Widgets.CompactHoverDetail {
                iconText: root.collapsedIcon
                labelText: "Bluetooth"
                valueText: {
                    if (!Services.BluetoothService.enabled) return "Off"
                    var n = Services.BluetoothService.connectedDevices.length
                    return n > 0 ? (n + " connected") : "On"
                }
                progressValue: 0
                accentColor: root.stateColor
                interactive: false

                secondaryText: {
                    if (!Services.BluetoothService.enabled) return ""
                    var cd = Services.BluetoothService.connectedDevices
                    if (cd.length === 0) return Services.BluetoothService.scanningActive ? "Scanning…" : "No devices connected"
                    return cd.slice(0, 2).map(d => d.name || d.deviceName || "Device").join(" · ")
                }
            }
        }
    }
}
