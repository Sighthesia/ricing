import QtQuick
import Quickshell.Widgets
import "../common" as Common
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
    readonly property bool blurActive: !!(
        root.capsule
        && root.capsule.isCurrent
        && !root.capsule.isTransitionCurrent
        && !host._workspaceSettlePending
        && root._detailProgress >= 0.999
        && root._revealProgress >= 0.999
    )
    readonly property Item blurSourceItem: surface.blurSourceItem
    readonly property bool providesPrimaryWidth: !!(root.capsule && root.capsule.isCurrent)
    readonly property real _maxCapsuleWidth: Math.max(
        root._metrics.height,
        host && host._workspaceCapsuleMaxWidth !== undefined ? host._workspaceCapsuleMaxWidth : 1
    )
    readonly property real _primaryHorizontalPadding: CapsuleMetrics.compactInnerHorizontal
    readonly property real _primaryOuterSpacing: CapsuleMetrics.groupGap
    readonly property real _primaryCardSpacing: CapsuleMetrics.inlineGap
    readonly property real _primaryTrailingPadding: CapsuleMetrics.compactSidePadding
    readonly property real _activeWorkspaceLabelWidth: activeWorkspaceLabel.text !== ""
        ? Math.ceil(activeWorkspaceLabel.implicitWidth) + CapsuleMetrics.compactInnerHorizontal
        : 0
    readonly property real _workspaceAreaMinWidth: {
        const labelWidth = root._activeWorkspaceLabelWidth > 0
            ? root._activeWorkspaceLabelWidth + root._primaryOuterSpacing
            : 0
        const titleAreaWidth = labelWidth + root._primaryTrailingPadding
        const workspaceMaxSideWidth = host && host._workspaceMaxSideWidth !== undefined
            ? host._workspaceMaxSideWidth
            : 1
        const workspaceAreaWidth = workspaceMaxSideWidth
            + root._primaryOuterSpacing
            + root._primaryTrailingPadding

        return Math.max(titleAreaWidth, workspaceAreaWidth)
    }
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
    readonly property real _collapsedDiameter: root._metrics.height
    readonly property real _screenStartY: -host._workspaceStageScreenY - (root._collapsedDiameter / 2)
    readonly property real _targetY: root._metrics.y
    readonly property real _targetWidth: Math.min(
        root._maxCapsuleWidth,
        Math.max(root._workspaceAreaMinWidth, root._metrics.width)
    )
    readonly property real _enterOpacityFactor: Math.max(0, Math.min(1, root._revealProgress / 0.08))
    readonly property real _exitOpacityFactor: Math.max(0, Math.min(1, root._revealProgress / 0.6))
    readonly property real _revealOpacityFactor: host._stageExiting ? root._exitOpacityFactor : root._enterOpacityFactor
    readonly property real visibleY: root.y < root._screenStartY
        ? root._screenStartY
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

        width += root._primaryTrailingPadding

        return Math.max(144, width)
    }

    // Shared title-width cap derived from the actual capsule width after clamping.
    readonly property real _cardTitleWidthCap: {
        if (root._cardCount <= 0)
            return Infinity

        const availableForRow = Math.max(
            0,
            root.width - root._primaryHorizontalPadding
                - root._primaryTrailingPadding
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
            root._primaryCardSpacing,
            root._focusedIconIndex
        )
    }

    x: (host._workspaceStageWidth - width) / 2
    y: root._screenStartY + ((root._targetY - root._screenStartY) * root._revealProgress)
    width: root._collapsedDiameter + ((root._targetWidth - root._collapsedDiameter) * root._revealProgress)
    height: root._metrics.height
    opacity: root.capsule && root.capsule.visible ? root._capsuleOpacity * root._revealOpacityFactor : 0
    visible: root.capsule !== null && opacity > 0
    clip: false

    Behavior on opacity {
        enabled: false

        NumberAnimation {
            duration: host._workspaceCapsuleOpacityDuration
            easing.type: Services.Motion.number.surfaceEasing
        }
    }

    // Keep the visible capsule surface attached to the stage even near the top edge.
        Common.GlassCapsule {
            id: surface

        x: 0
        y: root._surfaceOffsetY
        width: root.width
        height: root.height
        radius: height / 2
        surfaceColor: root._surfaceColor
        outlineColor: root._outlineColor
        borderWidth: 1
        clipContent: true

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
                    width: activeWorkspaceLabel.visible ? root._activeWorkspaceLabelWidth : 0
                    height: 32
                    radius: height / 2
                    color: Qt.rgba(
                        Services.Color.mSurfaceVariant.r,
                        Services.Color.mSurfaceVariant.g,
                        Services.Color.mSurfaceVariant.b,
                        0.35
                    )

                    Services.FluidText {
                        id: activeWorkspaceLabel
                        anchors.centerIn: parent

                        text: root._activeWorkspaceIndex > 0 ? String(root._activeWorkspaceIndex) : ""
                        color: Services.Color.mPrimary
                        font.bold: true
                        visible: text !== ""
                    }
                }

                // Host the moving focus indicator and the title cards in one layer.
                Item {
                    id: windowTitleRow

                    property real focusedIndicatorX: 0
                    property real focusedIndicatorY: 0
                    property real focusedIndicatorWidth: 0
                    property real focusedIndicatorHeight: 32
                    property bool focusedIndicatorVisible: false

                    function syncFocusedIndicatorGeometry() {
                        for (let index = 0; index < titleCardRepeater.count; index++) {
                            const item = titleCardRepeater.itemAt(index)
                            if (!item || !item.isFocusedCard)
                                continue

                            focusedIndicatorX = item.x
                            focusedIndicatorY = item.y
                            focusedIndicatorWidth = item.width
                            focusedIndicatorHeight = item.height
                            focusedIndicatorVisible = root._detailProgress > 0.01
                            return
                        }

                        focusedIndicatorVisible = false
                    }

                    width: titleCardContent.implicitWidth
                    height: Math.max(titleCardContent.implicitHeight, 32)

                    onWidthChanged: focusedIndicatorSync.restart()
                    onHeightChanged: focusedIndicatorSync.restart()

                    // Resample on first reveal and on focus changes too: card
                    // delegates may not exist yet when the row first sizes, so
                    // width/height alone miss the initial focused-card geometry
                    // (indicator otherwise appears only after a workspace switch).
                    readonly property real _revealDetail: root._detailProgress
                    readonly property int _focusedCard: root._focusedIconIndex
                    on_RevealDetailChanged: focusedIndicatorSync.restart()
                    on_FocusedCardChanged: focusedIndicatorSync.restart()

                    // Defer geometry sampling until the row layout has settled.
                    Timer {
                        id: focusedIndicatorSync

                        interval: 0
                        repeat: false
                        onTriggered: windowTitleRow.syncFocusedIndicatorGeometry()
                    }

                    // Track both card edges at two speeds so the rectangle stretches
                    // toward travel direction regardless of left/right movement.
                    Item {
                        id: focusedEdgeTracker

                        readonly property real _targetLeft: windowTitleRow.focusedIndicatorX
                        readonly property real _targetRight: windowTitleRow.focusedIndicatorX + windowTitleRow.focusedIndicatorWidth

                        // Fast pair snaps to the target; slow pair lags to form the trail.
                        property real leftFast: _targetLeft
                        property real leftSlow: _targetLeft
                        property real rightFast: _targetRight
                        property real rightSlow: _targetRight

                        // Rectangle spans the outermost of each pair, so it is direction-symmetric.
                        readonly property real rectLeft: Math.min(leftFast, leftSlow)
                        readonly property real rectRight: Math.max(rightFast, rightSlow)

                        Behavior on leftFast {
                            NumberAnimation {
                                duration: Services.Motion.number.contentDuration
                                easing.type: Easing.OutSine
                            }
                        }

                        Behavior on rightFast {
                            NumberAnimation {
                                duration: Services.Motion.number.contentDuration
                                easing.type: Easing.OutSine
                            }
                        }

                        Behavior on leftSlow {
                            NumberAnimation {
                                duration: Services.Motion.number.contentDuration + 60
                                easing.type: Easing.OutSine
                            }
                        }

                        Behavior on rightSlow {
                            NumberAnimation {
                                duration: Services.Motion.number.contentDuration + 60
                                easing.type: Easing.OutSine
        }
    }
}

                    // Single persistent highlight; trail comes from edge desync, not a second layer.
                    Rectangle {
                        id: focusedTitleIndicator

                        x: focusedEdgeTracker.rectLeft
                        y: windowTitleRow.focusedIndicatorY
                        width: Math.max(0, focusedEdgeTracker.rectRight - focusedEdgeTracker.rectLeft)
                        height: windowTitleRow.focusedIndicatorHeight
                        radius: height / 2
                        color: Qt.rgba(
                            Services.Color.mPrimary.r,
                            Services.Color.mPrimary.g,
                            Services.Color.mPrimary.b,
                            0.28 + (0.12 * root._detailProgress)
                        )
                        border.width: 0
                        opacity: windowTitleRow.focusedIndicatorVisible ? 1 : 0
                        visible: opacity > 0
                        z: 1
                        antialiasing: true

                        Behavior on y {
                            NumberAnimation {
                                duration: Services.Motion.number.contentDuration + 40
                                easing.type: Services.Motion.number.contentEasing
                            }
                        }

                        Behavior on height {
                            NumberAnimation {
                                duration: Services.Motion.number.contentDuration + 60
                                easing.type: Services.Motion.number.contentEasing
                            }
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Services.Motion.number.shortDuration
                                easing.type: Services.Motion.number.shortEasing
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Services.Motion.number.shortDuration
                                easing.type: Services.Motion.number.shortEasing
                            }
                        }
                    }

                    // Keep the title-card row geometry stable above the moving indicator.
                    Row {
                        id: titleCardContent

                        spacing: CapsuleMetrics.inlineGap
                        z: 2

                        Repeater {
                            id: titleCardRepeater

                            // Use a stable count as the model (not the array
                            // itself) so a focus change — which rebuilds the
                            // _activeWindows array but keeps the same window
                            // count — updates each delegate's bindings in place
                            // instead of destroying and recreating every card.
                            // Recreation reset card x to 0 and made the focus
                            // indicator jump to the left and lag a step behind.
                            model: root._isPrimaryCapsule ? root._activeWindows.length : 0

                            delegate: Rectangle {
                                required property int index
                                readonly property var modelData: (root._activeWindows && index >= 0 && index < root._activeWindows.length)
                                    ? root._activeWindows[index]
                                    : ({})
                                property bool isFocusedCard: !!modelData.isFocused

                                readonly property real _cardProgress: root._detailProgress
                                readonly property real _collapsedCardWidth: modelData.icon ? 30 : 16
                                readonly property real _naturalTitleWidth: {
                                    const measureItem = primaryMeasureRepeater.itemAt(index)
                                    return measureItem ? measureItem.naturalTitleWidth : Math.max(24, Math.ceil(titleText.implicitWidth))
                                }
                                readonly property real _cardBaseWidth: (modelData.icon ? 21 : 0) + CapsuleMetrics.compactInnerHorizontal
                                // Focused card keeps its full natural title;
                                // non-focused cards yield to the shared cap so
                                // the row fits within the clamped capsule width.
                                readonly property real _expandedTitleWidth: isFocusedCard
                                    ? _naturalTitleWidth
                                    : Math.min(
                                        root._cardTitleWidthCap,
                                        _naturalTitleWidth
                                )
                                readonly property real _expandedCardWidth: _cardBaseWidth + _expandedTitleWidth

                                width: _collapsedCardWidth + ((_expandedCardWidth - _collapsedCardWidth) * _cardProgress)
                                height: 32
                                radius: height / 2
                                color: modelData.isFocused
                                    ? "transparent"
                                    : Qt.rgba(
                                        Services.Color.mSurfaceVariant.r,
                                        Services.Color.mSurfaceVariant.g,
                                        Services.Color.mSurfaceVariant.b,
                                        0.35
                                    )
                                border.width: modelData.isFocused ? 0 : 1
                                border.color: Qt.rgba(
                                    Services.Color.mOutline.r,
                                    Services.Color.mOutline.g,
                                    Services.Color.mOutline.b,
                                    0.08 + (0.06 * root._detailProgress)
                                )
                                z: 1

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Services.Motion.number.shortDuration
                                        easing.type: Services.Motion.number.shortEasing
                                    }
                                }

                                Behavior on border.width {
                                    NumberAnimation {
                                        duration: Services.Motion.number.shortDuration
                                        easing.type: Services.Motion.number.shortEasing
                                    }
                                }

                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: Services.Motion.number.shortDuration
                                        easing.type: Services.Motion.number.shortEasing
                                    }
                                }

                                // Push this card's geometry to the indicator
                                // directly when focused, instead of the indicator
                                // imperatively scanning itemAt() (which returns
                                // stale geometry on the first focus switch). This
                                // is the same imperative-lookup pitfall that made
                                // the stage width unstable.
                                function _pushFocusGeometryIfFocused() {
                                    if (!isFocusedCard)
                                        return
                                    windowTitleRow.focusedIndicatorX = x
                                    windowTitleRow.focusedIndicatorY = y
                                    windowTitleRow.focusedIndicatorWidth = width
                                    windowTitleRow.focusedIndicatorHeight = height
                                    windowTitleRow.focusedIndicatorVisible = root._detailProgress > 0.01
                                }
                                onIsFocusedCardChanged: {
                                    if (isFocusedCard)
                                        _pushFocusGeometryIfFocused()
                                    else
                                        focusedIndicatorSync.restart()
                                }
                                onXChanged: _pushFocusGeometryIfFocused()
                                onYChanged: _pushFocusGeometryIfFocused()
                                onWidthChanged: _pushFocusGeometryIfFocused()
                                onHeightChanged: _pushFocusGeometryIfFocused()
                                Component.onCompleted: _pushFocusGeometryIfFocused()

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
                                    Services.FluidText {
                                        id: titleText

                                        text: modelData.title || ""
                                        font.bold: false
                                        color: modelData.isFocused
                                            ? Services.Color.mOnSurface
                                            : Services.Color.mOnSurfaceVariant
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        width: _expandedTitleWidth * root._detailProgress
                                        opacity: root._detailProgress
                                        visible: width > 0.5 || opacity > 0.01

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: Services.Motion.number.shortDuration
                                                easing.type: Services.Motion.number.shortEasing
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Keep the trailing content padding inside the measured row.
                        Item {
                            width: root._primaryTrailingPadding
                            height: 1
                            visible: width > 0
                        }

                        // Preserve the empty focused-workspace fallback.
                        Services.FluidText {
                            visible: root._isPrimaryCapsule && root._isEmptyWorkspace
                            text: "空工作区"
                            color: Services.Color.mOnSurfaceVariant
                            opacity: 0.5
                        }
                    }
                }
            }

                // Measure the focused workspace content with real implicit widths.
                Row {
                    id: primaryMeasureRow
                    visible: false
                    spacing: CapsuleMetrics.groupGap

                    Services.FluidText {
                        id: primaryMeasureWorkspaceLabel

                        text: root._activeWorkspaceIndex > 0 ? String(root._activeWorkspaceIndex) : ""
                        font.bold: true
                        visible: text !== ""
                    }

                    Row {
                        spacing: CapsuleMetrics.inlineGap

                        Repeater {
                            id: primaryMeasureRepeater

                            // Stable count model (see titleCardRepeater) so a
                            // focus change reuses delegates instead of
                            // rebuilding the measurement items.
                            model: root._activeWindows ? root._activeWindows.length : 0

                            delegate: Item {
                                required property int index
                                readonly property var modelData: (root._activeWindows && index >= 0 && index < root._activeWindows.length)
                                    ? root._activeWindows[index]
                                    : ({})

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

                                    Services.FluidText {
                                        id: measureTitleText

                                        text: modelData.title || ""
                                    }
                                }
                            }
                        }

                        Services.FluidText {
                            visible: root._isEmptyWorkspace
                            text: "空工作区"
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

                        Services.FluidText {
                            id: neighborWorkspaceLabel
                            anchors.verticalCenter: parent.verticalCenter

                            text: root.capsule ? String(root.capsule.workspaceIndex) : ""
                            color: root._textColor
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
                Services.FluidText {
                    text: root._isEmptyWorkspace ? "空工作区" : ""
                    color: Services.Color.mOnSurfaceVariant
                    opacity: 0.75
                    visible: text !== "" && root._emphasis >= 0.35
                }
            }
        }

    }
}
