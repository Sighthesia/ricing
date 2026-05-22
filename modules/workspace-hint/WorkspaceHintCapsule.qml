import QtQuick
import Quickshell.Widgets
import "../../services" as Services
import "../../services/CapsuleMetrics.js" as CapsuleMetrics
import "WorkspaceHintCapsule.js" as Capsule

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
    readonly property real _outgoingHandoffProgress: root._isOutgoingPrimaryCapsule
        ? Math.max(0, Math.min(1, (0.18 - root._detailProgress) / 0.18))
        : 0
    readonly property bool _isOutgoingPrimaryCapsule: !!(
        host._workspaceSettlePending
        && host._transitionSourceHint
        && root.absoluteIndex === host._transitionSourceHint.activeWorkspacePosition
        && !(root.capsule && root.capsule.isCurrent)
    )
    readonly property bool _isPrimaryCapsule: !!(
        (root.capsule && (root.capsule.isCurrent || root.capsule.isTransitionCurrent))
        || root._isOutgoingPrimaryCapsule
    )
    readonly property var _activeWindows: root._isOutgoingPrimaryCapsule
        ? ((host._transitionSourceHint && host._transitionSourceHint.windows) || [])
        : ((root.capsule && root.capsule.icons) || [])
    readonly property int _activeWorkspaceIndex: root._isOutgoingPrimaryCapsule
        ? ((host._transitionSourceHint && host._transitionSourceHint.workspaceIndex) || -1)
        : (root.capsule ? root.capsule.workspaceIndex : -1)
    readonly property bool _isEmptyWorkspace: root._isPrimaryCapsule
        ? root._activeWindows.length === 0
        : (root.capsule && (root.capsule.icons || []).length === 0)
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
    readonly property bool providesPrimaryWidth: !!(root.capsule && root.capsule.isCurrent)
    readonly property real _maxCapsuleWidth: Math.max(
        root._metrics.height,
        host && host._workspaceCapsuleMaxWidth !== undefined ? host._workspaceCapsuleMaxWidth : 1
    )
    readonly property real _primaryHorizontalPadding: CapsuleMetrics.compactInnerHorizontal
    readonly property real _primaryOuterSpacing: CapsuleMetrics.groupGap
    readonly property real _primaryCardSpacing: CapsuleMetrics.inlineGap
    readonly property real _activeWorkspaceLabelWidth: primaryMeasureWorkspaceLabel.visible
        ? primaryMeasureWorkspaceLabel.implicitWidth
        : 0
    readonly property real preferredPrimaryWidth: Math.min(root._maxCapsuleWidth, root._naturalPrimaryWidth)
    readonly property int _cardCount: root._isPrimaryCapsule ? root._activeWindows.length : 0
    readonly property real _iconSize: 16 + (2 * root._emphasis)
    readonly property real _iconSpacing: 5
    readonly property int _visibleIconCount: root.capsule && root.capsule.icons ? root.capsule.icons.length : 0
    readonly property int _focusedIconIndex: {
        const items = root._isPrimaryCapsule ? root._activeWindows : ((root.capsule && root.capsule.icons) || [])
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

    readonly property real _naturalPrimaryWidth: {
        let width = root._primaryHorizontalPadding
        if (root._activeWorkspaceLabelWidth > 0)
            width += root._activeWorkspaceLabelWidth + root._primaryOuterSpacing

        for (let index = 0; index < root._cardCount; index++) {
            const item = primaryMeasureRepeater.itemAt(index)
            width += item ? item.naturalCardWidth : 56
            if (index < root._cardCount - 1)
                width += root._primaryCardSpacing
        }

        return Math.max(144, width)
    }

    // Shared title-width cap derived from the actual capsule width after clamping.
    readonly property real _cardTitleWidthCap: {
        if (root._cardCount <= 0)
            return Infinity

        const availableForRow = Math.max(
            0,
            root.width - root._primaryHorizontalPadding
                - (root._activeWorkspaceLabelWidth > 0 ? root._activeWorkspaceLabelWidth + root._primaryOuterSpacing : 0)
        )
        const titleWidths = []
        const baseWidths = []

        for (let index = 0; index < root._cardCount; index++) {
            const item = primaryMeasureRepeater.itemAt(index)
            titleWidths.push(item ? item.naturalTitleWidth : 24)
            baseWidths.push(item ? item.baseCardWidth : CapsuleMetrics.compactInnerHorizontal)
        }

        return Capsule.computeCardTitleWidthCap(
            titleWidths,
            baseWidths,
            availableForRow,
            root._primaryCardSpacing
        )
    }

    x: (host._workspaceStageWidth - width) / 2
    y: (-host._workspaceStageTargetY)
        + ((host._workspaceStageTargetY + root._metrics.y) * root._revealProgress)
    width: Math.min(
        root._maxCapsuleWidth,
        root._metrics.height + ((root._metrics.width - root._metrics.height) * root._revealProgress)
    )
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
            anchors.leftMargin: CapsuleMetrics.compactSidePadding
            anchors.rightMargin: CapsuleMetrics.compactSidePadding
            clip: true

            // Restore the focused workspace title-card row inside the primary capsule.
            Row {
                id: activeContent
                x: Math.max(0, (parent.width - implicitWidth) / 2)
                y: (parent.height - height) / 2
                spacing: CapsuleMetrics.groupGap
                opacity: root._isOutgoingPrimaryCapsule
                    ? (1 - root._outgoingHandoffProgress)
                    : (root._isPrimaryCapsule ? root._detailProgress : 0)
                visible: opacity > 0

                // Keep the active workspace number pinned to the left.
                Rectangle {
                    width: activeWorkspaceLabel.visible ? activeWorkspaceLabel.implicitWidth + CapsuleMetrics.compactInnerHorizontal : 0
                    height: 32
                    radius: height / 2
                    color: Qt.rgba(
                        Services.Color.mSurfaceVariant.r,
                        Services.Color.mSurfaceVariant.g,
                        Services.Color.mSurfaceVariant.b,
                        0.35
                    )

                    Text {
                        id: activeWorkspaceLabel
                        anchors.centerIn: parent

                        text: root._activeWorkspaceIndex > 0 ? String(root._activeWorkspaceIndex) : ""
                        color: Services.Color.mOnSurface
                        font.pixelSize: Services.TextSize.barContent
                        font.bold: true
                        visible: text !== ""
                    }
                }

                // Show all window titles for the focused workspace.
                Row {
                    id: windowTitleRow
                    spacing: CapsuleMetrics.inlineGap

                    Repeater {
                        model: root._isPrimaryCapsule ? root._activeWindows : []

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            readonly property real _cardProgress: root._detailProgress
                            readonly property real _collapsedCardWidth: modelData.icon ? 30 : 16
                            readonly property real _naturalTitleWidth: {
                                const measureItem = primaryMeasureRepeater.itemAt(index)
                                return measureItem ? measureItem.naturalTitleWidth : Math.max(24, Math.ceil(titleText.implicitWidth))
                            }
                            readonly property real _cardBaseWidth: (modelData.icon ? 21 : 0) + CapsuleMetrics.compactInnerHorizontal
                            readonly property real _expandedTitleWidth: Math.min(
                                root._cardTitleWidthCap,
                                _naturalTitleWidth
                            )
                            readonly property real _expandedCardWidth: _cardBaseWidth + _expandedTitleWidth

                            width: _collapsedCardWidth + ((_expandedCardWidth - _collapsedCardWidth) * _cardProgress)
                            height: 32
                            radius: height / 2
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
                                spacing: 6

                                // Show the window icon inside each title card.
                                Item {
                                    width: modelData.icon ? 16 : 0
                                    height: 16

                                    Behavior on width {
                                        NumberAnimation {
                                            duration: Services.Motion.number.contentDuration
                                            easing.type: Services.Motion.number.contentEasing
                                        }
                                    }

                                    IconImage {
                                        anchors.fill: parent
                                        source: modelData.icon || ""
                                        implicitSize: 16
                                        visible: parent.width > 0
                                    }
                                }

                                // Show one window title using the old elide rules.
                                Text {
                                    id: titleText

                                    text: modelData.title || ""
                                    font.pixelSize: Services.TextSize.barContent
                                    font.bold: modelData.isFocused
                                    color: modelData.isFocused
                                        ? Services.Color.mOnSurface
                                        : Services.Color.mOnSurfaceVariant
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    width: _expandedTitleWidth * root._detailProgress
                                    opacity: root._detailProgress
                                    visible: width > 0.5 || opacity > 0.01
                                }
                            }
                        }
                    }

                    // Preserve the empty focused-workspace fallback.
                    Text {
                        visible: root._isPrimaryCapsule && root._isEmptyWorkspace
                        text: "空工作区"
                        font.pixelSize: Services.TextSize.barContent
                        color: Services.Color.mOnSurfaceVariant
                        opacity: 0.5
                    }
                }
            }

                // Measure the focused workspace content with real implicit widths.
                Row {
                    id: primaryMeasureRow
                    visible: false
                    spacing: CapsuleMetrics.groupGap

                    Text {
                        id: primaryMeasureWorkspaceLabel

                        text: root._activeWorkspaceIndex > 0 ? String(root._activeWorkspaceIndex) : ""
                        font.pixelSize: Services.TextSize.barContent
                        font.bold: true
                        visible: text !== ""
                    }

                    Row {
                        spacing: CapsuleMetrics.inlineGap

                        Repeater {
                            id: primaryMeasureRepeater

                            model: root._activeWindows

                            delegate: Item {
                                required property var modelData

                                readonly property real naturalTitleWidth: Math.max(24, Math.ceil(measureTitleText.implicitWidth))
                                readonly property real baseCardWidth: (modelData.icon ? 21 : 0) + CapsuleMetrics.compactInnerHorizontal
                                readonly property real naturalCardWidth: baseCardWidth + naturalTitleWidth

                                implicitWidth: naturalCardWidth
                                implicitHeight: 32

                                Row {
                                    id: measureCardRow
                                    spacing: 6

                                    Item {
                                        width: modelData.icon ? 16 : 0
                                        height: 16
                                    }

                                    Text {
                                        id: measureTitleText

                                        text: modelData.title || ""
                                        font.pixelSize: Services.TextSize.barContent
                                    }
                                }
                            }
                        }

                        Text {
                            visible: root._isEmptyWorkspace
                            text: "空工作区"
                            font.pixelSize: Services.TextSize.barContent
                        }
                    }
                }

                // Keep neighbor workspaces compact with only number and icons.
                Row {
                    id: neighborContent
                    anchors.centerIn: parent
                    spacing: CapsuleMetrics.inlineGap
                    opacity: root._isOutgoingPrimaryCapsule
                        ? root._outgoingHandoffProgress
                        : (root._isPrimaryCapsule ? (1 - root._detailProgress) : 1)
                    visible: opacity > 0

                    // Show the workspace number as the capsule label.
                    Item {
                        width: neighborWorkspaceLabel.visible ? neighborWorkspaceLabel.implicitWidth : 0
                        height: root._iconSize + 10

                        Text {
                            id: neighborWorkspaceLabel
                            anchors.verticalCenter: parent.verticalCenter

                            text: root.capsule ? String(root.capsule.workspaceIndex) : ""
                            color: root._textColor
                            font.pixelSize: Services.TextSize.barContent
                            font.bold: root._emphasis >= 0.5
                            visible: text !== ""
                        }
                    }

                // Keep the workspace icon strip aligned like DymicShell's stage capsules.
                Item {
                    implicitWidth: root._visibleIconCount > 0
                        ? root._visibleIconCount * root._iconSize + Math.max(0, root._visibleIconCount - 1) * root._iconSpacing
                        : 0
                    implicitHeight: root._iconSize + 10
                    width: implicitWidth
                    height: implicitHeight
                    visible: width > 0

                    Rectangle {
                        width: root._iconSize + 10
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
                            ? root._focusedIconIndex * (root._iconSize + root._iconSpacing) - 5
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
                            model: root.capsule && root.capsule.icons ? root.capsule.icons : []

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
                    font.pixelSize: Services.TextSize.barContent
                    opacity: 0.75
                    visible: text !== "" && root._emphasis >= 0.35
                }
            }
        }
    }
}
