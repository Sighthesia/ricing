.pragma library

function refreshStageSlots(host, hint, includeCurrentAnchor, preserveUnassigned, stageApi, cloneApi) {
    host._workspaceStageSlots = cloneApi.slotsForEntries(
        host._persistentStageSlotIndices,
        host._workspaceStageSlots,
        stageApi.workspaceStageCapsulesForHint(host, hint, includeCurrentAnchor, stageApi.workspaceCapsuleForAbsolute),
        cloneApi.cloneWorkspaceCapsule,
        "workspace-slot",
        preserveUnassigned
    )

    host._titleStageSlots = cloneApi.slotsForEntries(
        host._persistentStageSlotIndices,
        host._titleStageSlots,
        stageApi.titleStageCapsulesForHint(host, hint, includeCurrentAnchor, stageApi.titleCapsuleForAbsolute),
        cloneApi.cloneTitleCapsule,
        "title-slot",
        preserveUnassigned
    )
}

function settleWorkspaceStageSlots(host, hint, stageApi, cloneApi) {
    host._workspaceStageSlots = cloneApi.slotsForEntries(
        host._persistentStageSlotIndices,
        host._workspaceStageSlots,
        stageApi.workspaceStageCapsulesForHint(host, hint, false, stageApi.workspaceCapsuleForAbsolute),
        cloneApi.cloneWorkspaceCapsule,
        "workspace-slot",
        false
    )
}

function retireWorkspaceStageSlots(host, hint, stageApi, cloneApi) {
    var entries = stageApi.workspaceStageCapsulesForHint(host, hint, false, stageApi.workspaceCapsuleForAbsolute)
    var slots = cloneApi.slotsForEntries(
        host._persistentStageSlotIndices,
        host._workspaceStageSlots,
        entries,
        cloneApi.cloneWorkspaceCapsule,
        "workspace-slot",
        true
    )
    var activeIndices = ({})
    var hasRetiring = false

    for (var entryIndex = 0; entryIndex < entries.length; entryIndex++)
        activeIndices[entries[entryIndex].absoluteIndex] = true

    for (var slotIndex = 0; slotIndex < slots.length; slotIndex++) {
        var slot = slots[slotIndex]
        if (!slot || slot.absoluteIndex < 0 || !slot.capsule)
            continue
        if (activeIndices[slot.absoluteIndex])
            continue
        if (slot.capsule.visible === false)
            continue

        slot = cloneApi.cloneStageSlot ? cloneApi.cloneStageSlot(slot, cloneApi.cloneWorkspaceCapsule, slot.slotId) : {
            slotId: slot.slotId,
            absoluteIndex: slot.absoluteIndex,
            workspaceIndex: slot.workspaceIndex,
            capsule: cloneApi.cloneWorkspaceCapsule(slot.capsule)
        }
        slot.capsule.visible = false
        slots[slotIndex] = slot
        hasRetiring = true
    }

    host._workspaceStageSlots = slots
    return hasRetiring
}

function cleanupWorkspaceStageSlots(host, hint, stageApi, cloneApi) {
    settleWorkspaceStageSlots(host, hint, stageApi, cloneApi)
}

function settleTitleStageSlots(host, hint, stageApi, cloneApi) {
    host._titleStageSlots = cloneApi.slotsForEntries(
        host._persistentStageSlotIndices,
        host._titleStageSlots,
        stageApi.titleStageCapsulesForHint(host, hint, false, stageApi.titleCapsuleForAbsolute),
        cloneApi.cloneTitleCapsule,
        "title-slot",
        false
    )
}

function anchorAnimationDuration(host, from, to, baseDuration) {
    var distance = Math.abs(to - from)
    if (distance <= 0.001)
        return 0

    return Math.min(
        host._anchorMaximumDuration,
        Math.round(baseDuration + Math.max(0, distance - 1) * host._anchorDurationStep)
    )
}

function retargetWorkspaceAnchor(host, target, immediate, workspaceAnimation) {
    host._workspaceSettlePending = false
    workspaceAnimation.stop()

    if (immediate || target < 0 || host._animatedWorkspaceAnchor < 0) {
        host._workspaceAnchorAnimationEnabled = false
        host._workspaceAnchorDuration = host._workspaceAnchorBaseDuration
        host._workspaceAnchorTarget = target
        host._animatedWorkspaceAnchor = target
        host._workspaceAnchorAnimationEnabled = true
        return
    }

    var currentAnchor = host._animatedWorkspaceAnchor
    var duration = anchorAnimationDuration(host, currentAnchor, target, host._workspaceAnchorBaseDuration)
    if (duration === 0) {
        host._workspaceAnchorAnimationEnabled = false
        host._workspaceAnchorDuration = host._workspaceAnchorBaseDuration
        host._workspaceAnchorTarget = target
        host._animatedWorkspaceAnchor = target
        host._workspaceAnchorAnimationEnabled = true
        return
    }

    host._workspaceAnchorDuration = duration
    host._workspaceSettlePending = true
    host._workspaceAnchorTarget = target
    host._animatedWorkspaceAnchor = target
    workspaceAnimation.interval = Math.max(1, duration + 1)
    workspaceAnimation.restart()
}

function retargetTitleAnchor(host, target, immediate, titleAnimation) {
    host._titleSettlePending = false
    titleAnimation.stop()

    if (immediate || target < 0 || host._animatedTitleAnchor < 0) {
        host._titleAnchorAnimationEnabled = false
        host._titleAnchorDuration = host._titleAnchorBaseDuration
        host._titleAnchorTarget = target
        host._animatedTitleAnchor = target
        host._titleAnchorAnimationEnabled = true
        return
    }

    var currentAnchor = host._animatedTitleAnchor
    var duration = anchorAnimationDuration(host, currentAnchor, target, host._titleAnchorBaseDuration)
    if (duration === 0) {
        host._titleAnchorAnimationEnabled = false
        host._titleAnchorDuration = host._titleAnchorBaseDuration
        host._titleAnchorTarget = target
        host._animatedTitleAnchor = target
        host._titleAnchorAnimationEnabled = true
        return
    }

    host._titleAnchorDuration = duration
    host._titleSettlePending = true
    host._titleAnchorTarget = target
    host._animatedTitleAnchor = target
    titleAnimation.interval = Math.max(1, duration + 1)
    titleAnimation.restart()
}

function focusedWorkspaceIconIndexForHint(hint) {
    var windows = hint && hint.windows ? hint.windows : []

    for (var index = 0; index < windows.length; index++) {
        if (windows[index] && windows[index].isFocused)
            return index
    }

    return -1
}

function retargetWorkspaceFocusIndicator(host, hint, immediate) {
    var focusedIndex = focusedWorkspaceIconIndexForHint(hint)
    host._workspaceFocusIndex = focusedIndex
}

function retargetHintAnchors(host, hint, immediate, workspaceAnimation, titleAnimation, stageApi) {
    retargetWorkspaceAnchor(host, stageApi.workspaceAnchorForHint(hint), immediate, workspaceAnimation)
    retargetTitleAnchor(host, stageApi.titleAnchorForHint(hint), immediate, titleAnimation)
    retargetWorkspaceFocusIndicator(host, hint, immediate)
}

function workspaceMetrics(host, slotPosition, absoluteIndex, lerpFn) {
    if (host._workspaceUsesBinaryLayout
        && absoluteIndex >= host._workspaceVisibleStart
        && absoluteIndex <= host._workspaceVisibleEnd) {
        var visibleTop = host._workspaceSingleSideTrim / 2
        var binaryGap = host._workspaceColumnGap
        var binaryAnchor = host._workspaceBinaryAnchorProgress
        var relativeIndex = Math.max(0, absoluteIndex - host._workspaceVisibleStart)
        var emphasis = Math.max(0, 1 - Math.abs(relativeIndex - binaryAnchor))
        var width = lerpFn(host._workspaceSideWidth, host._workspacePrimaryWidth, emphasis)
        var topHeight = lerpFn(host._workspacePrimaryHeight, host._workspaceSideHeight, binaryAnchor)
        var bottomHeight = lerpFn(host._workspaceSideHeight, host._workspacePrimaryHeight, binaryAnchor)

        return {
            x: (host._workspaceStageWidth - width) / 2,
            y: relativeIndex === 0 ? visibleTop : (visibleTop + topHeight + binaryGap),
            width: width,
            height: relativeIndex === 0 ? topHeight : bottomHeight,
            emphasis: emphasis,
            opacity: lerpFn(0.5, 1, emphasis)
        }
    }

    var topY = 0
    var centerY = host._workspaceSideHeight + host._workspaceColumnGap
    var bottomY = centerY + host._workspacePrimaryHeight + host._workspaceColumnGap

    if (slotPosition < -1) {
        var beforeOverflow = Math.min(1, -1 - slotPosition)
        return {
            x: (host._workspaceStageWidth - host._workspaceSideWidth) / 2,
            y: topY - beforeOverflow * (host._workspaceSideHeight + host._workspaceColumnGap),
            width: host._workspaceSideWidth,
            height: host._workspaceSideHeight,
            emphasis: 0,
            opacity: 0.45
        }
    }

    if (slotPosition > 1) {
        var afterOverflow = Math.min(1, slotPosition - 1)
        return {
            x: (host._workspaceStageWidth - host._workspaceSideWidth) / 2,
            y: bottomY + afterOverflow * (host._workspaceSideHeight + host._workspaceColumnGap),
            width: host._workspaceSideWidth,
            height: host._workspaceSideHeight,
            emphasis: 0,
            opacity: 0.45
        }
    }

    var clamped = Math.max(-1, Math.min(1, slotPosition))

    if (clamped <= 0) {
        var leftProgress = clamped + 1
        var leftWidth = lerpFn(host._workspaceSideWidth, host._workspacePrimaryWidth, leftProgress)
        return {
            x: (host._workspaceStageWidth - leftWidth) / 2,
            y: lerpFn(topY, centerY, leftProgress),
            width: leftWidth,
            height: lerpFn(host._workspaceSideHeight, host._workspacePrimaryHeight, leftProgress),
            emphasis: leftProgress,
            opacity: lerpFn(0.5, 1, leftProgress)
        }
    }

    var rightProgress = clamped
    var rightWidth = lerpFn(host._workspacePrimaryWidth, host._workspaceSideWidth, rightProgress)
    return {
        x: (host._workspaceStageWidth - rightWidth) / 2,
        y: lerpFn(centerY, bottomY, rightProgress),
        width: rightWidth,
        height: lerpFn(host._workspacePrimaryHeight, host._workspaceSideHeight, rightProgress),
        emphasis: 1 - rightProgress,
        opacity: lerpFn(1, 0.5, rightProgress)
    }
}

function titleMetrics(host, slotPosition, lerpFn) {
    var leftX = 0
    var centerX = host._titleSideWidth + host._capsuleGap
    var rightX = centerX + host._titlePrimaryWidth + host._capsuleGap

    if (slotPosition < -1) {
        var beforeOverflow = Math.min(1, -1 - slotPosition)
        return {
            x: leftX - beforeOverflow * (host._titleSideWidth + host._capsuleGap),
            width: host._titleSideWidth,
            emphasis: 0,
            opacity: 0.68
        }
    }

    if (slotPosition > 1) {
        var afterOverflow = Math.min(1, slotPosition - 1)
        return {
            x: rightX + afterOverflow * (host._titleSideWidth + host._capsuleGap),
            width: host._titleSideWidth,
            emphasis: 0,
            opacity: 0.68
        }
    }

    var clamped = Math.max(-1, Math.min(1, slotPosition))

    if (clamped <= 0) {
        var leftProgress = clamped + 1
        return {
            x: lerpFn(leftX, centerX, leftProgress),
            width: lerpFn(host._titleSideWidth, host._titlePrimaryWidth, leftProgress),
            emphasis: leftProgress,
            opacity: lerpFn(0.68, 1, leftProgress)
        }
    }

    var rightProgress = clamped
    return {
        x: lerpFn(centerX, rightX, rightProgress),
        width: lerpFn(host._titlePrimaryWidth, host._titleSideWidth, rightProgress),
        emphasis: 1 - rightProgress,
        opacity: lerpFn(1, 0.68, rightProgress)
    }
}

function handleHintChange(host, liveHint, workspaceAnimation, titleAnimation, cloneApi, stageApi, motionApi) {
    var nextHint = cloneApi.cloneHint(liveHint)

    if (!nextHint || !nextHint.visible) {
        if (host._hostKeepsHintVisible && host._renderHint && host._renderHint.visible)
            return

        host._renderHint = nextHint
        refreshStageSlots(host, nextHint, false, false, stageApi, cloneApi)
        retargetHintAnchors(host, nextHint, true, workspaceAnimation, titleAnimation, stageApi)
        return
    }

    var wasVisible = !!(host._renderHint && host._renderHint.visible)
    host._renderHint = nextHint
    refreshStageSlots(host, nextHint, wasVisible, wasVisible, stageApi, cloneApi)
    retargetHintAnchors(host, nextHint, !wasVisible, workspaceAnimation, titleAnimation, stageApi)
}
