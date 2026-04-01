import QtQuick
import qs.config
import qs.services

// Renders the SuperIsland window hint with slot-driven workspace and title motion.
Item {
    id: root

    required property var event

    readonly property bool _hostKeepsHintVisible: !!(root.event && root.event.type === "window-hint")
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
    readonly property real _overflowSlotPosition: 1.18
    readonly property int _workspaceStageWidth: root._workspacePrimaryWidth
    readonly property int _workspaceStageHeight: root._workspaceSideHeight * 2 + root._workspacePrimaryHeight + root._workspaceColumnGap * 2
    readonly property int _titleStageWidth: root._titleSideWidth * 2 + root._titlePrimaryWidth + root._capsuleGap * 2
    readonly property int _titleStageHeight: root._titleCapsuleHeight
    readonly property var _workspaceStageCapsules: root._workspaceStageCapsulesForHint(root._hint)
    readonly property var _titleStageCapsules: root._titleStageCapsulesForHint(root._hint)
    readonly property int _workspaceAnchorBaseDuration: Math.max(150, Math.round(Theme.anim.moveDuration * 1.05))
    readonly property int _titleAnchorBaseDuration: Math.max(140, Theme.anim.moveDuration)
    readonly property int _anchorDurationStep: Math.max(16, Math.round(Theme.anim.moveDuration * 0.1))
    readonly property int _anchorMaximumDuration: Math.max(190, Math.round(Theme.anim.moveDuration * 1.35))

    property real _animatedWorkspaceAnchor: -1
    property real _animatedTitleAnchor: -1

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
            activeWorkspacePosition: hint.activeWorkspacePosition !== undefined ? hint.activeWorkspacePosition : -1,
            currentWindowId: hint.currentWindowId || "",
            currentWindowTitle: hint.currentWindowTitle || "",
            currentWindowIcon: hint.currentWindowIcon || "",
            currentIndex: hint.currentIndex !== undefined ? hint.currentIndex : -1,
            windows: hint.windows ? hint.windows.slice() : [],
            workspaces: hint.workspaces ? hint.workspaces.map(workspace => root._cloneWorkspaceSummary(workspace)) : [],
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
                visible: !!nextWorkspace && nextWorkspace.workspaceIndex > 0
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

    function _workspaceAnchorForHint(hint) {
        if (!hint || hint.visible !== true)
            return -1

        const position = hint.activeWorkspacePosition
        return position !== undefined && position >= 0 ? position : -1
    }

    function _titleAnchorForHint(hint) {
        if (!hint || hint.visible !== true)
            return -1

        const currentIndex = hint.currentIndex !== undefined ? hint.currentIndex : -1
        if (currentIndex >= 0)
            return currentIndex

        return (hint.windows || []).length > 0 ? 0 : 0
    }

    function _workspaceCapsuleForAbsolute(absoluteIndex, hint) {
        const safeHint = hint || {}
        const summaries = safeHint.workspaces || []
        const activePosition = root._workspaceAnchorForHint(safeHint)
        const summary = absoluteIndex >= 0 && absoluteIndex < summaries.length ? summaries[absoluteIndex] : null
        const isCurrent = absoluteIndex === activePosition
        const workspaceIndex = isCurrent
            ? (safeHint.workspaceIndex !== undefined ? safeHint.workspaceIndex : (summary ? summary.workspaceIndex : -1))
            : (summary ? summary.workspaceIndex : -1)

        return {
            key: (summary ? (summary.workspaceId || "workspace") : "workspace") + "-" + absoluteIndex,
            label: root._workspaceLabel(workspaceIndex),
            icons: isCurrent ? (safeHint.windows || []) : (summary && summary.icons ? summary.icons.slice() : []),
            visible: isCurrent || workspaceIndex > 0
        }
    }

    function _titleCapsuleForAbsolute(absoluteIndex, hint) {
        const safeHint = hint || {}
        const windows = safeHint.windows || []

        if (windows.length === 0 && absoluteIndex === 0) {
            return {
                key: "current-title-empty",
                title: safeHint.currentWindowTitle || "Window hint",
                icon: safeHint.currentWindowIcon || "",
                visible: true
            }
        }

        if (absoluteIndex < 0 || absoluteIndex >= windows.length) {
            return {
                key: "title-" + absoluteIndex,
                title: "",
                icon: "",
                visible: false
            }
        }

        const windowData = windows[absoluteIndex]
        const title = windowData ? (windowData.title || "") : ""
        return {
            key: (windowData ? (windowData.windowId || "window") : "window") + "-" + absoluteIndex,
            title: title,
            icon: windowData ? (windowData.icon || "") : "",
            visible: title !== "" || absoluteIndex === root._titleAnchorForHint(safeHint)
        }
    }

    function _visibleAbsoluteRange(anchor, length) {
        if (length <= 0)
            return ({ from: 0, to: -1 })

        const resolvedAnchor = anchor >= 0 ? anchor : 0
        return {
            from: Math.max(0, Math.floor(resolvedAnchor) - 2),
            to: Math.min(length - 1, Math.ceil(resolvedAnchor) + 2)
        }
    }

    function _workspaceStageCapsulesForHint(hint) {
        const safeHint = hint || {}
        const summaries = safeHint.workspaces || []
        const anchor = root._animatedWorkspaceAnchor >= 0 ? root._animatedWorkspaceAnchor : root._workspaceAnchorForHint(safeHint)
        const range = root._visibleAbsoluteRange(anchor, summaries.length)
        const items = []

        for (let index = range.from; index <= range.to; index++) {
            const capsule = root._workspaceCapsuleForAbsolute(index, safeHint)
            const slotPosition = index - anchor
            if (!capsule.visible || Math.abs(slotPosition) > 2)
                continue

            items.push({
                key: capsule.key,
                capsule: capsule,
                slotPosition: slotPosition
            })
        }

        return items
    }

    function _titleStageCapsulesForHint(hint) {
        const safeHint = hint || {}
        const windows = safeHint.windows || []
        const anchor = root._animatedTitleAnchor >= 0 ? root._animatedTitleAnchor : root._titleAnchorForHint(safeHint)
        const items = []

        if (windows.length === 0) {
            items.push({
                key: "current-title-empty",
                capsule: root._titleCapsuleForAbsolute(0, safeHint),
                slotPosition: 0
            })
            return items
        }

        const range = root._visibleAbsoluteRange(anchor, windows.length)
        for (let index = range.from; index <= range.to; index++) {
            const capsule = root._titleCapsuleForAbsolute(index, safeHint)
            const slotPosition = index - anchor
            if (!capsule.visible || Math.abs(slotPosition) > 2)
                continue

            items.push({
                key: capsule.key,
                capsule: capsule,
                slotPosition: slotPosition
            })
        }

        return items
    }

    function _anchorAnimationDuration(from, to, baseDuration) {
        const distance = Math.abs(to - from)
        if (distance <= 0.001)
            return 0

        return Math.min(
            root._anchorMaximumDuration,
            Math.round(baseDuration + Math.max(0, distance - 1) * root._anchorDurationStep)
        )
    }

    function _retargetWorkspaceAnchor(target, immediate) {
        _workspaceAnchorAnimation.stop()

        if (immediate || target < 0 || root._animatedWorkspaceAnchor < 0) {
            root._animatedWorkspaceAnchor = target
            return
        }

        const currentAnchor = root._animatedWorkspaceAnchor
        const duration = root._anchorAnimationDuration(currentAnchor, target, root._workspaceAnchorBaseDuration)
        if (duration === 0) {
            root._animatedWorkspaceAnchor = target
            return
        }

        _workspaceAnchorAnimation.from = currentAnchor
        _workspaceAnchorAnimation.to = target
        _workspaceAnchorAnimation.duration = duration
        _workspaceAnchorAnimation.start()
    }

    function _retargetTitleAnchor(target, immediate) {
        _titleAnchorAnimation.stop()

        if (immediate || target < 0 || root._animatedTitleAnchor < 0) {
            root._animatedTitleAnchor = target
            return
        }

        const currentAnchor = root._animatedTitleAnchor
        const duration = root._anchorAnimationDuration(currentAnchor, target, root._titleAnchorBaseDuration)
        if (duration === 0) {
            root._animatedTitleAnchor = target
            return
        }

        _titleAnchorAnimation.from = currentAnchor
        _titleAnchorAnimation.to = target
        _titleAnchorAnimation.duration = duration
        _titleAnchorAnimation.start()
    }

    function _retargetHintAnchors(hint, immediate) {
        root._retargetWorkspaceAnchor(root._workspaceAnchorForHint(hint), immediate)
        root._retargetTitleAnchor(root._titleAnchorForHint(hint), immediate)
    }

    function _visibleWorkspaceIcons(capsule, emphasis) {
        const icons = capsule && capsule.icons ? capsule.icons : []
        const limit = emphasis >= 0.5 ? 5 : 2
        return icons.slice(0, limit)
    }

    function _workspaceMetrics(slotPosition) {
        const topY = 0
        const centerY = root._workspaceSideHeight + root._workspaceColumnGap
        const bottomY = centerY + root._workspacePrimaryHeight + root._workspaceColumnGap

        if (slotPosition < -1) {
            const overflow = Math.min(1, -1 - slotPosition)
            return {
                x: (root._workspaceStageWidth - root._workspaceSideWidth) / 2,
                y: topY - overflow * (root._workspaceSideHeight + root._workspaceColumnGap),
                width: root._workspaceSideWidth,
                height: root._workspaceSideHeight,
                emphasis: 0,
                opacity: 0.45
            }
        }

        if (slotPosition > 1) {
            const overflow = Math.min(1, slotPosition - 1)
            return {
                x: (root._workspaceStageWidth - root._workspaceSideWidth) / 2,
                y: bottomY + overflow * (root._workspaceSideHeight + root._workspaceColumnGap),
                width: root._workspaceSideWidth,
                height: root._workspaceSideHeight,
                emphasis: 0,
                opacity: 0.45
            }
        }

        const clamped = Math.max(-1, Math.min(1, slotPosition))

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
        const leftX = 0
        const centerX = root._titleSideWidth + root._capsuleGap
        const rightX = centerX + root._titlePrimaryWidth + root._capsuleGap

        if (slotPosition < -1) {
            const overflow = Math.min(1, -1 - slotPosition)
            return {
                x: leftX - overflow * (root._titleSideWidth + root._capsuleGap),
                width: root._titleSideWidth,
                emphasis: 0,
                opacity: 0.68
            }
        }

        if (slotPosition > 1) {
            const overflow = Math.min(1, slotPosition - 1)
            return {
                x: rightX + overflow * (root._titleSideWidth + root._capsuleGap),
                width: root._titleSideWidth,
                emphasis: 0,
                opacity: 0.68
            }
        }

        const clamped = Math.max(-1, Math.min(1, slotPosition))

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

    function _handleHintChange() {
        const nextHint = root._cloneHint(root._liveHint)

        if (!nextHint || !nextHint.visible) {
            if (root._hostKeepsHintVisible && root._renderHint && root._renderHint.visible) {
                return
            }

            root._renderHint = nextHint
            root._retargetHintAnchors(nextHint, true)
            return
        }

        const wasVisible = !!(root._renderHint && root._renderHint.visible)
        root._renderHint = nextHint
        root._retargetHintAnchors(nextHint, !wasVisible)
    }

    // Workspace capsule visual.
    component WorkspaceCapsule: Item {
        id: workspaceCapsule

        required property var capsule
        required property real slotPosition
        property bool hiddenForMotion: false
        property real forcedOpacity: -1

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
        opacity: hiddenForMotion ? 0 : (forcedOpacity >= 0 ? forcedOpacity * _metrics.opacity : (capsule && capsule.visible ? _metrics.opacity : 0))
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
                        text: workspaceCapsule.capsule && (workspaceCapsule.capsule.icons || []).length === 0 ? "Empty" : ""
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
        property real forcedOpacity: -1

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
        opacity: hiddenForMotion ? 0 : (forcedOpacity >= 0 ? forcedOpacity * _metrics.opacity : (capsule && capsule.visible ? _metrics.opacity : 0))
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

    NumberAnimation {
        id: _workspaceAnchorAnimation

        target: root
        property: "_animatedWorkspaceAnchor"
        easing.type: Theme.anim.moveType
    }

    NumberAnimation {
        id: _titleAnchorAnimation

        target: root
        property: "_animatedTitleAnchor"
        easing.type: Theme.anim.moveType
    }

    Component.onCompleted: {
        root._renderHint = root._cloneHint(root._liveHint)
        root._retargetHintAnchors(root._renderHint, true)
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
                clip: true

                Repeater {
                    model: root._workspaceStageCapsules

                    delegate: WorkspaceCapsule {
                        required property var modelData

                        capsule: modelData.capsule
                        slotPosition: modelData.slotPosition
                        hiddenForMotion: false
                    }
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
                    model: root._titleStageCapsules

                    delegate: TitleCapsule {
                        required property var modelData

                        capsule: modelData.capsule
                        slotPosition: modelData.slotPosition
                        hiddenForMotion: false
                    }
                }
            }
        }
    }
}
