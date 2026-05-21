.pragma library

function workspaceAnchorForHint(hint) {
    if (!hint || hint.visible !== true)
        return -1

    var position = hint.activeWorkspacePosition
    return position !== undefined && position >= 0 ? position : -1
}

function workspaceSummaryHasContent(summary) {
    return !!(summary && summary.icons && summary.icons.length > 0)
}

function workspaceEdgePlaceholderIndex(summaries, anchor, step) {
    var safeSummaries = summaries || []
    var resolvedAnchor = anchor !== undefined ? Math.round(anchor) : -1

    if (resolvedAnchor < 0 || resolvedAnchor >= safeSummaries.length)
        return -1
    if (!workspaceSummaryHasContent(safeSummaries[resolvedAnchor]))
        return -1

    var candidate = resolvedAnchor + step
    if (candidate < 0 || candidate >= safeSummaries.length)
        return -1
    if (workspaceSummaryHasContent(safeSummaries[candidate]))
        return -1

    for (var index = candidate + step; index >= 0 && index < safeSummaries.length; index += step) {
        if (workspaceSummaryHasContent(safeSummaries[index]))
            return -1
    }

    return candidate
}

function workspaceIsEdgePlaceholder(summaries, absoluteIndex, anchor) {
    return absoluteIndex === workspaceEdgePlaceholderIndex(summaries, anchor, -1)
        || absoluteIndex === workspaceEdgePlaceholderIndex(summaries, anchor, 1)
}

function workspaceCapsuleVisible(summary, isCurrent, isTransitionCurrent) {
    return isCurrent || isTransitionCurrent || workspaceSummaryHasContent(summary)
}

function workspaceCapsuleForAbsolute(absoluteIndex, hint, transitionAnchor, transitionHint) {
    var safeHint = hint || {}
    var safeTransitionHint = transitionHint || null
    var summaries = safeHint.workspaces || []
    var activePosition = workspaceAnchorForHint(safeHint)
    var transitionPosition = safeTransitionHint ? workspaceAnchorForHint(safeTransitionHint) : -1
    var summary = absoluteIndex >= 0 && absoluteIndex < summaries.length ? summaries[absoluteIndex] : null
    var isCurrent = absoluteIndex === activePosition
    var isTransitionCurrent = transitionPosition >= 0 && absoluteIndex === transitionPosition && absoluteIndex !== activePosition
    var isEdgePlaceholder = workspaceIsEdgePlaceholder(summaries, absoluteIndex, activePosition)
        || (transitionPosition >= 0 && workspaceIsEdgePlaceholder(summaries, absoluteIndex, transitionPosition))
    var workspaceIndex = isCurrent
        ? (safeHint.workspaceIndex !== undefined ? safeHint.workspaceIndex : (summary ? summary.workspaceIndex : -1))
        : (isTransitionCurrent
            ? (safeTransitionHint.workspaceIndex !== undefined ? safeTransitionHint.workspaceIndex : (summary ? summary.workspaceIndex : -1))
        : (summary ? summary.workspaceIndex : -1)
        )

    return {
        key: (summary ? (summary.workspaceId || "workspace") : "workspace") + "-" + absoluteIndex,
        icons: isCurrent
            ? (safeHint.windows || [])
            : (isTransitionCurrent
                ? (safeTransitionHint.windows || [])
                : (summary && summary.icons ? summary.icons.slice() : [])),
        workspaceIndex: workspaceIndex,
        currentWindowTitle: isCurrent ? (safeHint.currentWindowTitle || "") : "",
        currentWindowIcon: isCurrent ? (safeHint.currentWindowIcon || "") : "",
        isCurrent: isCurrent,
        isTransitionCurrent: isTransitionCurrent,
        isEdgePlaceholder: isEdgePlaceholder,
        visible: isEdgePlaceholder || workspaceCapsuleVisible(summary, isCurrent, isTransitionCurrent)
    }
}

function workspaceDisplayLayoutForHint(hint) {
    var safeHint = hint || {}
    return workspaceDisplayLayoutForAnchor(safeHint.workspaces || [], workspaceAnchorForHint(safeHint))
}

function workspaceDisplayLayoutForAnchor(summaries, anchor) {
    var resolvedAnchor = anchor !== undefined ? Math.round(anchor) : -1
    var safeSummaries = summaries || []
    var beforeIndex = -1
    var afterIndex = -1

    if (resolvedAnchor < 0 || resolvedAnchor >= safeSummaries.length) {
        return {
            first: -1,
            last: -1,
            count: 0,
            hasBefore: false,
            hasAfter: false
        }
    }

    for (var before = resolvedAnchor - 1; before >= 0; before--) {
        if (!workspaceSummaryHasContent(safeSummaries[before]))
            continue

        beforeIndex = before
        break
    }

    for (var after = resolvedAnchor + 1; after < safeSummaries.length; after++) {
        if (!workspaceSummaryHasContent(safeSummaries[after]))
            continue

        afterIndex = after
        break
    }

    if (beforeIndex < 0)
        beforeIndex = workspaceEdgePlaceholderIndex(safeSummaries, resolvedAnchor, -1)

    if (afterIndex < 0)
        afterIndex = workspaceEdgePlaceholderIndex(safeSummaries, resolvedAnchor, 1)

    if (beforeIndex >= 0 && afterIndex >= 0) {
        return {
            first: beforeIndex,
            last: afterIndex,
            count: 3,
            hasBefore: true,
            hasAfter: true
        }
    }

    if (beforeIndex >= 0) {
        return {
            first: beforeIndex,
            last: resolvedAnchor,
            count: 2,
            hasBefore: true,
            hasAfter: false
        }
    }

    if (afterIndex >= 0) {
        return {
            first: resolvedAnchor,
            last: afterIndex,
            count: 2,
            hasBefore: false,
            hasAfter: true
        }
    }

    return {
        first: resolvedAnchor,
        last: resolvedAnchor,
        count: 1,
        hasBefore: false,
        hasAfter: false
    }
}

function workspaceDisplayAbsoluteIndicesForAnchor(summaries, anchor) {
    var layout = workspaceDisplayLayoutForAnchor(summaries, anchor)
    var items = []

    for (var index = layout.first; index <= layout.last; index++) {
        if (index >= 0)
            items.push(index)
    }

    return items
}

function visibleWorkspaceStageAbsoluteIndices(host) {
    var slots = host && host._workspaceStageSlots ? host._workspaceStageSlots : []
    var items = []
    var seen = ({})

    for (var index = 0; index < slots.length; index++) {
        var slot = slots[index]
        if (!slot || slot.absoluteIndex < 0 || !slot.capsule || slot.capsule.visible !== true)
            continue
        if (seen[slot.absoluteIndex])
            continue

        seen[slot.absoluteIndex] = true
        items.push(slot.absoluteIndex)
    }

    return items
}

function mergedWorkspaceDisplayAbsoluteIndices(host, hint) {
    var safeHint = hint || {}
    var summaries = safeHint.workspaces || []
    var targetAnchor = workspaceAnchorForHint(safeHint)
    var items = []
    var seen = ({})
    var targetItems = workspaceDisplayAbsoluteIndicesForAnchor(summaries, targetAnchor)
    var currentItems = visibleWorkspaceStageAbsoluteIndices(host)

    if (currentItems.length === 0)
        currentItems = workspaceDisplayAbsoluteIndicesForAnchor(summaries, host ? host._animatedWorkspaceAnchor : -1)

    for (var currentIndex = 0; currentIndex < currentItems.length; currentIndex++) {
        var currentAbsoluteIndex = currentItems[currentIndex]
        if (seen[currentAbsoluteIndex])
            continue

        seen[currentAbsoluteIndex] = true
        items.push(currentAbsoluteIndex)
    }

    for (var index = 0; index < targetItems.length; index++) {
        var targetAbsoluteIndex = targetItems[index]
        if (seen[targetAbsoluteIndex])
            continue

        seen[targetAbsoluteIndex] = true
        items.push(targetAbsoluteIndex)
    }

    return items
}

function workspaceStageCapsulesForHint(host, hint, includeCurrentAnchor) {
    var safeHint = hint || {}
    var transitionHint = includeCurrentAnchor ? (host ? host._transitionSourceHint : null) : null
    var indices = includeCurrentAnchor
        ? mergedWorkspaceDisplayAbsoluteIndices(host, safeHint)
        : workspaceDisplayAbsoluteIndicesForAnchor(safeHint.workspaces || [], workspaceAnchorForHint(safeHint))
    var items = []

    for (var listIndex = 0; listIndex < indices.length; listIndex++) {
        var index = indices[listIndex]
        var capsule = workspaceCapsuleForAbsolute(
            index,
            safeHint,
            includeCurrentAnchor ? host._animatedWorkspaceAnchor : undefined,
            transitionHint
        )
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

function workspaceStageSlotPositionAt(host, slotIndex) {
    var slots = host && host._workspaceStageSlots ? host._workspaceStageSlots : []
    var slot = slotIndex >= 0 && slotIndex < slots.length ? slots[slotIndex] : null
    if (!slot || slot.absoluteIndex < 0 || host._animatedWorkspaceAnchor < 0)
        return host._overflowSlotPosition

    return slot.absoluteIndex - host._animatedWorkspaceAnchor
}
