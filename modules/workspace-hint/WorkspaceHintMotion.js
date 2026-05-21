.pragma library

function _cloneIcons(items) {
    var safeItems = items || []
    var copies = []

    for (var index = 0; index < safeItems.length; index++)
        copies.push(Object.assign({}, safeItems[index]))

    return copies
}

function cloneWorkspaceCapsule(capsule) {
    if (!capsule)
        return null

    return {
        key: capsule.key || "",
        icons: _cloneIcons(capsule.icons),
        workspaceIndex: capsule.workspaceIndex !== undefined ? capsule.workspaceIndex : -1,
        currentWindowTitle: capsule.currentWindowTitle || "",
        currentWindowIcon: capsule.currentWindowIcon || "",
        isCurrent: capsule.isCurrent === true,
        isTransitionCurrent: capsule.isTransitionCurrent === true,
        isEdgePlaceholder: capsule.isEdgePlaceholder === true,
        visible: capsule.visible === true
    }
}

function emptyStageSlots(slotIndices, prefix) {
    var safeIndices = slotIndices || []
    var items = []

    for (var index = 0; index < safeIndices.length; index++) {
        items.push({
            slotId: prefix + "-" + index,
            absoluteIndex: -1,
            capsule: null
        })
    }

    return items
}

function _cloneStageSlot(slot) {
    return {
        slotId: slot.slotId,
        absoluteIndex: slot.absoluteIndex,
        capsule: cloneWorkspaceCapsule(slot.capsule)
    }
}

function _stageSlotsFrom(slotIndices, currentSlots, prefix) {
    var safeIndices = slotIndices || []
    var safeCurrent = currentSlots || []
    var items = []

    for (var index = 0; index < safeIndices.length; index++) {
        var slotId = prefix + "-" + index
        var currentSlot = index < safeCurrent.length ? safeCurrent[index] : null
        items.push(currentSlot ? _cloneStageSlot(currentSlot) : {
            slotId: slotId,
            absoluteIndex: -1,
            capsule: null
        })
    }

    return items
}

function _slotsForEntries(slotIndices, existingSlots, entries, preserveUnassigned) {
    var current = _stageSlotsFrom(slotIndices, existingSlots, "workspace-slot")
    var slots = emptyStageSlots(slotIndices, "workspace-slot")
    var safeEntries = entries || []
    var assignedSlots = ({})

    for (var entryIndex = 0; entryIndex < Math.min(slots.length, safeEntries.length); entryIndex++) {
        var entry = safeEntries[entryIndex]
        var slotIndex = -1

        for (var i = 0; i < current.length; i++) {
            if (assignedSlots[i])
                continue
            if (current[i].absoluteIndex !== entry.absoluteIndex)
                continue

            slotIndex = i
            break
        }

        if (slotIndex < 0) {
            for (var j = 0; j < current.length; j++) {
                if (assignedSlots[j])
                    continue
                if (current[j].absoluteIndex >= 0
                        && (!current[j].capsule || current[j].capsule.visible !== false))
                    continue

                slotIndex = j
                break
            }
        }

        if (slotIndex < 0) {
            for (var k = 0; k < current.length; k++) {
                if (assignedSlots[k])
                    continue

                slotIndex = k
                break
            }
        }

        if (slotIndex < 0)
            break

        assignedSlots[slotIndex] = true
        slots[slotIndex] = {
            slotId: current[slotIndex].slotId,
            absoluteIndex: entry.absoluteIndex,
            capsule: cloneWorkspaceCapsule(entry.capsule)
        }
    }

    if (preserveUnassigned) {
        for (var n = 0; n < current.length; n++) {
            if (assignedSlots[n])
                continue
            if (current[n].absoluteIndex < 0 || !current[n].capsule)
                continue
            if (current[n].capsule.visible === false)
                continue

            slots[n] = _cloneStageSlot(current[n])
        }
    }

    return slots
}

function refreshStageSlots(host, hint, includeCurrentAnchor, preserveUnassigned, stageApi) {
    host._workspaceStageSlots = _slotsForEntries(
        host._persistentStageSlotIndices,
        host._workspaceStageSlots,
        stageApi.workspaceStageCapsulesForHint(host, hint, includeCurrentAnchor),
        preserveUnassigned
    )
}

function settleWorkspaceStageSlots(host, hint, stageApi) {
    host._workspaceStageSlots = _slotsForEntries(
        host._persistentStageSlotIndices,
        host._workspaceStageSlots,
        stageApi.workspaceStageCapsulesForHint(host, hint, false),
        false
    )
    host._transitionSourceHint = null
}

function retireWorkspaceStageSlots(host, hint, stageApi) {
    var entries = stageApi.workspaceStageCapsulesForHint(host, hint, false)
    var slots = _slotsForEntries(
        host._persistentStageSlotIndices,
        host._workspaceStageSlots,
        entries,
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

        slot = _cloneStageSlot(slot)
        slot.capsule.visible = false
        slots[slotIndex] = slot
        hasRetiring = true
    }

    host._workspaceStageSlots = slots
    return hasRetiring
}

function cleanupWorkspaceStageSlots(host, hint, stageApi) {
    settleWorkspaceStageSlots(host, hint, stageApi)
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
        host._workspaceCapsuleOpacityDuration = host._workspaceAnchorBaseDuration
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
        host._workspaceCapsuleOpacityDuration = host._workspaceAnchorBaseDuration
        host._workspaceAnchorTarget = target
        host._animatedWorkspaceAnchor = target
        host._workspaceAnchorAnimationEnabled = true
        return
    }

    host._workspaceAnchorDuration = duration
    host._workspaceCapsuleOpacityDuration = duration
    host._workspaceSettlePending = true
    host._workspaceAnchorTarget = target
    host._animatedWorkspaceAnchor = target
    workspaceAnimation.interval = Math.max(1, duration + 1)
    workspaceAnimation.restart()
}

function handleHintChange(host, liveHint, workspaceAnimation, stageApi) {
    var nextHint = liveHint || null
    var immediate = !host._renderHint || !host._renderHint.visible || host._animatedWorkspaceAnchor < 0
    var previousHint = host._renderHint || null

    host._transitionSourceHint = immediate ? null : previousHint
    host._renderHint = nextHint
    refreshStageSlots(host, nextHint, !immediate, true, stageApi)
    if (!immediate)
        retireWorkspaceStageSlots(host, nextHint, stageApi)
    retargetWorkspaceAnchor(host, stageApi.workspaceAnchorForHint(nextHint), immediate, workspaceAnimation)
    if (immediate) {
        settleWorkspaceStageSlots(host, nextHint, stageApi)
        host._transitionSourceHint = null
    }
}

function _lerp(from, to, progress) {
    return from + (to - from) * progress
}

function workspaceMetrics(host, slotPosition) {
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
        var leftWidth = _lerp(host._workspaceSideWidth, host._workspacePrimaryWidth, leftProgress)
        return {
            x: (host._workspaceStageWidth - leftWidth) / 2,
            y: _lerp(topY, centerY, leftProgress),
            width: leftWidth,
            height: _lerp(host._workspaceSideHeight, host._workspacePrimaryHeight, leftProgress),
            emphasis: leftProgress,
            opacity: _lerp(0.5, 1, leftProgress)
        }
    }

    var rightProgress = clamped
    var rightWidth = _lerp(host._workspacePrimaryWidth, host._workspaceSideWidth, rightProgress)
    return {
        x: (host._workspaceStageWidth - rightWidth) / 2,
        y: _lerp(centerY, bottomY, rightProgress),
        width: rightWidth,
        height: _lerp(host._workspacePrimaryHeight, host._workspaceSideHeight, rightProgress),
        emphasis: 1 - rightProgress,
        opacity: _lerp(1, 0.5, rightProgress)
    }
}
