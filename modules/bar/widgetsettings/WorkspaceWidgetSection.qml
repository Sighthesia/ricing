import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../settings"

// Functional settings for the WorkspaceWidget (two-state island indicator).
// Shown in WidgetSettingsPanel when the active widget is "workspaceWidget".
Item {
    id: root

    implicitWidth: ThemeSettings.rowWidth
    implicitHeight: _col.implicitHeight

    Column {
        id: _col
        width: parent.width
        spacing: 0

        // ── Default mode ─────────────────────────────────────────────────
        Item {
            width: parent.width
            height: ThemeSettings.rowHeight

            Row {
                anchors.fill: parent
                anchors.leftMargin: ThemeSettings.panelPadding
                anchors.rightMargin: ThemeSettings.panelPadding
                spacing: ThemeSettings.rowGap

                Text {
                    width: ThemeSettings.labelWidth
                    anchors.verticalCenter: parent.verticalCenter
                    text: "默认形态"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.textMuted
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: ThemeSettings.behaviorOptionGap

                    Repeater {
                        model: [
                            { value: "focus",    label: "聚焦" },
                            { value: "overview", label: "概览" }
                        ]

                        delegate: Rectangle {
                            required property var modelData

                            readonly property bool _selected:
                                SettingsService.data.workspaceWidget.defaultMode === modelData.value

                            width: ThemeSettings.behaviorOptionWidth; height: ThemeSettings.switchHeight
                            radius: ThemeSettings.sidebarSurfaceRadius
                            color: _selected ? Colors.highlight : Colors.surface
                            opacity: _selected ? 0.9 : 0.6

                            Behavior on color { ColorAnimation { duration: Theme.anim.highlightDuration } }
                            Behavior on opacity { NumberAnimation { duration: Theme.anim.highlightDuration } }

                            Text {
                                anchors.centerIn: parent
                                text: parent.modelData.label
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                color: parent._selected ? Colors.background : Colors.text
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    SettingsService.data.workspaceWidget.defaultMode = parent.modelData.value
                                    SettingsService.save()
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Hover toggle ──────────────────────────────────────────────────
        Item {
            width: parent.width
            height: ThemeSettings.rowHeight

            Row {
                anchors.fill: parent
                anchors.leftMargin: ThemeSettings.panelPadding
                anchors.rightMargin: ThemeSettings.panelPadding
                spacing: ThemeSettings.rowGap

                Text {
                    width: ThemeSettings.labelWidth
                    anchors.verticalCenter: parent.verticalCenter
                    text: "悬浮切换"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.textMuted
                }

                Rectangle {
                    id: _toggleTrack
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(36 * Theme.uiScale); height: Math.round(20 * Theme.uiScale); radius: height / 2
                    color: SettingsService.data.workspaceWidget.hoverEnabled
                        ? Colors.highlight : Colors.surface
                    Behavior on color { ColorAnimation { duration: Theme.anim.highlightDuration } }

                    Rectangle {
                        id: _toggleKnob
                        anchors.verticalCenter: parent.verticalCenter
                        x: SettingsService.data.workspaceWidget.hoverEnabled ? parent.width - width - 2 : 2
                        width: Math.round(16 * Theme.uiScale); height: Math.round(16 * Theme.uiScale); radius: width / 2
                        color: Colors.text

                        Behavior on x { NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            SettingsService.data.workspaceWidget.hoverEnabled =
                                !SettingsService.data.workspaceWidget.hoverEnabled
                            SettingsService.save()
                        }
                    }
                }
            }
        }

        // ── Title max width ───────────────────────────────────────────────
        SliderSection {
            width: parent.width
            label: "标题宽度"
            value: SettingsService.data.workspaceWidget.titleMaxWidth
            from: 60; to: 400; stepSize: 10; unit: "px"
            onValueCommitted: newValue => {
                SettingsService.data.workspaceWidget.titleMaxWidth = newValue
                SettingsService.save()
            }
        }

        // ── Revert delay ─────────────────────────────────────────────────
        SliderSection {
            width: parent.width
            label: "切换延迟"
            value: SettingsService.data.workspaceWidget.revertDelay
            from: 300; to: 5000; stepSize: 100; unit: "ms"
            onValueCommitted: newValue => {
                SettingsService.data.workspaceWidget.revertDelay = newValue
                SettingsService.save()
            }
        }
    }
}
