import QtQuick
import ".."
import "../../lazerbar"
import "../../../services" as Services

// Square wi-fi: click toggles power, signal of the connected network fills the bar below.
BarPill {
    id: root

    // Widget identity contract filled by the layout loader.
    property string widgetId: ""
    property string instanceKey: ""
    property string section: ""
    property string screenName: ""

    readonly property bool wifiEnabled: Services.NetworkService.wifiEnabled
    readonly property bool wifiConnected: Services.NetworkService.wifiConnected
    readonly property bool connecting: Services.NetworkService.connecting
    readonly property string connectingTo: Services.NetworkService.connectingTo
    readonly property bool scanning: Services.NetworkService.scanningActive
    readonly property var networks: Services.NetworkService.networks
    readonly property string statusText: Services.NetworkService.getStatusText()
    // Signal of the connected network drives the level bar; 0 while offline.
    readonly property int signal: {
        if (!root.wifiConnected || !root.networks) return 0
        var values = Object.values(root.networks)
        for (var i = 0; i < values.length; i++) {
            if (values[i] && values[i].connected) return Number(values[i].signal) || 0
        }
        return 0
    }
    readonly property real level: root.wifiConnected ? Math.max(0, Math.min(1, root.signal / 100)) : 0

    // Opt-in hover intent for BarPopupHost.
    hoverIntentEnabled: true

    onClicked: Services.NetworkService.setWifiEnabled(!root.wifiEnabled)

    implicitWidth: LazerTheme.barWidgetHeight
    implicitHeight: LazerTheme.barWidgetHeight

    // Build hover intent payload for the two-layer popup.
    function buildHoverIntent() {
        var centerX = 0
        try { centerX = root.mapToGlobal(root.width / 2, root.height / 2).x } catch (e) {
            try { centerX = root.mapToItem(null, root.width / 2, 0).x } catch (e2) { centerX = 0 }
        }
        if (!isFinite(centerX)) centerX = 0
        var summaryText = "Wi-Fi off"
        if (root.wifiEnabled) {
            if (root.connecting) summaryText = root.connectingTo !== "" ? "Connecting " + root.connectingTo : "Connecting"
            else if (root.statusText !== "") summaryText = root.statusText
            else if (root.scanning) summaryText = "Scanning…"
            else summaryText = "Not connected"
        }
        return {
            widgetId: root.widgetId,
            instanceKey: root.instanceKey,
            screenName: root.screenName,
            title: "Wi-Fi",
            iconSource: Qt.resolvedUrl("../icons/wifi.svg"),
            summary: summaryText,
            actionKind: "network",
            anchorX: centerX,
            payload: {
                networkService: Services.NetworkService
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

    // Icon stays vertically centered; signal sits directly below it.
    Image {
        id: wifiIcon

        anchors.centerIn: parent
        anchors.verticalCenterOffset: -2
        width: LazerTheme.barGlyphSize - 4
        height: LazerTheme.barGlyphSize - 4
        source: Qt.resolvedUrl("../icons/wifi.svg")
        opacity: !root.wifiEnabled ? 0.35 : (root.wifiConnected ? 0.9 : 0.6)

        Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
    }

    // Rounded horizontal signal bar below the icon, mirroring volume.
    Rectangle {
        id: wifiTrack

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
            width: root.connecting ? parent.width : parent.width * root.level
            radius: 1.5
            color: root.connecting ? LazerTheme.textMuted : LazerTheme.accentColor

            Behavior on width {
                enabled: !MotionTokens.reducedMotion
                NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuad }
            }
            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        }
    }
}
