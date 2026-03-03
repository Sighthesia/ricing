import Quickshell
import QtQuick
import qs.config
import qs.services

// Right-click context menu for the bar background.
// Anchor to the BarContent item; positions itself below the bar at click X.
PopupWindow {
    id: root

    // The BarContent Item — used to calculate the popup's on-screen position.
    required property Item anchorTarget

    visible: false
    color: "transparent"

    anchor.item: anchorTarget
    // Place anchor point at the bar's bottom edge, horizontally at click X.
    // The menu expands downward (Quickshell default gravity: Bottom|Right).
    anchor.rect.x: Math.max(0, Math.min(_clickX - implicitWidth / 2,
                                         (anchorTarget ? anchorTarget.width : 0) - implicitWidth))
    anchor.rect.y: anchorTarget ? anchorTarget.height : 0
    anchor.rect.width: 1
    anchor.rect.height: 1

    implicitWidth: Math.max(160, menuColumn.implicitWidth + 24)
    implicitHeight: menuColumn.implicitHeight + 8

    property real _clickX: 0

    // Open menu at BarContent-local x coordinate.
    // `_y` is accepted for API symmetry with MouseArea.onClicked but is ignored:
    // the menu always appears at the bar's bottom edge regardless of click y.
    function showAt(x, _y) {
        _clickX = x;
        anchor.updateAnchor();
        visible = true;
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.surface
        radius: Theme.cornerRadius
        border.color: Colors.border
        border.width: 1

        Column {
            id: menuColumn
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 4
            spacing: 2

            // --- Layout mode item ---
            Item {
                id: layoutItem
                width: parent.width
                height: 28

                // Hover highlight overlay
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: Theme.cornerRadius - 2
                    color: Colors.highlight
                    opacity: layoutArea.containsMouse ? 0.12 : 0
                    Behavior on opacity {
                        NumberAnimation { duration: Theme.anim.highlightDuration }
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    spacing: 8

                    Text {
                        text: "\uf0c9"
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeIcon
                        color: BarLayoutService.settingsMode ? Colors.highlight : Colors.text
                        opacity: BarLayoutService.settingsMode ? 1.0 : 0.7
                    }

                    Text {
                        text: BarLayoutService.settingsMode ? "退出布局模式" : "布局模式"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeBody
                        color: Colors.text
                    }
                }

                MouseArea {
                    id: layoutArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        BarLayoutService.activePanel =
                            BarLayoutService.settingsMode ? "none" : "layout";
                        root.visible = false;
                    }
                }
            }

            // --- Settings item ---
            Item {
                id: settingsItem
                width: parent.width
                height: 28

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: Theme.cornerRadius - 2
                    color: Colors.highlight
                    opacity: settingsArea.containsMouse ? 0.12 : 0
                    Behavior on opacity {
                        NumberAnimation { duration: Theme.anim.highlightDuration }
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    spacing: 8

                    Text {
                        text: "\uf013"
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeIcon
                        color: Colors.text
                        opacity: 0.7
                    }

                    Text {
                        text: "设置"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeBody
                        color: Colors.text
                    }
                }

                MouseArea {
                    id: settingsArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        BarLayoutService.activePanel = "config";
                        root.visible = false;
                    }
                }
            }
        }
    }
}
