import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services

// Widget picker panel — same visual style as SettingsPanelWindow.
// Opens below the bar on the right side when BarLayoutService.widgetPickerOpen is true.
PanelWindow {
    id: root

    // Mirror SettingsPanelWindow positioning: top-right, margin pushes below bar
    anchors { top: true; right: true }
    margins { top: Theme.barHeight }

    implicitWidth: 480
    implicitHeight: 480
    color: "transparent"

    focusable: true

    // Visible only while widgetPickerOpen AND in layout mode
    visible: BarLayoutService.widgetPickerOpen && BarLayoutService.settingsMode
    onVisibleChanged: if (!visible) BarLayoutService.widgetPickerOpen = false

    // Widget registry — mirrors BarContent.widgetRegistry.
    // FIXME: promote to a shared singleton in V2 to avoid duplication.
    readonly property var widgetRegistry: ({
        "clock":           Qt.resolvedUrl("widgets/Clock.qml"),
        "workspaceWidget": Qt.resolvedUrl("widgets/WorkspaceWidget.qml")
    })

    // Human-readable display names for the picker cards
    readonly property var widgetNames: ({
        "clock":           "\u65f6\u949f",
        "workspaceWidget": "\u5de5\u4f5c\u533a"
    })

    property string searchQuery: ""

    // Filtered list of widget ids based on the current search query
    readonly property var filteredWidgets: {
        let keys = Object.keys(widgetRegistry);
        if (!searchQuery) return keys;
        let q = searchQuery.toLowerCase();
        return keys.filter(k => (widgetNames[k] || k).toLowerCase().includes(q));
    }

    // Returns how many instances of widgetId are currently in the layout
    function countInstances(widgetId) {
        let n = 0;
        for (let i = 0; i < BarLayoutService.layoutModel.count; i++)
            if (BarLayoutService.layoutModel.get(i).id === widgetId) n++;
        return n;
    }

    // Outer card — same structure as SettingsPanelWindow
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 4
        anchors.rightMargin: 4
        anchors.bottomMargin: 4
        radius: Theme.cornerRadius
        color: Colors.background
        border.color: Colors.border
        border.width: 1

        // Subtle inner highlight border
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Theme.cornerRadius - 1
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.04)
            border.width: 1
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: Theme.barPadding

            // Panel title
            Text {
                text: "\u5c0f\u7ec4\u4ef6\u5e93"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeBody
                font.weight: Font.Medium
                color: Colors.text
            }

            // Search bar
            Rectangle {
                Layout.fillWidth: true
                height: Theme.barHeight - Theme.barPadding
                radius: Theme.cornerRadius
                color: Colors.surface
                border.color: Colors.border
                border.width: 1

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.widgetPadding
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u641c\u7d22\u5c0f\u7ec4\u4ef6\u2026"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.textMuted
                    visible: searchInput.displayText.length === 0
                }

                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.leftMargin: Theme.widgetPadding
                    anchors.rightMargin: Theme.widgetPadding
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.text
                    clip: true
                    onTextChanged: root.searchQuery = text

                    Keys.onEscapePressed: {
                        if (text.length > 0) {
                            clear();
                        } else {
                            BarLayoutService.widgetPickerOpen = false;
                        }
                    }
                }
            }

            // Widget card grid
            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: 148
                cellHeight: 104

                model: root.filteredWidgets

                delegate: Item {
                    width: grid.cellWidth
                    height: grid.cellHeight

                    Rectangle {
                        id: card
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: Theme.cornerRadius
                        color: cardHover.containsMouse ? Colors.surface : "transparent"
                        border.color: cardHover.containsMouse ? Colors.border : "transparent"
                        border.width: 1

                        Behavior on color {
                            ColorAnimation { duration: Theme.anim.highlightDuration }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 4

                            // Live widget preview — scaled down to fit the card
                            Item {
                                Layout.fillWidth: true
                                height: 60
                                clip: true

                                Loader {
                                    id: widgetLoader
                                    anchors.centerIn: parent
                                    source: root.widgetRegistry[modelData] || ""
                                    transform: Scale {
                                        xScale: 0.65
                                        yScale: 0.65
                                        origin.x: widgetLoader.width / 2
                                        origin.y: widgetLoader.height / 2
                                    }
                                }
                            }

                            // Widget name label
                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: root.widgetNames[modelData] || modelData
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                color: Colors.textMuted
                                elide: Text.ElideRight
                            }
                        }

                        // Instance count badge — shown only when at least one instance exists
                        Rectangle {
                            visible: root.countInstances(modelData) > 0
                            width: 18
                            height: 18
                            radius: 9
                            color: Colors.highlight
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.topMargin: 2
                            anchors.rightMargin: 2

                            Text {
                                anchors.centerIn: parent
                                text: root.countInstances(modelData)
                                font.family: Theme.fontFamily
                                font.pixelSize: Math.max(8, Theme.fontSizeSmall - 2)
                                color: "white"
                            }
                        }

                        MouseArea {
                            id: cardHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            // Insert into the section the user clicked on the bar to open the picker.
                            // FIXME: V2 should support dragging cards directly onto the bar.
                            onClicked: BarLayoutService.addWidget(modelData, BarLayoutService.widgetPickerTargetSection)
                        }
                    }
                }
            }
        }
    }
}
