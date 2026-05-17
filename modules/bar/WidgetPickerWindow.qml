import "."
import "../../services" as Services
import QtQuick
import Quickshell
import Quickshell.Wayland

// Widget picker panel for inserting widgets into the selected dockzone section.
Variants {
    id: root

    model: Quickshell.screens

    // Present the picker in an overlay window below the bar.
    PanelWindow {
        required property var modelData

        screen: modelData
        visible: Services.BarLayoutService.widgetPickerVisible
        color: "transparent"
        implicitWidth: 320
        implicitHeight: pickerFrame.height + 16
        exclusiveZone: -1
        WlrLayershell.layer: WlrLayer.Overlay

        anchors {
            top: true
            left: true
            right: true
        }

        margins {
            top: Services.BarLayoutService.barHeight + 8
        }

        // Render the picker card centered below the bar.
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
            opacity: Services.BarLayoutService.widgetPickerVisible ? 1 : 0
            scale: Services.BarLayoutService.widgetPickerVisible ? 1 : 0.96
            transformOrigin: Item.Top

            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 0.3 } }

            Column {
                id: contentColumn

                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                // Show which dockzone section will receive the new widget.
                Text {
                    text: "Add widget to - " + Services.BarLayoutService.widgetPickerSection
                    color: "#aaaaaa"
                    font.pixelSize: 12
                }

                // Provide a simple inline search field for the available widgets.
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
                        selectedTextColor: "white"
                        selectionColor: "#4466aa"

                        // Keep a lightweight placeholder inside the search field.
                        Text {
                            anchors.fill: parent
                            text: "Search widgets..."
                            color: "#666666"
                            font.pixelSize: 12
                            visible: !searchInput.text && !searchInput.activeFocus
                        }
                    }
                }

                // List the widgets that can be inserted into the current section.
                Column {
                    width: parent.width
                    spacing: 4

                    Repeater {
                        model: _filteredWidgets()

                        // Render a clickable card for each available widget.
                        Rectangle {
                            required property var modelData

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

                                // Show the widget label prominently.
                                Text {
                                    text: modelData.label
                                    color: "white"
                                    font.pixelSize: 12
                                    font.bold: true
                                }

                                // Show the short widget description when available.
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

        // Close the picker when clicking outside the card.
        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: Services.BarLayoutService.closeWidgetPicker()
        }

        // Filter the available widgets using the current search query.
        function _filteredWidgets() {
            var all = Services.BarLayoutService.availableWidgets
            var query = searchInput.text.toLowerCase().trim()

            if (!query)
                return all

            return all.filter(function (widget) {
                return widget.label.toLowerCase().indexOf(query) !== -1
                    || (widget.description || "").toLowerCase().indexOf(query) !== -1
            })
        }
    }
}
