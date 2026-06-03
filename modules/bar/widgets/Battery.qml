import "." as Widgets
import QtQuick
import "../../../services" as Services

// Show the primary battery as a compact icon-and-percent bar widget.
Item {
    id: root

    property string widgetInstanceKey: ""

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
    readonly property string collapsedText: root.showStateLabel
        ? Services.BatteryService.iconText
        : String(Services.BatteryService.percentage)
    readonly property string detailStateText: root.showStateLabel ? Services.BatteryService.iconText : ""

    Component.onCompleted: Services.SettingsService.ensureWidgetSettings("battery", root.widgetInstanceKey)

    Behavior on implicitWidth {
        NumberAnimation { duration: Services.Motion.number.contentDuration; easing.type: Services.Motion.number.contentEasing }
    }

    readonly property color stateColor: {
        if (Services.BatteryService.critical)
            return Services.Color.mError
        if (Services.BatteryService.low)
            return Services.Color.mTertiary
        if (Services.BatteryService.charging)
            return Services.Color.mPrimary
        return Services.Color.mOnSurfaceVariant
    }

    // Render the circular battery badge and reveal configured details on hover.
    Widgets.CircularHoverWidget {
        id: batteryBadge

        anchors.centerIn: parent
        centerText: root.collapsedText
        centerTextPixelSize: root.collapsedText.length >= 3 ? 8 : 9
        centerTextColor: root.stateColor
        progressValue: Services.BatteryService.percentage / 100
        progressColor: root.stateColor

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.detailStateText
            color: root.stateColor
            font.pixelSize: Services.TextSize.barContent
            visible: text !== ""
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Services.BatteryService.percentage + "%"
            color: root.stateColor
            visible: root.showPercentage
            font.pixelSize: Services.TextSize.barContent
        }
    }
}
