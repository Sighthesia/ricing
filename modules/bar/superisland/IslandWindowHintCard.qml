import Quickshell
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
    readonly property int _headerHeight: Theme.barWidget.pillHeight
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
    readonly property var _persistentStageSlotIndices: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    readonly property int _workspaceAnchorBaseDuration: Math.max(150, Math.round(Theme.anim.moveDuration * 1.05))
    readonly property int _titleAnchorBaseDuration: Math.max(140, Theme.anim.moveDuration)
    readonly property int _anchorDurationStep: Math.max(16, Math.round(Theme.anim.moveDuration * 0.1))
    readonly property int _anchorMaximumDuration: Math.max(190, Math.round(Theme.anim.moveDuration * 1.35))
    readonly property int _workspaceFocusLeadDuration: Math.max(70, Math.round(Theme.anim.moveDuration * 0.42))
    readonly property int _workspaceFocusTrailDuration: Math.max(240, Math.round(Theme.anim.moveDuration * 1.45))

    property real _animatedWorkspaceAnchor: -1
    property real _animatedTitleAnchor: -1
    property bool _workspaceSettlePending: false
    property bool _titleSettlePending: false
    // Inspired by end-4/dots-hyprland ("illogical impulse") workspace indicator motion.
    // Reference: https://github.com/end-4/dots-hyprland/blob/main/dots/.config/quickshell/ii/modules/ii/bar/Workspaces.qml
    property int _workspaceFocusIndex: -1
    property var _workspaceStageSlots: root._emptyStageSlots("workspace-slot")
    property var _titleStageSlots: root._emptyStageSlots("title-slot")

    implicitWidth: Math.min(
        root._maxPreviewWidth,
        Math.max(
            root._minPreviewWidth,
            Math.max(root._workspaceStageWidth, root._titleStageWidth) + root._padH * 2 + root._stagePadH * 2
        )
    )
    implicitHeight: root._headerHeight + root._workspaceStageHeight + root._rowGap + root._titleStageHeight + root._padV * 2 + root._stagePadV * 2

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
            workspaceIndex: capsule.workspaceIndex !== undefined ? capsule.workspaceIndex : -1,
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

    function _emptyStageSlots(prefix) {
        const slots = []

        for (let index = 0; index < root._persistentStageSlotIndices.length; index++) {
            slots.push({
                slotId: prefix + "-" + index,
                absoluteIndex: -1,
                workspaceIndex: -1,
                capsule: null
            })
        }

        return slots
    }

    function _cloneStageSlot(slot, cloneCapsule, slotId) {
        return {
            slotId: slot ? (slot.slotId || slotId) : slotId,
            absoluteIndex: slot && slot.absoluteIndex !== undefined ? slot.absoluteIndex : -1,
            workspaceIndex: slot && slot.workspaceIndex !== undefined ? slot.workspaceIndex : -1,
            capsule: cloneCapsule(slot ? slot.capsule : null)
        }
    }

    function _stageSlotsFrom(currentSlots, cloneCapsule, prefix) {
        const slots = []

        for (let index = 0; index < root._persistentStageSlotIndices.length; index++) {
            const slotId = prefix + "-" + index
            const currentSlot = currentSlots && index < currentSlots.length ? currentSlots[index] : null
            slots.push(root._cloneStageSlot(currentSlot, cloneCapsule, slotId))
        }

        return slots
    }

    function _slotsForEntries(currentSlots, entries, cloneCapsule, prefix, preserveUnassigned) {
        const current = root._stageSlotsFrom(currentSlots, cloneCapsule, prefix)
        const slots = root._emptyStageSlots(prefix)
        const assignedSlots = ({})

        for (let entryIndex = 0; entryIndex < Math.min(slots.length, entries.length); entryIndex++) {
            const entry = entries[entryIndex]
            let slotIndex = -1

            for (let index = 0; index < current.length; index++) {
                if (assignedSlots[index])
                    continue
                if (current[index].absoluteIndex !== entry.absoluteIndex)
                    continue

                slotIndex = index
                break
            }

            if (slotIndex < 0) {
                for (let index = 0; index < current.length; index++) {
                    if (assignedSlots[index])
                        continue
                    if (current[index].absoluteIndex >= 0)
                        continue

                    slotIndex = index
                    break
                }
            }

            if (slotIndex < 0) {
                for (let index = 0; index < current.length; index++) {
                    if (assignedSlots[index])
                        continue

                    slotIndex = index
                    break
                }
            }

            if (slotIndex < 0)
                break

            assignedSlots[slotIndex] = true
            slots[slotIndex] = {
                slotId: current[slotIndex].slotId,
                absoluteIndex: entry.absoluteIndex,
                workspaceIndex: entry.capsule && entry.capsule.workspaceIndex !== undefined
                    ? entry.capsule.workspaceIndex
                    : entry.absoluteIndex,
                capsule: cloneCapsule(entry.capsule)
            }
        }

        if (preserveUnassigned) {
            for (let index = 0; index < current.length; index++) {
                if (assignedSlots[index])
                    continue
                if (current[index].absoluteIndex < 0 || !current[index].capsule)
                    continue

                slots[index] = root._cloneStageSlot(current[index], cloneCapsule, current[index].slotId)
            }
        }

        return slots
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
            workspaceIndex: workspaceIndex,
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

    function _visibleAbsoluteIndices(anchor, length) {
        const range = root._visibleAbsoluteRange(anchor, length)
        const items = []

        for (let index = range.from; index <= range.to; index++)
            items.push(index)

        return items
    }

    function _mergedVisibleAbsoluteIndices(currentAnchor, targetAnchor, length) {
        const items = []
        const seen = ({})
        const targetRange = root._visibleAbsoluteRange(targetAnchor, length)
        const currentRange = root._visibleAbsoluteRange(currentAnchor, length)

        for (let index = targetRange.from; index <= targetRange.to; index++) {
            if (index < 0 || index >= length || seen[index])
                continue

            seen[index] = true
            items.push(index)
        }

        for (let index = currentRange.from; index <= currentRange.to; index++) {
            if (index < 0 || index >= length || seen[index])
                continue

            seen[index] = true
            items.push(index)
        }

        items.sort((left, right) => left - right)
        return items
    }

    function _workspaceStageCapsulesForHint(hint, includeCurrentAnchor) {
        const safeHint = hint || {}
        const summaries = safeHint.workspaces || []
        const anchor = root._workspaceAnchorForHint(safeHint)
        const indices = includeCurrentAnchor
            ? root._mergedVisibleAbsoluteIndices(root._animatedWorkspaceAnchor, anchor, summaries.length)
            : root._visibleAbsoluteIndices(anchor, summaries.length)
        const items = []

        for (let listIndex = 0; listIndex < indices.length; listIndex++) {
            const index = indices[listIndex]
            const capsule = root._workspaceCapsuleForAbsolute(index, safeHint)
            if (!capsule.visible)
                continue

            items.push({
                key: capsule.key,
                capsule: capsule,
                absoluteIndex: index
            })
        }

        return items
    }

    function _titleStageCapsulesForHint(hint, includeCurrentAnchor) {
        const safeHint = hint || {}
        const windows = safeHint.windows || []
        const anchor = root._titleAnchorForHint(safeHint)
        const items = []

        if (windows.length === 0) {
            items.push({
                key: "current-title-empty",
                capsule: root._titleCapsuleForAbsolute(0, safeHint),
                absoluteIndex: 0
            })
            return items
        }

        const indices = includeCurrentAnchor
            ? root._mergedVisibleAbsoluteIndices(root._animatedTitleAnchor, anchor, windows.length)
            : root._visibleAbsoluteIndices(anchor, windows.length)
        for (let listIndex = 0; listIndex < indices.length; listIndex++) {
            const index = indices[listIndex]
            const capsule = root._titleCapsuleForAbsolute(index, safeHint)
            if (!capsule.visible)
                continue

            items.push({
                key: capsule.key,
                capsule: capsule,
                absoluteIndex: index
            })
        }

        return items
    }

    function _workspaceStageSlotAt(slotIndex) {
        return slotIndex >= 0 && slotIndex < root._workspaceStageSlots.length
            ? root._workspaceStageSlots[slotIndex]
            : null
    }

    function _titleStageSlotAt(slotIndex) {
        return slotIndex >= 0 && slotIndex < root._titleStageSlots.length
            ? root._titleStageSlots[slotIndex]
            : null
    }

    function _workspaceStageCapsuleAt(slotIndex) {
        const slot = root._workspaceStageSlotAt(slotIndex)
        return slot ? slot.capsule : null
    }

    function _titleStageCapsuleAt(slotIndex) {
        const slot = root._titleStageSlotAt(slotIndex)
        return slot ? slot.capsule : null
    }

    function _workspaceStageSlotPositionAt(slotIndex) {
        const slot = root._workspaceStageSlotAt(slotIndex)
        if (!slot || slot.absoluteIndex < 0 || root._animatedWorkspaceAnchor < 0)
            return root._overflowSlotPosition

        return slot.absoluteIndex - root._animatedWorkspaceAnchor
    }

    function _titleStageSlotPositionAt(slotIndex) {
        const slot = root._titleStageSlotAt(slotIndex)
        if (!slot || slot.absoluteIndex < 0 || root._animatedTitleAnchor < 0)
            return root._overflowSlotPosition

        return slot.absoluteIndex - root._animatedTitleAnchor
    }

    function _refreshStageSlots(hint, includeCurrentAnchor, preserveUnassigned) {
        root._workspaceStageSlots = root._slotsForEntries(
            root._workspaceStageSlots,
            root._workspaceStageCapsulesForHint(hint, includeCurrentAnchor),
            root._cloneWorkspaceCapsule,
            "workspace-slot",
            preserveUnassigned
        )
        root._titleStageSlots = root._slotsForEntries(
            root._titleStageSlots,
            root._titleStageCapsulesForHint(hint, includeCurrentAnchor),
            root._cloneTitleCapsule,
            "title-slot",
            preserveUnassigned
        )
    }

    function _settleWorkspaceStageSlots(hint) {
        root._workspaceStageSlots = root._slotsForEntries(
            root._workspaceStageSlots,
            root._workspaceStageCapsulesForHint(hint, false),
            root._cloneWorkspaceCapsule,
            "workspace-slot",
            false
        )
    }

    function _settleTitleStageSlots(hint) {
        root._titleStageSlots = root._slotsForEntries(
            root._titleStageSlots,
            root._titleStageCapsulesForHint(hint, false),
            root._cloneTitleCapsule,
            "title-slot",
            false
        )
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
        root._workspaceSettlePending = false
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
        root._workspaceSettlePending = true
        _workspaceAnchorAnimation.start()
    }

    function _retargetTitleAnchor(target, immediate) {
        root._titleSettlePending = false
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
        root._titleSettlePending = true
        _titleAnchorAnimation.start()
    }

    function _retargetHintAnchors(hint, immediate) {
        root._retargetWorkspaceAnchor(root._workspaceAnchorForHint(hint), immediate)
        root._retargetTitleAnchor(root._titleAnchorForHint(hint), immediate)
        root._retargetWorkspaceFocusIndicator(hint, immediate)
    }

    function _visibleWorkspaceIcons(capsule, emphasis) {
        const icons = capsule && capsule.icons ? capsule.icons : []
        return icons
    }

    function _focusedWorkspaceIconIndex(capsule) {
        const icons = capsule && capsule.icons ? capsule.icons : []

        for (let index = 0; index < icons.length; index++) {
            if (icons[index] && icons[index].isFocused)
                return index
        }

        return -1
    }

    function _focusedWorkspaceIconIndexForHint(hint) {
        const windows = hint && hint.windows ? hint.windows : []

        for (let index = 0; index < windows.length; index++) {
            if (windows[index] && windows[index].isFocused)
                return index
        }

        return -1
    }

    function _retargetWorkspaceFocusIndicator(hint, immediate) {
        const focusedIndex = root._focusedWorkspaceIconIndexForHint(hint)
        root._workspaceFocusIndex = focusedIndex
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
            root._refreshStageSlots(nextHint, false, false)
            root._retargetHintAnchors(nextHint, true)
            return
        }

        const wasVisible = !!(root._renderHint && root._renderHint.visible)
        root._renderHint = nextHint
        root._refreshStageSlots(nextHint, wasVisible, wasVisible)
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
        readonly property int _focusedIconIndex: root._focusedWorkspaceIconIndex(workspaceCapsule.capsule)
        readonly property real _iconStripSpacing: Math.max(2, Theme.barWidget.iconSpacing - 1)
        readonly property real _indicatorSize: workspaceCapsule._iconSize + Math.max(6, Math.round(8 * Theme.uiScale))
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
            root._lerp(0.18, 0.34, workspaceCapsule._emphasis)
        )

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

            // Workspace content row.
            Row {
                anchors.centerIn: parent
                spacing: Theme.barWidget.badgePaddingH

                // Workspace label.
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

                // Workspace icon strip.
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
                                ? Math.abs(_workspaceFocusIndexPair.idx1 - _workspaceFocusIndexPair.idx2) * workspaceCapsule._indicatorStep + workspaceCapsule._indicatorSize
                                : workspaceCapsule._indicatorSize
                            height: workspaceCapsule._indicatorSize
                            radius: height / 2
                            color: workspaceCapsule._indicatorColor
                            opacity: workspaceCapsule._showFocusIndicator ? 1 : 0
                            visible: opacity > 0
                            x: workspaceCapsule._showFocusIndicator
                                ? Math.min(_workspaceFocusIndexPair.idx1, _workspaceFocusIndexPair.idx2) * workspaceCapsule._indicatorStep - workspaceCapsule._indicatorOffset
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
                        }
                    }

                    // Empty workspace label.
                    Text {
                        text: workspaceCapsule.capsule && (workspaceCapsule.capsule.icons || []).length === 0
                            ? root._workspaceLabel(workspaceCapsule.capsule.workspaceIndex)
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

        onStopped: {
            if (!root._workspaceSettlePending)
                return

            root._workspaceSettlePending = false
            root._settleWorkspaceStageSlots(root._hint)
        }
    }

    NumberAnimation {
        id: _titleAnchorAnimation

        target: root
        property: "_animatedTitleAnchor"
        easing.type: Theme.anim.moveType

        onStopped: {
            if (!root._titleSettlePending)
                return

            root._titleSettlePending = false
            root._settleTitleStageSlots(root._hint)
        }
    }

    SystemClock {
        id: _hintClock

        precision: SystemClock.Minutes
    }

    QtObject {
        id: _workspaceFocusIndexPair

        property int index: root._workspaceFocusIndex
        property real idx1: index
        property real idx2: index
        property int idx1Duration: root._workspaceFocusLeadDuration
        property int idx2Duration: root._workspaceFocusTrailDuration

        Behavior on idx1 {
            NumberAnimation {
                duration: _workspaceFocusIndexPair.idx1Duration
                easing.type: Easing.OutSine
            }
        }

        Behavior on idx2 {
            NumberAnimation {
                duration: _workspaceFocusIndexPair.idx2Duration
                easing.type: Easing.OutSine
            }
        }
    }

    Component.onCompleted: {
        root._renderHint = root._cloneHint(root._liveHint)
        root._refreshStageSlots(root._renderHint, false, false)
        root._retargetHintAnchors(root._renderHint, true)
    }

    Item {
        anchors.fill: parent

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.max(0, (root._headerHeight - implicitHeight) / 2)
            text: Qt.formatDateTime(_hintClock.date, "hh:mm")
            color: Colors.text
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeBody
            font.bold: true
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: root._headerHeight - 1
            width: Math.max(0, parent.width - root._padH * 2)
            height: 1
            radius: height / 2
            color: Colors.border
            opacity: 0.42
        }

        Item {
            id: _contentArea

            anchors {
                top: parent.top
                topMargin: root._headerHeight
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }

            // Main capsule stack.
            Column {
                anchors.centerIn: parent
                width: Math.max(root._workspaceStageWidth, root._titleStageWidth)
                spacing: root._rowGap

                Item {
                    width: parent.width
                    height: root._workspaceStageHeight

                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root._workspaceStageWidth
                        height: parent.height
                        clip: true

                        Repeater {
                            model: root._persistentStageSlotIndices

                            delegate: WorkspaceCapsule {
                                required property int modelData

                                capsule: root._workspaceStageCapsuleAt(modelData)
                                slotPosition: root._workspaceStageSlotPositionAt(modelData)
                                hiddenForMotion: false
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: root._titleStageHeight

                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root._titleStageWidth
                        height: parent.height

                        Repeater {
                            model: root._persistentStageSlotIndices

                            delegate: TitleCapsule {
                                required property int modelData

                                capsule: root._titleStageCapsuleAt(modelData)
                                slotPosition: root._titleStageSlotPositionAt(modelData)
                                hiddenForMotion: false
                            }
                        }
                    }
                }
            }
        }
    }
}
