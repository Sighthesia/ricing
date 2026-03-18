import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// Compact bar widget for system monitoring metrics.
Rectangle {
    id: root

    function _statusColor() {
        switch (SystemMonitorService.highestSeverity) {
        case "critical": return Colors.destructive
        case "warning": return Colors.highlight
        default: return Colors.textMuted
        }
    }

    function _statusText() {
        switch (SystemMonitorService.highestSeverity) {
        case "critical": return "!!"
        case "warning": return "!"
        default: return ""
        }
    }

    color: Colors.background
    radius: Theme.cornerRadius
    implicitHeight: Theme.barHeight
    implicitWidth: content.implicitWidth + Theme.widgetPadding * 2

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: Theme.barWidget.pillSpacing

        // Status indicator based on highest severity
        Rectangle {
            id: statusIndicator
            implicitWidth: Theme.barWidget.compactIconSize
            implicitHeight: Theme.barWidget.compactIconSize
            radius: 2
            color: root._statusColor()

            // Optional severity text overlay
            Text {
                anchors.fill: parent
                font.family: Theme.fontMono
                font.pixelSize: Theme.barWidget.compactIconSize - 2
                font.bold: true
                text: root._statusText()
                color: Colors.text
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                visible: Theme.barWidget.compactIconSize >= 16
            }
        }

        // Main metrics display (first 3 pinned metrics)
        RowLayout {
            id: metricsRow
            spacing: Theme.barWidget.iconSpacing

            Repeater {
                model: SystemMonitorService.metrics
                delegate: Text {
                    text: modelData.displayValue || ""
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: true
                    color: modelData.severity === "critical" ? Colors.destructive
                            : modelData.severity === "warning" ? Colors.highlight
                            : Colors.text
                    width: 30
                    horizontalAlignment: Text.AlignHCenter
                    visible: index < 3
                }
            }
        }

        // Separator
        Rectangle {
            implicitWidth: 1
            implicitHeight: Theme.barWidget.primaryIconSize
            color: Colors.border
            opacity: 0.5
            Layout.alignment: Qt.AlignVCenter
        }

        // Optional volume display
        RowLayout {
            id: volumeRow
            spacing: Theme.barWidget.iconSpacing
            visible: SettingsService.data && SettingsService.data.systemMonitor ? SettingsService.data.systemMonitor.showVolume : false

            Text {
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                text: "VOL"
                color: Colors.textMuted
            }

            Text {
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                text: SystemMonitorService.volumeMuted ? "MUTE" : "%1".arg(Math.round(SystemMonitorService.volumeLevel * 100))
                color: SystemMonitorService.volumeMuted ? Colors.textMuted : Colors.text
            }
        }

        // Optional brightness display
        RowLayout {
            id: brightnessRow
            spacing: Theme.barWidget.iconSpacing
            visible: SettingsService.data && SettingsService.data.systemMonitor ? SettingsService.data.systemMonitor.showBrightness : false

            Text {
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                text: "BRIGHT"
                color: Colors.textMuted
            }

            Text {
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                text: "%1".arg(Math.round(SystemMonitorService.brightnessLevel * 100))
                color: Colors.text
            }
        }

        // Optional microphone mute indicator
        RowLayout {
            id: micRow
            spacing: Theme.barWidget.iconSpacing
            visible: SettingsService.data && SettingsService.data.systemMonitor ? SettingsService.data.systemMonitor.showMicrophone : false

            Text {
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                text: SystemMonitorService.microphoneMuted ? "MIC-MUTE" : "MIC"
                color: SystemMonitorService.microphoneMuted ? Colors.textMuted : Colors.text
            }
        }
    }
}