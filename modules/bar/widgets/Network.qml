import "." as Widgets
import QtQuick
import "../../../services" as Services

// Wi-Fi indicator with click-to-toggle and hover SSID reveal.
Item {
    id: root

    property string widgetInstanceKey: ""
    property real dockzoneRevealCenterX: -1
    property real dockzoneRevealTargetCenterX: -1
    property real dockzoneRevealViewportWidth: -1
    property real dockzoneActualExpandHeight: 0
    // Fixed detail viewport hover from the section-level hit target.
    property bool detailViewportHovered: false
    readonly property real dockzoneExpandHeight: wifiBadge.dockzoneExpandHeight
    readonly property real dockzoneExpandWidth: wifiBadge.dockzoneExpandWidth
    readonly property bool badgeActive: wifiBadge.pointerActive
    readonly property bool badgeContainsMouse: wifiBadge.badgeContainsMouse

    visible: Services.NetworkService.wifiAvailable
    implicitWidth: visible ? wifiBadge.implicitWidth : 0
    implicitHeight: 30

    // Signal of the connected network (0-100 → 0-1), or 0 when not connected.
    readonly property real connectedSignalFraction: {
        if (!Services.NetworkService.wifiConnected) return 0
        var connectedNet = Object.values(Services.NetworkService.networks).find(n => n.connected)
        return connectedNet ? connectedNet.signal / 100 : 0
    }

    readonly property color stateColor: {
        if (!Services.NetworkService.wifiEnabled) return Services.Color.mOnSurfaceVariant
        if (Services.NetworkService.networkConnectivity === "limited" || Services.NetworkService.networkConnectivity === "portal")
            return Services.Color.mTertiary
        if (Services.NetworkService.wifiConnected) return Services.Color.mPrimary
        return Services.Color.mOnSurface
    }

    readonly property string collapsedIcon: Services.NetworkService.getIcon()

    // Render the circular wifi badge and reveal SSID below the dockzone.
    Widgets.CircularHoverWidget {
        id: wifiBadge

        anchors.centerIn: parent
        clickable: true
        centerText: root.collapsedIcon
        centerTextFontFamily: "Symbols Nerd Font"
        centerTextPixelSize: 10
        centerTextColor: root.stateColor
        dockzoneRevealCenterX: root.dockzoneRevealCenterX
        dockzoneRevealTargetCenterX: root.dockzoneRevealTargetCenterX
        dockzoneRevealViewportWidth: root.dockzoneRevealViewportWidth
        dockzoneActualExpandHeight: root.dockzoneActualExpandHeight
        detailViewportHovered: root.detailViewportHovered
        progressValue: Services.NetworkService.wifiConnected ? root.connectedSignalFraction : -1
        progressColor: root.stateColor
        onActivated: Services.NetworkService.setWifiEnabled(!Services.NetworkService.wifiEnabled)

        Widgets.CompactHoverDetail {
            iconText: root.collapsedIcon
            labelText: "Wi-Fi"
            valueText: {
                if (!Services.NetworkService.wifiEnabled) return "Off"
                if (Services.NetworkService.connecting) return "…"
                if (Services.NetworkService.wifiConnected) {
                    var connectedNet = Object.values(Services.NetworkService.networks).find(n => n.connected)
                    return connectedNet ? Math.round(connectedNet.signal) + "%" : "Connected"
                }
                return Services.NetworkService.scanningActive ? "Scanning" : "On"
            }
            progressValue: Services.NetworkService.wifiConnected ? root.connectedSignalFraction : 0
            accentColor: root.stateColor
            interactive: false

            secondaryText: {
                if (!Services.NetworkService.wifiEnabled) return ""
                if (Services.NetworkService.connecting) return Services.NetworkService.connectingTo
                if (Services.NetworkService.wifiConnected) {
                    var connectedNet = Object.values(Services.NetworkService.networks).find(n => n.connected)
                    return connectedNet ? connectedNet.ssid : ""
                }
                var count = Object.keys(Services.NetworkService.networks).length
                return count > 0 ? count + " networks found" : (Services.NetworkService.scanningActive ? "Scanning…" : "No networks")
            }
        }
    }
}
