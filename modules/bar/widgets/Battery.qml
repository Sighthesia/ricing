import "." as Widgets
import QtQuick
import "../../../services" as Services

// Show the primary battery as a compact icon-and-percent bar widget.
Item {
    id: root

    property string widgetInstanceKey: ""
    readonly property real dockzoneExpandHeight: batteryBadge.dockzoneExpandHeight
    readonly property real dockzoneExpandWidth: batteryBadge.dockzoneExpandWidth
    readonly property bool badgeActive: batteryBadge.badgeActive
    readonly property Component detailComponent: batteryBadge.detailComponent

    visible: Services.BatteryService.available
    implicitWidth: visible ? batteryBadge.implicitWidth : 0
    implicitHeight: 30

    readonly property var batterySettings: Services.SettingsService.widgetSettingsObject(
        "battery",
        root.widgetInstanceKey
    )
    readonly property bool showPercentage: !root.batterySettings
        || root.batterySettings.showPercentage
        || (!root.batterySettings.showPercentage && !root.batterySettings.showStateLabel)
    readonly property bool showStateLabel: root.batterySettings
        ? root.batterySettings.showStateLabel
        : true
    readonly property string collapsedText: Services.BatteryService.charging
        ? "\uf0e7"
        : (Services.BatteryService.pluggedIn ? "\uf1e6" : "\uf242")
    readonly property string detailStateText: root.showStateLabel ? Services.BatteryService.iconText : ""

    Component.onCompleted: Services.SettingsService.ensureWidgetSettings("battery", root.widgetInstanceKey)

    readonly property color stateColor: {
        if (Services.BatteryService.critical)
            return Services.Color.mError
        if (Services.BatteryService.low)
            return Services.Color.mTertiary
        if (Services.BatteryService.charging)
            return Services.Color.mPrimary
        return Services.Color.mOnSurfaceVariant
    }

    // Render the circular battery badge and reveal configured details below the dockzone.
    Widgets.CircularHoverWidget {
        id: batteryBadge

        anchors.centerIn: parent
        centerTextFontFamily: "Symbols Nerd Font"
        centerText: root.collapsedText
        centerTextPixelSize: 10
        centerTextColor: root.stateColor
        progressValue: Services.BatteryService.percentage / 100
        progressColor: root.stateColor
        detailComponent: Component {
            Widgets.CompactHoverDetail {
                iconText: root.collapsedText
                labelText: "Battery"
                valueText: Services.BatteryService.percentage + "%"
                secondaryText: root.detailStateText
                progressValue: Services.BatteryService.percentage / 100
                accentColor: root.stateColor
            }
        }
    }
}
