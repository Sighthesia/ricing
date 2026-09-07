import QtQuick
import ".."
import "../../lazerbar"
import "../../../services" as Services

// Square battery: icon plus percentage, charge level shown as rounded horizontal bar below.
BarPill {
    id: root

    // Widget identity contract filled by the layout loader.
    property string widgetId: ""
    property string instanceKey: ""
    property string section: ""
    property string screenName: ""

    readonly property var widgetSettings: Services.SettingsService.widgetSettingsObject("battery", root.instanceKey)
    readonly property bool showPercentage: widgetSettings ? widgetSettings.showPercentage !== false : true
    readonly property bool showStateLabel: widgetSettings ? widgetSettings.showStateLabel !== false : true

    readonly property bool available: Services.BatteryService.available
    readonly property bool ready: Services.BatteryService.ready
    readonly property int percentage: Services.BatteryService.percentage
    readonly property real level: root.ready ? Math.max(0, Math.min(1, root.percentage / 100)) : 0
    readonly property bool charging: Services.BatteryService.charging
    readonly property bool pluggedIn: Services.BatteryService.pluggedIn
    readonly property bool low: Services.BatteryService.low
    readonly property bool critical: Services.BatteryService.critical
    readonly property bool showPctText: root.showPercentage && root.ready
    // Charging reads green, low/critical read pink, otherwise the accent fill.
    readonly property color stateColor: root.charging || root.pluggedIn ? LazerTheme.osuGreen
        : (root.low || root.critical ? LazerTheme.osuPink : LazerTheme.accentColor)
    readonly property string stateLabel: {
        if (!root.ready) return ""
        if (root.charging) return "Charging"
        if (root.pluggedIn) return "Full"
        if (root.critical) return "Critical"
        if (root.low) return "Low"
        return ""
    }

    // Opt-in hover intent for BarPopupHost.
    hoverIntentEnabled: true

    implicitWidth: root.showPctText ? contentRow.implicitWidth + 16 : LazerTheme.barWidgetHeight
    implicitHeight: LazerTheme.barWidgetHeight

    Component.onCompleted: {
        if (root.instanceKey !== "")
            Services.SettingsService.ensureWidgetSettings("battery", root.instanceKey)
    }

    // Build hover intent payload for the two-layer popup.
    function buildHoverIntent() {
        var centerX = 0
        try { centerX = root.mapToGlobal(root.width / 2, root.height / 2).x } catch (e) {
            try { centerX = root.mapToItem(null, root.width / 2, 0).x } catch (e2) { centerX = 0 }
        }
        if (!isFinite(centerX)) centerX = 0
        var summaryText = "No battery"
        if (root.available && root.ready) {
            summaryText = root.percentage + "%"
            if (root.showStateLabel && root.stateLabel !== "") summaryText += " · " + root.stateLabel
        } else if (root.available) {
            summaryText = "Unknown"
        }
        return {
            widgetId: root.widgetId,
            instanceKey: root.instanceKey,
            screenName: root.screenName,
            title: "Battery",
            iconSource: Qt.resolvedUrl("../icons/battery.svg"),
            summary: summaryText,
            actionKind: "battery",
            anchorX: centerX,
            payload: {
                batteryService: Services.BatteryService,
                percentage: root.percentage,
                ready: root.ready,
                charging: root.charging,
                pluggedIn: root.pluggedIn,
                low: root.low,
                critical: root.critical
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

    // Icon plus optional percentage readout.
    Row {
        id: contentRow

        anchors.centerIn: parent
        anchors.verticalCenterOffset: -3
        spacing: 5

        Image {
            id: batteryIcon

            anchors.verticalCenter: parent.verticalCenter
            width: LazerTheme.barGlyphSize - 4
            height: LazerTheme.barGlyphSize - 4
            source: Qt.resolvedUrl("../icons/battery.svg")
            opacity: !root.available || !root.ready ? 0.35 : 0.9

            Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showPctText
            text: root.percentage + "%"
            color: LazerTheme.textPrimary
            font.pixelSize: 12
            font.bold: true
        }
    }

    // State diamond: green while charging/full, pink while low/critical.
    Rectangle {
        anchors.top: parent.top
        anchors.topMargin: 5
        anchors.right: parent.right
        anchors.rightMargin: 5
        width: 7
        height: 7
        radius: 0
        rotation: 45
        color: (root.charging || root.pluggedIn) ? LazerTheme.osuGreen : LazerTheme.osuPink
        visible: root.showStateLabel && root.ready && (root.charging || root.pluggedIn || root.low || root.critical)
    }

    // Rounded horizontal charge bar below the icon, mirroring volume.
    Rectangle {
        id: batteryTrack

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        width: Math.max(contentRow.width, LazerTheme.barWidgetHeight - 16)
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
            color: root.ready ? root.stateColor : "transparent"

            Behavior on width {
                enabled: !MotionTokens.reducedMotion
                NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuad }
            }
            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        }
    }
}
