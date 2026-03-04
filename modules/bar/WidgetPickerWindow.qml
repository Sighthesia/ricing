import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// Full-width panel displayed below the bar in layout mode.
// Shows all registered widgets as live-rendered cards; clicking a card inserts it.
PanelWindow {
    id: root

    // Sit directly below the bar
    anchors { top: true; left: true; right: true }
    margins.top: Theme.barHeight

    // Reserve wayland space for this panel's height when visible
    exclusiveZone: panelBg.height

    WlrLayershell.layer: WlrLayer.Top
    color: "transparent"

    // Visible only while the picker is requested AND layout mode is active
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

    Rectangle {
        id: panelBg
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: mainColumn.implicitHeight + Theme.barPadding * 2
        color: Colors.background
        border.color: Colors.border
        border.width: 1

        ColumnLayout {
            id: mainColumn
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: Theme.barPadding
            }
            spacing: Theme.barPadding

            // Search bar
            Rectangle {
                id: searchBar
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
                            BarLayoutService.activePanel = "none";
                        }
                    }
                }
            }

            // Widget card grid
            GridView {
                id: grid
                Layout.fillWidth: true
                // Cap at 2 rows; scroll if more widgets than fit
                height: Math.min(implicitHeight, cellHeight * 2)
                clip: true
                cellWidth: 160
                cellHeight: 96
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

                            // Live widget preview — scaled down to fit the card preview area
                            Item {
                                Layout.fillWidth: true
                                height: 52
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
                            // Click inserts into the right section by default.
                            // FIXME: V2 should let the user choose a target section,
                            //        or support dragging cards directly onto the bar.
                            onClicked: BarLayoutService.addWidget(modelData, "right")
                        }
                    }
                }
            }
        }
    }
}
