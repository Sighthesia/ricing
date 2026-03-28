import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// Renders the expanded workspace hint preview for the SuperIsland hold surface.
Item {
    id: root

    required property var event

    readonly property var _hint: WindowHintService.activeHint
    readonly property int _padH: Theme.barWidget.contentPaddingH
    readonly property int _padV: Theme.barWidget.contentPaddingV
    readonly property int _laneGap: Math.max(2, Math.round(4 * Theme.uiScale))
    readonly property int _compactIcon: Math.max(10, Theme.barWidget.compactIconSize - 1)
    readonly property int _primaryIcon: Theme.barWidget.primaryIconSize
    readonly property int _pillHeight: Theme.barWidget.pillHeight
    readonly property int _mainIslandHeight: root._pillHeight * 3
    readonly property int _titleIslandHeight: Math.max(22, Theme.fontSizeBody + Theme.barWidget.badgePaddingV * 3)
    readonly property int _titleOverlap: Math.max(8, Math.round(root._titleIslandHeight * 0.45))
    readonly property int _stripHeight: Math.max(12, Theme.barWidget.compactIconSize)
    readonly property int _windowRowHeight: Math.max(20, Theme.barWidget.primaryIconSize + Theme.barWidget.contentPaddingV * 3)
    readonly property int _previewWidth: Math.round(396 * Theme.uiScale)

    implicitWidth: Math.min(
        root._previewWidth,
        Math.max(_workspaceRow.implicitWidth, _titleRow.implicitWidth) + root._padH * 2 + Math.round(36 * Theme.uiScale)
    )
    implicitHeight: root._mainIslandHeight + root._titleIslandHeight - root._titleOverlap

    Item {
        id: _mainIsland

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        height: root._mainIslandHeight

        Column {
            anchors.fill: parent
            anchors.leftMargin: root._padH
            anchors.rightMargin: root._padH
            anchors.topMargin: root._padV
            anchors.bottomMargin: root._titleIslandHeight - root._titleOverlap + root._padV
            spacing: root._laneGap

            Item {
                width: parent.width
                height: visible ? root._stripHeight : 0
                visible: root._hint.previousWorkspace.icons.length > 0

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Qt.rgba(1, 1, 1, 0.04)
                    opacity: 0.75
                }

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.barWidget.iconSpacing

                    Repeater {
                        model: root._hint.previousWorkspace.icons

                        delegate: Item {
                            required property var modelData

                            width: root._compactIcon
                            height: root._compactIcon
                            opacity: modelData.isFocused ? 0.52 : 0.28

                            Image {
                                anchors.fill: parent
                                source: modelData.icon || ""
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: root._windowRowHeight
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.05)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.04)

                Row {
                    id: _workspaceRow

                    anchors.centerIn: parent
                    spacing: Theme.barWidget.iconSpacing + 1

                    Repeater {
                        model: root._hint.windows

                        delegate: Rectangle {
                            required property var modelData

                            readonly property bool _focused: modelData.isFocused
                            readonly property int _distance:
                                root._hint.currentIndex >= 0
                                    ? Math.abs(index - root._hint.currentIndex)
                                    : 99

                            width: _focused
                                ? root._windowRowHeight + Theme.barWidget.badgePaddingH * 2
                                : root._windowRowHeight - Theme.barWidget.contentPaddingV
                            height: _focused ? root._windowRowHeight - 4 : root._windowRowHeight - 8
                            radius: height / 2
                            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                            color: _focused ? Colors.highlight : Qt.rgba(1, 1, 1, 0.06)
                            opacity: _focused ? 1 : (_distance === 1 ? 0.78 : 0.48)
                            border.width: _focused ? 0 : 1
                            border.color: Qt.rgba(1, 1, 1, 0.03)

                            Behavior on width {
                                NumberAnimation {
                                    duration: Theme.anim.moveDuration
                                    easing.type: Theme.anim.moveType
                                }
                            }

                            Behavior on height {
                                NumberAnimation {
                                    duration: Theme.anim.moveDuration
                                    easing.type: Theme.anim.moveType
                                }
                            }

                            Image {
                                anchors.centerIn: parent
                                width: _focused ? root._primaryIcon : root._compactIcon
                                height: width
                                source: modelData.icon || ""
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }
                        }
                    }

                    Text {
                        visible: root._hint.windows.length === 0
                        text: "No windows"
                        color: Colors.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                radius: height / 2
                color: Colors.border
                opacity: 0.35
            }

            Item {
                width: parent.width
                height: visible ? root._stripHeight : 0
                visible: root._hint.nextWorkspace.icons.length > 0

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Qt.rgba(1, 1, 1, 0.04)
                    opacity: 0.75
                }

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.barWidget.iconSpacing

                    Repeater {
                        model: root._hint.nextWorkspace.icons

                        delegate: Item {
                            required property var modelData

                            width: root._compactIcon
                            height: root._compactIcon
                            opacity: modelData.isFocused ? 0.52 : 0.28

                            Image {
                                anchors.fill: parent
                                source: modelData.icon || ""
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        id: _titleIsland

        anchors.top: _mainIsland.bottom
        anchors.topMargin: -root._titleOverlap
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width - root._padH * 2, Math.round(312 * Theme.uiScale))
        height: root._titleIslandHeight

        RowLayout {
            id: _titleRow

            anchors.fill: parent
            anchors.leftMargin: Theme.barWidget.badgePaddingH * 2
            anchors.rightMargin: Theme.barWidget.badgePaddingH * 2
            spacing: Theme.barWidget.iconSpacing

            Text {
                Layout.fillWidth: true
                text: root._hint.previousWindow.title || ""
                color: Colors.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
                maximumLineCount: 1
                verticalAlignment: Text.AlignVCenter
                opacity: text.length > 0 ? 0.86 : 0
            }

            Rectangle {
                Layout.minimumWidth: Math.round(116 * Theme.uiScale)
                Layout.preferredWidth: Math.round(150 * Theme.uiScale)
                Layout.maximumWidth: Math.round(176 * Theme.uiScale)
                Layout.preferredHeight: parent.height - Theme.barWidget.contentPaddingV * 2
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.04)

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.barWidget.badgePaddingH

                    Image {
                        width: root._compactIcon
                        height: width
                        source: root._hint.currentWindowIcon || ""
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        visible: source !== ""
                    }

                    Text {
                        width: Math.min(implicitWidth, Math.round(122 * Theme.uiScale))
                        text: root._hint.currentWindowTitle || "Window hint"
                        color: Colors.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: root._hint.nextWindow.title || ""
                color: Colors.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideLeft
                maximumLineCount: 1
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                opacity: text.length > 0 ? 0.86 : 0
            }
        }
    }
}
