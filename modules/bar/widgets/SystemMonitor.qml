import "." as Widgets
import QtQuick
import "../../../services" as Services

// Render a minimal CPU and memory monitor for the bar.
Item {
    id: root

    property string widgetInstanceKey: ""

    readonly property var monitorSettings: Services.SettingsService.widgetSettingsObject(
        "system-monitor",
        root.widgetInstanceKey
    )
    readonly property bool rawShowCpu: root.monitorSettings ? root.monitorSettings.showCpu : true
    readonly property bool rawShowMemory: root.monitorSettings ? root.monitorSettings.showMemory : true
    readonly property bool rawShowNetwork: root.monitorSettings ? root.monitorSettings.showNetwork : false
    readonly property bool rawShowLoad: root.monitorSettings ? root.monitorSettings.showLoad : false
    readonly property bool hasAnyMetric: root.rawShowCpu || root.rawShowMemory || root.rawShowNetwork || root.rawShowLoad
    readonly property bool showCpu: root.rawShowCpu || !root.hasAnyMetric
    readonly property bool showMemory: root.rawShowMemory || !root.hasAnyMetric
    readonly property bool showNetwork: root.rawShowNetwork
    readonly property bool showLoad: root.rawShowLoad
    readonly property string cpuLabel: "CPU " + Services.SystemMonitorService.cpuText
    readonly property string memLabel: "MEM " + Services.SystemMonitorService.memText
    readonly property string netLabel: "NET " + Services.SystemMonitorService.rxText + "/" + Services.SystemMonitorService.txText
    readonly property string loadLabel: "LD " + Services.SystemMonitorService.loadText
    readonly property color cpuAccentColor: Services.SystemMonitorService.cpuUsage >= 85
        ? Services.Color.mError
        : (Services.SystemMonitorService.cpuUsage >= 65
            ? Services.Color.mTertiary
            : Services.Color.mPrimary)

    implicitWidth: metricsBadge.implicitWidth
    implicitHeight: 30

    Component.onCompleted: Services.SettingsService.ensureWidgetSettings("system-monitor", root.widgetInstanceKey)

    Behavior on implicitWidth {
        NumberAnimation { duration: Services.Motion.number.contentDuration; easing.type: Services.Motion.number.contentEasing }
    }

    // Render the circular CPU badge and reveal configured metrics on hover.
    Widgets.CircularHoverWidget {
        id: metricsBadge

        anchors.centerIn: parent
        centerText: String(Math.round(Services.SystemMonitorService.cpuUsage))
        centerTextPixelSize: String(Math.round(Services.SystemMonitorService.cpuUsage)).length >= 3 ? 8 : 9
        centerTextColor: root.cpuAccentColor
        progressValue: Services.SystemMonitorService.cpuUsage / 100
        progressColor: root.cpuAccentColor

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.cpuLabel
            color: Services.Color.mOnSurface
            font.pixelSize: Services.TextSize.barContent
            visible: root.showCpu
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.memLabel
            color: Services.Color.mOnSurfaceVariant
            font.pixelSize: Services.TextSize.barContent
            visible: root.showMemory
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.netLabel
            color: Services.Color.mOnSurfaceVariant
            font.pixelSize: Services.TextSize.barContent
            visible: root.showNetwork
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.loadLabel
            color: Services.Color.mOnSurfaceVariant
            font.pixelSize: Services.TextSize.barContent
            visible: root.showLoad
        }
    }
}
