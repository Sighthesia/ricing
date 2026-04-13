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

function workspaceCapsuleVisible(summary, isCurrent) {
    return isCurrent || workspaceSummaryHasContent(summary)
}

function workspaceCapsuleForAbsolute(absoluteIndex, hint, workspaceLabelFn) {
    var safeHint = hint || {}
    var summaries = safeHint.workspaces || []
    var activePosition = workspaceAnchorForHint(safeHint)
    var summary = absoluteIndex >= 0 && absoluteIndex < summaries.length ? summaries[absoluteIndex] : null
    var isCurrent = absoluteIndex === activePosition
    var workspaceIndex = isCurrent
        ? (safeHint.workspaceIndex !== undefined ? safeHint.workspaceIndex : (summary ? summary.workspaceIndex : -1))
        : (summary ? summary.workspaceIndex : -1)

    return {
        key: (summary ? (summary.workspaceId || "workspace") : "workspace") + "-" + absoluteIndex,
        label: workspaceLabelFn(workspaceIndex),
        icons: isCurrent ? (safeHint.windows || []) : (summary && summary.icons ? summary.icons.slice() : []),
        workspaceIndex: workspaceIndex,
        visible: workspaceCapsuleVisible(summary, isCurrent)
    }
}

function workspaceStageLayoutForHint(hint) {
    var safeHint = hint || {}
    var summaries = safeHint.workspaces || []
    var anchor = workspaceAnchorForHint(safeHint)
    var layout = {
        hasBefore: false,
        hasAfter: false
    }

    if (anchor < 0 || anchor >= summaries.length)
        return layout

    var range = visibleAbsoluteRange(anchor, summaries.length)

    for (var index = range.from; index <= range.to; index++) {
        if (index === anchor)
            continue

        var summary = summaries[index]
        if (!workspaceCapsuleVisible(summary, false))
            continue

        if (index < anchor)
            layout.hasBefore = true
        else if (index > anchor)
            layout.hasAfter = true
    }

    return layout
}

function visibleWorkspaceCountForHint(hint) {
    var safeHint = hint || {}
    var summaries = safeHint.workspaces || []
    var anchor = workspaceAnchorForHint(safeHint)
    var visibleCount = 0

    for (var index = 0; index < summaries.length; index++) {
        if (workspaceCapsuleVisible(summaries[index], index === anchor))
            visibleCount += 1
    }

    return visibleCount
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
    var summaries = safeHint.workspaces || []
    var anchor = workspaceAnchorForHint(safeHint)
    var indices = includeCurrentAnchor
        ? mergedVisibleAbsoluteIndices(host._animatedWorkspaceAnchor, anchor, summaries.length)
        : visibleAbsoluteIndices(anchor, summaries.length)
    var items = []

    for (var listIndex = 0; listIndex < indices.length; listIndex++) {
        var index = indices[listIndex]
        var capsule = workspaceCapsuleForAbsoluteFn(index, safeHint)
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
