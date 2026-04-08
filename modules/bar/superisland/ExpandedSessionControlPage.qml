import QtQuick
import qs.config
import qs.services
import "../../sessioncontrol" as SessionControlParts

// Full-screen session control page rendered inside the expanded SuperIsland shell.
Item {
    id: root

    property real _entryOpacity: 0
    property real _entryScale: 0.985
    property real _entryOffsetY: Math.round(18 * Theme.uiScale)

    function pageActivated() {
        _enterAnim.stop()
        root._entryOpacity = 0
        root._entryScale = 0.985
        root._entryOffsetY = Math.round(18 * Theme.uiScale)
        _enterAnim.start()
    }

    function pageDeactivated() {
        _enterAnim.stop()
        root._entryOpacity = 1
        root._entryScale = 1
        root._entryOffsetY = 0
    }

    function pageExitDuration() {
        return 0
    }

    Item {
        anchors.fill: parent

        Item {
            id: _pageStage
            width: parent.width
            height: parent.height
            x: 0
            y: root._entryOffsetY
            opacity: root._entryOpacity
            scale: root._entryScale
            transformOrigin: Item.Center

            Rectangle {
                anchors.fill: parent
                radius: Theme.cornerRadius
                color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.18)
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.cornerRadius
                color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.14)
                border.color: Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, 0.22)
                border.width: 1
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.cornerRadius
                color: Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.04)
            }

            Rectangle {
                width: Math.round(root.width * 0.42)
                height: width
                radius: width / 2
                x: -width * 0.16
                y: -height * 0.08
                color: Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.12)
            }

            Rectangle {
                width: Math.round(root.width * 0.34)
                height: width
                radius: width / 2
                x: root.width - width * 0.82
                y: root.height - height * 0.76
                color: Qt.rgba(Colors.destructive.r, Colors.destructive.g, Colors.destructive.b, 0.09)
            }

            SessionControlParts.SessionControlContent {
                anchors.fill: parent
            }
        }
    }

    ParallelAnimation {
        id: _enterAnim

        NumberAnimation {
            target: root
            property: "_entryOpacity"
            to: 1
            duration: Theme.anim.highlightDuration
            easing.type: Easing.InOutCubic
        }

        NumberAnimation {
            target: root
            property: "_entryScale"
            to: 1
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            target: root
            property: "_entryOffsetY"
            to: 0
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }
    }
}
