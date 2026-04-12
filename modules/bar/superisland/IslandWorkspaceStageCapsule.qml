import QtQuick
import qs.config
import qs.services

// Workspace capsule renderer for window-hint stage slots.
Item {
    id: workspaceCapsule

    required property Item host
    required property QtObject focusIndexPair
    required property var capsule
    required property real slotPosition
    property bool hiddenForMotion: false
    property real forcedOpacity: -1

    readonly property var _metrics: host._workspaceMetrics(workspaceCapsule.slotPosition)
    readonly property real _emphasis: _metrics.emphasis
    readonly property color _fill: host._mixColor(host._secondaryCapsuleFill, host._primaryCapsuleFill, _emphasis)
    readonly property color _border: host._mixColor(host._secondaryCapsuleBorder, host._primaryCapsuleBorder, _emphasis)
    readonly property color _textColor: host._mixColor(Colors.textMuted, Colors.text, _emphasis)
    readonly property real _iconSize: host._lerp(host._compactIcon, host._primaryIcon, _emphasis)
    readonly property real _iconOpacity: host._lerp(0.4, 0.92, _emphasis)
    readonly property int _focusedIconIndex: host._focusedWorkspaceIconIndex(workspaceCapsule.capsule)
    readonly property real _iconStripSpacing: Math.max(2, Theme.barWidget.iconSpacing - 1)
    readonly property real _indicatorSize: workspaceCapsule._iconSize + Math.max(6, 8 * Theme.uiScale)
    readonly property real _indicatorOffset: (workspaceCapsule._indicatorSize - workspaceCapsule._iconSize) / 2
    readonly property real _indicatorStep: workspaceCapsule._iconSize + workspaceCapsule._iconStripSpacing
    readonly property bool _showFocusIndicator: workspaceCapsule._focusedIconIndex >= 0
        && workspaceCapsule._emphasis >= 0.45
        && workspaceCapsule.capsule
        && (workspaceCapsule.capsule.icons || []).length > 0
    readonly property color _indicatorColor: Qt.rgba(
        Colors.highlight.r,
        Colors.highlight.g,
        Colors.highlight.b,
        host._lerp(0.18, 0.34, workspaceCapsule._emphasis)
    )

    x: _metrics.x
    y: _metrics.y
    width: _metrics.width
    height: _metrics.height
    opacity: hiddenForMotion ? 0 : (forcedOpacity >= 0 ? forcedOpacity * _metrics.opacity : (capsule && capsule.visible ? _metrics.opacity : 0))
    visible: capsule !== null && opacity > 0

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: workspaceCapsule._fill
        border.width: 1
        border.color: workspaceCapsule._border
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: Theme.barWidget.badgePaddingH * 2
        anchors.rightMargin: Theme.barWidget.badgePaddingH * 2
        clip: true

        Row {
            anchors.centerIn: parent
            spacing: Theme.barWidget.badgePaddingH

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: workspaceCapsule.capsule && (workspaceCapsule.capsule.icons || []).length > 0
                    ? (workspaceCapsule.capsule.label || "")
                    : ""
                color: workspaceCapsule._textColor
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.bold: workspaceCapsule._emphasis >= 0.5
                verticalAlignment: Text.AlignVCenter
                visible: text !== ""
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: workspaceCapsule._iconStripSpacing

                Item {
                    implicitWidth: {
                        const iconCount = workspaceCapsule.capsule && workspaceCapsule.capsule.icons
                            ? workspaceCapsule.capsule.icons.length
                            : 0
                        if (iconCount <= 0)
                            return 0

                        return iconCount * workspaceCapsule._iconSize + Math.max(0, iconCount - 1) * workspaceCapsule._iconStripSpacing
                    }
                    implicitHeight: workspaceCapsule._indicatorSize
                    width: implicitWidth
                    height: implicitHeight
                    visible: width > 0

                    Rectangle {
                        y: (parent.height - height) / 2
                        width: workspaceCapsule._showFocusIndicator
                            ? Math.abs(focusIndexPair.idx1 - focusIndexPair.idx2) * workspaceCapsule._indicatorStep + workspaceCapsule._indicatorSize
                            : workspaceCapsule._indicatorSize
                        height: workspaceCapsule._indicatorSize
                        radius: height / 2
                        color: workspaceCapsule._indicatorColor
                        opacity: workspaceCapsule._showFocusIndicator ? 1 : 0
                        visible: opacity > 0
                        x: workspaceCapsule._showFocusIndicator
                            ? Math.min(focusIndexPair.idx1, focusIndexPair.idx2) * workspaceCapsule._indicatorStep - workspaceCapsule._indicatorOffset
                            : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.anim.moveDuration
                                easing.type: Theme.anim.moveType
                            }
                        }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: workspaceCapsule._iconStripSpacing

                        Repeater {
                            model: host._visibleWorkspaceIcons(workspaceCapsule.capsule)

                            delegate: Item {
                                required property var modelData

                                width: workspaceCapsule._iconSize
                                height: width
                                opacity: modelData.isFocused ? workspaceCapsule._iconOpacity : workspaceCapsule._iconOpacity * 0.78

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

                Text {
                    text: workspaceCapsule.capsule && (workspaceCapsule.capsule.icons || []).length === 0
                        ? host._workspaceLabel(workspaceCapsule.capsule.workspaceIndex)
                        : ""
                    color: Colors.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    verticalAlignment: Text.AlignVCenter
                    visible: text !== ""
                }
            }
        }
    }
}
