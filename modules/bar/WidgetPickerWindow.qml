import "."
import "../../services" as Services
import QtQuick
import Quickshell
import Quickshell.Wayland

// Widget picker panel — shows available widgets with search and metadata.
Variants {
    id: root

    model: Quickshell.screens

    PanelWindow {
        required property var modelData

        screen: modelData
        visible: Services.BarLayoutService.widgetPickerVisible
        color: "transparent"
        implicitWidth: 320
        implicitHeight: pickerFrame.height + 16

        anchors {
            top: true
            left: true
            right: true
        }

        margins {
            top: Services.BarLayoutService.barHeight + 8
        }

        // Picker surface frame.
        Rectangle {
            id: pickerFrame

            width: 320
            height: contentColumn.implicitHeight + 24
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            radius: 12
            color: "#1a1a1a"
            border.color: "#333333"
            border.width: 1

            Column {
                id: contentColumn

                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                // Section target heading.
                Text {
                    text: "Add widget to \u2014 " + Services.BarLayoutService.widgetPickerSection
                    color: "#aaaaaa"
                    font.pixelSize: 12
                }

                // Search input.
                Rectangle {
                    width: parent.width
                    height: 28
                    radius: 6
                    color: "#252525"
                    border.color: "#444444"
                    border.width: 1

                    TextInput {
                        id: searchInput

                        anchors.fill: parent
                        anchors.margins: 6
                        color: "white"
                        font.pixelSize: 12
                        clip: true

                        // Placeholder text.
                        Text {
                            anchors.fill: parent
                            text: "Search widgets..."
                            color: "#666666"
                            font.pixelSize: 12
                            visible: !searchInput.text && !searchInput.activeFocus
                        }
                    }
                }

                // Filtered widget list.
                Column {
                    width: parent.width
                    spacing: 4

                    Repeater {
                        model: _filteredWidgets()

                        // Widget option card.
                        Rectangle {
                            required property var modelData
                            required property int index

                            width: parent.width
                            height: 44
                            radius: 8
                            color: cardMouse.containsMouse ? "#333333" : "#222222"
                            border.color: cardMouse.containsMouse ? "#555555" : "#3a3a3a"
                            border.width: 1

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                spacing: 2

                                // Widget label.
                                Text {
                                    text: modelData.label
                                    color: "white"
                                    font.pixelSize: 12
                                    font.bold: true
                                }

                                // Widget description.
                                Text {
                                    text: modelData.description || ""
                                    color: "#888888"
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                    width: parent.width
                                    visible: text !== ""
                                }
                            }

                            MouseArea {
                                id: cardMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Services.BarLayoutService.addWidgetToSection(
                                        modelData.id,
                                        Services.BarLayoutService.widgetPickerSection
                                    )
                                    Services.BarLayoutService.closeWidgetPicker()
                                }
                            }
                        }
                    }
                }
            }
        }

        // Filter available widgets by search query.
        function _filteredWidgets() {
            var all = Services.BarLayoutService.availableWidgets
            var query = searchInput.text.toLowerCase().trim()
            if (!query) return all
            return all.filter(function (w) {
                return w.label.toLowerCase().indexOf(query) !== -1
                    || (w.description || "").toLowerCase().indexOf(query) !== -1
            })
        }
    }

}
