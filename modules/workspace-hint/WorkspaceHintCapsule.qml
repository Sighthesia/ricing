import QtQuick
import Quickshell.Widgets
import "../../services" as Services

// Render one workspace capsule using the shared slot-stage metrics.
Item {
    id: root

    required property var host
    required property var capsule
    required property real slotPosition
    required property int absoluteIndex

    readonly property var _metrics: host._workspaceMetricsForSlot(root.slotPosition, root.absoluteIndex)
    readonly property real _emphasis: root._metrics.emphasis
    readonly property real _revealProgress: host._stageRevealForSlot(root.slotPosition)
    readonly property real _detailProgress: Math.max(0, Math.min(1, (root._emphasis - 0.28) / 0.72))
    readonly property bool _isPrimaryCapsule: root.capsule && (root.capsule.isCurrent || root.capsule.isTransitionCurrent)
    readonly property bool _isEmptyWorkspace: root.capsule && (root.capsule.icons || []).length === 0
    readonly property real _visualEmphasis: root._isEmptyWorkspace
        ? Math.max(root._isPrimaryCapsule ? 0.56 : 0.42, root._emphasis)
        : Math.max(root._isPrimaryCapsule ? 0.74 : 0, root._emphasis)
    readonly property color _surfaceColor: root._isEmptyWorkspace
        ? Qt.rgba(
            Services.Color.mSurfaceVariant.r,
            Services.Color.mSurfaceVariant.g,
            Services.Color.mSurfaceVariant.b,
            0.34 + (0.24 * root._visualEmphasis)
        )
        : Qt.rgba(
            Services.Color.mSurface.r,
            Services.Color.mSurface.g,
            Services.Color.mSurface.b,
            0.72 + (0.2 * root._visualEmphasis)
        )
    readonly property color _outlineColor: Qt.rgba(
        Services.Color.mOutline.r,
        Services.Color.mOutline.g,
        Services.Color.mOutline.b,
        0.18 + (0.12 * root._visualEmphasis)
    )
    readonly property color _textColor: root._isEmptyWorkspace
        ? (root._isPrimaryCapsule ? Services.Color.mOnSurface : Services.Color.mOnSurfaceVariant)
        : Services.Color.mOnSurface
    readonly property real _capsuleOpacity: root._isEmptyWorkspace
        ? Math.max(root._metrics.opacity, 0.62)
        : root._metrics.opacity
    readonly property real _iconSize: 14 + (2 * root._emphasis)
    readonly property real _iconSpacing: 4
    readonly property int _visibleIconCount: Math.min(3, root.capsule && root.capsule.icons ? root.capsule.icons.length : 0)
    readonly property int _focusedIconIndex: {
        const items = root.capsule && root.capsule.icons ? root.capsule.icons : []
        for (let index = 0; index < items.length; index++) {
            if (items[index] && items[index].isFocused)
                return index
        }
        return -1
    }
    readonly property real visibleY: root.y < (-host._workspaceStageTargetY)
        ? (-host._workspaceStageTargetY)
        : root.y
    readonly property real _surfaceOffsetY: root.visibleY - root.y

    x: (host._workspaceStageWidth - width) / 2
    y: (-host._workspaceStageTargetY)
        + ((host._workspaceStageTargetY + root._metrics.y) * root._revealProgress)
    width: root._metrics.height + ((root._metrics.width - root._metrics.height) * root._revealProgress)
    height: root._metrics.height
    opacity: root.capsule && root.capsule.visible ? root._capsuleOpacity : 0
    visible: root.capsule !== null && opacity > 0
    clip: false

    Behavior on opacity {
        enabled: !host._workspaceSettlePending

        NumberAnimation {
            duration: host._workspaceCapsuleOpacityDuration
            easing.type: Services.Motion.number.surfaceEasing
        }
    }

    // Keep the visible capsule surface attached to the stage even near the top edge.
    Rectangle {
        id: surface

        x: 0
        y: root._surfaceOffsetY
        width: root.width
        height: root.height
        radius: height / 2
        color: root._surfaceColor
        border.color: root._outlineColor
        border.width: 1
        antialiasing: true

        // Center the workspace label and icon strip inside the capsule.
        Item {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            clip: true

            // Restore the focused workspace title-card row inside the primary capsule.
            Row {
                id: activeContent
                anchors.centerIn: parent
                spacing: 8
                opacity: root._isPrimaryCapsule ? root._detailProgress : 0
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Services.Motion.number.shortDuration
                        easing.type: Services.Motion.number.shortEasing
                    }
                }

                // Keep the active workspace number pinned to the left.
                Text {
                    text: root.capsule ? String(root.capsule.workspaceIndex) : ""
                    color: Services.Color.mOnSurface
                    font.pixelSize: 12
                    font.bold: true
                    visible: text !== ""
                }

                // Show all window titles for the focused workspace.
                Row {
                    id: windowTitleRow
                    spacing: 6

                    Repeater {
                        model: root._isPrimaryCapsule && root.capsule && root.capsule.icons ? root.capsule.icons : []

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            readonly property real _cardProgress: root._detailProgress
                            readonly property real _collapsedCardWidth: modelData.icon ? 28 : 14
                            readonly property real _expandedTitleWidth: Math.min(titleText.implicitWidth, 140)
                            readonly property real _expandedCardWidth: Math.max(
                                _expandedTitleWidth + (modelData.icon ? 19 : 0) + (modelData.isFocused ? 11 : 0) + 24,
                                100
                            )

                            width: _collapsedCardWidth + ((_expandedCardWidth - _collapsedCardWidth) * _cardProgress)
                            height: 28
                            radius: 8
                            color: modelData.isFocused
                                ? Qt.rgba(
                                    Services.Color.mPrimary.r,
                                    Services.Color.mPrimary.g,
                                    Services.Color.mPrimary.b,
                                    0.18
                                )
                                : Qt.rgba(
                                    Services.Color.mSurfaceVariant.r,
                                    Services.Color.mSurfaceVariant.g,
                                    Services.Color.mSurfaceVariant.b,
                                    0.35
                                )

                            Behavior on width {
                                NumberAnimation {
                                    duration: Services.Motion.number.contentDuration
                                    easing.type: Services.Motion.number.contentEasing
                                }
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: Services.Motion.number.shortDuration
                                    easing.type: Services.Motion.number.shortEasing
                                }
                            }

                            // Keep the focus dot and title aligned like the original hint.
                            Row {
                                id: winCardRow
                                anchors.centerIn: parent
                                spacing: 5

                                // Show the window icon inside each title card.
                                Item {
                                    width: modelData.icon ? 14 : 0
                                    height: 14

                                    Behavior on width {
                                        NumberAnimation {
                                            duration: Services.Motion.number.contentDuration
                                            easing.type: Services.Motion.number.contentEasing
                                        }
                                    }

                                    IconImage {
                                        anchors.fill: parent
                                        source: modelData.icon || ""
                                        implicitSize: 14
                                        visible: parent.width > 0
                                    }
                                }

                                // Mark the focused window card.
                                Rectangle {
                                    width: 5
                                    height: 5
                                    radius: 2.5
                                    color: Services.Color.mPrimary
                                    opacity: modelData.isFocused ? root._detailProgress : 0
                                    visible: opacity > 0

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: Services.Motion.number.shortDuration
                                            easing.type: Services.Motion.number.shortEasing
                                        }
                                    }
                                }

                                // Show one window title using the old elide rules.
                                Text {
                                    id: titleText

                                    text: modelData.title || ""
                                    font.pixelSize: 11
                                    font.bold: modelData.isFocused
                                    color: modelData.isFocused
                                        ? Services.Color.mOnSurface
                                        : Services.Color.mOnSurfaceVariant
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    width: _expandedTitleWidth * root._detailProgress
                                    opacity: root._detailProgress
                                    visible: width > 0.5 || opacity > 0.01

                                    Behavior on width {
                                        NumberAnimation {
                                            duration: Services.Motion.number.contentDuration
                                            easing.type: Services.Motion.number.contentEasing
                                        }
                                    }
                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: Services.Motion.number.shortDuration
                                            easing.type: Services.Motion.number.shortEasing
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Preserve the empty focused-workspace fallback.
                    Text {
                        visible: root._isPrimaryCapsule && root._isEmptyWorkspace
                        text: "空工作区"
                        font.pixelSize: 12
                        color: Services.Color.mOnSurfaceVariant
                        opacity: 0.5
                    }
                }
            }

            // Keep neighbor workspaces compact with only number and icons.
            Row {
                id: neighborContent
                anchors.centerIn: parent
                spacing: 6
                opacity: root._isPrimaryCapsule ? (1 - root._detailProgress) : 1
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Services.Motion.number.shortDuration
                        easing.type: Services.Motion.number.shortEasing
                    }
                }

                // Show the workspace number as the capsule label.
                Text {
                    text: root.capsule ? String(root.capsule.workspaceIndex) : ""
                    color: root._textColor
                    font.pixelSize: 12
                    font.bold: root._emphasis >= 0.5
                    visible: text !== ""
                }

                // Keep the workspace icon strip aligned like DymicShell's stage capsules.
                Item {
                    implicitWidth: root._visibleIconCount > 0
                        ? root._visibleIconCount * root._iconSize + Math.max(0, root._visibleIconCount - 1) * root._iconSpacing
                        : 0
                    implicitHeight: root._iconSize + 8
                    width: implicitWidth
                    height: implicitHeight
                    visible: width > 0

                    Rectangle {
                        width: root._iconSize + 8
                        height: width
                        radius: height / 2
                        color: Qt.rgba(
                            Services.Color.mPrimary.r,
                            Services.Color.mPrimary.g,
                            Services.Color.mPrimary.b,
                            0.18 + (0.12 * root._emphasis)
                        )
                        opacity: root._focusedIconIndex >= 0 ? 1 : 0
                        visible: opacity > 0
                        x: root._focusedIconIndex >= 0
                            ? root._focusedIconIndex * (root._iconSize + root._iconSpacing) - 4
                            : 0
                        y: (parent.height - height) / 2

                        Behavior on x {
                            NumberAnimation {
                                duration: Services.Motion.number.contentDuration
                                easing.type: Services.Motion.number.contentEasing
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Services.Motion.number.shortDuration
                                easing.type: Services.Motion.number.shortEasing
                            }
                        }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: root._iconSpacing

                        Repeater {
                            model: root.capsule && root.capsule.icons ? root.capsule.icons.slice(0, 3) : []

                            delegate: Item {
                                required property var modelData

                                width: root._iconSize
                                height: root._iconSize
                                opacity: modelData.isFocused ? 0.96 : (0.58 + (0.24 * root._emphasis))

                                IconImage {
                                    anchors.fill: parent
                                    source: modelData.icon || ""
                                    implicitSize: root._iconSize
                                }
                            }
                        }
                    }
                }

                // Keep empty workspaces readable even without window icons.
                Text {
                    text: root._isEmptyWorkspace ? "空工作区" : ""
                    color: Services.Color.mOnSurfaceVariant
                    font.pixelSize: 11
                    opacity: 0.75
                    visible: text !== "" && root._emphasis >= 0.35
                }
            }
        }
    }
}
