import Quickshell
import QtQuick
import qs.config

// Single workspace pill used by the workspace overview strip.
Item {
    id: root

    required property string wsId
    required property int idx
    required property bool isActive
    required property var appItems
    required property string focusedWindowId
    required property int pillHeight
    required property int pillPaddingH
    required property int iconSpacing
    required property int smallIconSize

    readonly property bool _hasApps: root.appItems.length > 0

    visible: root.isActive || root._hasApps
    width: visible ? _pill.implicitWidth : 0
    height: visible ? _pill.implicitHeight : 0

    Rectangle {
        id: _pill

        implicitHeight: root.pillHeight
        implicitWidth: Math.max(
            _iconsRow.implicitWidth + root.pillPaddingH * 2,
            root.pillHeight
        )
        radius: implicitHeight / 2
        color: root.isActive ? Colors.highlight : Colors.surface

        Behavior on color {
            ColorAnimation { duration: Theme.anim.highlightDuration }
        }

        Row {
            id: _iconsRow

            anchors.centerIn: parent
            spacing: root.iconSpacing

            Repeater {
                model: root.appItems

                delegate: Image {
                    required property var modelData

                    readonly property bool _isLoaded: status === Image.Ready
                    readonly property bool _isFocused:
                        root.isActive && modelData.winId === root.focusedWindowId

                    width: root.smallIconSize
                    height: root.smallIconSize
                    opacity: _isLoaded
                        ? (root.isActive ? (_isFocused ? 1.0 : 0.5) : 0.75)
                        : 0
                    scale: _isFocused ? 1.2 : 1.0
                    source: modelData.icon || ""
                    asynchronous: true
                    smooth: true
                    fillMode: Image.PreserveAspectFit

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.anim.highlightDuration }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.anim.highlightDuration
                            easing.type: Theme.anim.highlightType
                        }
                    }
                }
            }

            Text {
                visible: !root._hasApps
                text: root.idx
                font.family: Theme.fontMono
                font.bold: true
                font.pixelSize: Theme.fontSizeBody
                color: root.isActive ? Colors.background : Colors.textMuted

                Behavior on color {
                    ColorAnimation { duration: Theme.anim.highlightDuration }
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Colors.highlight
            opacity: _mouseArea.containsMouse ? 0.15 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.anim.highlightDuration
                    easing.type: Theme.anim.highlightType
                }
            }
        }

        MouseArea {
            id: _mouseArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Quickshell.execDetached([
                "niri", "msg", "action",
                "focus-workspace", root.idx.toString()
            ])
        }
    }
}
