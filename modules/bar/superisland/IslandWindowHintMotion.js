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
        host._animatedWorkspaceAnchor = target
        return
    }

    var currentAnchor = host._animatedWorkspaceAnchor
    var duration = anchorAnimationDuration(host, currentAnchor, target, host._workspaceAnchorBaseDuration)
    if (duration === 0) {
        host._animatedWorkspaceAnchor = target
        return
    }

    workspaceAnimation.from = currentAnchor
    workspaceAnimation.to = target
    workspaceAnimation.duration = duration
    host._workspaceSettlePending = true
    workspaceAnimation.start()
}

function retargetTitleAnchor(host, target, immediate, titleAnimation) {
    host._titleSettlePending = false
    titleAnimation.stop()

    if (immediate || target < 0 || host._animatedTitleAnchor < 0) {
        host._animatedTitleAnchor = target
        return
    }

    var currentAnchor = host._animatedTitleAnchor
    var duration = anchorAnimationDuration(host, currentAnchor, target, host._titleAnchorBaseDuration)
    if (duration === 0) {
        host._animatedTitleAnchor = target
        return
    }

    titleAnimation.from = currentAnchor
    titleAnimation.to = target
    titleAnimation.duration = duration
    host._titleSettlePending = true
    titleAnimation.start()
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

function workspaceMetrics(host, slotPosition, lerpFn) {
    var topY = -host._workspaceLeadingTrim
    var centerY = host._workspaceSideHeight + host._workspaceColumnGap - host._workspaceLeadingTrim
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
