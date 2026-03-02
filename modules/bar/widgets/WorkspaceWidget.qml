import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services

Rectangle {
    id: root

    color: Colors.background
    radius: Theme.cornerRadius
    implicitHeight: Theme.barHeight
    implicitWidth: layout.width + 20

    property Item activeItem: null

    // Sliding highlight pill behind active workspace
    Rectangle {
        id: indicator

        x: layout.x + (root.activeItem ? root.activeItem.x : 0)
        y: layout.y + (root.activeItem ? root.activeItem.y : 0)
        width: root.activeItem ? root.activeItem.width : 0
        height: 26
        radius: 14
        color: Colors.highlight

        Behavior on x {
            NumberAnimation {
                duration: Theme.anim.moveDuration
                easing.type: Theme.anim.moveType
            }
        }

        Behavior on width {
            NumberAnimation {
                duration: Theme.anim.moveDuration
                easing.type: Theme.anim.moveType
            }
        }
    }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 5

        Repeater {
            model: NiriService.workspaces

            delegate: Item {
                id: wsDelegate

                required property int idx
                required property bool isActive

                implicitWidth: isActive
                    ? (wsText.implicitWidth + 24)
                    : (wsText.implicitWidth + 12)
                implicitHeight: 26

                onIsActiveChanged: {
                    if (isActive) root.activeItem = wsDelegate;
                }

                Component.onCompleted: {
                    if (isActive) root.activeItem = wsDelegate;
                }

                Behavior on implicitWidth {
                    NumberAnimation {
                        duration: Theme.anim.moveDuration
                        easing.type: Theme.anim.moveType
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached([
                            "niri", "msg", "action",
                            "focus-workspace", wsDelegate.idx.toString()
                        ]);
                    }
                }

                Text {
                    id: wsText
                    anchors.centerIn: parent
                    text: wsDelegate.idx
                    font.family: Theme.fontMono
                    font.bold: true
                    font.pixelSize: 14
                    // Dark text on highlight pill, muted otherwise
                    color: wsDelegate.isActive
                        ? Colors.background
                        : Colors.textMuted

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.anim.highlightDuration
                        }
                    }
                }
            }
        }
    }
}
