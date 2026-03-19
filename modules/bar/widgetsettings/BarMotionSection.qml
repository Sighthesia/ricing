import QtQuick
import qs.config
import qs.services
import "../settings"

// Shared bar motion controls shown for every widget in WidgetSettingsPanel.
// This section exposes global motion settings before widget-specific controls.
Item {
    id: root

    readonly property var _presetOptions: [
        { value: "soft", label: "柔和" },
        { value: "balanced", label: "均衡" },
        { value: "snappy", label: "利落" }
    ]

    implicitWidth: 296
    implicitHeight: _column.implicitHeight

    Column {
        id: _column

        width: parent.width
        spacing: 0

        Item {
            objectName: "barMotionPresetSelector"
            width: parent.width
            height: Theme.settingsRowHeight

            Row {
                anchors.fill: parent
                anchors.leftMargin: Theme.settingsPanelPadding
                anchors.rightMargin: Theme.settingsPanelPadding
                spacing: 8

                Text {
                    width: Theme.settingsLabelWidth
                    anchors.verticalCenter: parent.verticalCenter
                    text: "预设"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.textMuted
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Repeater {
                        model: root._presetOptions

                        delegate: Rectangle {
                            required property var modelData

                            readonly property bool _selected:
                                SettingsService.data.barMotion.preset === modelData.value

                            width: 52
                            height: 24
                            radius: Theme.cornerRadius - 4
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
                                onClicked: SettingsService.data.barMotion.preset = parent.modelData.value
                            }
                        }
                    }
                }
            }
        }

        SliderSection {
            objectName: "barMotionIntensitySlider"
            width: parent.width
            label: "强度"
            value: SettingsService.data.barMotion.intensity
            from: SettingsService.barMotionIntensityMin
            to: SettingsService.barMotionIntensityMax
            stepSize: 0.05
            unit: "×"
            onValueCommitted: newValue => SettingsService.data.barMotion.intensity = newValue
        }

        SliderSection {
            objectName: "barMotionSpeedSlider"
            width: parent.width
            label: "速度"
            value: SettingsService.data.barMotion.speedMultiplier
            from: 0.5
            to: 2.0
            stepSize: 0.05
            unit: "×"
            onValueCommitted: newValue => SettingsService.data.barMotion.speedMultiplier = newValue
        }

        ToggleSection {
            objectName: "barMotionPulseToggle"
            width: parent.width
            label: "脉冲反馈"
            value: SettingsService.data.barMotion.pulseEnabled
            onToggled: newValue => SettingsService.data.barMotion.pulseEnabled = newValue
        }
    }
}
