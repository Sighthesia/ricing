import QtQuick
import ".."
import "../../lazerbar"
import "../../../services" as Services
import "BatteryLevel.js" as BatteryLevel

// Square battery: a single icon whose fill bucket shows the charge level.
BarPill {
    id: root

    // Widget identity contract filled by the layout loader.
    property string widgetId: ""
    property string instanceKey: ""
    property string section: ""
    property string screenName: ""

    readonly property var widgetSettings: Services.SettingsService.widgetSettingsObject("battery", root.instanceKey)
    readonly property bool showStateLabel: widgetSettings ? widgetSettings.showStateLabel !== false : true

    readonly property bool available: Services.BatteryService.available
    readonly property bool ready: Services.BatteryService.ready
    readonly property int percentage: Services.BatteryService.percentage
    readonly property bool charging: Services.BatteryService.charging
    readonly property bool pluggedIn: Services.BatteryService.pluggedIn
    readonly property bool low: Services.BatteryService.low
    readonly property bool critical: Services.BatteryService.critical
    readonly property string iconFile: BatteryLevel.iconFileFor(root.percentage, root.ready && root.available)
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

    implicitWidth: LazerTheme.barWidgetHeight
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
            iconSource: Qt.resolvedUrl(root.iconFile),
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

    // Single level icon centered on the pill.
    Image {
        id: batteryIcon

        anchors.centerIn: parent
        width: LazerTheme.barGlyphSize
        height: LazerTheme.barGlyphSize
        source: Qt.resolvedUrl(root.iconFile)
        opacity: !root.available || !root.ready ? 0.35 : 0.9

        Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
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
}
