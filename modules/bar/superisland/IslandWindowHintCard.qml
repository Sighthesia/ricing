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
    readonly property int _titleIslandHeight: Math.max(22, Theme.fontSizeBody + Theme.barWidget.badgePaddingV * 3)
    readonly property int _titleOverlap: Math.max(8, Math.round(root._titleIslandHeight * 0.45))
    readonly property int _sideTitleMaxWidth: Math.round(132 * Theme.uiScale)
    readonly property int _stripHeight: Math.max(12, Theme.barWidget.compactIconSize)
    readonly property int _windowRowHeight: Math.max(20, Theme.barWidget.primaryIconSize + Theme.barWidget.contentPaddingV * 3)
    readonly property int _minPreviewWidth: Math.round(320 * Theme.uiScale)
    readonly property int _maxPreviewWidth: Math.round(560 * Theme.uiScale)
    readonly property bool _hasPreviousStrip: root._hint.previousWorkspace.icons.length > 0
    readonly property bool _hasNextStrip: root._hint.nextWorkspace.icons.length > 0

    implicitWidth: Math.min(
        root._maxPreviewWidth,
        Math.max(
            root._minPreviewWidth,
            _workspaceRow.implicitWidth + root._padH * 2 + Math.round(36 * Theme.uiScale),
            _titleIsland.implicitWidth + root._padH * 2 + Math.round(20 * Theme.uiScale)
        )
    )
    implicitHeight: _mainIsland.implicitHeight + root._titleIslandHeight - root._titleOverlap

    Item {
        id: _mainIsland

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        height: implicitHeight
        implicitHeight: _mainIslandContent.implicitHeight + root._padV * 2 + root._titleOverlap

        Column {
            id: _mainIslandContent

            anchors.fill: parent
            anchors.leftMargin: root._padH
            anchors.rightMargin: root._padH
            anchors.topMargin: root._padV
            anchors.bottomMargin: root._padV + root._titleOverlap
            spacing: root._laneGap

            Item {
                width: parent.width
                height: visible ? root._stripHeight : 0
                visible: root._hasPreviousStrip

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
                visible: root._hasNextStrip

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
        width: Math.min(parent.width - root._padH * 2, implicitWidth)
        height: root._titleIslandHeight

        readonly property int _titleSidePadding: Theme.barWidget.badgePaddingH * 2
        readonly property int _titleSlotGap: Theme.barWidget.iconSpacing * 2
        readonly property int _titleContentWidth: Math.max(0, width - _titleSidePadding * 2)
        readonly property int _centerIslandWidth: Math.max(
            Math.round(116 * Theme.uiScale),
            Math.min(
                Math.round(320 * Theme.uiScale),
                _centerIslandContent.implicitWidth + Theme.barWidget.badgePaddingH * 4
            )
        )
        readonly property int _titlePreferredWidth: Math.max(
            _centerIslandWidth + _sideTitleMaxWidth * 2 + Theme.barWidget.iconSpacing * 4,
            Math.round(260 * Theme.uiScale)
        )
        readonly property int _resolvedCenterIslandWidth: Math.max(
            0,
            Math.min(_centerIslandWidth, _titleContentWidth)
        )
        readonly property int _sideSlotWidth: Math.max(
            0,
            Math.min(
                root._sideTitleMaxWidth,
                Math.floor((_titleContentWidth - _resolvedCenterIslandWidth - _titleSlotGap * 2) / 2)
            )
        )
        readonly property int _leadingGapWidth: _sideSlotWidth > 0 ? _titleSlotGap : 0
        readonly property int _trailingGapWidth: _sideSlotWidth > 0 ? _titleSlotGap : 0

        implicitWidth: Math.min(Math.round(460 * Theme.uiScale), _titlePreferredWidth)
        implicitHeight: root._titleIslandHeight

        // Title lanes keep previous/current/next widths stable.
        Row {
            anchors.fill: parent
            anchors.leftMargin: _titleSidePadding
            anchors.rightMargin: _titleSidePadding
            spacing: 0

            // Previous title lane.
            Item {
                width: _titleIsland._sideSlotWidth
                height: parent.height

                Text {
                    anchors.fill: parent
                    text: root._hint.previousWindow.title || ""
                    color: Colors.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    verticalAlignment: Text.AlignVCenter
                    opacity: text.length > 0 ? 0.86 : 0
                }
            }

            // Leading gap keeps breathing room around the center pill.
            Item {
                width: _titleIsland._leadingGapWidth
                height: parent.height
            }

            // Current title pill.
            Rectangle {
                id: _centerIsland

                width: _titleIsland._resolvedCenterIslandWidth
                height: parent.height - Theme.barWidget.contentPaddingV * 2
                anchors.verticalCenter: parent.verticalCenter
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.04)

                Row {
                    id: _centerIslandContent

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
                        width: Math.min(
                            implicitWidth,
                            Math.max(0, _centerIsland.width - Theme.barWidget.badgePaddingH * 4 - (root._hint.currentWindowIcon ? root._compactIcon + _centerIslandContent.spacing : 0))
                        )
                        text: root._hint.currentWindowTitle || "Window hint"
                        color: Colors.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // Trailing gap keeps breathing room around the center pill.
            Item {
                width: _titleIsland._trailingGapWidth
                height: parent.height
            }

            // Next title lane.
            Item {
                width: _titleIsland._sideSlotWidth
                height: parent.height

                Text {
                    anchors.fill: parent
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
}
