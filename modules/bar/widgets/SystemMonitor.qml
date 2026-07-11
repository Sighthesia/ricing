import "." as Widgets
import QtQuick
import "../../../services" as Services

// Render a minimal CPU and memory monitor for the bar.
Item {
    id: root

    property string widgetInstanceKey: ""
    property real dockzoneRevealCenterX: -1
    property real dockzoneRevealTargetCenterX: -1
    property real dockzoneRevealViewportWidth: -1
    property real dockzoneActualExpandHeight: 0
    // Fixed detail viewport hover from the section-level hit target.
    property bool detailViewportHovered: false

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
    readonly property real dockzoneExpandHeight: metricsBadge.dockzoneExpandHeight
    readonly property real dockzoneExpandWidth: metricsBadge.dockzoneExpandWidth
    readonly property bool badgeActive: metricsBadge.pointerActive
    readonly property bool badgeContainsMouse: metricsBadge.badgeContainsMouse

    implicitWidth: metricsBadge.implicitWidth
    implicitHeight: 30

    Component.onCompleted: Services.SettingsService.ensureWidgetSettings("system-monitor", root.widgetInstanceKey)

    // Render the circular CPU badge and reveal configured metrics below the dockzone.
    Widgets.CircularHoverWidget {
        id: metricsBadge

        anchors.centerIn: parent
        centerText: "\uf201"
        centerTextFontFamily: "Symbols Nerd Font"
        centerTextPixelSize: 10
        centerTextColor: root.cpuAccentColor
        dockzoneRevealCenterX: root.dockzoneRevealCenterX
        dockzoneRevealTargetCenterX: root.dockzoneRevealTargetCenterX
        dockzoneRevealViewportWidth: root.dockzoneRevealViewportWidth
        dockzoneActualExpandHeight: root.dockzoneActualExpandHeight
        detailViewportHovered: root.detailViewportHovered
        progressValue: Services.SystemMonitorService.cpuUsage / 100
        progressColor: root.cpuAccentColor

        Widgets.CompactHoverDetail {
            iconText: "\uf201"
            labelText: root.showCpu ? "CPU" : (root.showMemory ? "Memory" : "System")
            valueText: root.showCpu ? Services.SystemMonitorService.cpuText : (root.showMemory ? Services.SystemMonitorService.memText : "Live")
            secondaryText: {
                var details = []
                if (root.showMemory)
                    details.push(root.memLabel)
                if (root.showNetwork)
                    details.push(root.netLabel)
                if (root.showLoad)
                    details.push(root.loadLabel)
                return details.join("  ")
            }
            progressValue: root.showCpu
                ? Services.SystemMonitorService.cpuUsage / 100
                : (root.showMemory ? Services.SystemMonitorService.memPercent / 100 : 0)
            accentColor: root.cpuAccentColor
        }
    }
}
