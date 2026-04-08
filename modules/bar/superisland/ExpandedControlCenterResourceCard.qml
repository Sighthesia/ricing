import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import ".." as BarComponents
import "../widgets/systemmonitor" as MonitorParts

// Resource summary surface for the SuperIsland control center page.
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

    function _resourceStatusLabel() {
        if (SystemMonitorService.highestSeverity === "critical")
            return "高负载"
        if (SystemMonitorService.highestSeverity === "warning")
            return "需要留意"
        return "运行稳定"
    }

    function _togglePowerSave() {
        SettingsService.data.power.powerSaveEnabled = !SettingsService.data.power.powerSaveEnabled
        SettingsService.save()
    }

    radius: Theme.cornerRadius
    color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.68)
    border.color: Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, 0.72)
    border.width: 1
    implicitWidth: Math.round(280 * Theme.uiScale)
    implicitHeight: _resourceColumn.implicitHeight + Theme.settingsPanelPadding * 2

    ColumnLayout {
        id: _resourceColumn
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
                text: root._resourceStatusLabel()
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Colors.textMuted
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 1
            rowSpacing: 8

            Repeater {
                model: root._resourceMetrics

                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    radius: 12
                    color: Qt.rgba(
                        Colors.highlight.r,
                        Colors.highlight.g,
                        Colors.highlight.b,
                        modelData.severity === "critical" ? 0.12 : 0.08
                    )
                    border.color: Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, 0.24)
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
                                    color: modelData.severity === "critical"
                                        ? Colors.destructive
                                        : (modelData.severity === "warning" ? Colors.highlight : Colors.text)
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            radius: 12
            color: _powerSaveArea.containsMouse
                ? Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, SettingsService.powerSaveEnabled ? 0.18 : 0.12)
                : Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, SettingsService.powerSaveEnabled ? 0.22 : 0.12)
            border.color: SettingsService.powerSaveEnabled
                ? Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.72)
                : Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, 0.42)
            border.width: 1
            implicitHeight: _powerSaveRow.implicitHeight + Theme.barWidget.contentPaddingV * 4

            Behavior on color {
                ColorAnimation { duration: Theme.anim.highlightDuration }
            }

            Behavior on border.color {
                ColorAnimation { duration: Theme.anim.highlightDuration }
            }

            BarComponents.HoverRevealHighlight {
                anchors.fill: parent
                radius: 12
                hovered: _powerSaveArea.containsMouse
                highlightColor: Colors.highlight
                highlightOpacity: 0.12
                adaptiveContrast: true
                surfaceColor: parent.color
            }

            BarComponents.ClickRipple {
                id: _powerSaveRipple
                anchors.fill: parent
                radius: 12
                rippleColor: Colors.highlight
            }

            RowLayout {
                id: _powerSaveRow
                anchors.fill: parent
                anchors.margins: Theme.barWidget.contentPaddingH
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: 17
                    color: Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, SettingsService.powerSaveEnabled ? 0.22 : 0.12)

                    Text {
                        anchors.centerIn: parent
                        text: "\uf0e7"
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeBody + 2
                        color: Colors.highlight
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "省电模式"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Colors.text
                    }

                    Text {
                        Layout.fillWidth: true
                        text: SettingsService.powerSaveEnabled
                            ? "已关闭 Shell 动画、复杂视觉效果，并同步关闭 niri 动画。"
                            : "点击开启更轻量的 Shell 与 niri 视觉模式。"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Colors.textMuted
                        wrapMode: Text.WordWrap
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 24
                    radius: 12
                    color: SettingsService.powerSaveEnabled ? Colors.highlight : Colors.surface

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: SettingsService.powerSaveEnabled ? parent.width - width - 3 : 3
                        width: 18
                        height: 18
                        radius: 9
                        color: Colors.text

                        Behavior on x {
                            NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
                        }
                    }
                }
            }

            MouseArea {
                id: _powerSaveArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    _powerSaveRipple.triggerRipple(mouse.x, mouse.y)
                    root._togglePowerSave()
                }
            }
        }
    }
}
