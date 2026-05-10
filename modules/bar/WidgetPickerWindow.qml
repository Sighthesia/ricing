import "."
import "../../services" as Services
import QtQuick
import Quickshell
import Quickshell.Wayland

// Present the minimal widget picker as a thin bar-owned panel.
Variants {
    id: root

    model: Quickshell.screens

    // Show the available stable widgets for the current picker target section.
    PanelWindow {
        required property var modelData

        screen: modelData
        visible: Services.BarLayoutService.widgetPickerVisible
        color: "#1f1f1f"
        implicitWidth: 280
        implicitHeight: 180

        anchors {
            top: true
            left: true
            right: true
        }

        margins {
            top: 8
            left: 0
            right: 0
        }

        // Frame the picker in a compact rounded surface.
        Rectangle {
            id: pickerFrame

            width: 280
            height: 180
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            radius: 12
            color: "#242424"
            border.color: "#4a4a4a"
            border.width: 1

            // Stack the heading and option rows vertically.
            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                // Show which section will receive the new widget.
                Text {
                    text: "Add widget to " + Services.BarLayoutService.widgetPickerSection
                    color: "white"
                    font.pixelSize: 14
                }

                // List the currently supported stable widgets.
                Repeater {
                    model: Services.BarLayoutService.availableWidgets

                    // Render each widget option as a tappable row.
                    Rectangle {
                        required property var modelData
                        required property int index

                        width: parent.width
                        height: 36
                        radius: 8
                        color: "#333333"
                        border.color: "#555555"
                        border.width: 1

                        // Show the widget label inside the option row.
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            text: modelData.label
                            color: "white"
                            font.pixelSize: 12
                        }

                        // Activate the selected widget when the row is clicked.
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                Services.BarLayoutService.addWidgetToSection(modelData.id, Services.BarLayoutService.widgetPickerSection)
                                Services.BarLayoutService.closeWidgetPicker()
                            }
                        }
                    }
                }

            }

        }

    }

}
