import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../widgets/systemmonitor" as MonitorParts

// Resource summary card for the SuperIsland control center page.
Rectangle {
    id: root

    readonly property var _resourceMetrics: root._buildResourceMetrics()

    function _buildResourceMetrics() {
        const source = (SystemMonitorService.persistentMetrics || []).concat(SystemMonitorService.expandedMetrics || [])
        const preferredKeys = ["cpu", "memory", "temperature", "battery"]
        const entries = []

        for (let keyIndex = 0; keyIndex < preferredKeys.length; keyIndex++) {
            const preferredKey = preferredKeys[keyIndex]
            for (let metricIndex = 0; metricIndex < source.length; metricIndex++) {
                const metric = source[metricIndex]
                if (metric && metric.key === preferredKey) {
                    entries.push(metric)
                    break
                }
            }
        }

        return entries
    }

    function _metricAccent(metric) {
        if (!metric || metric.available === false)
            return Colors.border
        if (metric.severity === "critical")
            return Colors.destructive
        if (metric.severity === "warning")
            return Colors.highlight
        return Colors.text
    }

    function _statusLabel() {
        if (SystemMonitorService.highestSeverity === "critical")
            return "高负载"
        if (SystemMonitorService.highestSeverity === "warning")
            return "需要留意"
        return "运行稳定"
    }

    radius: Theme.cornerRadius
    color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.68)
    border.color: Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, 0.72)
    border.width: 1
    implicitHeight: _contentColumn.implicitHeight + Theme.settingsPanelPadding * 2

    ColumnLayout {
        id: _contentColumn
        anchors.fill: parent
        anchors.margins: Theme.settingsPanelPadding
        spacing: 10

        ColumnLayout {
            spacing: 2

            Text {
                text: "资源监控"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeBody
                font.weight: Font.Medium
                color: Colors.text
            }

            Text {
                text: root._statusLabel()
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Colors.textMuted
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 8
            rowSpacing: 8

            Repeater {
                model: root._resourceMetrics

                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    radius: 12
                    color: Qt.rgba(root._metricAccent(modelData).r, root._metricAccent(modelData).g, root._metricAccent(modelData).b, 0.08)
                    border.color: Qt.rgba(root._metricAccent(modelData).r, root._metricAccent(modelData).g, root._metricAccent(modelData).b, 0.18)
                    border.width: 1
                    implicitHeight: _metricRow.implicitHeight + Theme.barWidget.contentPaddingV * 4

                    RowLayout {
                        id: _metricRow
                        anchors.fill: parent
                        anchors.margins: Theme.barWidget.contentPaddingH
                        spacing: 10

                        MonitorParts.SystemMonitorGauge {
                            metric: modelData
                            interactive: false
                            detailPreview: false
                            Layout.alignment: Qt.AlignTop
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: modelData.title || "指标"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                color: Colors.textMuted
                                elide: Text.ElideRight
                            }

                            Text {
                                text: modelData.displayText || "--"
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeBody
                                font.weight: Font.DemiBold
                                color: modelData.available === false ? Colors.textMuted : Colors.text
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 5
                                radius: height / 2
                                color: Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, 0.45)

                                Rectangle {
                                    width: parent.width * Math.max(0, Math.min(1, Number(modelData.normalizedProgress) || 0))
                                    height: parent.height
                                    radius: parent.radius
                                    color: root._metricAccent(modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
