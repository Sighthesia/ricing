import QtQuick
import qs.config
import qs.services

// Renders the SuperIsland window hint with slot-driven workspace and title motion.
Item {
    id: root

    required property var event

    readonly property var _liveHint: WindowHintService.activeHint
    property var _renderHint: null
    readonly property var _hint: root._renderHint || root._liveHint
    readonly property int _padH: Theme.barWidget.contentPaddingH
    readonly property int _padV: Theme.barWidget.contentPaddingV
    readonly property int _rowGap: Math.max(10, Math.round(12 * Theme.uiScale))
    readonly property int _capsuleGap: Math.max(4, Math.round(5 * Theme.uiScale))
    readonly property int _workspaceColumnGap: Math.max(10, Math.round(12 * Theme.uiScale))
    readonly property int _stagePadH: Math.max(14, Math.round(18 * Theme.uiScale))
    readonly property int _stagePadV: Math.max(14, Math.round(18 * Theme.uiScale))
    readonly property int _compactIcon: Math.max(10, Theme.barWidget.compactIconSize - 1)
    readonly property int _primaryIcon: Theme.barWidget.primaryIconSize
    readonly property int _workspaceSideWidth: Math.round(164 * Theme.uiScale)
    readonly property int _workspacePrimaryWidth: Math.round(300 * Theme.uiScale)
    readonly property int _titleSideWidth: Math.round(132 * Theme.uiScale)
    readonly property int _titlePrimaryWidth: Math.round(292 * Theme.uiScale)
    readonly property int _workspaceSideHeight: Math.max(24, Theme.barWidget.pillHeight + Theme.barWidget.contentPaddingV)
    readonly property int _workspacePrimaryHeight: Math.max(54, Theme.barWidget.pillHeight + Theme.barWidget.contentPaddingV * 7)
    readonly property int _titleCapsuleHeight: Math.max(30, Theme.fontSizeBody + Theme.barWidget.badgePaddingV * 6)
    readonly property int _minPreviewWidth: Math.round(320 * Theme.uiScale)
    readonly property int _maxPreviewWidth: Math.round(560 * Theme.uiScale)
    readonly property color _stageFill: Qt.rgba(1, 1, 1, 0.02)
    readonly property color _stageBorder: Qt.rgba(1, 1, 1, 0.035)
    readonly property color _primaryCapsuleFill: Qt.rgba(1, 1, 1, 0.09)
    readonly property color _secondaryCapsuleFill: Qt.rgba(1, 1, 1, 0.04)
    readonly property color _primaryCapsuleBorder: Qt.rgba(1, 1, 1, 0.08)
    readonly property color _secondaryCapsuleBorder: Qt.rgba(1, 1, 1, 0.03)
    readonly property var _slotIndices: [-1, 0, 1]
    readonly property int _workspaceStageWidth: root._workspacePrimaryWidth
    readonly property int _workspaceStageHeight: root._workspaceSideHeight * 2 + root._workspacePrimaryHeight + root._workspaceColumnGap * 2
    readonly property int _titleStageWidth: root._titleSideWidth * 2 + root._titlePrimaryWidth + root._capsuleGap * 2
    readonly property int _titleStageHeight: root._titleCapsuleHeight
    readonly property var _previousWorkspaceCapsule: root._workspaceCapsuleForRelative(-1, root._hint)
    readonly property var _currentWorkspaceCapsule: root._workspaceCapsuleForRelative(0, root._hint)
    readonly property var _nextWorkspaceCapsule: root._workspaceCapsuleForRelative(1, root._hint)
    readonly property var _previousTitleCapsule: root._titleCapsuleForRelative(-1, root._hint)
    readonly property var _currentTitleCapsule: root._titleCapsuleForRelative(0, root._hint)
    readonly property var _nextTitleCapsule: root._titleCapsuleForRelative(1, root._hint)

    property var _lastHintSnapshot: null

    property bool _workspaceMotionActive: false
    property int _workspaceMotionDirection: 0
    property real _workspaceOutgoingSlotPosition: 0
    property real _workspaceIncomingSlotPosition: 0
    property var _workspaceOutgoingCapsule: null
    property var _workspaceIncomingCapsule: null

    property bool _titleMotionActive: false
    property int _titleMotionDirection: 0
    property real _titleOutgoingSlotPosition: 0
    property real _titleIncomingSlotPosition: 0
    property var _titleOutgoingCapsule: null
    property var _titleIncomingCapsule: null

    implicitWidth: Math.min(
        root._maxPreviewWidth,
        Math.max(
            root._minPreviewWidth,
            Math.max(root._workspaceStageWidth, root._titleStageWidth) + root._padH * 2 + root._stagePadH * 2
        )
    )
    implicitHeight: root._workspaceStageHeight + root._rowGap + root._titleStageHeight + root._padV * 2 + root._stagePadV * 2

    function _lerp(from, to, progress) {
        return from + (to - from) * progress
    }

    function _mixColor(from, to, progress) {
        return Qt.rgba(
            root._lerp(from.r, to.r, progress),
            root._lerp(from.g, to.g, progress),
            root._lerp(from.b, to.b, progress),
            root._lerp(from.a, to.a, progress)
        )
    }

    function _workspaceLabel(index) {
        if (index <= 0)
            return ""

        return "WS " + index
    }

    function _cloneWindowData(windowData) {
        return {
            windowId: windowData ? (windowData.windowId || "") : "",
            title: windowData ? (windowData.title || "") : "",
            icon: windowData ? (windowData.icon || "") : "",
            isFocused: windowData ? !!windowData.isFocused : false
        }
    }

    function _cloneWorkspaceSummary(summary) {
        return {
            workspaceId: summary ? (summary.workspaceId || "") : "",
            workspaceIndex: summary ? (summary.workspaceIndex || -1) : -1,
            icons: summary && summary.icons ? summary.icons.slice() : []
        }
    }

    function _cloneHint(hint) {
        if (!hint)
            return null

        return {
            visible: hint.visible === true,
            workspaceId: hint.workspaceId || "",
            workspaceIndex: hint.workspaceIndex !== undefined ? hint.workspaceIndex : -1,
            currentWindowId: hint.currentWindowId || "",
            currentWindowTitle: hint.currentWindowTitle || "",
            currentWindowIcon: hint.currentWindowIcon || "",
            currentIndex: hint.currentIndex !== undefined ? hint.currentIndex : -1,
            windows: hint.windows ? hint.windows.slice() : [],
            previousWindow: root._cloneWindowData(hint.previousWindow),
            nextWindow: root._cloneWindowData(hint.nextWindow),
            previousWorkspace: root._cloneWorkspaceSummary(hint.previousWorkspace),
            nextWorkspace: root._cloneWorkspaceSummary(hint.nextWorkspace)
        }
    }

    function _cloneWorkspaceCapsule(capsule) {
        if (!capsule)
            return null

        return {
            key: capsule.key || "",
            label: capsule.label || "",
            icons: (capsule.icons || []).slice(),
            visible: capsule.visible !== false
        }
    }

    function _cloneTitleCapsule(capsule) {
        if (!capsule)
            return null

        return {
            key: capsule.key || "",
            title: capsule.title || "",
            icon: capsule.icon || "",
            visible: capsule.visible !== false
        }
    }

    function _workspaceCapsuleForRelative(relativeSlot, hint) {
        const safeHint = hint || {}

        if (relativeSlot < 0) {
            const previousWorkspace = safeHint.previousWorkspace || null
            const icons = previousWorkspace ? (previousWorkspace.icons || []) : []
            return {
                key: "previous-workspace",
                label: root._workspaceLabel(previousWorkspace ? previousWorkspace.workspaceIndex : -1),
                icons: icons,
                visible: !!previousWorkspace && previousWorkspace.workspaceIndex > 0 && icons.length > 0
            }
        }

        if (relativeSlot > 0) {
            const nextWorkspace = safeHint.nextWorkspace || null
            const icons = nextWorkspace ? (nextWorkspace.icons || []) : []
            return {
                key: "next-workspace",
                label: root._workspaceLabel(nextWorkspace ? nextWorkspace.workspaceIndex : -1),
                icons: icons,
                visible: !!nextWorkspace && nextWorkspace.workspaceIndex > 0 && icons.length > 0
            }
        }

        return {
            key: "current-workspace",
            label: root._workspaceLabel(safeHint.workspaceIndex !== undefined ? safeHint.workspaceIndex : -1),
            icons: safeHint.windows || [],
            visible: true
        }
    }

    function _titleCapsuleForRelative(relativeSlot, hint) {
        const safeHint = hint || {}

        if (relativeSlot < 0) {
            const previousWindow = safeHint.previousWindow || null
            return {
                key: "previous-title",
                title: previousWindow ? (previousWindow.title || "") : "",
                icon: previousWindow ? (previousWindow.icon || "") : "",
                visible: !!previousWindow && (previousWindow.title || "") !== ""
            }
        }

        if (relativeSlot > 0) {
            const nextWindow = safeHint.nextWindow || null
            return {
                key: "next-title",
                title: nextWindow ? (nextWindow.title || "") : "",
                icon: nextWindow ? (nextWindow.icon || "") : "",
                visible: !!nextWindow && (nextWindow.title || "") !== ""
            }
        }

        return {
            key: "current-title",
            title: safeHint.currentWindowTitle || "Window hint",
            icon: safeHint.currentWindowIcon || "",
            visible: true
        }
    }

    function _visibleWorkspaceIcons(capsule, emphasis) {
        const icons = capsule && capsule.icons ? capsule.icons : []
        const limit = emphasis >= 0.5 ? 5 : 2
        return icons.slice(0, limit)
    }

    function _workspaceMetrics(slotPosition) {
        const clamped = Math.max(-1, Math.min(1, slotPosition))
        const topY = 0
        const centerY = root._workspaceSideHeight + root._workspaceColumnGap
        const bottomY = centerY + root._workspacePrimaryHeight + root._workspaceColumnGap

        if (clamped <= 0) {
            const progress = clamped + 1
            const width = root._lerp(root._workspaceSideWidth, root._workspacePrimaryWidth, progress)
            return {
                x: (root._workspaceStageWidth - width) / 2,
                y: root._lerp(topY, centerY, progress),
                width: width,
                height: root._lerp(root._workspaceSideHeight, root._workspacePrimaryHeight, progress),
                emphasis: progress,
                opacity: root._lerp(0.5, 1, progress)
            }
        }

        const progress = clamped
        const width = root._lerp(root._workspacePrimaryWidth, root._workspaceSideWidth, progress)
        return {
            x: (root._workspaceStageWidth - width) / 2,
            y: root._lerp(centerY, bottomY, progress),
            width: width,
            height: root._lerp(root._workspacePrimaryHeight, root._workspaceSideHeight, progress),
            emphasis: 1 - progress,
            opacity: root._lerp(1, 0.5, progress)
        }
    }

    function _titleMetrics(slotPosition) {
        const clamped = Math.max(-1, Math.min(1, slotPosition))
        const leftX = 0
        const centerX = root._titleSideWidth + root._capsuleGap
        const rightX = centerX + root._titlePrimaryWidth + root._capsuleGap

        if (clamped <= 0) {
            const progress = clamped + 1
            return {
                x: root._lerp(leftX, centerX, progress),
                width: root._lerp(root._titleSideWidth, root._titlePrimaryWidth, progress),
                emphasis: progress,
                opacity: root._lerp(0.68, 1, progress)
            }
        }

        const progress = clamped
        return {
            x: root._lerp(centerX, rightX, progress),
            width: root._lerp(root._titlePrimaryWidth, root._titleSideWidth, progress),
            emphasis: 1 - progress,
            opacity: root._lerp(1, 0.68, progress)
        }
    }

    function _workspaceDirection(previousHint, nextHint) {
        if (!previousHint || !nextHint)
            return 0

        if ((previousHint.workspaceId || "") === (nextHint.workspaceId || "")) {
            if (previousHint.workspaceIndex !== nextHint.workspaceIndex)
                return nextHint.workspaceIndex > previousHint.workspaceIndex ? 1 : -1

            return 0
        }

        if ((nextHint.workspaceId || "") !== "") {
            if ((previousHint.nextWorkspace ? previousHint.nextWorkspace.workspaceId : "") === nextHint.workspaceId)
                return 1
            if ((previousHint.previousWorkspace ? previousHint.previousWorkspace.workspaceId : "") === nextHint.workspaceId)
                return -1
        }

        if (previousHint.workspaceIndex !== nextHint.workspaceIndex)
            return nextHint.workspaceIndex > previousHint.workspaceIndex ? 1 : -1

        return 0
    }

    function _titleDirection(previousHint, nextHint) {
        if (!previousHint || !nextHint)
            return 0

        if ((previousHint.workspaceId || "") !== (nextHint.workspaceId || ""))
            return root._workspaceDirection(previousHint, nextHint)

        if ((previousHint.currentWindowId || "") === (nextHint.currentWindowId || ""))
            return 0

        if ((nextHint.currentWindowId || "") !== "") {
            if ((previousHint.nextWindow ? previousHint.nextWindow.windowId : "") === nextHint.currentWindowId)
                return 1
            if ((previousHint.previousWindow ? previousHint.previousWindow.windowId : "") === nextHint.currentWindowId)
                return -1
        }

        if ((previousHint.workspaceId || "") === (nextHint.workspaceId || "")
                && previousHint.currentIndex !== nextHint.currentIndex) {
            return nextHint.currentIndex > previousHint.currentIndex ? 1 : -1
        }

        return 0
    }

    function _workspaceBaseSlotHidden(slot) {
        return root._workspaceMotionActive && (slot === 0 || slot === -root._workspaceMotionDirection)
    }

    function _titleBaseSlotHidden(slot) {
        return root._titleMotionActive && (slot === 0 || slot === -root._titleMotionDirection)
    }

    function _clearWorkspaceTransition() {
        _workspaceMotion.stop()
        root._workspaceMotionActive = false
        root._workspaceMotionDirection = 0
        root._workspaceOutgoingSlotPosition = 0
        root._workspaceIncomingSlotPosition = 0
        root._workspaceOutgoingCapsule = null
        root._workspaceIncomingCapsule = null
    }

    function _clearTitleTransition() {
        _titleMotion.stop()
        root._titleMotionActive = false
        root._titleMotionDirection = 0
        root._titleOutgoingSlotPosition = 0
        root._titleIncomingSlotPosition = 0
        root._titleOutgoingCapsule = null
        root._titleIncomingCapsule = null
    }

    function _startWorkspaceTransition(direction) {
        const previousHint = root._lastHintSnapshot
        const nextHint = root._hint

        if (direction === 0 || !previousHint || !nextHint) {
            return
        }

        const outgoingCapsule = root._cloneWorkspaceCapsule(root._workspaceCapsuleForRelative(0, previousHint))
        const incomingCapsule = root._cloneWorkspaceCapsule(root._workspaceCapsuleForRelative(0, nextHint))

        if (!outgoingCapsule || !outgoingCapsule.visible || !incomingCapsule || !incomingCapsule.visible) {
            root._clearWorkspaceTransition()
            return
        }

        _workspaceMotion.stop()
        root._workspaceMotionActive = true
        root._workspaceMotionDirection = direction
        root._workspaceOutgoingCapsule = outgoingCapsule
        root._workspaceIncomingCapsule = incomingCapsule
        root._workspaceOutgoingSlotPosition = 0
        root._workspaceIncomingSlotPosition = direction
        _workspaceOutgoingSlotAnim.from = 0
        _workspaceOutgoingSlotAnim.to = -direction
        _workspaceIncomingSlotAnim.from = direction
        _workspaceIncomingSlotAnim.to = 0
        _workspaceMotion.start()
    }

    function _startTitleTransition(direction) {
        const previousHint = root._lastHintSnapshot
        const nextHint = root._hint

        if (direction === 0 || !previousHint || !nextHint) {
            root._clearTitleTransition()
            return
        }

        const outgoingCapsule = root._cloneTitleCapsule(root._titleCapsuleForRelative(0, previousHint))
        const incomingCapsule = root._cloneTitleCapsule(root._titleCapsuleForRelative(0, nextHint))

        if (!outgoingCapsule || !outgoingCapsule.visible || !incomingCapsule || !incomingCapsule.visible) {
            root._clearTitleTransition()
            return
        }

        _titleMotion.stop()
        root._titleMotionActive = true
        root._titleMotionDirection = direction
        root._titleOutgoingCapsule = outgoingCapsule
        root._titleIncomingCapsule = incomingCapsule
        root._titleOutgoingSlotPosition = 0
        root._titleIncomingSlotPosition = direction
        _titleOutgoingSlotAnim.from = 0
        _titleOutgoingSlotAnim.to = -direction
        _titleIncomingSlotAnim.from = direction
        _titleIncomingSlotAnim.to = 0
        _titleMotion.start()
    }

    function _syncSnapshots(hint) {
        root._lastHintSnapshot = root._cloneHint(hint || root._hint)
    }

    function _handleHintChange() {
        const nextHint = root._cloneHint(root._liveHint)

        if (!nextHint || !nextHint.visible) {
            root._clearWorkspaceTransition()
            root._clearTitleTransition()
            return
        }

        const previousHint = root._lastHintSnapshot
        const workspaceDirection = root._workspaceDirection(previousHint, nextHint)
        const titleDirection = root._titleDirection(previousHint, nextHint)

        root._renderHint = nextHint
        root._startWorkspaceTransition(workspaceDirection)
        root._startTitleTransition(titleDirection)
        root._syncSnapshots(nextHint)
    }

    // Workspace capsule visual.
    component WorkspaceCapsule: Item {
        id: workspaceCapsule

        required property var capsule
        required property real slotPosition
        property bool hiddenForMotion: false

        readonly property var _metrics: root._workspaceMetrics(workspaceCapsule.slotPosition)
        readonly property real _emphasis: _metrics.emphasis
        readonly property color _fill: root._mixColor(root._secondaryCapsuleFill, root._primaryCapsuleFill, _emphasis)
        readonly property color _border: root._mixColor(root._secondaryCapsuleBorder, root._primaryCapsuleBorder, _emphasis)
        readonly property color _textColor: root._mixColor(Colors.textMuted, Colors.text, _emphasis)
        readonly property int _iconSize: Math.round(root._lerp(root._compactIcon, root._primaryIcon, _emphasis))
        readonly property real _iconOpacity: root._lerp(0.4, 0.92, _emphasis)
        readonly property bool _trailingLabel: workspaceCapsule.slotPosition > 0.25

        x: _metrics.x
        y: _metrics.y
        width: _metrics.width
        height: _metrics.height
        opacity: hiddenForMotion ? 0 : (capsule && capsule.visible ? _metrics.opacity : 0)
        visible: capsule !== null && opacity > 0

        // Capsule surface.
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: workspaceCapsule._fill
            border.width: 1
            border.color: workspaceCapsule._border
        }

        // Capsule content clip.
        Item {
            anchors.fill: parent
            anchors.leftMargin: Theme.barWidget.badgePaddingH * 2
            anchors.rightMargin: Theme.barWidget.badgePaddingH * 2
            clip: true

            // Capsule content row.
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.barWidget.badgePaddingH

                // Leading workspace label.
                Text {
                    text: !workspaceCapsule._trailingLabel && workspaceCapsule.capsule ? (workspaceCapsule.capsule.label || "") : ""
                    color: workspaceCapsule._textColor
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: workspaceCapsule._emphasis >= 0.5
                    verticalAlignment: Text.AlignVCenter
                    visible: text !== ""
                }

                // Workspace icon strip.
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Math.max(2, Theme.barWidget.iconSpacing - 1)

                    Repeater {
                        model: root._visibleWorkspaceIcons(workspaceCapsule.capsule, workspaceCapsule._emphasis)

                        // Workspace icon item.
                        delegate: Item {
                            required property var modelData

                            width: workspaceCapsule._iconSize
                            height: width
                            opacity: modelData.isFocused ? workspaceCapsule._iconOpacity : workspaceCapsule._iconOpacity * 0.78

                            // Workspace icon.
                            Image {
                                anchors.fill: parent
                                source: modelData.icon || ""
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }
                        }
                    }

                    // Empty workspace label.
                    Text {
                        text: workspaceCapsule.capsule && (workspaceCapsule.capsule.icons || []).length === 0 && workspaceCapsule._emphasis >= 0.5 ? "Empty" : ""
                        color: Colors.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        verticalAlignment: Text.AlignVCenter
                        visible: text !== ""
                    }
                }

                // Trailing workspace label.
                Text {
                    text: workspaceCapsule._trailingLabel && workspaceCapsule.capsule ? (workspaceCapsule.capsule.label || "") : ""
                    color: workspaceCapsule._textColor
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: workspaceCapsule._emphasis >= 0.5
                    verticalAlignment: Text.AlignVCenter
                    visible: text !== ""
                }
            }
        }
    }

    // Title capsule visual.
    component TitleCapsule: Item {
        id: titleCapsule

        required property var capsule
        required property real slotPosition
        property bool hiddenForMotion: false

        readonly property var _metrics: root._titleMetrics(titleCapsule.slotPosition)
        readonly property real _emphasis: _metrics.emphasis
        readonly property color _fill: root._mixColor(root._secondaryCapsuleFill, root._primaryCapsuleFill, _emphasis)
        readonly property color _border: root._mixColor(root._secondaryCapsuleBorder, root._primaryCapsuleBorder, _emphasis)
        readonly property color _textColor: root._mixColor(Colors.textMuted, Colors.text, _emphasis)
        readonly property real _iconOpacity: root._lerp(0.68, 0.92, _emphasis)
        readonly property int _iconSize: Math.round(root._lerp(Math.max(10, root._compactIcon - 1), root._compactIcon, _emphasis))
        readonly property int _elideMode: titleCapsule.slotPosition > 0.25 ? Text.ElideLeft : Text.ElideRight
        readonly property int _horizontalAlignment: titleCapsule.slotPosition > 0.25 ? Text.AlignRight : Text.AlignLeft

        x: _metrics.x
        y: 0
        width: _metrics.width
        height: root._titleCapsuleHeight
        opacity: hiddenForMotion ? 0 : (capsule && capsule.visible ? _metrics.opacity : 0)
        visible: capsule !== null && opacity > 0

        // Capsule surface.
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: titleCapsule._fill
            border.width: 1
            border.color: titleCapsule._border
        }

        // Capsule content clip.
        Item {
            anchors.fill: parent
            anchors.leftMargin: Theme.barWidget.badgePaddingH * 2
            anchors.rightMargin: Theme.barWidget.badgePaddingH * 2
            clip: true

            // Capsule content row.
            Row {
                id: _titleContentRow

                anchors.fill: parent
                spacing: Theme.barWidget.badgePaddingH

                // Title icon.
                Image {
                    id: _titleIcon

                    anchors.verticalCenter: parent.verticalCenter
                    width: titleCapsule._iconSize
                    height: width
                    source: titleCapsule.capsule ? (titleCapsule.capsule.icon || "") : ""
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    visible: source !== ""
                    opacity: titleCapsule._iconOpacity
                }

                // Title text.
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, _titleContentRow.width - (_titleIcon.visible ? _titleIcon.width + _titleContentRow.spacing : 0))
                    text: titleCapsule.capsule ? (titleCapsule.capsule.title || "") : ""
                    color: titleCapsule._textColor
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: titleCapsule._emphasis >= 0.5
                    elide: titleCapsule._elideMode
                    maximumLineCount: 1
                    horizontalAlignment: titleCapsule._horizontalAlignment
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    Connections {
        target: WindowHintService

        function onActiveHintChanged() {
            root._handleHintChange()
        }
    }

    ParallelAnimation {
        id: _workspaceMotion

        NumberAnimation {
            id: _workspaceOutgoingSlotAnim
            target: root
            property: "_workspaceOutgoingSlotPosition"
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            id: _workspaceIncomingSlotAnim
            target: root
            property: "_workspaceIncomingSlotPosition"
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        onFinished: root._clearWorkspaceTransition()
    }

    ParallelAnimation {
        id: _titleMotion

        NumberAnimation {
            id: _titleOutgoingSlotAnim
            target: root
            property: "_titleOutgoingSlotPosition"
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        NumberAnimation {
            id: _titleIncomingSlotAnim
            target: root
            property: "_titleIncomingSlotPosition"
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }

        onFinished: root._clearTitleTransition()
    }

    Component.onCompleted: {
        root._renderHint = root._cloneHint(root._liveHint)
        root._syncSnapshots(root._renderHint)
    }

    // Shared stage ties both capsule rows together.
    Rectangle {
        anchors.centerIn: parent
        z: -1
        width: Math.max(root._workspaceStageWidth, root._titleStageWidth) + root._stagePadH * 2
        height: root._workspaceStageHeight + root._rowGap + root._titleStageHeight + root._stagePadV * 2
        radius: Math.min(Math.round(height / 2), Math.round(Theme.cornerRadius * 3 * Theme.uiScale))
        color: root._stageFill
        border.width: 1
        border.color: root._stageBorder
    }

    // Main capsule stack.
    Column {
        anchors.centerIn: parent
        width: Math.max(root._workspaceStageWidth, root._titleStageWidth)
        spacing: root._rowGap

        // Workspace stage wrapper.
        Item {
            width: parent.width
            height: root._workspaceStageHeight

            // Workspace slot stage.
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: root._workspaceStageWidth
                height: parent.height

                Repeater {
                    model: root._slotIndices

                    delegate: WorkspaceCapsule {
                        required property var modelData

                        capsule: root._workspaceCapsuleForRelative(modelData, root._hint)
                        slotPosition: modelData
                        hiddenForMotion: root._workspaceBaseSlotHidden(modelData)
                    }
                }

                // Outgoing workspace snapshot.
                WorkspaceCapsule {
                    z: 1
                    capsule: root._workspaceOutgoingCapsule
                    slotPosition: root._workspaceOutgoingSlotPosition
                    hiddenForMotion: false
                }

                // Incoming workspace snapshot.
                WorkspaceCapsule {
                    z: 2
                    capsule: root._workspaceIncomingCapsule
                    slotPosition: root._workspaceIncomingSlotPosition
                    hiddenForMotion: false
                }
            }
        }

        // Title stage wrapper.
        Item {
            width: parent.width
            height: root._titleStageHeight

            // Title slot stage.
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: root._titleStageWidth
                height: parent.height

                Repeater {
                    model: root._slotIndices

                    delegate: TitleCapsule {
                        required property var modelData

                        capsule: root._titleCapsuleForRelative(modelData, root._hint)
                        slotPosition: modelData
                        hiddenForMotion: root._titleBaseSlotHidden(modelData)
                    }
                }

                // Outgoing title snapshot.
                TitleCapsule {
                    z: 1
                    capsule: root._titleOutgoingCapsule
                    slotPosition: root._titleOutgoingSlotPosition
                    hiddenForMotion: false
                }

                // Incoming title snapshot.
                TitleCapsule {
                    z: 2
                    capsule: root._titleIncomingCapsule
                    slotPosition: root._titleIncomingSlotPosition
                    hiddenForMotion: false
                }
            }
        }
    }
}
