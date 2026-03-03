import QtQuick
import qs.config

// Left navigation sidebar for the settings panel.
// Emits pageSelected(page) when a nav item is clicked.
Item {
    id: root

    property string currentPage: "appearance"
    signal pageSelected(string page)

    implicitWidth: 108
    implicitHeight: navCol.implicitHeight + 16

    // Sidebar background
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.5)
        radius: Theme.cornerRadius
    }

    Column {
        id: navCol
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 8
            topMargin: 12
        }
        spacing: 2

        Repeater {
            model: [
                { page: "appearance", icon: "\uf53f", label: "外观" },
                { page: "about",      icon: "\uf05a", label: "关于" }
            ]

            delegate: Item {
                required property var modelData

                width: parent.width
                height: 34

                readonly property bool active: root.currentPage === modelData.page

                // Active/hover highlight
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.cornerRadius - 4
                    color: parent.active ? Colors.highlight : (navItem.containsMouse ? Colors.surface : "transparent")
                    opacity: parent.active ? 0.25 : 0.5

                    Behavior on color { ColorAnimation { duration: Theme.anim.highlightDuration } }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.icon
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall + 1
                        color: active ? Colors.highlight : Colors.textMuted

                        Behavior on color { ColorAnimation { duration: Theme.anim.highlightDuration } }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: active ? Colors.text : Colors.textMuted
                        font.weight: active ? Font.Medium : Font.Normal

                        Behavior on color { ColorAnimation { duration: Theme.anim.highlightDuration } }
                    }
                }

                MouseArea {
                    id: navItem
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.pageSelected(modelData.page)
                }
            }
        }
    }
}
