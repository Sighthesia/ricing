.pragma library

function workspaceAnchorForHint(hint) {
    if (!hint || hint.visible !== true)
        return -1

    var position = hint.activeWorkspacePosition
    return position !== undefined && position >= 0 ? position : -1
}

function titleAnchorForHint(hint) {
    if (!hint || hint.visible !== true)
        return -1

    var currentIndex = hint.currentIndex !== undefined ? hint.currentIndex : -1
    if (currentIndex >= 0)
        return currentIndex

    return (hint.windows || []).length > 0 ? 0 : 0
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

function workspaceCapsuleForAbsolute(absoluteIndex, hint, workspaceLabelFn, transitionAnchor) {
    var safeHint = hint || {}
    var summaries = safeHint.workspaces || []
    var activePosition = workspaceAnchorForHint(safeHint)
    var transitionPosition = transitionAnchor !== undefined ? Math.round(transitionAnchor) : -1
    var summary = absoluteIndex >= 0 && absoluteIndex < summaries.length ? summaries[absoluteIndex] : null
    var isCurrent = absoluteIndex === activePosition
    var isTransitionCurrent = absoluteIndex === transitionPosition
    var isEdgePlaceholder = workspaceIsEdgePlaceholder(summaries, absoluteIndex, activePosition)
        || workspaceIsEdgePlaceholder(summaries, absoluteIndex, transitionPosition)
    var workspaceIndex = isCurrent
        ? (safeHint.workspaceIndex !== undefined ? safeHint.workspaceIndex : (summary ? summary.workspaceIndex : -1))
        : (summary ? summary.workspaceIndex : -1)

    return {
        key: (summary ? (summary.workspaceId || "workspace") : "workspace") + "-" + absoluteIndex,
        label: workspaceLabelFn(workspaceIndex),
        icons: isCurrent ? (safeHint.windows || []) : (summary && summary.icons ? summary.icons.slice() : []),
        workspaceIndex: workspaceIndex,
        visible: isEdgePlaceholder || workspaceCapsuleVisible(summary, isCurrent, isTransitionCurrent)
    }
}

function workspaceStageLayoutForHint(hint) {
    var layout = workspaceDisplayLayoutForHint(hint)
    return {
        hasBefore: layout.hasBefore,
        hasAfter: layout.hasAfter
    }
}

function visibleWorkspaceCountForHint(hint) {
    return workspaceDisplayLayoutForHint(hint).count
}

function visibleWorkspaceAbsoluteBoundsForHint(hint) {
    var layout = workspaceDisplayLayoutForHint(hint)
    return ({ first: layout.first, last: layout.last })
}

function visibleWorkspaceStageSlotCount(host) {
    var slots = host && host._workspaceStageSlots ? host._workspaceStageSlots : []
    var visibleCount = 0

    for (var index = 0; index < slots.length; index++) {
        var slot = slots[index]
        if (slot && slot.capsule && slot.capsule.visible)
            visibleCount += 1
    }

    return visibleCount
}

function visibleWorkspaceStageSlotBounds(host) {
    var slots = host && host._workspaceStageSlots ? host._workspaceStageSlots : []
    var first = -1
    var last = -1

    for (var index = 0; index < slots.length; index++) {
        var slot = slots[index]
        if (!slot || slot.absoluteIndex < 0 || !slot.capsule || !slot.capsule.visible)
            continue

        if (first < 0 || slot.absoluteIndex < first)
            first = slot.absoluteIndex
        if (last < 0 || slot.absoluteIndex > last)
            last = slot.absoluteIndex
    }

    return ({ first: first, last: last })
}

function titleCapsuleForAbsolute(absoluteIndex, hint) {
    var safeHint = hint || {}
    var windows = safeHint.windows || []

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

    var windowData = windows[absoluteIndex]
    var title = windowData ? (windowData.title || "") : ""

    return {
        key: (windowData ? (windowData.windowId || "window") : "window") + "-" + absoluteIndex,
        title: title,
        icon: windowData ? (windowData.icon || "") : "",
        visible: title !== "" || absoluteIndex === titleAnchorForHint(safeHint)
    }
}

function visibleAbsoluteRange(anchor, length) {
    if (length <= 0)
        return ({ from: 0, to: -1 })

    var resolvedAnchor = anchor >= 0 ? anchor : 0
    return {
        from: Math.max(0, Math.floor(resolvedAnchor) - 2),
        to: Math.min(length - 1, Math.ceil(resolvedAnchor) + 2)
    }
}

function visibleAbsoluteIndices(anchor, length) {
    var range = visibleAbsoluteRange(anchor, length)
    var items = []

    for (var index = range.from; index <= range.to; index++)
        items.push(index)

    return items
}

function mergedVisibleAbsoluteIndices(currentAnchor, targetAnchor, length) {
    var items = []
    var seen = ({})
    var targetRange = visibleAbsoluteRange(targetAnchor, length)
    var currentRange = visibleAbsoluteRange(currentAnchor, length)

    for (var index = targetRange.from; index <= targetRange.to; index++) {
        if (index < 0 || index >= length || seen[index])
            continue

        seen[index] = true
        items.push(index)
    }

    for (var i = currentRange.from; i <= currentRange.to; i++) {
        if (i < 0 || i >= length || seen[i])
            continue

        seen[i] = true
        items.push(i)
    }

    items.sort(function(left, right) { return left - right })
    return items
}

function workspaceStageCapsulesForHint(host, hint, includeCurrentAnchor, workspaceCapsuleForAbsoluteFn) {
    var safeHint = hint || {}
    var anchor = workspaceAnchorForHint(safeHint)
    var indices = includeCurrentAnchor
        ? mergedWorkspaceDisplayAbsoluteIndices(host, safeHint)
        : workspaceDisplayAbsoluteIndicesForHint(safeHint)
    var items = []

    for (var listIndex = 0; listIndex < indices.length; listIndex++) {
        var index = indices[listIndex]
        var capsule = workspaceCapsuleForAbsoluteFn(
            index,
            safeHint,
            includeCurrentAnchor ? host._animatedWorkspaceAnchor : undefined
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

function workspaceDisplayLayoutForHint(hint) {
    var safeHint = hint || {}
    var summaries = safeHint.workspaces || []
    var anchor = workspaceAnchorForHint(safeHint)

    return workspaceDisplayLayoutForAnchor(summaries, anchor)
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

function workspaceDisplayAbsoluteIndicesForHint(hint) {
    return workspaceDisplayAbsoluteIndicesForAnchor((hint || {}).workspaces || [], workspaceAnchorForHint(hint))
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

function titleStageCapsulesForHint(host, hint, includeCurrentAnchor, titleCapsuleForAbsoluteFn) {
    var safeHint = hint || {}
    var windows = safeHint.windows || []
    var anchor = titleAnchorForHint(safeHint)
    var items = []

    if (windows.length === 0) {
        items.push({
            key: "current-title-empty",
            capsule: titleCapsuleForAbsoluteFn(0, safeHint),
            absoluteIndex: 0
        })
        return items
    }

    var indices = includeCurrentAnchor
        ? mergedVisibleAbsoluteIndices(host._animatedTitleAnchor, anchor, windows.length)
        : visibleAbsoluteIndices(anchor, windows.length)

    for (var listIndex = 0; listIndex < indices.length; listIndex++) {
        var index = indices[listIndex]
        var capsule = titleCapsuleForAbsoluteFn(index, safeHint)
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

function workspaceStageSlotAt(host, slotIndex) {
    return slotIndex >= 0 && slotIndex < host._workspaceStageSlots.length
        ? host._workspaceStageSlots[slotIndex]
        : null
}

function titleStageSlotAt(host, slotIndex) {
    return slotIndex >= 0 && slotIndex < host._titleStageSlots.length
        ? host._titleStageSlots[slotIndex]
        : null
}

function workspaceStageCapsuleAt(host, slotIndex) {
    var slot = workspaceStageSlotAt(host, slotIndex)
    return slot ? slot.capsule : null
}

function workspaceStageAbsoluteIndexAt(host, slotIndex) {
    var slot = workspaceStageSlotAt(host, slotIndex)
    return slot && slot.absoluteIndex !== undefined ? slot.absoluteIndex : -1
}

function titleStageCapsuleAt(host, slotIndex) {
    var slot = titleStageSlotAt(host, slotIndex)
    return slot ? slot.capsule : null
}

function workspaceStageSlotPositionAt(host, slotIndex) {
    var slot = workspaceStageSlotAt(host, slotIndex)
    if (!slot || slot.absoluteIndex < 0 || host._animatedWorkspaceAnchor < 0)
        return host._overflowSlotPosition

    return slot.absoluteIndex - host._animatedWorkspaceAnchor
}

function titleStageSlotPositionAt(host, slotIndex) {
    var slot = titleStageSlotAt(host, slotIndex)
    if (!slot || slot.absoluteIndex < 0 || host._animatedTitleAnchor < 0)
        return host._overflowSlotPosition

    return slot.absoluteIndex - host._animatedTitleAnchor
}
