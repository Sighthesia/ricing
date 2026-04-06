.pragma library

function setBarMetrics(currentWidth, currentPadding, contentWidth, padding) {
    var nextContentWidth = Math.max(0, Number(contentWidth) || 0)
    var nextPadding = Math.max(0, Number(padding) || 0)

    return {
        changed: !(currentWidth === nextContentWidth && currentPadding === nextPadding),
        barContentWidth: nextContentWidth,
        barContentPadding: nextPadding
    }
}

function setTransientExtension(transientExtensions, ownerKey, height) {
    if (!ownerKey) {
        return {
            accepted: false,
            changed: false,
            transientExtensions: transientExtensions
        }
    }

    var nextHeight = Math.max(0, Number(height) || 0)
    var nextExtensions = Object.assign({}, transientExtensions)

    if (nextExtensions[ownerKey] === nextHeight) {
        return {
            accepted: true,
            changed: false,
            transientExtensions: transientExtensions
        }
    }

    nextExtensions[ownerKey] = nextHeight

    return {
        accepted: true,
        changed: true,
        transientExtensions: nextExtensions
    }
}

function clearTransientExtension(transientExtensions, ownerKey) {
    if (!ownerKey || transientExtensions[ownerKey] === undefined) {
        return {
            accepted: false,
            changed: false,
            transientExtensions: transientExtensions
        }
    }

    var nextExtensions = Object.assign({}, transientExtensions)
    delete nextExtensions[ownerKey]

    return {
        accepted: true,
        changed: true,
        transientExtensions: nextExtensions
    }
}

function maxTransientExtension(transientExtensions) {
    var maxHeight = 0

    for (var ownerKey in transientExtensions) {
        var nextHeight = Math.max(0, Number(transientExtensions[ownerKey]) || 0)

        if (nextHeight > maxHeight)
            maxHeight = nextHeight
    }

    return maxHeight
}

function dragStateSnapshot(service) {
    return {
        isDragging: service.isDragging,
        dragHoverZone: service.dragHoverZone,
        draggedWidgetId: service.draggedWidgetId,
        draggedInstanceKey: service.draggedInstanceKey,
        dragVisualX: service.dragVisualX,
        dragVisualCenterX: service.dragVisualCenterX,
        draggedWidth: service.draggedWidth,
        ghostSection: service.ghostSection,
        ghostIndex: service.ghostIndex
    }
}

function applyDragState(service, nextState) {
    service.isDragging = nextState.isDragging
    service.dragHoverZone = nextState.dragHoverZone
    service.draggedWidgetId = nextState.draggedWidgetId
    service.draggedInstanceKey = nextState.draggedInstanceKey
    service.dragVisualX = nextState.dragVisualX
    service.dragVisualCenterX = nextState.dragVisualCenterX
    service.draggedWidth = nextState.draggedWidth
    service.ghostSection = nextState.ghostSection
    service.ghostIndex = nextState.ghostIndex
}
